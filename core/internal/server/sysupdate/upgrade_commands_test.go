package sysupdate

import (
	"reflect"
	"testing"
)

func TestUpgradeCommandBuilders(t *testing.T) {
	pkexecOpts := UpgradeOptions{UseSudo: false}

	tests := []struct {
		name string
		got  []string
		want []string
	}{
		{
			name: "dnf full upgrade",
			got:  dnfUpgradeArgv("dnf5", pkexecOpts),
			want: []string{"pkexec", "dnf5", "upgrade", "--refresh", "-y"},
		},
		{
			name: "apt full upgrade",
			got:  aptUpgradeArgv("apt-get", pkexecOpts),
			want: []string{"pkexec", "env", "DEBIAN_FRONTEND=noninteractive", "LC_ALL=C", "apt-get", "upgrade", "-y"},
		},
		{
			name: "zypper full update",
			got:  zypperUpgradeArgv(pkexecOpts),
			want: []string{"pkexec", "zypper", "--non-interactive", "update"},
		},
		{
			name: "pacman full sync upgrade",
			got:  pacmanUpgradeArgv(pkexecOpts),
			want: []string{"pkexec", "pacman", "-Syu", "--noconfirm", "--needed"},
		},
		{
			name: "aur helper full update with aur",
			got:  archHelperUpgradeArgv("paru", true),
			want: []string{"paru", "-Syu", "--noconfirm", "--needed"},
		},
		{
			name: "aur helper repo-only full update",
			got:  archHelperUpgradeArgv("yay", false),
			want: []string{"yay", "-Syu", "--noconfirm", "--needed", "--repo"},
		},
		{
			name: "flatpak full update",
			got:  flatpakUpgradeArgv(),
			want: []string{"flatpak", "update", "-y", "--noninteractive"},
		},
		{
			name: "rpm-ostree upgrade",
			got:  rpmOstreeUpgradeArgv(UpgradeOptions{}),
			want: []string{"rpm-ostree", "upgrade"},
		},
		{
			name: "rpm-ostree check",
			got:  rpmOstreeUpgradeArgv(UpgradeOptions{DryRun: true}),
			want: []string{"rpm-ostree", "upgrade", "--check"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !reflect.DeepEqual(tt.got, tt.want) {
				t.Fatalf("argv = %#v, want %#v", tt.got, tt.want)
			}
		})
	}
}

func TestBackendHasTargetsRespectsBackendAndOptions(t *testing.T) {
	targets := []Package{
		{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf5"},
		{Name: "google-chrome", Repo: RepoAUR, Backend: "paru"},
		{Name: "Discord", Repo: RepoFlatpak, Backend: "flatpak"},
		{Name: "silverblue", Repo: RepoOSTree, Backend: "rpm-ostree"},
	}

	if !BackendHasTargets(dnfBackend{bin: "dnf5"}, targets, true, true) {
		t.Fatal("dnf5 target was not detected")
	}
	if BackendHasTargets(dnfBackend{bin: "dnf"}, targets, true, true) {
		t.Fatal("dnf target should not match dnf5 package targets")
	}
	if !BackendHasTargets(archHelperBackend{id: "paru"}, targets, true, true) {
		t.Fatal("AUR helper target was not detected")
	}
	if BackendHasTargets(archHelperBackend{id: "paru"}, targets, false, true) {
		t.Fatal("AUR helper should not match AUR-only target when AUR is disabled")
	}
	if !BackendHasTargets(flatpakBackend{}, targets, true, true) {
		t.Fatal("Flatpak target was not detected")
	}
	if BackendHasTargets(flatpakBackend{}, targets, true, false) {
		t.Fatal("Flatpak target should not match when Flatpak is disabled")
	}
	if !BackendHasTargets(rpmOstreeBackend{}, targets, true, true) {
		t.Fatal("rpm-ostree target was not detected")
	}
}

func TestUpgradeNeedsPrivilegeSkipsFlatpakOnly(t *testing.T) {
	backends := []Backend{dnfBackend{bin: "dnf5"}, flatpakBackend{}}
	opts := UpgradeOptions{IncludeAUR: true, IncludeFlatpak: true}

	flatpakOnly := []Package{{Name: "Discord", Repo: RepoFlatpak, Backend: "flatpak"}}
	if UpgradeNeedsPrivilege(backends, flatpakOnly, opts) {
		t.Fatal("Flatpak-only updates should not need privileged auth")
	}

	mixed := []Package{
		{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf5"},
		{Name: "Discord", Repo: RepoFlatpak, Backend: "flatpak"},
	}
	if !UpgradeNeedsPrivilege(backends, mixed, opts) {
		t.Fatal("mixed system updates should need privileged auth")
	}

	opts.DryRun = true
	if UpgradeNeedsPrivilege(backends, mixed, opts) {
		t.Fatal("dry-run updates should not need privileged auth")
	}
}

func TestUpgradeBackendsFiltersFlatpakOnly(t *testing.T) {
	sel := Selection{
		System:  dnfBackend{bin: "dnf5"},
		Overlay: []Backend{flatpakBackend{}},
	}
	opts := UpgradeOptions{
		IncludeAUR:     true,
		IncludeFlatpak: true,
		Targets:        []Package{{Name: "Discord", Repo: RepoFlatpak, Backend: "flatpak"}},
	}

	got := upgradeBackends(sel, opts)
	if len(got) != 1 || got[0].ID() != "flatpak" {
		t.Fatalf("upgradeBackends(flatpak-only) = %#v, want only flatpak", got)
	}

	opts.Targets = append(opts.Targets, Package{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf5"})
	got = upgradeBackends(sel, opts)
	if len(got) != 2 || got[0].ID() != "dnf5" || got[1].ID() != "flatpak" {
		t.Fatalf("upgradeBackends(mixed) = %#v, want dnf5 then flatpak", got)
	}
}
