package configuration_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"slices"
	"strings"
	"testing"
)

func noError(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func read(t *testing.T, name string) string {
	t.Helper()
	content, err := os.ReadFile(name)
	noError(t, err)

	return string(content)
}

func console(t *testing.T, dir, expression string, result any) {
	t.Helper()
	command := exec.CommandContext(t.Context(), "tofu", "console")
	command.Dir = dir
	command.Stdin = strings.NewReader(expression + "\n")
	var stderr bytes.Buffer
	command.Stderr = &stderr

	output, err := command.Output()
	if err != nil {
		t.Fatalf("tofu console: %v\n%s", err, stderr.String())
	}

	var encoded string
	noError(t, json.Unmarshal(output, &encoded))
	noError(t, json.Unmarshal([]byte(encoded), result))
}

type application struct {
	Paths      []string
	Restart    []string
	TryRestart []string `json:"try_restart"`
	Enable     []string
	Secrets    []string
}

type deployments struct {
	Files        map[string]map[string]string
	Sources      map[string]string
	Applications map[string]application
}

// Render the actual deployment locals with synthetic variables and secret names.
// A private copy lets isolation tests change one application without touching the repo.
func renderDeployments(t *testing.T, edits map[string]string) deployments {
	t.Helper()
	repo, err := filepath.Abs("..")
	noError(t, err)
	dir := t.TempDir()
	noError(t, os.CopyFS(filepath.Join(dir, "configs"), os.DirFS(filepath.Join(repo, "configs"))))
	noError(t, os.WriteFile(filepath.Join(dir, "deployment.tf"), []byte(read(t, filepath.Join(repo, "deployment.tf"))), 0644))
	for name, extra := range edits {
		file := filepath.Join(dir, name)
		noError(t, os.WriteFile(file, []byte(read(t, file)+extra), 0644))
	}

	variables := map[string]string{}
	secrets := map[string]string{}
	interpolation := regexp.MustCompile(`\$\{(\w+)\}`)
	secret := regexp.MustCompile(`(?m)^Secret=([^,\r\n]+)`)

	noError(t, filepath.WalkDir(dir, func(name string, entry fs.DirEntry, err error) error {
		if err != nil || entry.IsDir() {
			return err
		}
		if strings.HasSuffix(name, ".tf") {
			return nil
		}
		content := read(t, name)
		for _, match := range interpolation.FindAllStringSubmatchIndex(content, -1) {
			if match[0] > 0 && content[match[0]-1] == '$' {
				continue
			}
			variable := content[match[2]:match[3]]
			variables[variable] = "example.test"
			if strings.HasSuffix(variable, "_ip") {
				variables[variable] = "192.0.2.1"
			}
		}
		for _, match := range secret.FindAllStringSubmatch(content, -1) {
			secrets[match[1]] = "synthetic-secret-id"
		}
		return nil
	}))
	variables["email"] = "review@example.test"

	values, err := json.Marshal(variables)
	noError(t, err)
	secretValues, err := json.Marshal(secrets)
	noError(t, err)
	inputs := fmt.Sprintf("locals {\n containers_config = jsondecode(%q)\n podman_secrets = jsondecode(%q)\n}\n", values, secretValues)
	noError(t, os.WriteFile(filepath.Join(dir, "inputs.tf"), []byte(inputs), 0644))
	var result deployments
	console(t, dir, `jsonencode({Files=local.deployment_files, Sources=local.config_files, Applications=local.applications})`, &result)

	return result
}

func render(t *testing.T) map[string]string {
	t.Helper()
	files := map[string]string{}
	for owner, deployment := range renderDeployments(t, nil).Files {
		for name, content := range deployment {
			if _, exists := files[name]; exists {
				t.Fatalf("%s duplicates an owned file: %s", owner, name)
			}
			files[name] = content
		}
	}

	return files
}

func generate(t *testing.T, files map[string]string) map[string]string {
	t.Helper()
	stage := t.TempDir()
	for name, content := range files {
		destination := filepath.Join(stage, "files", name)
		noError(t, os.MkdirAll(filepath.Dir(destination), 0755))
		noError(t, os.WriteFile(destination, []byte(content), 0644))
	}
	generated := filepath.Join(stage, "generated")
	noError(t, os.Mkdir(generated, 0700))

	generator := ""
	for _, candidate := range []string{
		"/usr/libexec/podman/quadlet",
		"/usr/lib/systemd/system-generators/podman-system-generator",
	} {
		if _, err := os.Stat(candidate); err == nil {
			generator = candidate
			break
		}
	}
	if generator == "" {
		t.Fatal("install Podman to validate the real Quadlet definitions")
	}

	command := exec.CommandContext(t.Context(), generator, "--user", "--no-kmsg-log", generated)
	command.Env = append(os.Environ(), "QUADLET_UNIT_DIRS="+filepath.Join(stage, "files/containers/systemd"))
	output, err := command.CombinedOutput()
	if err != nil {
		t.Fatalf("Quadlet generation: %v\n%s", err, output)
	}

	units := map[string]string{}
	entries, err := os.ReadDir(generated)
	noError(t, err)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		units[entry.Name()] = read(t, filepath.Join(generated, entry.Name()))
	}

	return units
}

