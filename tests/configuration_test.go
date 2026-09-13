package configuration_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
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

// render fills every template variable with a placeholder, so the test needs no
// secrets and no Bitwarden session to reach the real Quadlet definitions.
func render(t *testing.T) map[string]string {
	t.Helper()
	repo, err := filepath.Abs("..")
	noError(t, err)
	configDir := filepath.Join(repo, "configs")
	variables := map[string]string{}
	interpolation := regexp.MustCompile(`\$\{(\w+)\}`)

	noError(t, filepath.WalkDir(configDir, func(name string, entry fs.DirEntry, err error) error {
		if err != nil || entry.IsDir() {
			return err
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
		return nil
	}))
	variables["email"] = "review@example.test"

	values, err := json.Marshal(variables)
	noError(t, err)
	expression := fmt.Sprintf(
		`jsonencode({for name in fileset(%q, "**") : trimsuffix(name, ".tftpl") => templatefile(%q, jsondecode(%q))})`,
		configDir,
		configDir+"/${name}",
		string(values),
	)
	var files map[string]string
	console(t, t.TempDir(), expression, &files)

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

// unitName applies the generator's naming rules, which the deployment provider
// reimplements to decide which units it owns. Checking them against the real
// generator is what this repository can do and the provider's own tests cannot.
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

func TestGeneratedUnitsMatchDeclaredQuadlets(t *testing.T) {
	files := render(t)
	generated := generate(t, files)

	expected := map[string]string{}
	for name := range files {
		if !strings.HasPrefix(name, "containers/systemd/") {
			continue
		}
		if unit := unitName(name); unit != "" {
			expected[unit] = name
		}
	}
	if len(expected) == 0 {
		t.Fatal("no Quadlet definitions were rendered")
	}

	for unit, source := range expected {
		if _, found := generated[unit]; !found {
			t.Errorf("%s declares %s, which the generator did not produce", source, unit)
		}
	}

	// The other direction catches a Quadlet type the deployment does not know
	// about yet: it would run on the host without ever being owned, restarted
	// or removed.
	for unit := range generated {
		if _, found := expected[unit]; !found {
			t.Errorf("the generator produced %s, which the deployment would not own", unit)
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

		// The restart group exists because systemd couples the two; if that
		// coupling ever disappears, grouping them is no longer justified.
		unit := unitName(name)
		if !strings.Contains(generated[unit], pod) {
			t.Errorf("%s no longer references %s, so the pod restart group is unfounded", unit, pod)
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

	owned := []string{".service", ".timer", ".socket", ".conf"}
	for name := range files {
		if !strings.HasPrefix(name, "systemd/user/") {
			continue
		}
		if !slices.Contains(owned, filepath.Ext(name)) {
			t.Errorf("%s is not a unit the deployment can own", name)
		}
	}
}
