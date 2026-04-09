package headless

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/greeter"
)

// Config holds all CLI parameters for unattended installation.
type Config struct {
	Compositor  string // "niri" or "hyprland"
	Terminal    string // "ghostty", "kitty", or "alacritty"
	IncludeDeps []string
	ExcludeDeps []string
	Yes         bool
}

// Runner orchestrates unattended (headless) installation.
type Runner struct {
	cfg     Config
	logChan chan string
}

// NewRunner creates a new headless runner.
func NewRunner(cfg Config) *Runner {
	return &Runner{
		cfg:     cfg,
		logChan: make(chan string, 1000),
	}
}

// GetLogChan returns the log channel for file logging.
func (r *Runner) GetLogChan() <-chan string {
	return r.logChan
}

// Run executes the full unattended installation flow.
func (r *Runner) Run() error {
	r.log("Starting headless installation")

	// 1. Parse compositor and terminal selections
	wm, err := r.parseWindowManager()
	if err != nil {
		return err
	}

	terminal, err := r.parseTerminal()
	if err != nil {
		return err
	}

	// 2. Detect OS
	r.log("Detecting operating system...")
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return fmt.Errorf("OS detection failed: %w", err)
	}

	if distros.IsUnsupportedDistro(osInfo.Distribution.ID, osInfo.VersionID) {
		return fmt.Errorf("unsupported distribution: %s %s", osInfo.PrettyName, osInfo.VersionID)
	}

	fmt.Fprintf(os.Stdout, "Detected: %s (%s)\n", osInfo.PrettyName, osInfo.Architecture)

	// 3. Create distribution instance
	distro, err := distros.NewDistribution(osInfo.Distribution.ID, r.logChan)
	if err != nil {
		return fmt.Errorf("failed to initialize distribution: %w", err)
	}

	// 4. Detect dependencies
	r.log("Detecting dependencies...")
	fmt.Fprintln(os.Stdout, "Detecting dependencies...")
	dependencies, err := distro.DetectDependenciesWithTerminal(context.Background(), wm, terminal)
	if err != nil {
		return fmt.Errorf("dependency detection failed: %w", err)
	}

	// 5. Apply include/exclude filters and build disabled/reinstall maps
	disabledItems := make(map[string]bool)
	reinstallItems := make(map[string]bool)

	// dms-greeter is opt-in (disabled by default), matching TUI behavior
	for i := range dependencies {
		if dependencies[i].Name == "dms-greeter" {
			disabledItems["dms-greeter"] = true
			break
		}
	}

	// Process --include-deps (enable items that are disabled by default)
	for _, name := range r.cfg.IncludeDeps {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		if !r.depExists(dependencies, name) {
			return fmt.Errorf("--include-deps: unknown dependency %q", name)
		}
		delete(disabledItems, name)
	}

	// Process --exclude-deps (disable items)
	for _, name := range r.cfg.ExcludeDeps {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		if !r.depExists(dependencies, name) {
			return fmt.Errorf("--exclude-deps: unknown dependency %q", name)
		}
		// Don't allow excluding DMS itself
		if name == "dms (DankMaterialShell)" {
			return fmt.Errorf("--exclude-deps: cannot exclude required package %q", name)
		}
		disabledItems[name] = true
	}

	// Print dependency summary
	fmt.Fprintln(os.Stdout, "\nDependencies:")
	for _, dep := range dependencies {
		marker := "  "
		status := ""
		if disabledItems[dep.Name] {
			marker = "  SKIP "
			status = "(disabled)"
		} else {
			switch dep.Status {
			case deps.StatusInstalled:
				marker = "  OK   "
				status = "(installed)"
			case deps.StatusMissing:
				marker = "  NEW  "
				status = "(will install)"
			case deps.StatusNeedsUpdate:
				marker = "  UPD  "
				status = "(will update)"
			case deps.StatusNeedsReinstall:
				marker = "  RE   "
				status = "(will reinstall)"
			}
		}
		fmt.Fprintf(os.Stdout, "%s%-30s %s\n", marker, dep.Name, status)
	}
	fmt.Fprintln(os.Stdout)

	// 6. Authenticate sudo
	sudoPassword, err := r.resolveSudoPassword()
	if err != nil {
		return err
	}

	// 7. Install packages
	fmt.Fprintln(os.Stdout, "Installing packages...")
	r.log("Starting package installation")

	progressChan := make(chan distros.InstallProgressMsg, 100)

	installErr := make(chan error, 1)
	go func() {
		defer close(progressChan)
		installErr <- distro.InstallPackages(
			context.Background(),
			dependencies,
			wm,
			sudoPassword,
			reinstallItems,
			disabledItems,
			false, // skipGlobalUseFlags
			progressChan,
		)
	}()

	// Consume progress messages and print them
	for msg := range progressChan {
		if msg.Error != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", msg.Error)
		} else if msg.Step != "" {
			fmt.Fprintf(os.Stdout, "  [%3.0f%%] %s\n", msg.Progress*100, msg.Step)
		}
		if msg.LogOutput != "" {
			r.log(msg.LogOutput)
		}
	}

	if err := <-installErr; err != nil {
		return fmt.Errorf("package installation failed: %w", err)
	}

	// 8. Greeter setup (if dms-greeter was included)
	if !disabledItems["dms-greeter"] && r.depExists(dependencies, "dms-greeter") {
		compositorName := "niri"
		if wm == deps.WindowManagerHyprland {
			compositorName = "Hyprland"
		}
		fmt.Fprintln(os.Stdout, "Configuring DMS greeter...")
		logFunc := func(line string) {
			r.log(line)
			fmt.Fprintf(os.Stdout, "  greeter: %s\n", line)
		}
		if err := greeter.AutoSetupGreeter(compositorName, sudoPassword, logFunc); err != nil {
			// Non-fatal, matching TUI behavior
			fmt.Fprintf(os.Stderr, "Warning: greeter setup issue (non-fatal): %v\n", err)
		}
	}

	// 9. Deploy configurations (replace all existing configs in headless mode)
	fmt.Fprintln(os.Stdout, "Deploying configurations...")
	r.log("Starting configuration deployment")

	deployer := config.NewConfigDeployer(r.logChan)
	results, err := deployer.DeployConfigurationsSelectiveWithReinstalls(
		context.Background(),
		wm,
		terminal,
		dependencies,
		nil, // replaceConfigs=nil means replace all
		reinstallItems,
	)
	if err != nil {
		return fmt.Errorf("configuration deployment failed: %w", err)
	}

	for _, result := range results {
		if result.Deployed {
			msg := fmt.Sprintf("  Deployed: %s", result.ConfigType)
			if result.BackupPath != "" {
				msg += fmt.Sprintf(" (backup: %s)", result.BackupPath)
			}
			fmt.Fprintln(os.Stdout, msg)
		}
		if result.Error != nil {
			fmt.Fprintf(os.Stderr, "  Error deploying %s: %v\n", result.ConfigType, result.Error)
		}
	}

	fmt.Fprintln(os.Stdout, "\nInstallation complete!")
	r.log("Headless installation completed successfully")
	return nil
}