// unitName is the homelab Quadlet naming convention, used only in tests.
func unitName(file string) string {
	base := filepath.Base(file)
	stem := strings.TrimSuffix(base, filepath.Ext(base))

	switch filepath.Ext(base) {
	case ".container":
		return stem + ".service"
	case ".pod":
		return stem + "-pod.service"
	case ".network":
		return stem + "-network.service"
	case ".volume":
		return stem + "-volume.service"
	}

	return ""
}

func hasDirectiveValue(content, directive, value string) bool {
	for _, line := range strings.Split(content, "\n") {
		if values, found := strings.CutPrefix(line, directive+"="); found && slices.Contains(strings.Fields(values), value) {
			return true
		}
	}
	return false
}

func TestActivationReferencesInstalledUnits(t *testing.T) {
	config := renderDeployments(t, nil)
	for owner, policy := range config.Applications {
		t.Run(owner, func(t *testing.T) {
			files := config.Files[owner]
			generated := generate(t, files)
			for _, unit := range slices.Concat(policy.Restart, policy.TryRestart, policy.Enable) {
				if _, native := files["systemd/user/"+unit]; !native {
					if _, exists := generated[unit]; !exists {
						t.Errorf("activation refers to an unowned unit: %s", unit)
					}
				}
			}
			for _, unit := range policy.Restart {
				if slices.Contains(policy.TryRestart, unit) {
					t.Errorf("%s appears in both restart and try_restart", unit)
				}
			}
			for _, unit := range policy.Enable {
				if _, native := files["systemd/user/"+unit]; !native {
					t.Errorf("enable refers to a non-native unit: %s", unit)
				}
			}
			for name, source := range files {
				if strings.HasSuffix(name, ".pod") && slices.Contains(policy.Restart, unitName(name)) {
					if !hasDirectiveValue(generated[unitName(name)], "WantedBy", "default.target") {
						t.Errorf("%s has no pod boot entry point", name)
					}
				}
				if !strings.HasSuffix(name, ".container") {
					continue
				}
				unit := unitName(name)
				if slices.Contains(policy.Restart, unit) || slices.Contains(policy.TryRestart, unit) {
					if !strings.Contains(generated[unit], "WantedBy=multi-user.target default.target") && !strings.Contains(generated[unit], "WantedBy=default.target") {
						t.Errorf("%s has no boot entry point", unit)
					}
				} else if !slices.Contains(policy.Restart, owner+".target") {
					pod := owner + "-pod.service"
					if !hasDirectiveValue(source, "Pod", owner+".pod") || !slices.Contains(policy.Restart, pod) {
						t.Errorf("%s is not covered by activation", unit)
					}
					if hasDirectiveValue(generated[unit], "WantedBy", "default.target") || hasDirectiveValue(generated[unit], "WantedBy", "multi-user.target") {
						t.Errorf("%s bypasses its pod's boot entry point", unit)
					}
				}
			}
		})
	}
	traefik := config.Applications["traefik"]
	if !slices.Equal(traefik.TryRestart, []string{"traefik.service"}) {
		t.Error("Traefik must retain conditional restart with socket activation")
	}
}

