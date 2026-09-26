package sysupdate

import (
	"context"
	"regexp"
	"strings"
)

func init() {
	// FreeBSD's pkg(8) is the native binary package manager. Register it after
	// the Linux backends; IsAvailable keeps this harmless on other systems.
	RegisterSystemBackend(func() Backend { return &pkgBackend{} })
}

type pkgBackend struct{}

func (pkgBackend) ID() string                         { return "pkg" }
func (pkgBackend) DisplayName() string                { return "FreeBSD pkg" }
func (pkgBackend) Repo() RepoKind                     { return RepoSystem }
func (pkgBackend) NeedsAuth() bool                    { return true }
func (pkgBackend) RunsInTerminal() bool               { return false }
func (pkgBackend) IsAvailable(_ context.Context) bool { return commandExists("pkg") }

// pkg upgrade -n prints upgrade rows like:
//
//	nano: 8.6 -> 8.7 [FreeBSD]
//
// Keep the parser deliberately tolerant of repository names and whitespace.
var pkgUpgradeLine = regexp.MustCompile(`^\s*([^:\s][^:]*):\s+(\S+)\s+->\s+(\S+)(?:\s+\[[^]]+\])?\s*$`)

func (pkgBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	out, err := Capture(ctx, []string{"pkg", "upgrade", "-n", "-q"})
	if err != nil {
		return nil, err
	}
	return parsePkgUpgradeDryRun(out), nil
}

func parsePkgUpgradeDryRun(text string) []Package {
	var pkgs []Package
	seen := make(map[string]bool)
	for _, raw := range strings.Split(text, "\n") {
		m := pkgUpgradeLine.FindStringSubmatch(raw)
		if m == nil {
			continue
		}
		name := strings.TrimSpace(m[1])
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		pkgs = append(pkgs, Package{
			Name:        name,
			Repo:        RepoSystem,
			Backend:     "pkg",
			FromVersion: m[2],
			ToVersion:   m[3],
		})
	}
	return pkgs
}

func (pkgBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	if !BackendHasTargets(pkgBackend{}, opts.Targets, opts.IncludeAUR, opts.IncludeFlatpak) {
		return nil
	}
	if opts.DryRun {
		return Run(ctx, []string{"pkg", "upgrade", "-n"}, RunOptions{OnLine: onLine})
	}

	// pkg upgrade accepts package names, so preserve the UI selection and any
	// ignored packages instead of forcing an all-packages upgrade.
	ignored := make(map[string]bool, len(opts.Ignored))
	for _, name := range opts.Ignored {
		ignored[name] = true
	}
	argv := []string{"pkg", "upgrade", "-y"}
	for _, p := range opts.Targets {
		if p.Backend != "pkg" || ignored[p.Name] || !safePkgName.MatchString(p.Name) {
			continue
		}
		argv = append(argv, p.Name)
	}
	if len(argv) == 3 {
		return nil
	}
	return Run(ctx, privilegedArgv(opts, argv...), RunOptions{OnLine: onLine, AttachStdio: opts.AttachStdio})
}
