package configuration_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// Execute the actual wrapper with synthetic Podman secrets and a recorded restic
// invocation. No privilege change, containers or backup repositories are involved.
func TestResticReadsCurrentPodmanSecrets(t *testing.T) {
	repo, err := filepath.Abs("..")
	noError(t, err)
	dir := t.TempDir()
	write := func(name, content string) {
		noError(t, os.WriteFile(filepath.Join(dir, name), []byte(content), 0700))
	}
	write("id", "#!/bin/sh\nprintf 1000\n")
	write("runuser", `#!/bin/sh
set -eu
test "$1 $2 $3" = '-u homelab --'
shift 3
exec "$@"
`)
	write("podman", `#!/bin/bash
set -eu
test "$XDG_RUNTIME_DIR" = /run/user/1000
test "$1 $2 $3 $4 $5" = 'secret inspect --showsecret --format {{.SecretData}}'
printf '%s\n' "$6" >> "$CALLS"
cat "$FIXTURES/$6"
`)
	write("restic", `#!/bin/bash
set -eu
test -z "${RESTIC_PASSWORD_FILE-}"
test -z "${RESTIC_PASSWORD_COMMAND-}"
printf '%s\0' "$RESTIC_PASSWORD" "${B2_ACCOUNT_ID-}" "${B2_ACCOUNT_KEY-}" "${AWS_ACCESS_KEY_ID-}" "${AWS_SECRET_ACCESS_KEY-}" "$@" > "$RESULT"
exit "${RESTIC_EXIT:-0}"
`)
	for name, value := range map[string]string{
		"restic-password":      "synthetic password with $ and ' and \"",
		"restic-b2-account-id": "synthetic-b2-id", "restic-b2-account-key": "synthetic-b2-key",
		"restic-aws-access-key-id": "synthetic-aws-id", "restic-aws-secret-access-key": "synthetic-aws-key",
	} {
		write(name, value)
	}
	run := func(backend string, extraEnv ...string) ([]string, error) {
		_ = os.Remove(filepath.Join(dir, "result"))
		write("calls", "")
		command := exec.CommandContext(t.Context(), "bash", filepath.Join(repo, "butane/restic-with-secrets.sh"), backend, "-r", "synthetic repository", "backup", "synthetic path")
		command.Env = append(os.Environ(),
			"PATH="+dir+":"+os.Getenv("PATH"), "FIXTURES="+dir, "CALLS="+filepath.Join(dir, "calls"), "RESULT="+filepath.Join(dir, "result"),
			"B2_ACCOUNT_ID=", "B2_ACCOUNT_KEY=", "AWS_ACCESS_KEY_ID=", "AWS_SECRET_ACCESS_KEY=",
			"RESTIC_PASSWORD_FILE=stale-file", "RESTIC_PASSWORD_COMMAND=stale-command",
		)
		command.Env = append(command.Env, extraEnv...)
		output, err := command.CombinedOutput()
		if strings.Contains(string(output), "synthetic password") || strings.Contains(string(output), "synthetic-b2-key") || strings.Contains(string(output), "synthetic-aws-key") {
			t.Fatal("the wrapper disclosed secret contents in its output")
		}
		if err != nil {
			return nil, err
		}
		return strings.Split(strings.TrimSuffix(read(t, filepath.Join(dir, "result")), "\x00"), "\x00"), nil
	}
	for _, backend := range []string{"backblaze", "storj"} {
		values, err := run(backend)
		noError(t, err)
		want := []string{"synthetic password with $ and ' and \"", "", "", "", "", "-r", "synthetic repository", "backup", "synthetic path"}
		if backend == "backblaze" {
			want[1], want[2] = "synthetic-b2-id", "synthetic-b2-key"
		} else {
			want[3], want[4] = "synthetic-aws-id", "synthetic-aws-key"
		}
		if !reflect.DeepEqual(want, values) {
			t.Fatalf("%s passed unexpected synthetic credentials or arguments", backend)
		}
		if len(strings.Fields(read(t, filepath.Join(dir, "calls")))) != 3 {
			t.Fatal("expected only the password and this backend's two secrets")
		}
	}
	write("restic-password", "rotated synthetic password")
	values, err := run("storj")
	noError(t, err)
	if values[0] != "rotated synthetic password" {
		t.Fatal("restic did not receive the rotated password")
	}
	if _, err := run("storj", "RESTIC_EXIT=7"); err == nil || err.(*exec.ExitError).ExitCode() != 7 {
		t.Fatalf("restic's exit code was lost: %v", err)
	}
	noError(t, os.Remove(filepath.Join(dir, "restic-aws-secret-access-key")))
	if _, err := run("storj"); err == nil {
		t.Fatal("a missing secret must fail the job")
	}
	if _, err := os.Stat(filepath.Join(dir, "result")); !os.IsNotExist(err) {
		t.Fatal("restic ran despite a missing secret")
	}
}

func renderHost(t *testing.T) string {
	t.Helper()
	repo, err := filepath.Abs("..")
	noError(t, err)
	// Render the real Butane template through Terraform's templatefile function.
	dir := t.TempDir()
	var rendered string
	console(t, dir, `jsonencode(templatefile("`+filepath.Join(repo, "butane/fcos.yml.tftpl")+`", {
ssh_keys=[], homelab_ssh_keys=[], hostname="test", truenas_ip="192.0.2.1", truenas_iqn="test",
root_ca="synthetic", firewall_config="", mac_address="00:00:00:00:00:01", ip="192.0.2.2",
gateway="192.0.2.1", mask="255.255.255.0", nameserver="192.0.2.1",
restic_runner=file("`+filepath.Join(repo, "butane/restic-with-secrets.sh")+`")
}))`, &rendered)
	return rendered
}

func TestResticUnitsUseTheWrapper(t *testing.T) {
	rendered := renderHost(t)
	if strings.Contains(rendered, "LoadCredential=restic-") || strings.Contains(rendered, "CREDENTIALS_DIRECTORY") {
		t.Fatal("restic units must read secrets through the Podman wrapper")
	}
	for _, backend := range []string{"backblaze", "storj"} {
		if strings.Count(rendered, "ExecStart=/etc/restic/run "+backend+" ") != 2 {
			t.Fatalf("both %s backup and prune must use the wrapper", backend)
		}
		start := strings.Index(rendered, "    - name: restic-"+backend+".service")
		unit := strings.SplitN(rendered[start:], "    - name:", 3)[1]
		check := strings.Index(unit, "ExecStartPre=/etc/restic/run "+backend+" version")
		snapshot := strings.Index(unit, "ExecStart=/usr/sbin/lvcreate")
		if check < 0 || snapshot < check {
			t.Fatal("secret check must run before snapshot creation")
		}
	}
	if !strings.Contains(rendered, "    - path: /etc/restic/run\n      mode: 0755") || !strings.Contains(rendered, "runtime_dir=/run/user/$(id -u homelab)") {
		t.Fatal("Ignition did not include the executable wrapper")
	}
}