func TestDeploymentsGenerateIndependentlyAndOwnTheirSupportFiles(t *testing.T) {
	config := renderDeployments(t, nil)
	fileOwners, unitOwners := map[string]string{}, map[string]string{}
	unitContents := map[string]string{}
	for owner, files := range config.Files {
		generated := generate(t, files)
		for name := range files {
			if previous, exists := fileOwners[name]; exists {
				t.Errorf("%s and %s both own %s", owner, previous, name)
			}
			fileOwners[name] = owner
			if strings.Contains(name, "/container.d/") {
				t.Errorf("global drop-in crosses deployment boundaries: %s", name)
			}
			if strings.HasPrefix(name, "systemd/user/") && !strings.Contains(strings.TrimPrefix(name, "systemd/user/"), "/") {
				generated[filepath.Base(name)] = files[name]
			}
		}
		for name, content := range generated {
			if previous, exists := unitOwners[name]; exists {
				t.Errorf("%s and %s both own unit %s", owner, previous, name)
			}
			unitOwners[name] = owner
			unitContents[name] = content
		}

		for name, source := range files {
			if strings.Contains(source, "\nNetwork=systemd-reverse-proxy\n") {
				unit := generated[unitName(name)]
				for _, directive := range []string{"Requires", "After"} {
					pattern := regexp.MustCompile(`(?m)^` + directive + `=.*\breverse-proxy-network\.service\b`)
					if !pattern.MatchString(unit) {
						t.Errorf("%s lacks %s for the shared network", name, directive)
					}
				}
			}
		}

		if target := files["systemd/user/"+owner+".target"]; target != "" {
			if !strings.Contains(target, "WantedBy=default.target") {
				t.Errorf("%s has no boot entry point", owner)
			}
			policy := config.Applications[owner]
			if !slices.Contains(policy.Restart, owner+".target") || !slices.Contains(policy.Enable, owner+".target") {
				t.Errorf("%s target must be both restarted and enabled", owner)
			}
			for name, source := range files {
				if unitName(name) == "" && !strings.HasSuffix(name, ".timer") {
					continue
				}
				unit := unitName(name)
				if strings.HasSuffix(name, ".timer") {
					unit = filepath.Base(name)
				}
				if !strings.Contains(generated[unit], "PartOf="+owner+".target") || !strings.Contains(target, unit) {
					t.Errorf("%s is not attached to %s.target", name, owner)
				}
				if strings.Contains(source, "WantedBy=multi-user.target") || strings.Contains(source, "WantedBy=default.target") {
					t.Errorf("%s bypasses its deployment's boot entry point", name)
				}
			}
		}
	}
	for source := range config.Sources {
		if source == "containers/systemd/container.d/10-restart.conf" {
			continue // Shared defaults are copied to addressed drop-ins.
		}
		if _, exists := fileOwners[source]; !exists {
			t.Errorf("configuration has no deployment owner: %s", source)
		}
	}
	if _, exists := config.Files["fcos"]; exists {
		t.Error("each application must have its own deployment")
	}

	if unitOwners["reverse-proxy-network.service"] != "reverse-proxy" {
		t.Error("the shared network must have its own deployment")
	}

	// Only the shared network is installed before every application. Even soft
	// dependencies must not pull in units managed by another application.
	dependencies := regexp.MustCompile(`(?m)^(?:Wants|Requires|Requisite|BindsTo|PartOf|After|Before)=(.*)$`)
	for unit, content := range unitContents {
		for _, match := range dependencies.FindAllStringSubmatch(content, -1) {
			for _, dependency := range strings.Fields(match[1]) {
				owner := unitOwners[dependency]
				if owner != "" && owner != unitOwners[unit] && owner != "reverse-proxy" {
					t.Errorf("%s in %s depends on %s in independently installed application %s", unit, unitOwners[unit], dependency, owner)
				}
			}
		}
	}
}

