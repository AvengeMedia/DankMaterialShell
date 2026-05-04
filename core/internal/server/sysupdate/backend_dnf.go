package sysupdate

import (
	"context"
	"errors"
	"os/exec"
	"strings"
)

func init() {
	RegisterSystemBackend(func() Backend { return &dnfBackend{bin: "dnf5"} })
	RegisterSystemBackend(func() Backend { return &dnfBackend{bin: "dnf"} })
}

type dnfBackend struct {
	bin string
}

func (b dnfBackend) ID() string           { return b.bin }
func (b dnfBackend) DisplayName() string  { return strings.ToUpper(b.bin) }
func (b dnfBackend) Repo() RepoKind       { return RepoSystem }
func (b dnfBackend) NeedsAuth() bool      { return true }
func (b dnfBackend) RunsInTerminal() bool { return false }

func (b dnfBackend) IsAvailable(ctx context.Context) bool {
	if !commandExists(b.bin) {
		return false
	}
	if commandExists("rpm-ostree") && ostreeBooted(ctx) {
		return false
	}
	return true
}

func (b dnfBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	out, err := dnfListUpgrades(ctx, b.bin)
	if err != nil {
		return nil, err
	}
	installed := rpmInstalledVersions(ctx)
	return parseDnfList(out, b.bin, installed), nil
}

func (b dnfBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	if opts.DryRun {
		return Run(ctx, []string{b.bin, "upgrade", "--refresh", "--assumeno"}, RunOptions{OnLine: onLine})
	}
	names := pickTargetNames(opts.Targets, b.bin, true)
	if len(names) == 0 {
		return nil
	}
	argv := append([]string{"pkexec", b.bin, "upgrade", "--refresh", "-y"}, names...)
	return Run(ctx, argv, RunOptions{OnLine: onLine})
}

func dnfListUpgrades(ctx context.Context, bin string) (string, error) {
	cmd := exec.CommandContext(ctx, bin, "list", "--upgrades", "--quiet")
	out, err := cmd.Output()
	if err == nil {
		return string(out), nil
	}
	if exitErr, ok := errors.AsType[*exec.ExitError](err); ok && exitErr.ExitCode() == 1 {
		return "", nil
	}
	return "", err
}

func rpmInstalledVersions(ctx context.Context) map[string]string {
	out, err := exec.CommandContext(ctx, "rpm", "-qa", "--qf", `%{NAME}\t%{VERSION}-%{RELEASE}\n`).Output()
	if err != nil {
		return nil
	}
	m := make(map[string]string)
	for line := range strings.SplitSeq(string(out), "\n") {
		name, ver, ok := strings.Cut(line, "\t")
		if !ok {
			continue
		}
		m[name] = ver
	}
	return m
}

func parseDnfList(text, backendID string, installed map[string]string) []Package {
	if text == "" {
		return nil
	}
	var pkgs []Package
	for line := range strings.SplitSeq(text, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		nameArch := fields[0]
		version := fields[1]
		dot := strings.LastIndex(nameArch, ".")
		if dot <= 0 {
			continue
		}
		if !looksLikeRpmVersion(version) {
			continue
		}
		name := nameArch[:dot]
		pkgs = append(pkgs, Package{
			Name:        nameArch,
			Repo:        RepoSystem,
			Backend:     backendID,
			FromVersion: installed[name],
			ToVersion:   version,
		})
	}
	return pkgs
}

func looksLikeRpmVersion(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r >= '0' && r <= '9' {
			return true
		}
	}
	return false
}
