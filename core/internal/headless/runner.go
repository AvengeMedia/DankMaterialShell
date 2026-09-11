package headless

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

// ErrConfirmationRequired is returned when --yes is not set and the user
// must explicitly confirm the operation.
var ErrConfirmationRequired = fmt.Errorf("confirmation required: pass --yes to proceed")

// validConfigNames maps lowercase CLI input to the deployer key used in
// replaceConfigs. Keep in sync with the config types checked by
// shouldReplaceConfig in deployer.go.
var validConfigNames = map[string]string{
	"niri":      "Niri",
	"hyprland":  "Hyprland",
	"ghostty":   "Ghostty",
	"kitty":     "Kitty",
	"alacritty": "Alacritty",
}

// orderedConfigNames defines the canonical order for config names in output.
// Must be kept in sync with validConfigNames.
var orderedConfigNames = []string{"niri", "hyprland", "ghostty", "kitty", "alacritty"}

// Config holds all CLI parameters for unattended installation.
type Config struct {
	Compositor        string   // "niri", "hyprland", or "mango"
	Terminal          string   // "ghostty", "kitty", or "alacritty"
	PrivescTool       string   // "sudo", "doas", or "run0"; empty means autodetect
	GitAll            bool     // git variant for every dep that supports it
	GitDeps           []string // deps to force the git variant of
	AllFeatures       bool     // enable all optional deps
	IncludeDeps       []string
	ExcludeDeps       []string
	ReplaceConfigs    []string // specific configs to deploy (e.g. "niri", "ghostty")
	ReplaceConfigsAll bool     // deploy/replace all configurations
	Yes               bool
	DankSearch        bool // install danksearch and enable its user service
	DankCalendar      bool // install dankcalendar
	DmsGreeter        bool // install dms-greeter
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

	if err := r.applyPrivescTool(); err != nil {
		return err
	}

	// 1. Parse compositor and terminal selections
	wm, err := r.parseWindowManager()
	if err != nil {
		return err
	}

	terminal, err := r.parseTerminal()
	if err != nil {
		return err
	}

	// 2. Build replace-configs map
	replaceConfigs, err := r.buildReplaceConfigs()
	if err != nil {
		return err
	}

	// 3. Detect OS
	r.log("Detecting operating system...")
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return fmt.Errorf("OS detection failed: %w", err)
	}

	if distros.IsUnsupportedDistro(osInfo.Distribution.ID, osInfo.VersionID) {
		return fmt.Errorf("unsupported distribution: %s %s", osInfo.PrettyName, osInfo.VersionID)
	}

	fmt.Fprintf(os.Stdout, "Detected: %s (%s)\n", osInfo.PrettyName, osInfo.Architecture)

	// 4. Create distribution instance
	distro, err := distros.NewDistribution(osInfo.Distribution.ID, r.logChan)
	if err != nil {
		return fmt.Errorf("failed to initialize distribution: %w", err)
	}

	// 5. Detect dependencies
	r.log("Detecting dependencies...")
	fmt.Fprintln(os.Stdout, "Detecting dependencies...")
	dependencies, err := distro.DetectDependenciesWithTerminal(context.Background(), wm, terminal)
	if err != nil {
		return fmt.Errorf("dependency detection failed: %w", err)
	}

	reinstallItems, err := r.applyGitVariants(dependencies, gitVariantChecker(distro, wm, dependencies))
	if err != nil {
		return err
	}

	// 5. Apply include/exclude filters and build the disabled-items map.
	disabledItems, err := r.buildDisabledItems(dependencies)
	if err != nil {
		return err
	}

	// Print dependency summary
	fmt.Fprintln(os.Stdout, "\nDependencies:")
	for _, dep := range dependencies {
		marker := "  "
		status := ""
		if disabledItems[dep.Name] {
			marker = "  SKIP "
			status = "(disabled)"
		} else if reinstallItems[dep.Name] {
			marker = "  RE   "
			status = "(will reinstall)"
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

	// 6b. Require explicit confirmation unless --yes is set
	if !r.cfg.Yes {
		if replaceConfigs == nil {
			// --replace-configs-all
			fmt.Fprintln(os.Stdout, "Packages will be installed and all configurations will be replaced.")
			fmt.Fprintln(os.Stdout, "Existing config files will be backed up before replacement.")
		} else if r.anyConfigEnabled(replaceConfigs) {
			var names []string
			for _, cliName := range orderedConfigNames {
				deployerKey := validConfigNames[cliName]
				if replaceConfigs[deployerKey] {
					names = append(names, deployerKey)
				}
			}
			fmt.Fprintf(os.Stdout, "Packages will be installed. The following configurations will be replaced (with backups): %s\n", strings.Join(names, ", "))
		} else {
			fmt.Fprintln(os.Stdout, "Packages will be installed. No configurations will be deployed.")
		}
		fmt.Fprintln(os.Stdout, "Re-run with --yes (-y) to proceed.")
		r.log("Aborted: --yes not set")
		return ErrConfirmationRequired
	}

	// 7. Authenticate sudo
	sudoPassword, err := r.resolveSudoPassword()
	if err != nil {
		return err
	}

	// 8. Install packages
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
			fmt.Fprintf(os.Stdout, "    %s\n", msg.LogOutput)
		}
	}

	if err := <-installErr; err != nil {
		return fmt.Errorf("package installation failed: %w", err)
	}

	useSystemd := true
	if distroConfig, exists := distros.Registry[osInfo.Distribution.ID]; exists && distroConfig.Family == distros.FamilyVoid {
		useSystemd = false
	}

	// 9. Greeter setup (if dms-greeter was included)
	if !disabledItems["dms-greeter"] && r.depExists(dependencies, "dms-greeter") {
		fmt.Fprintln(os.Stdout, "Configuring DMS greeter...")
		logFunc := func(line string) {
			r.log(line)
			fmt.Fprintf(os.Stdout, "  greeter: %s\n", line)
		}
		if err := utils.RunDmsGreeterInstall(sudoPassword, logFunc); err != nil {
			// Non-fatal, matching TUI behavior
			fmt.Fprintf(os.Stderr, "Warning: greeter setup issue (non-fatal): %v\n", err)
		}
	}

	// 9b. danksearch service setup (if danksearch was included)
	if useSystemd && !disabledItems["danksearch"] && r.depExists(dependencies, "danksearch") {
		fmt.Fprintln(os.Stdout, "Enabling danksearch service...")
		logFunc := func(line string) {
			r.log(line)
			fmt.Fprintf(os.Stdout, "  danksearch: %s\n", line)
		}
		if err := distros.SetupDsearchService(context.Background(), logFunc); err != nil {
			// Non-fatal, matching greeter behavior
			fmt.Fprintf(os.Stderr, "Warning: danksearch service setup issue (non-fatal): %v\n", err)
		}
	}

	// 10. Deploy configurations
	fmt.Fprintln(os.Stdout, "Deploying configurations...")
	r.log("Starting configuration deployment")

	deployer := config.NewConfigDeployer(r.logChan)
	results, err := deployer.DeployConfigurationsSelectiveWithReinstallsAndSystemd(
		context.Background(),
		wm,
		terminal,
		dependencies,
		replaceConfigs,
		reinstallItems,
		useSystemd,
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

func (r *Runner) applyPrivescTool() error {
	if r.cfg.PrivescTool == "" {
		return nil
	}
	switch tool := privesc.Tool(strings.ToLower(r.cfg.PrivescTool)); tool {
	case privesc.ToolSudo, privesc.ToolDoas, privesc.ToolRun0:
		if err := privesc.SetTool(tool); err != nil {
			return fmt.Errorf("--privesc: %w", err)
		}
		return nil
	default:
		return fmt.Errorf("invalid --privesc value %q: must be 'sudo', 'doas', or 'run0'", r.cfg.PrivescTool)
	}
}

// CanToggle is not enough: some distros discard the variant (hyprland on Arch maps to stable either way)
func gitVariantChecker(distro distros.Distribution, wm deps.WindowManager, dependencies []deps.Dependency) func(name string) bool {
	stable := distro.GetPackageMappingWithVariants(wm, map[string]deps.PackageVariant{})
	allGit := make(map[string]deps.PackageVariant, len(dependencies))
	for _, dep := range dependencies {
		allGit[dep.Name] = deps.VariantGit
	}
	git := distro.GetPackageMappingWithVariants(wm, allGit)
	return func(name string) bool {
		mapping, ok := git[name]
		return ok && mapping != stable[name]
	}
}

func (r *Runner) applyGitVariants(dependencies []deps.Dependency, hasGitVariant func(name string) bool) (map[string]bool, error) {
	reinstallItems := make(map[string]bool)

	// InstallPackages skips StatusInstalled deps unless marked for reinstall
	markGit := func(dep *deps.Dependency) {
		if dep.Variant == deps.VariantStable && dep.Status == deps.StatusInstalled {
			reinstallItems[dep.Name] = true
		}
		dep.Variant = deps.VariantGit
	}

	for _, name := range r.cfg.GitDeps {
		name = strings.ToLower(strings.TrimSpace(name))
		if name == "" {
			continue
		}
		dep := findDepFold(dependencies, name)
		if dep == nil {
			return nil, fmt.Errorf("--git-deps: unknown dependency %q", name)
		}
		if !dep.CanToggle || !hasGitVariant(dep.Name) {
			return nil, fmt.Errorf("--git-deps: %q does not have a git variant on this distribution", dep.Name)
		}
		markGit(dep)
	}

	if !r.cfg.GitAll {
		return reinstallItems, nil
	}

	for i := range dependencies {
		if dependencies[i].CanToggle && hasGitVariant(dependencies[i].Name) {
			markGit(&dependencies[i])
		}
	}
	return reinstallItems, nil
}

func findDepFold(dependencies []deps.Dependency, lowerName string) *deps.Dependency {
	if lowerName == "dms" {
		lowerName = "dms (dankmaterialshell)"
	}
	for i := range dependencies {
		if strings.ToLower(dependencies[i].Name) == lowerName {
			return &dependencies[i]
		}
	}
	return nil
}

// buildDisabledItems computes the set of dependencies that should be skipped
// during installation. Optional components are opt-in (disabled by default),
// then re-enabled by --all-features, the dedicated flags, and --include-deps.
func (r *Runner) buildDisabledItems(dependencies []deps.Dependency) (map[string]bool, error) {
	disabledItems := make(map[string]bool)

	if !r.cfg.AllFeatures {
		for i := range dependencies {
			if !dependencies[i].Required {
				disabledItems[dependencies[i].Name] = true
			}
		}
	}

	// Dedicated flags resolve before include/exclude
	if r.cfg.DankSearch {
		if !r.depExists(dependencies, "danksearch") {
			return nil, fmt.Errorf("--danksearch: not available on this distribution")
		}
		delete(disabledItems, "danksearch")
	}
	if r.cfg.DankCalendar {
		if !r.depExists(dependencies, "dankcalendar") {
			return nil, fmt.Errorf("--dankcalendar: not available on this distribution")
		}
		delete(disabledItems, "dankcalendar")
	}
	if r.cfg.DmsGreeter {
		if !r.depExists(dependencies, "dms-greeter") {
			return nil, fmt.Errorf("--dms-greeter: not available on this distribution")
		}
		delete(disabledItems, "dms-greeter")
	}

	// Process --include-deps (enable items that are disabled by default)
	for _, name := range r.cfg.IncludeDeps {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		if !r.depExists(dependencies, name) {
			return nil, fmt.Errorf("--include-deps: unknown dependency %q", name)
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
			return nil, fmt.Errorf("--exclude-deps: unknown dependency %q", name)
		}
		// Don't allow excluding DMS itself
		if name == "dms (DankMaterialShell)" {
			return nil, fmt.Errorf("--exclude-deps: cannot exclude required package %q", name)
		}
		disabledItems[name] = true
	}

	return disabledItems, nil
}

// buildReplaceConfigs converts the --replace-configs / --replace-configs-all
// flags into the map[string]bool consumed by the config deployer.
//
// Returns:
//   - nil when --replace-configs-all is set (deployer treats nil as "replace all")
//   - a map with all known configs set to false when neither flag is set (deploy only if config file is missing on disk)
//   - a map with requested configs true, all others false for --replace-configs
//   - an error when both flags are set or an invalid config name is given
func (r *Runner) buildReplaceConfigs() (map[string]bool, error) {
	hasSpecific := len(r.cfg.ReplaceConfigs) > 0
	if hasSpecific && r.cfg.ReplaceConfigsAll {
		return nil, fmt.Errorf("--replace-configs and --replace-configs-all are mutually exclusive")
	}

	if r.cfg.ReplaceConfigsAll {
		return nil, nil
	}

	// Build a map with all known configs explicitly set to false
	result := make(map[string]bool, len(validConfigNames))
	for _, cliName := range orderedConfigNames {
		result[validConfigNames[cliName]] = false
	}

	// Enable only the requested configs
	for _, name := range r.cfg.ReplaceConfigs {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		deployerKey, ok := validConfigNames[strings.ToLower(name)]
		if !ok {
			return nil, fmt.Errorf("--replace-configs: unknown config %q; valid values: niri, hyprland, ghostty, kitty, alacritty", name)
		}
		result[deployerKey] = true
	}

	return result, nil
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
	case "mango", "mangowc":
		return deps.WindowManagerMango, nil
	default:
		return 0, fmt.Errorf("invalid --compositor value %q: must be 'niri', 'hyprland', or 'mango'", r.cfg.Compositor)
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
	tool, err := privesc.Detect()
	if err != nil {
		return "", err
	}

	if err := privesc.CheckCached(context.Background()); err == nil {
		r.log(fmt.Sprintf("%s cache is valid, no password needed", tool.Name()))
		fmt.Fprintf(os.Stdout, "%s: using cached credentials\n", tool.Name())
		return "", nil
	}

	switch tool {
	case privesc.ToolSudo:
		return "", fmt.Errorf(
			"sudo authentication required but no cached credentials found\n" +
				"Options:\n" +
				"  1. Run 'sudo -v' before dankinstall to cache credentials\n" +
				"  2. Configure passwordless sudo for your user",
		)
	case privesc.ToolDoas:
		return "", fmt.Errorf(
			"doas authentication required but no cached credentials found\n" +
				"Options:\n" +
				"  1. Run 'doas true' before dankinstall to cache credentials (requires 'persist' in /etc/doas.conf)\n" +
				"  2. Configure a 'nopass' rule in /etc/doas.conf for your user",
		)
	case privesc.ToolRun0:
		return "", fmt.Errorf(
			"run0 authentication required but no cached credentials found\n" +
				"Configure a polkit rule granting your user passwordless privilege\n" +
				"(see `man polkit` for details on rules in /etc/polkit-1/rules.d/)",
		)
	default:
		return "", fmt.Errorf("unsupported privilege tool: %s", tool)
	}
}

func (r *Runner) anyConfigEnabled(m map[string]bool) bool {
	for _, v := range m {
		if v {
			return true
		}
	}
	return false
}

func (r *Runner) depExists(dependencies []deps.Dependency, name string) bool {
	for _, dep := range dependencies {
		if dep.Name == name {
			return true
		}
	}
	return false
}
