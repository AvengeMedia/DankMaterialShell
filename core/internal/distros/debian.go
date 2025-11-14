package distros

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
)

func init() {
	Register("debian", "#A80030", FamilyDebian, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewDebianDistribution(config, logChan)
	})
}

type DebianDistribution struct {
	*BaseDistribution
	*ManualPackageInstaller
	config DistroConfig
}

func NewDebianDistribution(config DistroConfig, logChan chan<- string) *DebianDistribution {
	base := NewBaseDistribution(logChan)
	return &DebianDistribution{
		BaseDistribution:       base,
		ManualPackageInstaller: &ManualPackageInstaller{BaseDistribution: base},
		config:                 config,
	}
}

func (d *DebianDistribution) GetID() string {
	return d.config.ID
}

func (d *DebianDistribution) GetColorHex() string {
	return d.config.ColorHex
}

func (d *DebianDistribution) GetFamily() DistroFamily {
	return d.config.Family
}

func (d *DebianDistribution) GetPackageManager() PackageManagerType {
	return PackageManagerAPT
}

func (d *DebianDistribution) DetectDependencies(ctx context.Context, wm deps.WindowManager) ([]deps.Dependency, error) {
	return d.DetectDependenciesWithTerminal(ctx, wm, deps.TerminalGhostty)
}

func (d *DebianDistribution) DetectDependenciesWithTerminal(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal) ([]deps.Dependency, error) {
	var dependencies []deps.Dependency

	dependencies = append(dependencies, d.detectDMS())

	dependencies = append(dependencies, d.detectSpecificTerminal(terminal))

	dependencies = append(dependencies, d.detectGit())
	dependencies = append(dependencies, d.detectWindowManager(wm))
	dependencies = append(dependencies, d.detectQuickshell())
	dependencies = append(dependencies, d.detectXDGPortal())
	dependencies = append(dependencies, d.detectPolkitAgent())
	dependencies = append(dependencies, d.detectAccountsService())

	if wm == deps.WindowManagerNiri {
		dependencies = append(dependencies, d.detectXwaylandSatellite())
	}

	dependencies = append(dependencies, d.detectMatugen())
	dependencies = append(dependencies, d.detectDgop())
	dependencies = append(dependencies, d.detectHyprpicker())
	dependencies = append(dependencies, d.detectClipboardTools()...)

	return dependencies, nil
}

func (d *DebianDistribution) detectXDGPortal() deps.Dependency {
	status := deps.StatusMissing
	if d.packageInstalled("xdg-desktop-portal-gtk") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xdg-desktop-portal-gtk",
		Status:      status,
		Description: "Desktop integration portal for GTK",
		Required:    true,
	}
}

func (d *DebianDistribution) detectPolkitAgent() deps.Dependency {
	status := deps.StatusMissing
	if d.packageInstalled("mate-polkit") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "mate-polkit",
		Status:      status,
		Description: "PolicyKit authentication agent",
		Required:    true,
	}
}

func (d *DebianDistribution) detectXwaylandSatellite() deps.Dependency {
	status := deps.StatusMissing
	if d.commandExists("xwayland-satellite") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xwayland-satellite",
		Status:      status,
		Description: "Xwayland support",
		Required:    true,
	}
}

func (d *DebianDistribution) detectAccountsService() deps.Dependency {
	status := deps.StatusMissing
	if d.packageInstalled("accountsservice") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "accountsservice",
		Status:      status,
		Description: "D-Bus interface for user account query and manipulation",
		Required:    true,
	}
}

func (d *DebianDistribution) packageInstalled(pkg string) bool {
	cmd := exec.Command("dpkg", "-l", pkg)
	err := cmd.Run()
	return err == nil
}