func (r *Runner) log(message string) {
	select {
	case r.logChan <- message:
	default:
	}
}

func (r *Runner) parseWindowManager() (deps.WindowManager, error) {
	switch strings.ToLower(r.cfg.Compositor) {
	case "niri":
		return deps.WindowManagerNiri, nil
	case "hyprland":
		return deps.WindowManagerHyprland, nil
	default:
		return 0, fmt.Errorf("invalid --compositor value %q: must be 'niri' or 'hyprland'", r.cfg.Compositor)
	}
}

func (r *Runner) parseTerminal() (deps.Terminal, error) {
	switch strings.ToLower(r.cfg.Terminal) {
	case "ghostty":
		return deps.TerminalGhostty, nil
	case "kitty":
		return deps.TerminalKitty, nil
	case "alacritty":
		return deps.TerminalAlacritty, nil
	default:
		return 0, fmt.Errorf("invalid --term value %q: must be 'ghostty', 'kitty', or 'alacritty'", r.cfg.Terminal)
	}
}

func (r *Runner) resolveSudoPassword() (string, error) {
	// Check if sudo credentials are cached (via sudo -v or NOPASSWD)
	cmd := exec.Command("sudo", "-n", "true")
	if err := cmd.Run(); err == nil {
		r.log("sudo cache is valid, no password needed")
		fmt.Fprintln(os.Stdout, "sudo: using cached credentials")
		return "", nil
	}

	return "", fmt.Errorf(
		"sudo authentication required but no cached credentials found\n" +
			"Options:\n" +
			"  1. Run 'sudo -v' before dankinstall to cache credentials\n" +
			"  2. Configure passwordless sudo for your user",
	)
}

func (r *Runner) depExists(dependencies []deps.Dependency, name string) bool {
	for _, dep := range dependencies {
		if dep.Name == name {
			return true
		}
	}
	return false
}
