package sysupdate

import (
	"context"
	"os/exec"
	"regexp"
	"strings"
)

func init() {
	RegisterSystemBackend(func() Backend { return &aptBackend{} })
}

var aptUpgradableLine = regexp.MustCompile(`^([^/]+)/\S+\s+(\S+)\s+\S+\s+\[upgradable from:\s+([^\]]+)\]`)

type aptBackend struct{}

func (aptBackend) ID() string           { return "apt" }
func (aptBackend) DisplayName() string  { return "APT" }
func (aptBackend) Repo() RepoKind       { return RepoSystem }
func (aptBackend) NeedsAuth() bool      { return true }
func (aptBackend) RunsInTerminal() bool { return false }
func (aptBackend) IsAvailable(_ context.Context) bool {
	return commandExists("apt") || commandExists("apt-get")
}

func (aptBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	cmd := exec.CommandContext(ctx, "apt", "list", "--upgradable")
	cmd.Env = append(cmd.Environ(), "LC_ALL=C")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	return parseAptUpgradable(string(out)), nil
}

func (aptBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	bin := "apt-get"
	if !commandExists(bin) {
		bin = "apt"
	}
	if opts.DryRun {
		return Run(ctx, []string{bin, "upgrade", "--dry-run"}, RunOptions{
			Env:    []string{"DEBIAN_FRONTEND=noninteractive", "LC_ALL=C"},
			OnLine: onLine,
		})
	}
	names := pickTargetNames(opts.Targets, "apt", true)
	if len(names) == 0 {
		return nil
	}
	privesc := privescBin(opts.UseSudo)
	argv := append([]string{privesc, "env", "DEBIAN_FRONTEND=noninteractive", "LC_ALL=C", bin, "install", "-y", "--only-upgrade"}, names...)
	return Run(ctx, argv, RunOptions{OnLine: onLine})
}

func parseAptUpgradable(text string) []Package {
	if text == "" {
		return nil
	}
	var pkgs []Package
	for line := range strings.SplitSeq(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		m := aptUpgradableLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		pkgs = append(pkgs, Package{
			Name:        m[1],
			Repo:        RepoSystem,
			Backend:     "apt",
			FromVersion: m[3],
			ToVersion:   m[2],
		})
	}
	return pkgs
}
