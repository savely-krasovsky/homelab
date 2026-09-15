package configuration_test

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// Account IDs and container mappings define ownership on persistent storage.
func TestServiceAccountStorageIdentity(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "host.yml")
	noError(t, os.WriteFile(path, []byte(renderHost(t)), 0600))
	var host struct {
		Passwd struct {
			Users []struct {
				Name         string
				UID          int
				PrimaryGroup string `json:"primary_group"`
				Groups       []string
			}
			Groups []struct {
				Name string
				GID  int
			}
		}
		Storage struct {
			Files []struct {
				Path     string
				Contents struct{ Inline string }
			}
		}
	}
	console(t, dir, fmt.Sprintf("jsonencode(yamldecode(file(%q)))", path), &host)
	declaredGroups := map[string]bool{}
	for _, group := range host.Passwd.Groups {
		declaredGroups[group.Name] = true
	}
	ids := map[string]int{"homelab": 1000, "core": 1001}
	for name, id := range ids {
		user := slices.IndexFunc(host.Passwd.Users, func(user struct {
			Name         string
			UID          int
			PrimaryGroup string `json:"primary_group"`
			Groups       []string
		}) bool {
			return user.Name == name
		})
		if user < 0 || host.Passwd.Users[user].UID != id || host.Passwd.Users[user].PrimaryGroup != name {
			t.Fatalf("%s must keep its assigned UID and primary group", name)
		}
		group := slices.IndexFunc(host.Passwd.Groups, func(group struct {
			Name string
			GID  int
		}) bool {
			return group.Name == name
		})
		if group < 0 || host.Passwd.Groups[group].GID != id {
			t.Fatalf("%s must keep its assigned GID", name)
		}
		if name == "homelab" {
			for _, group := range host.Passwd.Users[user].Groups {
				if group != "systemd-journal" && !declaredGroups[group] {
					t.Fatalf("supplementary group %s must be declared before homelab is created", group)
				}
			}
			for _, privileged := range []string{"sudo", "wheel", "docker"} {
				if slices.Contains(host.Passwd.Users[user].Groups, privileged) {
					t.Fatalf("application user has administrative group %s", privileged)
				}
			}
		}
	}
	files := map[string]string{}
	for _, file := range host.Storage.Files {
		files[file.Path] = file.Contents.Inline
	}
	for _, name := range []string{"/etc/subuid", "/etc/subgid"} {
		if files[name] != "homelab:524288:65536\ncore:655360:65536\n" {
			t.Fatalf("%s must define the assigned container IDs without overlapping ranges", name)
		}
	}
	if !strings.Contains(files["/var/home/homelab/.config/containers/storage.conf"], `graphroot = "/mnt/docker/core"`) {
		t.Fatal("homelab must use the configured Podman graphroot")
	}
}
