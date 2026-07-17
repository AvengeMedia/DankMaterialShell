package sysupdate

import (
	"reflect"
	"strings"
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
			got:  archHelperUpgradeArgv("paru", true, nil),
			want: []string{"paru", "-Syu", "--noconfirm", "--needed"},
		},
		{
			name: "aur helper repo-only full update",
			got:  archHelperUpgradeArgv("yay", false, nil),
			want: []string{"yay", "-Syu", "--noconfirm", "--needed", "--repo"},
		},
		{
			name: "aur helper with ignored packages",
			got:  archHelperUpgradeArgv("paru", true, []string{"linux", "bad;name", "discord"}),
			want: []string{"paru", "-Syu", "--noconfirm", "--needed", "--ignore", "linux,discord"},
		},
		{
			name: "pacman never passes --ignore",
			got:  pacmanUpgradeArgv(UpgradeOptions{Ignored: []string{"linux"}}),
			want: []string{"pkexec", "pacman", "-Syu", "--noconfirm", "--needed"},
		},
		{
			name: "dnf with ignored packages",
			got:  dnfUpgradeArgv("dnf5", UpgradeOptions{Ignored: []string{"kernel", "mesa"}}),
			want: []string{"pkexec", "dnf5", "upgrade", "--refresh", "-y", "--exclude=kernel,mesa"},
		},
		{
			name: "apt without ignored uses plain upgrade",
			got:  aptUpgradeArgv("apt-get", UpgradeOptions{}),
			want: []string{"pkexec", "env", "DEBIAN_FRONTEND=noninteractive", "LC_ALL=C", "apt-get", "upgrade", "-y"},
		},
		{
			name: "zypper without ignored uses plain update",
			got:  zypperUpgradeArgv(UpgradeOptions{}),
			want: []string{"pkexec", "zypper", "--non-interactive", "update"},
		},
		{
			name: "flatpak full update",
			got:  flatpakUpgradeArgv(UpgradeOptions{}),
			want: []string{"flatpak", "update", "-y", "--noninteractive"},
		},
		{
			name: "flatpak update with ignored targets refs",
			got: flatpakUpgradeArgv(UpgradeOptions{
				Ignored: []string{"org.mozilla.firefox"},
				Targets: []Package{
					{Name: "Discord", Repo: RepoFlatpak, Ref: "com.discordapp.Discord//stable"},
					{Name: "bash", Repo: RepoSystem, Backend: "apt"},
				},
			}),
			want: []string{"flatpak", "update", "-y", "--noninteractive", "com.discordapp.Discord//stable"},
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

func TestDropPacmanRepoIgnoresKeepsAURHolds(t *testing.T) {
	pending := []Package{
		{Name: "linux", Repo: RepoSystem},
		{Name: "librewolf", Repo: RepoAUR},
	}
	got := dropPacmanRepoIgnores([]string{"linux", "librewolf", "not-pending"}, pending)
	want := []string{"librewolf", "not-pending"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("ignored = %#v, want %#v", got, want)
	}
}

func TestAptUpgradeArgvHoldsIgnored(t *testing.T) {
	argv := aptUpgradeArgv("apt-get", UpgradeOptions{Ignored: []string{"linux-image-generic", "bad;name"}})
	if len(argv) < 2 || argv[len(argv)-2] != "-c" {
		t.Fatalf("expected sh -c script, got %#v", argv)
	}
	script := argv[len(argv)-1]
	if !strings.Contains(script, "apt-mark hold") || !strings.Contains(script, "apt-mark unhold") {
		t.Fatalf("hold script missing hold/unhold: %q", script)
	}
	if !strings.Contains(script, "linux-image-generic") {
		t.Fatalf("hold script missing ignored package: %q", script)
	}
	if strings.Contains(script, "bad;name") {
		t.Fatalf("hold script must drop unsafe name: %q", script)
	}
}

func TestZypperUpgradeArgvLocksIgnored(t *testing.T) {
	argv := zypperUpgradeArgv(UpgradeOptions{Ignored: []string{"kernel-default"}})
	if len(argv) < 2 || argv[len(argv)-2] != "-c" {
		t.Fatalf("expected sh -c script, got %#v", argv)
	}
	script := argv[len(argv)-1]
	if !strings.Contains(script, "zypper --non-interactive al") || !strings.Contains(script, "zypper --non-interactive rl") {
		t.Fatalf("lock script missing add/remove lock: %q", script)
	}
	if !strings.Contains(script, "kernel-default") {
		t.Fatalf("lock script missing ignored package: %q", script)
	}
}

func TestShellSafeNames(t *testing.T) {
	got := shellSafeNames([]string{"linux", "gtk+", "bad name", "rm -rf /", "org.mozilla.firefox", "a;b"})
	want := []string{"linux", "gtk+", "org.mozilla.firefox"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("shellSafeNames() = %#v, want %#v", got, want)
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
