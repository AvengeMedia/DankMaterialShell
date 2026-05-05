package sysupdate

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

func init() {
	RegisterSystemBackend(func() Backend { return &archHelperBackend{id: "paru"} })
	RegisterSystemBackend(func() Backend { return &archHelperBackend{id: "yay"} })
	RegisterSystemBackend(func() Backend { return &pacmanBackend{} })
}

var archUpdateLine = regexp.MustCompile(`^(\S+)\s+(\S+)\s+->\s+(\S+)`)

type pacmanBackend struct{}

func (pacmanBackend) ID() string                         { return "pacman" }
func (pacmanBackend) DisplayName() string                { return "Pacman" }
func (pacmanBackend) Repo() RepoKind                     { return RepoSystem }
func (pacmanBackend) NeedsAuth() bool                    { return true }
func (pacmanBackend) RunsInTerminal() bool               { return false }
func (pacmanBackend) IsAvailable(_ context.Context) bool { return commandExists("pacman") }

func (b pacmanBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	out, err := pacmanRepoUpdates(ctx)
	if err != nil {
		return nil, err
	}
	return parseArchUpdates(out, b.ID(), RepoSystem), nil
}

func (b pacmanBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	if opts.DryRun {
		return Run(ctx, []string{"pacman", "-Sup"}, RunOptions{OnLine: onLine})
	}
	if !BackendHasTargets(b, opts.Targets, opts.IncludeAUR, opts.IncludeFlatpak) {
		return nil
	}
	return Run(ctx, pacmanUpgradeArgv(opts), RunOptions{OnLine: onLine, AttachStdio: opts.AttachStdio})
}

func pacmanUpgradeArgv(opts UpgradeOptions) []string {
	return privilegedArgv(opts, "pacman", "-Syu", "--noconfirm", "--needed")
}

type archHelperBackend struct {
	id string
}

func (b archHelperBackend) ID() string      { return b.id }
func (b archHelperBackend) Repo() RepoKind  { return RepoSystem }
func (b archHelperBackend) NeedsAuth() bool { return true }
func (b archHelperBackend) RunsInTerminal() bool {
	return os.Getenv("DMS_FORCE_PKEXEC") != "1"
}
func (b archHelperBackend) IsAvailable(_ context.Context) bool { return commandExists(b.id) }

func (b archHelperBackend) DisplayName() string {
	switch b.id {
	case "paru":
		return "Paru (AUR)"
	case "yay":
		return "Yay (AUR)"
	default:
		return b.id
	}
}

func (b archHelperBackend) CheckUpdates(ctx context.Context) ([]Package, error) {
	repoOut, err := pacmanRepoUpdates(ctx)
	if err != nil {
		return nil, err
	}
	pkgs := parseArchUpdates(repoOut, b.id, RepoSystem)

	aurOut, err := capturePermissive(ctx, b.id, "-Qua")
	if err != nil {
		return nil, err
	}
	pkgs = append(pkgs, parseArchUpdates(aurOut, b.id, RepoAUR)...)
	return pkgs, nil
}

func (b archHelperBackend) Upgrade(ctx context.Context, opts UpgradeOptions, onLine func(string)) error {
	if opts.DryRun {
		return Run(ctx, []string{b.id, "-Sup"}, RunOptions{OnLine: onLine})
	}
	if !BackendHasTargets(b, opts.Targets, opts.IncludeAUR, opts.IncludeFlatpak) {
		return nil
	}
	if os.Getenv("DMS_FORCE_PKEXEC") == "1" {
		argv := append([]string{"pkexec"}, archHelperUpgradeArgv(b.id, opts.IncludeAUR)...)
		return Run(ctx, argv, RunOptions{OnLine: onLine, AttachStdio: opts.AttachStdio})
	}
	term := findTerminal(opts.Terminal)
	if term == "" {
		return fmt.Errorf("no terminal found (pick one in DMS settings, set $TERMINAL, or install kitty/ghostty/foot/alacritty)")
	}
	cmd := strings.Join(archHelperUpgradeArgv(b.id, opts.IncludeAUR), " ")
	title := fmt.Sprintf("DMS — System Update (%s)", b.id)
	return Run(ctx, wrapInTerminal(term, title, cmd), RunOptions{OnLine: onLine})
}