func TestDirectoryPreparationIsGuardedAndMatchesBindMounts(t *testing.T) {
	files := render(t)
	generated := generate(t, files)
	bind := regexp.MustCompile(`(?m)^Volume=(/var/mnt/docker/app_data/[^:\r\n]+):`)
	prestart := regexp.MustCompile(`(?m)^ExecStartPre=([^\r\n]*)`)
	for name, content := range files {
		if !strings.HasSuffix(name, ".container") {
			continue
		}
		t.Run(unitName(name), func(t *testing.T) {
			commands := prestart.FindAllStringSubmatch(generated[unitName(name)], -1)
			if len(commands) == 0 || commands[0][1] != "/usr/bin/mountpoint -q /var/mnt/docker" {
				t.Fatal("the mount check must precede all other preparation")
			}
			directories := []string{}
			for _, match := range bind.FindAllStringSubmatch(content, -1) {
				directories = append(directories, match[1])
			}
			if len(directories) == 0 {
				return
			}
			if len(commands) < 3 || commands[1][1] != "/usr/bin/test -d /var/mnt/docker/app_data" {
				t.Fatal("check the existing data root before creating directories")
			}
			prefix := "/usr/bin/mkdir -p -m 0755 -- "
			if !strings.HasPrefix(commands[2][1], prefix) {
				t.Fatal("create missing directories without changing existing permissions")
			}
			created := strings.Fields(strings.TrimPrefix(commands[2][1], prefix))
			slices.Sort(directories)
			slices.Sort(created)
			if !slices.Equal(slices.Compact(directories), slices.Compact(created)) {
				t.Errorf("directory preparation %v does not match bind mounts %v", created, directories)
			}
		})
	}
}

func TestApplicationChangesStayInsideTheirDeployment(t *testing.T) {
	before := renderDeployments(t, nil)
	for owner, files := range before.Files {
		t.Run(owner, func(t *testing.T) {
			// Choose a real source, excluding generated copies of shared defaults.
			names := []string{}
			for name := range files {
				if _, source := before.Sources[name]; source {
					names = append(names, name)
				}
			}
			slices.Sort(names)
			if len(names) == 0 {
				t.Fatal("deployment has no sources")
			}
			file := filepath.Join("configs", names[0])
			if _, err := os.Stat(filepath.Join("..", file)); os.IsNotExist(err) {
				file += ".tftpl"
			}
			after := renderDeployments(t, map[string]string{file: "\n# Changed application configuration\n"})
			for deployment, previous := range before.Files {
				changed := !reflect.DeepEqual(previous, after.Files[deployment])
				if changed != (deployment == owner) {
					t.Errorf("editing %s: deployment %s changed=%v", owner, deployment, changed)
				}
			}
		})
	}
}

func TestSharedDefaultsUpdateOnlyContainerDeployments(t *testing.T) {
	before := renderDeployments(t, nil)
	after := renderDeployments(t, map[string]string{
		"configs/containers/systemd/container.d/10-restart.conf": "\nTimeoutStopSec=120\n",
	})
	for owner, files := range before.Files {
		hasContainer := false
		for name := range files {
			hasContainer = hasContainer || strings.HasSuffix(name, ".container")
		}
		if changed := !reflect.DeepEqual(files, after.Files[owner]); changed != hasContainer {
			t.Errorf("shared defaults changed=%v for %s, has containers=%v", changed, owner, hasContainer)
		}
	}
}

func TestConfigBindMountsBelongToTheirApplication(t *testing.T) {
	config := renderDeployments(t, nil)
	mount := regexp.MustCompile(`(?m)^Volume=%E/([^:\r\n]+):`)
	for owner, files := range config.Files {
		for name, content := range files {
			for _, match := range mount.FindAllStringSubmatch(content, -1) {
				found := false
				for path := range files {
					found = found || path == match[1] || strings.HasPrefix(path, match[1]+"/")
				}
				if !found {
					t.Errorf("%s in %s mounts configuration owned elsewhere: %s", name, owner, match[1])
				}
			}
		}
	}
}