func (d *DebianDistribution) GetPackageMapping(wm deps.WindowManager) map[string]PackageMapping {
	packages := map[string]PackageMapping{
		"git":                    {Name: "git", Repository: RepoTypeSystem},
		"kitty":                  {Name: "kitty", Repository: RepoTypeSystem},
		"alacritty":              {Name: "alacritty", Repository: RepoTypeSystem},
		"wl-clipboard":           {Name: "wl-clipboard", Repository: RepoTypeSystem},
		"xdg-desktop-portal-gtk": {Name: "xdg-desktop-portal-gtk", Repository: RepoTypeSystem},
		"mate-polkit":            {Name: "mate-polkit", Repository: RepoTypeSystem},
		"accountsservice":        {Name: "accountsservice", Repository: RepoTypeSystem},

		"dms (DankMaterialShell)": {Name: "dms", Repository: RepoTypeManual, BuildFunc: "installDankMaterialShell"},
		"niri":                    {Name: "niri", Repository: RepoTypeManual, BuildFunc: "installNiri"},
		"quickshell":              {Name: "quickshell", Repository: RepoTypeManual, BuildFunc: "installQuickshell"},
		"ghostty":                 {Name: "ghostty", Repository: RepoTypeManual, BuildFunc: "installGhostty"},
		"matugen":                 {Name: "matugen", Repository: RepoTypeManual, BuildFunc: "installMatugen"},
		"dgop":                    {Name: "dgop", Repository: RepoTypeManual, BuildFunc: "installDgop"},
		"cliphist":                {Name: "cliphist", Repository: RepoTypeManual, BuildFunc: "installCliphist"},
		"hyprpicker":              {Name: "hyprpicker", Repository: RepoTypeManual, BuildFunc: "installHyprpicker"},
	}

	if wm == deps.WindowManagerNiri {
		packages["niri"] = PackageMapping{Name: "niri", Repository: RepoTypeManual, BuildFunc: "installNiri"}
		packages["xwayland-satellite"] = PackageMapping{Name: "xwayland-satellite", Repository: RepoTypeManual, BuildFunc: "installXwaylandSatellite"}
	}

	return packages
}

func (d *DebianDistribution) InstallPrerequisites(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.06,
		Step:       "Updating package lists...",
		IsComplete: false,
		LogOutput:  "Updating APT package lists",
	}

	updateCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get update")
	if err := d.runWithProgress(updateCmd, progressChan, PhasePrerequisites, 0.06, 0.07); err != nil {
		return fmt.Errorf("failed to update package lists: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhasePrerequisites,
		Progress:    0.08,
		Step:        "Installing build-essential...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get install -y build-essential",
		LogOutput:   "Installing build tools",
	}

	checkCmd := exec.CommandContext(ctx, "dpkg", "-l", "build-essential")
	if err := checkCmd.Run(); err != nil {
		cmd := ExecSudoCommand(ctx, sudoPassword, "apt-get install -y build-essential")
		if err := d.runWithProgress(cmd, progressChan, PhasePrerequisites, 0.08, 0.09); err != nil {
			return fmt.Errorf("failed to install build-essential: %w", err)
		}
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhasePrerequisites,
		Progress:    0.10,
		Step:        "Installing development dependencies...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get install -y curl wget git cmake ninja-build pkg-config libxcb-cursor-dev libglib2.0-dev libpolkit-agent-1-dev",
		LogOutput:   "Installing additional development tools",
	}

	devToolsCmd := ExecSudoCommand(ctx, sudoPassword,
		"apt-get install -y curl wget git cmake ninja-build pkg-config libxcb-cursor-dev libglib2.0-dev libpolkit-agent-1-dev")
	if err := d.runWithProgress(devToolsCmd, progressChan, PhasePrerequisites, 0.10, 0.12); err != nil {
		return fmt.Errorf("failed to install development tools: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.12,
		Step:       "Prerequisites installation complete",
		IsComplete: false,
		LogOutput:  "Prerequisites successfully installed",
	}

	return nil
}

func (d *DebianDistribution) InstallPackages(ctx context.Context, dependencies []deps.Dependency, wm deps.WindowManager, sudoPassword string, reinstallFlags map[string]bool, disabledFlags map[string]bool, skipGlobalUseFlags bool, progressChan chan<- InstallProgressMsg) error {
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.05,
		Step:       "Checking system prerequisites...",
		IsComplete: false,
		LogOutput:  "Starting prerequisite check...",
	}

	if err := d.InstallPrerequisites(ctx, sudoPassword, progressChan); err != nil {
		return fmt.Errorf("failed to install prerequisites: %w", err)
	}

	systemPkgs, manualPkgs, variantMap := d.categorizePackages(dependencies, wm, reinstallFlags, disabledFlags)

	if len(systemPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.35,
			Step:       fmt.Sprintf("Installing %d system packages...", len(systemPkgs)),
			IsComplete: false,
			NeedsSudo:  true,
			LogOutput:  fmt.Sprintf("Installing system packages: %s", strings.Join(systemPkgs, ", ")),
		}
		if err := d.installAPTPackages(ctx, systemPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install APT packages: %w", err)
		}
	}

	if len(manualPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.80,
			Step:       "Installing build dependencies...",
			IsComplete: false,
			LogOutput:  "Installing build tools for manual compilation",
		}
		if err := d.installBuildDependencies(ctx, manualPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install build dependencies: %w", err)
		}

		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.85,
			Step:       fmt.Sprintf("Building %d packages from source...", len(manualPkgs)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Building from source: %s", strings.Join(manualPkgs, ", ")),
		}
		if err := d.InstallManualPackages(ctx, manualPkgs, variantMap, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install manual packages: %w", err)
		}
	}

	progressChan <- InstallProgressMsg{
		Phase:      PhaseConfiguration,
		Progress:   0.90,
		Step:       "Configuring system...",
		IsComplete: false,
		LogOutput:  "Starting post-installation configuration...",
	}

	progressChan <- InstallProgressMsg{
		Phase:      PhaseComplete,
		Progress:   1.0,
		Step:       "Installation complete!",
		IsComplete: true,
		LogOutput:  "All packages installed and configured successfully",
	}

	return nil
}