func archHelperUpgradeArgv(id string, includeAUR bool) []string {
	argv := []string{id, "-Syu", "--noconfirm", "--needed"}
	if !includeAUR {
		argv = append(argv, "--repo")
	}
	return argv
}

func pacmanRepoUpdates(ctx context.Context) (string, error) {
	if commandExists("checkupdates") {
		return capturePermissive(ctx, "checkupdates")
	}
	if commandExists("fakeroot") {
		out, err := pacmanCheckViaFakeroot(ctx)
		if err == nil {
			return out, nil
		}
		log.Warnf("[sysupdate] fakeroot db refresh failed, falling back to stale pacman -Qu: %v", err)
	}
	return capturePermissive(ctx, "pacman", "-Qu")
}

func pacmanCheckViaFakeroot(ctx context.Context) (string, error) {
	dir, err := pacmanPrivateDB()
	if err != nil {
		return "", err
	}

	if err := seedPacmanDB(dir); err != nil {
		return "", fmt.Errorf("seed sync db: %w", err)
	}

	refresh := exec.CommandContext(ctx, "fakeroot", "--", "pacman", "-Sy", "--dbpath", dir, "--logfile", "/dev/null", "--disable-sandbox")
	if out, err := refresh.CombinedOutput(); err != nil {
		return "", fmt.Errorf("fakeroot pacman -Sy: %w (%s)", err, strings.TrimSpace(string(out)))
	}

	return capturePermissive(ctx, "pacman", "-Qu", "--dbpath", dir)
}

func seedPacmanDB(dir string) error {
	syncDir := filepath.Join(dir, "sync")
	if err := os.MkdirAll(syncDir, 0o755); err != nil {
		return err
	}
	dbs, err := filepath.Glob("/var/lib/pacman/sync/*.db")
	if err != nil {
		return err
	}
	for _, src := range dbs {
		if err := copyFile(src, filepath.Join(syncDir, filepath.Base(src))); err != nil {
			return err
		}
	}

	localLink := filepath.Join(dir, "local")
	if fi, err := os.Lstat(localLink); err == nil {
		if fi.Mode()&os.ModeSymlink == 0 {
			if err := os.RemoveAll(localLink); err != nil {
				return err
			}
		} else {
			return nil
		}
	}
	return os.Symlink("/var/lib/pacman/local", localLink)
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err := io.Copy(out, in); err != nil {
		return err
	}
	return out.Sync()
}

func pacmanPrivateDB() (string, error) {
	tmp := os.Getenv("TMPDIR")
	if tmp == "" {
		tmp = "/tmp"
	}
	dir := filepath.Join(tmp, fmt.Sprintf("dms-checkup-db-%d", os.Getuid()))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	return dir, nil
}

func capturePermissive(ctx context.Context, argv ...string) (string, error) {
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	out, err := cmd.Output()
	if err == nil {
		return string(out), nil
	}
	if exitErr, ok := errors.AsType[*exec.ExitError](err); ok {
		switch exitErr.ExitCode() {
		case 1, 2:
			return string(out), nil
		}
	}
	return "", err
}

func parseArchUpdates(text, backendID string, repo RepoKind) []Package {
	if text == "" {
		return nil
	}
	var pkgs []Package
	for line := range strings.SplitSeq(text, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		m := archUpdateLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		p := Package{
			Name:        m[1],
			Repo:        repo,
			Backend:     backendID,
			FromVersion: m[2],
			ToVersion:   m[3],
		}
		if repo == RepoAUR {
			p.ChangelogURL = "https://aur.archlinux.org/packages/" + p.Name
		}
		pkgs = append(pkgs, p)
	}
	return pkgs
}