func TestSystemdUnitsVerifyTogether(t *testing.T) {
	config := renderDeployments(t, nil)
	dir := t.TempDir()
	var names []string
	for _, files := range config.Files {
		units := generate(t, files)
		for name, content := range files {
			if strings.HasPrefix(name, "systemd/user/") {
				units[strings.TrimPrefix(name, "systemd/user/")] = content
			}
		}
		for name, content := range units {
			path := filepath.Join(dir, name)
			noError(t, os.MkdirAll(filepath.Dir(path), 0755))
			noError(t, os.WriteFile(path, []byte(content), 0644))
			if !strings.Contains(name, "/") {
				names = append(names, path)
			}
		}
	}
	slices.Sort(names)
	command := exec.CommandContext(t.Context(), "systemd-analyze", append([]string{"--user", "--man=no", "verify"}, names...)...)
	command.Env = append(os.Environ(), "SYSTEMD_UNIT_PATH="+dir+":/usr/lib/systemd/user", "LC_ALL=C")
	output, err := command.CombinedOutput()
	if err != nil || bytes.Contains(output, []byte("ordering cycle")) {
		t.Fatalf("systemd units have invalid dependencies or directives: %v\n%s", err, output)
	}
}

func TestSecretTriggersCoverOnlyTheirConsumers(t *testing.T) {
	config := renderDeployments(t, nil)
	secrets := regexp.MustCompile(`(?m)^Secret=([^,\r\n]+)`)
	for owner, files := range config.Files {
		triggers := config.Applications[owner].Secrets
		consumers := map[string]bool{}
		for _, content := range files {
			for _, match := range secrets.FindAllStringSubmatch(content, -1) {
				consumers[match[1]] = true
				if !slices.Contains(triggers, match[1]) {
					t.Errorf("%s consumes %s without a revision trigger", owner, match[1])
				}
			}
		}
		for _, name := range triggers {
			if !consumers[name] {
				t.Errorf("%s watches unrelated secret %s", owner, name)
			}
		}
	}
}

func TestPodMembersBindToTheirPod(t *testing.T) {
	files := render(t)
	generated := generate(t, files)
	member := regexp.MustCompile(`(?m)^Pod=([^\r\n]+)`)

	for name, content := range files {
		matches := member.FindStringSubmatch(content)
		if !strings.HasSuffix(name, ".container") || len(matches) == 0 {
			continue
		}

		pod := strings.TrimSuffix(matches[1], ".pod") + "-pod.service"
		if _, found := generated[pod]; !found {
			t.Errorf("%s joins %s, which is not declared", name, matches[1])

			continue
		}

		unit := unitName(name)
		// These generated dependencies propagate pod start, stop and restart
		// operations to its containers.
		for _, directive := range []string{"BindsTo", "After"} {
			if !hasDirectiveValue(generated[unit], directive, pod) {
				t.Errorf("%s lacks %s=%s", unit, directive, pod)
			}
		}
		for _, directive := range []string{"Wants", "Before"} {
			if !hasDirectiveValue(generated[pod], directive, unit) {
				t.Errorf("%s does not start %s with the pod: missing %s", pod, unit, directive)
			}
		}
	}
}

func TestNativeUnitsAreSelfContained(t *testing.T) {
	files := render(t)

	for name := range files {
		if !strings.HasPrefix(name, "systemd/user/") || !strings.HasSuffix(name, ".timer") {
			continue
		}

		service := strings.TrimSuffix(name, ".timer") + ".service"
		if _, found := files[service]; !found {
			t.Errorf("%s has no %s to start", name, filepath.Base(service))
		}
	}

	owned := []string{".service", ".timer", ".socket", ".target", ".conf"}
	for name := range files {
		if !strings.HasPrefix(name, "systemd/user/") {
			continue
		}
		if !slices.Contains(owned, filepath.Ext(name)) {
			t.Errorf("%s is not a unit the deployment can own", name)
		}
	}
}

// nft needs CAP_NET_ADMIN even to check a ruleset; a user and network namespace grants it.
func TestFirewallRulesetParses(t *testing.T) {
	if exec.CommandContext(t.Context(), "unshare", "-Urn", "nft", "--version").Run() != nil {
		t.Skip("nft inside an unprivileged user namespace is not available")
	}

	repo, err := filepath.Abs("..")
	noError(t, err)
	output, err := exec.CommandContext(t.Context(), "unshare", "-Urn", "nft", "-c", "-f", filepath.Join(repo, "butane/nftables.nft")).CombinedOutput()
	if err != nil {
		t.Fatalf("nftables ruleset does not parse: %v\n%s", err, output)
	}
}