func (d *DebianDistribution) categorizePackages(dependencies []deps.Dependency, wm deps.WindowManager, reinstallFlags map[string]bool, disabledFlags map[string]bool) ([]string, []string, map[string]deps.PackageVariant) {
	systemPkgs := []string{}
	manualPkgs := []string{}

	variantMap := make(map[string]deps.PackageVariant)
	for _, dep := range dependencies {
		variantMap[dep.Name] = dep.Variant
	}

	packageMap := d.GetPackageMapping(wm)

	for _, dep := range dependencies {
		if disabledFlags[dep.Name] {
			continue
		}

		if dep.Status == deps.StatusInstalled && !reinstallFlags[dep.Name] {
			continue
		}

		pkgInfo, exists := packageMap[dep.Name]
		if !exists {
			d.log(fmt.Sprintf("Warning: No package mapping for %s", dep.Name))
			continue
		}

		switch pkgInfo.Repository {
		case RepoTypeSystem:
			systemPkgs = append(systemPkgs, pkgInfo.Name)
		case RepoTypeManual:
			manualPkgs = append(manualPkgs, dep.Name)
		}
	}

	return systemPkgs, manualPkgs, variantMap
}

func (d *DebianDistribution) installAPTPackages(ctx context.Context, packages []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	d.log(fmt.Sprintf("Installing APT packages: %s", strings.Join(packages, ", ")))

	args := []string{"apt-get", "install", "-y"}
	args = append(args, packages...)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.40,
		Step:        "Installing system packages...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: fmt.Sprintf("sudo %s", strings.Join(args, " ")),
	}

	cmd := ExecSudoCommand(ctx, sudoPassword, strings.Join(args, " "))
	return d.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.40, 0.60)
}

