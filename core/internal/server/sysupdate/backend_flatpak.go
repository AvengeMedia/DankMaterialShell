package sysupdate

import (
	"context"
	"os/exec"
	"strings"
)

func init() {
	RegisterOverlayBackend(func() Backend { return &flatpakBackend{} })
}

type flatpakBackend struct{}

func (flatpakBackend) ID() string                         { return "flatpak" }
func (flatpakBackend) DisplayName() string                { return "Flatpak" }
func (flatpakBackend) Repo() RepoKind                     { return RepoFlatpak }
func (flatpakBackend) NeedsAuth() bool                    { return false }
func (flatpakBackend) RunsInTerminal() bool               { return false }
func (flatpakBackend) IsAvailable(_ context.Context) bool { return commandExists("flatpak") }

func (flatpakBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	cmd := exec.CommandContext(ctx, "flatpak", "remote-ls", "--updates", "--columns=application,version,branch,commit,name")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	installed := flatpakInstalled(ctx)
	return parseFlatpakUpdates(string(out), installed), nil
}

func flatpakInstalled(ctx context.Context) map[string]flatpakInstalledEntry {
	out, err := exec.CommandContext(ctx, "flatpak", "list", "--columns=application,version,branch,active").Output()
	if err != nil {
		return nil
	}
	m := make(map[string]flatpakInstalledEntry)
	for line := range strings.SplitSeq(string(out), "\n") {
		if line == "" {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) == 0 || fields[0] == "" {
			continue
		}
		appID := fields[0]
		entry := flatpakInstalledEntry{}
		if len(fields) > 1 {
			entry.version = fields[1]
		}
		if len(fields) > 2 {
			entry.branch = fields[2]
		}
		if len(fields) > 3 {
			entry.commit = fields[3]
		}
		key := appID
		if entry.branch != "" {
			key = appID + "//" + entry.branch
		}
		m[key] = entry
	}
	return m
}

type flatpakInstalledEntry struct {
	version string
	branch  string
	commit  string
}

func (flatpakBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	if opts.DryRun {
		return Run(ctx, []string{"flatpak", "update", "--no-deploy", "-y"}, RunOptions{OnLine: onLine})
	}
	if !BackendHasTargets(flatpakBackend{}, opts.Targets, opts.IncludeAUR, opts.IncludeFlatpak) {
		return nil
	}
	return Run(ctx, flatpakUpgradeArgv(), RunOptions{OnLine: onLine})
}

func flatpakUpgradeArgv() []string {
	return []string{"flatpak", "update", "-y", "--noninteractive"}
}

func parseFlatpakUpdates(text string, installed map[string]flatpakInstalledEntry) []Package {
	if text == "" {
		return nil
	}
	var pkgs []Package
	for line := range strings.SplitSeq(text, "\n") {
		if line == "" {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) == 0 || fields[0] == "" {
			continue
		}
		appID := fields[0]
		version, branch, commit := "", "", ""
		if len(fields) > 1 {
			version = fields[1]
		}
		if len(fields) > 2 {
			branch = fields[2]
		}
		if len(fields) > 3 {
			commit = fields[3]
		}
		display := appID
		if len(fields) > 4 && fields[4] != "" {
			display = fields[4]
		}

		key := appID
		if branch != "" {
			key = appID + "//" + branch
		}
		inst := installed[key]

		if inst.commit != "" && commit != "" && strings.HasPrefix(commit, inst.commit) {
			continue
		}

		from, to := flatpakVersionPair(inst.version, inst.commit, version, commit)

		ref := appID
		if branch != "" {
			ref = appID + "//" + branch
		}

		pkgs = append(pkgs, Package{
			Name:        display,
			Repo:        RepoFlatpak,
			Backend:     "flatpak",
			FromVersion: from,
			ToVersion:   to,
			Ref:         ref,
		})
	}
	return pkgs
}

func flatpakVersionPair(installedVer, installedCommit, remoteVer, remoteCommit string) (from, to string) {
	if remoteVer != "" {
		return installedVer, remoteVer
	}
	return shortCommit(installedCommit), shortCommit(remoteCommit)
}

func shortCommit(c string) string {
	if len(c) > 8 {
		return c[:8]
	}
	return c
}
