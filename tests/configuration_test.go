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

type group struct {
	Units       []string `json:"units"`
	Enable      []string `json:"enable"`
	Hash        string   `json:"hash"`
	UsesSecrets bool     `json:"uses_secrets"`
}

type payload struct {
	Files  map[string]string `json:"files"`
	Units  []string          `json:"units"`
	Groups map[string]group  `json:"groups"`
}

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

func render(t *testing.T) payload {
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

	dir := t.TempDir()
	data, err := json.Marshal(files)
	noError(t, err)
	noError(t, os.WriteFile(filepath.Join(dir, "files.json"), data, 0600))
	noError(t, os.WriteFile(filepath.Join(dir, "inputs.tf"), []byte(`locals { config_files = jsondecode(file("files.json")) }`), 0600))
	deployment := strings.ReplaceAll(read(t, filepath.Join(repo, "deployment.tf")), "${path.module}", repo)
	noError(t, os.WriteFile(filepath.Join(dir, "deployment.tf"), []byte(deployment), 0600))

	var result payload
	console(t, dir, `jsonencode({files=local.config_files,groups=local.deployment_groups,units=local.managed_units})`, &result)

	return result
}

func TestRenderedQuadletsAndRestartGroups(t *testing.T) {
	config := render(t)
	stage := t.TempDir()
	for name, content := range config.Files {
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

	for _, unit := range config.Units {
		if _, err := os.Stat(filepath.Join(generated, unit)); err == nil {
			continue
		}
		if _, err := os.Stat(filepath.Join(stage, "files/systemd/user", unit)); err == nil {
			continue
		}
		t.Errorf("unit was not generated: %s", unit)
	}

	for name, group := range config.Groups {
		if group.Hash == "" || len(group.Units) == 0 {
			t.Errorf("empty restart group %s", name)
		}
		for _, unit := range append(slices.Clone(group.Units), group.Enable...) {
			if !slices.Contains(config.Units, unit) {
				t.Errorf("group %s refers to unowned unit %s", name, unit)
			}
		}
	}

	for name, content := range config.Files {
		if !strings.HasSuffix(name, ".container") {
			continue
		}
		matches := regexp.MustCompile(`(?m)^Pod=([^\r\n]+)`).FindStringSubmatch(content)
		if len(matches) == 0 {
			continue
		}
		pod := strings.TrimSuffix(matches[1], ".pod") + "-pod.service"
		member := strings.TrimSuffix(filepath.Base(name), ".container") + ".service"
		if !slices.Contains(config.Groups[pod].Units, member) {
			t.Errorf("%s is missing from pod restart group %s", member, pod)
		}
	}
}
