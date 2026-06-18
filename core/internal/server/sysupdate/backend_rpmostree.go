package sysupdate

import (
	"context"
	"encoding/json"
	"errors"
	"os/exec"
)

const ostreeExitUpdateAvailable = 77

func init() {
	RegisterSystemBackend(func() Backend { return &rpmOstreeBackend{} })
}

type rpmOstreeBackend struct{}

func (rpmOstreeBackend) ID() string           { return "rpm-ostree" }
func (rpmOstreeBackend) DisplayName() string  { return "rpm-ostree" }
func (rpmOstreeBackend) Repo() RepoKind       { return RepoOSTree }
func (rpmOstreeBackend) NeedsAuth() bool      { return true }
func (rpmOstreeBackend) RunsInTerminal() bool { return false }

func (b rpmOstreeBackend) IsAvailable(ctx context.Context) bool {
	if !commandExists("rpm-ostree") {
		return false
	}
	return ostreeBooted(ctx)
}

type ostreeStatus struct {
	Deployments  []ostreeDeployment `json:"deployments"`
	CachedUpdate *ostreeCached      `json:"cached-update"`
}

type ostreeDeployment struct {
	Origin    string `json:"origin"`
	Version   string `json:"version"`
	Timestamp int64  `json:"timestamp"`
	Booted    bool   `json:"booted"`
}

type ostreeCached struct {
	Origin    string `json:"origin"`
	Version   string `json:"version"`
	Timestamp int64  `json:"timestamp"`
	Checksum  string `json:"checksum"`
}

func ostreeBooted(ctx context.Context) bool {
	cmd := exec.CommandContext(ctx, "rpm-ostree", "status", "--json")
	out, err := cmd.Output()
	if err != nil {
		return false
	}
	var s ostreeStatus
	if err := json.Unmarshal(out, &s); err != nil {
		return false
	}
	return len(s.Deployments) > 0
}

func (rpmOstreeBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	cmd := exec.CommandContext(ctx, "rpm-ostree", "upgrade", "--check")
	if err := cmd.Run(); err != nil {
		exitErr, ok := errors.AsType[*exec.ExitError](err)
		if !ok || exitErr.ExitCode() != ostreeExitUpdateAvailable {
			return nil, err
		}
	}

	statusOut, err := exec.CommandContext(ctx, "rpm-ostree", "status", "--json").Output()
	if err != nil {
		return nil, err
	}
	return parseRpmOstreeStatus(statusOut)
}

func parseRpmOstreeStatus(statusOut []byte) ([]Package, error) {
	var s ostreeStatus
	if err := json.Unmarshal(statusOut, &s); err != nil {
		return nil, err
	}
	if s.CachedUpdate == nil {
		return nil, nil
	}

	booted := bootedDeployment(s.Deployments)
	from := ""
	if booted != nil {
		from = booted.Version
	}
	if from == s.CachedUpdate.Version {
		return nil, nil
	}

	name := s.CachedUpdate.Origin
	if name == "" {
		name = "system"
	}
	return []Package{{
		Name:        name,
		Repo:        RepoOSTree,
		Backend:     "rpm-ostree",
		FromVersion: from,
		ToVersion:   s.CachedUpdate.Version,
	}}, nil
}

func bootedDeployment(deps []ostreeDeployment) *ostreeDeployment {
	for i := range deps {
		if deps[i].Booted {
			return &deps[i]
		}
	}
	return nil
}

func (rpmOstreeBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	if !BackendHasTargets(rpmOstreeBackend{}, opts.Targets, opts.IncludeAUR, opts.IncludeFlatpak) {
		return nil
	}
	return Run(ctx, rpmOstreeUpgradeArgv(opts), RunOptions{OnLine: onLine, AttachStdio: opts.AttachStdio})
}

func rpmOstreeUpgradeArgv(opts UpgradeOptions) []string {
	argv := []string{"rpm-ostree", "upgrade"}
	if opts.DryRun {
		argv = append(argv, "--check")
	}
	return argv
}