func (d *DebianDistribution) installBuildDependencies(ctx context.Context, manualPkgs []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	buildDeps := make(map[string]bool)

	for _, pkg := range manualPkgs {
		switch pkg {
		case "niri":
			buildDeps["curl"] = true
			buildDeps["libxkbcommon-dev"] = true
			buildDeps["libwayland-dev"] = true
			buildDeps["libudev-dev"] = true
			buildDeps["libinput-dev"] = true
			buildDeps["libdisplay-info-dev"] = true
			buildDeps["libpango1.0-dev"] = true
			buildDeps["libcairo-dev"] = true
			buildDeps["libpipewire-0.3-dev"] = true
			buildDeps["libc6-dev"] = true
			buildDeps["clang"] = true
			buildDeps["libseat-dev"] = true
			buildDeps["libgbm-dev"] = true
			buildDeps["alacritty"] = true
			buildDeps["fuzzel"] = true
		case "quickshell":
			buildDeps["qt6-base-dev"] = true
			buildDeps["qt6-base-private-dev"] = true
			buildDeps["qt6-declarative-dev"] = true
			buildDeps["qt6-declarative-private-dev"] = true
			buildDeps["qt6-wayland-dev"] = true
			buildDeps["qt6-wayland-private-dev"] = true
			buildDeps["qt6-tools-dev"] = true
			buildDeps["libqt6svg6-dev"] = true
			buildDeps["qt6-shadertools-dev"] = true
			buildDeps["spirv-tools"] = true
			buildDeps["libcli11-dev"] = true
			buildDeps["libjemalloc-dev"] = true
			buildDeps["libwayland-dev"] = true
			buildDeps["wayland-protocols"] = true
			buildDeps["libdrm-dev"] = true
			buildDeps["libgbm-dev"] = true
			buildDeps["libegl-dev"] = true
			buildDeps["libgles2-mesa-dev"] = true
			buildDeps["libgl1-mesa-dev"] = true
			buildDeps["libxcb1-dev"] = true
			buildDeps["libpipewire-0.3-dev"] = true
			buildDeps["libpam0g-dev"] = true
		case "ghostty":
			buildDeps["curl"] = true
		case "matugen":
			buildDeps["curl"] = true
		}
	}

	for _, pkg := range manualPkgs {
		switch pkg {
		case "niri", "matugen":
			if err := d.installRust(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install Rust: %w", err)
			}
		case "cliphist", "dgop":
			if err := d.installGo(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install Go: %w", err)
			}
		}
	}

	if len(buildDeps) == 0 {
		return nil
	}

	depList := make([]string, 0, len(buildDeps))
	for dep := range buildDeps {
		depList = append(depList, dep)
	}

	args := []string{"apt-get", "install", "-y"}
	args = append(args, depList...)

	cmd := ExecSudoCommand(ctx, sudoPassword, strings.Join(args, " "))
	return d.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.80, 0.82)
}

func (d *DebianDistribution) installRust(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if d.commandExists("cargo") {
		return nil
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.82,
		Step:        "Installing rustup...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get install rustup",
	}

	rustupInstallCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get install -y rustup")
	if err := d.runWithProgress(rustupInstallCmd, progressChan, PhaseSystemPackages, 0.82, 0.83); err != nil {
		return fmt.Errorf("failed to install rustup: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.83,
		Step:        "Installing stable Rust toolchain...",
		IsComplete:  false,
		CommandInfo: "rustup install stable",
	}

	rustInstallCmd := exec.CommandContext(ctx, "bash", "-c", "rustup install stable && rustup default stable")
	if err := d.runWithProgress(rustInstallCmd, progressChan, PhaseSystemPackages, 0.83, 0.84); err != nil {
		return fmt.Errorf("failed to install Rust toolchain: %w", err)
	}

	if !d.commandExists("cargo") {
		d.log("Warning: cargo not found in PATH after Rust installation, trying to source environment")
	}

	return nil
}

func (d *DebianDistribution) installGo(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if d.commandExists("go") {
		return nil
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.87,
		Step:        "Installing Go...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get install golang-go",
	}

	installCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get install -y golang-go")
	return d.runWithProgress(installCmd, progressChan, PhaseSystemPackages, 0.87, 0.90)
}

func (d *DebianDistribution) installGhosttyDebian(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	d.log("Installing Ghostty using Debian installer script...")

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Running Ghostty Debian installer...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | sudo bash",
		LogOutput:   "Installing Ghostty using pre-built Debian package",
	}

	installCmd := ExecSudoCommand(ctx, sudoPassword,
		"/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)\"")

	if err := d.runWithProgress(installCmd, progressChan, PhaseSystemPackages, 0.1, 0.9); err != nil {
		return fmt.Errorf("failed to install Ghostty: %w", err)
	}

	d.log("Ghostty installed successfully using Debian installer")
	return nil
}

func (d *DebianDistribution) InstallManualPackages(ctx context.Context, packages []string, variantMap map[string]deps.PackageVariant, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	d.log(fmt.Sprintf("Installing manual packages: %s", strings.Join(packages, ", ")))

	for _, pkg := range packages {
		switch pkg {
		case "ghostty":
			if err := d.installGhosttyDebian(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install ghostty: %w", err)
			}
		default:
			if err := d.ManualPackageInstaller.InstallManualPackages(ctx, []string{pkg}, variantMap, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install %s: %w", pkg, err)
			}
		}
	}

	return nil
}
