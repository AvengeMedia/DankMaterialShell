package distros

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
)

func init() {
	Register("ubuntu", "#E95420", FamilyUbuntu, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewUbuntuDistribution(config, logChan)
	})
}

type UbuntuDistribution struct {
	*BaseDistribution
	*ManualPackageInstaller
	config DistroConfig
}

func NewUbuntuDistribution(config DistroConfig, logChan chan<- string) *UbuntuDistribution {
	base := NewBaseDistribution(logChan)
	return &UbuntuDistribution{
		BaseDistribution:       base,
		ManualPackageInstaller: &ManualPackageInstaller{BaseDistribution: base},
		config:                 config,
	}
}

func (u *UbuntuDistribution) GetID() string {
	return u.config.ID
}

func (u *UbuntuDistribution) GetColorHex() string {
	return u.config.ColorHex
}

func (u *UbuntuDistribution) GetFamily() DistroFamily {
	return u.config.Family
}

func (u *UbuntuDistribution) GetPackageManager() PackageManagerType {
	return PackageManagerAPT
}

func (u *UbuntuDistribution) DetectDependencies(ctx context.Context, wm deps.WindowManager) ([]deps.Dependency, error) {
	return u.DetectDependenciesWithTerminal(ctx, wm, deps.TerminalGhostty)
}

func (u *UbuntuDistribution) DetectDependenciesWithTerminal(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal) ([]deps.Dependency, error) {
	var dependencies []deps.Dependency

	// DMS at the top (shell is prominent)
	dependencies = append(dependencies, u.detectDMS())

	// Terminal with choice support
	dependencies = append(dependencies, u.detectSpecificTerminal(terminal))

	// Common detections using base methods
	dependencies = append(dependencies, u.detectGit())
	dependencies = append(dependencies, u.detectWindowManager(wm))
	dependencies = append(dependencies, u.detectQuickshell())
	dependencies = append(dependencies, u.detectXDGPortal())
	dependencies = append(dependencies, u.detectPolkitAgent())
	dependencies = append(dependencies, u.detectAccountsService())

	// Hyprland-specific tools
	if wm == deps.WindowManagerHyprland {
		dependencies = append(dependencies, u.detectHyprlandTools()...)
	}

	// Niri-specific tools
	if wm == deps.WindowManagerNiri {
		dependencies = append(dependencies, u.detectXwaylandSatellite())
	}

	// Base detections (common across distros)
	dependencies = append(dependencies, u.detectMatugen())
	dependencies = append(dependencies, u.detectDgop())
	dependencies = append(dependencies, u.detectHyprpicker())
	dependencies = append(dependencies, u.detectClipboardTools()...)

	return dependencies, nil
}

func (u *UbuntuDistribution) detectXDGPortal() deps.Dependency {
	status := deps.StatusMissing
	if u.packageInstalled("xdg-desktop-portal-gtk") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xdg-desktop-portal-gtk",
		Status:      status,
		Description: "Desktop integration portal for GTK",
		Required:    true,
	}
}

func (u *UbuntuDistribution) detectPolkitAgent() deps.Dependency {
	status := deps.StatusMissing
	if u.packageInstalled("mate-polkit") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "mate-polkit",
		Status:      status,
		Description: "PolicyKit authentication agent",
		Required:    true,
	}
}

func (u *UbuntuDistribution) detectXwaylandSatellite() deps.Dependency {
	status := deps.StatusMissing
	if u.commandExists("xwayland-satellite") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xwayland-satellite",
		Status:      status,
		Description: "Xwayland support",
		Required:    true,
	}
}

func (u *UbuntuDistribution) detectAccountsService() deps.Dependency {
	status := deps.StatusMissing
	if u.packageInstalled("accountsservice") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "accountsservice",
		Status:      status,
		Description: "D-Bus interface for user account query and manipulation",
		Required:    true,
	}
}

func (u *UbuntuDistribution) packageInstalled(pkg string) bool {
	cmd := exec.Command("dpkg", "-l", pkg)
	err := cmd.Run()
	return err == nil
}

func (u *UbuntuDistribution) GetPackageMapping(wm deps.WindowManager) map[string]PackageMapping {
	packages := map[string]PackageMapping{
		// Standard APT packages
		"git":                    {Name: "git", Repository: RepoTypeSystem},
		"kitty":                  {Name: "kitty", Repository: RepoTypeSystem},
		"alacritty":              {Name: "alacritty", Repository: RepoTypeSystem},
		"wl-clipboard":           {Name: "wl-clipboard", Repository: RepoTypeSystem},
		"xdg-desktop-portal-gtk": {Name: "xdg-desktop-portal-gtk", Repository: RepoTypeSystem},
		"mate-polkit":            {Name: "mate-polkit", Repository: RepoTypeSystem},
		"accountsservice":        {Name: "accountsservice", Repository: RepoTypeSystem},
		"hyprpicker":             {Name: "hyprpicker", Repository: RepoTypePPA, RepoURL: "ppa:cppiber/hyprland"},

		// Manual builds (niri and quickshell likely not available in Ubuntu repos or PPAs)
		"dms (DankMaterialShell)": {Name: "dms", Repository: RepoTypeManual, BuildFunc: "installDankMaterialShell"},
		"niri":                    {Name: "niri", Repository: RepoTypeManual, BuildFunc: "installNiri"},
		"quickshell":              {Name: "quickshell", Repository: RepoTypeManual, BuildFunc: "installQuickshell"},
		"ghostty":                 {Name: "ghostty", Repository: RepoTypeManual, BuildFunc: "installGhostty"},
		"matugen":                 {Name: "matugen", Repository: RepoTypeManual, BuildFunc: "installMatugen"},
		"dgop":                    {Name: "dgop", Repository: RepoTypeManual, BuildFunc: "installDgop"},
		"cliphist":                {Name: "cliphist", Repository: RepoTypeManual, BuildFunc: "installCliphist"},
	}

	switch wm {
	case deps.WindowManagerHyprland:
		// Use the cppiber PPA for Hyprland
		packages["hyprland"] = PackageMapping{Name: "hyprland", Repository: RepoTypePPA, RepoURL: "ppa:cppiber/hyprland"}
		packages["grim"] = PackageMapping{Name: "grim", Repository: RepoTypeSystem}
		packages["slurp"] = PackageMapping{Name: "slurp", Repository: RepoTypeSystem}
		packages["hyprctl"] = PackageMapping{Name: "hyprland", Repository: RepoTypePPA, RepoURL: "ppa:cppiber/hyprland"}
		packages["grimblast"] = PackageMapping{Name: "grimblast", Repository: RepoTypeManual, BuildFunc: "installGrimblast"}
		packages["jq"] = PackageMapping{Name: "jq", Repository: RepoTypeSystem}
	case deps.WindowManagerNiri:
		packages["niri"] = PackageMapping{Name: "niri", Repository: RepoTypeManual, BuildFunc: "installNiri"}
		packages["xwayland-satellite"] = PackageMapping{Name: "xwayland-satellite", Repository: RepoTypeManual, BuildFunc: "installXwaylandSatellite"}
	}

	return packages
}

func (u *UbuntuDistribution) InstallPrerequisites(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.06,
		Step:       "Updating package lists...",
		IsComplete: false,
		LogOutput:  "Updating APT package lists",
	}

	updateCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get update")
	if err := u.runWithProgress(updateCmd, progressChan, PhasePrerequisites, 0.06, 0.07); err != nil {
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
		// Not installed, install it
		cmd := ExecSudoCommand(ctx, sudoPassword, "apt-get install -y build-essential")
		if err := u.runWithProgress(cmd, progressChan, PhasePrerequisites, 0.08, 0.09); err != nil {
			return fmt.Errorf("failed to install build-essential: %w", err)
		}
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhasePrerequisites,
		Progress:    0.10,
		Step:        "Installing development dependencies...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get install -y curl wget git cmake ninja-build pkg-config libglib2.0-dev libpolkit-agent-1-dev",
		LogOutput:   "Installing additional development tools",
	}

	devToolsCmd := ExecSudoCommand(ctx, sudoPassword,
		"apt-get install -y curl wget git cmake ninja-build pkg-config libglib2.0-dev libpolkit-agent-1-dev")
	if err := u.runWithProgress(devToolsCmd, progressChan, PhasePrerequisites, 0.10, 0.12); err != nil {
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

func (u *UbuntuDistribution) InstallPackages(ctx context.Context, dependencies []deps.Dependency, wm deps.WindowManager, sudoPassword string, reinstallFlags map[string]bool, disabledFlags map[string]bool, skipGlobalUseFlags bool, progressChan chan<- InstallProgressMsg) error {
	// Phase 1: Check Prerequisites
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.05,
		Step:       "Checking system prerequisites...",
		IsComplete: false,
		LogOutput:  "Starting prerequisite check...",
	}

	if err := u.InstallPrerequisites(ctx, sudoPassword, progressChan); err != nil {
		return fmt.Errorf("failed to install prerequisites: %w", err)
	}

	systemPkgs, ppaPkgs, manualPkgs, variantMap := u.categorizePackages(dependencies, wm, reinstallFlags, disabledFlags)

	// Phase 2: Enable PPA repositories
	if len(ppaPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.15,
			Step:       "Enabling PPA repositories...",
			IsComplete: false,
			LogOutput:  "Setting up PPA repositories for additional packages",
		}
		if err := u.enablePPARepos(ctx, ppaPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to enable PPA repositories: %w", err)
		}
	}

	// Phase 3: System Packages (APT)
	if len(systemPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.35,
			Step:       fmt.Sprintf("Installing %d system packages...", len(systemPkgs)),
			IsComplete: false,
			NeedsSudo:  true,
			LogOutput:  fmt.Sprintf("Installing system packages: %s", strings.Join(systemPkgs, ", ")),
		}
		if err := u.installAPTPackages(ctx, systemPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install APT packages: %w", err)
		}
	}

	// Phase 4: PPA Packages
	ppaPkgNames := u.extractPackageNames(ppaPkgs)
	if len(ppaPkgNames) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseAURPackages, // Reusing AUR phase for PPA
			Progress:   0.65,
			Step:       fmt.Sprintf("Installing %d PPA packages...", len(ppaPkgNames)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Installing PPA packages: %s", strings.Join(ppaPkgNames, ", ")),
		}
		if err := u.installPPAPackages(ctx, ppaPkgNames, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install PPA packages: %w", err)
		}
	}

	// Phase 5: Manual Builds
	if len(manualPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.80,
			Step:       "Installing build dependencies...",
			IsComplete: false,
			LogOutput:  "Installing build tools for manual compilation",
		}
		if err := u.installBuildDependencies(ctx, manualPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install build dependencies: %w", err)
		}

		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.85,
			Step:       fmt.Sprintf("Building %d packages from source...", len(manualPkgs)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Building from source: %s", strings.Join(manualPkgs, ", ")),
		}
		if err := u.InstallManualPackages(ctx, manualPkgs, variantMap, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install manual packages: %w", err)
		}
	}

	// Phase 6: Configuration
	progressChan <- InstallProgressMsg{
		Phase:      PhaseConfiguration,
		Progress:   0.90,
		Step:       "Configuring system...",
		IsComplete: false,
		LogOutput:  "Starting post-installation configuration...",
	}

	// Phase 7: Complete
	progressChan <- InstallProgressMsg{
		Phase:      PhaseComplete,
		Progress:   1.0,
		Step:       "Installation complete!",
		IsComplete: true,
		LogOutput:  "All packages installed and configured successfully",
	}

	return nil
}

func (u *UbuntuDistribution) categorizePackages(dependencies []deps.Dependency, wm deps.WindowManager, reinstallFlags map[string]bool, disabledFlags map[string]bool) ([]string, []PackageMapping, []string, map[string]deps.PackageVariant) {
	systemPkgs := []string{}
	ppaPkgs := []PackageMapping{}
	manualPkgs := []string{}

	variantMap := make(map[string]deps.PackageVariant)
	for _, dep := range dependencies {
		variantMap[dep.Name] = dep.Variant
	}

	packageMap := u.GetPackageMapping(wm)

	for _, dep := range dependencies {
		if disabledFlags[dep.Name] {
			continue
		}

		if dep.Status == deps.StatusInstalled && !reinstallFlags[dep.Name] {
			continue
		}

		pkgInfo, exists := packageMap[dep.Name]
		if !exists {
			u.log(fmt.Sprintf("Warning: No package mapping for %s", dep.Name))
			continue
		}

		switch pkgInfo.Repository {
		case RepoTypeSystem:
			systemPkgs = append(systemPkgs, pkgInfo.Name)
		case RepoTypePPA:
			ppaPkgs = append(ppaPkgs, pkgInfo)
		case RepoTypeManual:
			manualPkgs = append(manualPkgs, dep.Name)
		}
	}

	return systemPkgs, ppaPkgs, manualPkgs, variantMap
}

func (u *UbuntuDistribution) extractPackageNames(packages []PackageMapping) []string {
	names := make([]string, len(packages))
	for i, pkg := range packages {
		names[i] = pkg.Name
	}
	return names
}

func (u *UbuntuDistribution) enablePPARepos(ctx context.Context, ppaPkgs []PackageMapping, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	enabledRepos := make(map[string]bool)

	installPPACmd := ExecSudoCommand(ctx, sudoPassword,
		"apt-get install -y software-properties-common")
	if err := u.runWithProgress(installPPACmd, progressChan, PhaseSystemPackages, 0.15, 0.17); err != nil {
		return fmt.Errorf("failed to install software-properties-common: %w", err)
	}

	for _, pkg := range ppaPkgs {
		if pkg.RepoURL != "" && !enabledRepos[pkg.RepoURL] {
			u.log(fmt.Sprintf("Enabling PPA repository: %s", pkg.RepoURL))
			progressChan <- InstallProgressMsg{
				Phase:       PhaseSystemPackages,
				Progress:    0.20,
				Step:        fmt.Sprintf("Enabling PPA repo %s...", pkg.RepoURL),
				IsComplete:  false,
				NeedsSudo:   true,
				CommandInfo: fmt.Sprintf("sudo add-apt-repository -y %s", pkg.RepoURL),
			}

			cmd := ExecSudoCommand(ctx, sudoPassword,
				fmt.Sprintf("add-apt-repository -y %s", pkg.RepoURL))
			if err := u.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.20, 0.22); err != nil {
				u.logError(fmt.Sprintf("failed to enable PPA repo %s", pkg.RepoURL), err)
				return fmt.Errorf("failed to enable PPA repo %s: %w", pkg.RepoURL, err)
			}
			u.log(fmt.Sprintf("PPA repo %s enabled successfully", pkg.RepoURL))
			enabledRepos[pkg.RepoURL] = true
		}
	}

	if len(enabledRepos) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:       PhaseSystemPackages,
			Progress:    0.25,
			Step:        "Updating package lists...",
			IsComplete:  false,
			NeedsSudo:   true,
			CommandInfo: "sudo apt-get update",
		}

		updateCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get update")
		if err := u.runWithProgress(updateCmd, progressChan, PhaseSystemPackages, 0.25, 0.27); err != nil {
			return fmt.Errorf("failed to update package lists after adding PPAs: %w", err)
		}
	}

	return nil
}

func (u *UbuntuDistribution) installAPTPackages(ctx context.Context, packages []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	u.log(fmt.Sprintf("Installing APT packages: %s", strings.Join(packages, ", ")))

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
	return u.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.40, 0.60)
}

func (u *UbuntuDistribution) installPPAPackages(ctx context.Context, packages []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	u.log(fmt.Sprintf("Installing PPA packages: %s", strings.Join(packages, ", ")))

	args := []string{"apt-get", "install", "-y"}
	args = append(args, packages...)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseAURPackages,
		Progress:    0.70,
		Step:        "Installing PPA packages...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: fmt.Sprintf("sudo %s", strings.Join(args, " ")),
	}

	cmd := ExecSudoCommand(ctx, sudoPassword, strings.Join(args, " "))
	return u.runWithProgress(cmd, progressChan, PhaseAURPackages, 0.70, 0.85)
}

func (u *UbuntuDistribution) installBuildDependencies(ctx context.Context, manualPkgs []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
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
			buildDeps["libxcb-cursor-dev"] = true
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
			buildDeps["libgtk-4-dev"] = true
			buildDeps["libadwaita-1-dev"] = true
		case "matugen":
			buildDeps["curl"] = true
		case "cliphist":
			// Go will be installed separately with PPA
		}
	}

	for _, pkg := range manualPkgs {
		switch pkg {
		case "niri", "matugen":
			if err := u.installRust(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install Rust: %w", err)
			}
		case "ghostty":
			if err := u.installZig(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install Zig: %w", err)
			}
		case "cliphist", "dgop":
			if err := u.installGo(ctx, sudoPassword, progressChan); err != nil {
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
	return u.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.80, 0.82)
}

func (u *UbuntuDistribution) installRust(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if u.commandExists("cargo") {
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
	if err := u.runWithProgress(rustupInstallCmd, progressChan, PhaseSystemPackages, 0.82, 0.83); err != nil {
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
	if err := u.runWithProgress(rustInstallCmd, progressChan, PhaseSystemPackages, 0.83, 0.84); err != nil {
		return fmt.Errorf("failed to install Rust toolchain: %w", err)
	}

	// Verify cargo is now available
	if !u.commandExists("cargo") {
		u.log("Warning: cargo not found in PATH after Rust installation, trying to source environment")
	}

	return nil
}

func (u *UbuntuDistribution) installZig(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if u.commandExists("zig") {
		return nil
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	cacheDir := filepath.Join(homeDir, ".cache", "dankinstall")
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	zigUrl := "https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz"
	zigTmp := filepath.Join(cacheDir, "zig.tar.xz")

	downloadCmd := exec.CommandContext(ctx, "curl", "-L", zigUrl, "-o", zigTmp)
	if err := u.runWithProgress(downloadCmd, progressChan, PhaseSystemPackages, 0.84, 0.85); err != nil {
		return fmt.Errorf("failed to download Zig: %w", err)
	}

	extractCmd := ExecSudoCommand(ctx, sudoPassword,
		fmt.Sprintf("tar -xf %s -C /opt/", zigTmp))
	if err := u.runWithProgress(extractCmd, progressChan, PhaseSystemPackages, 0.85, 0.86); err != nil {
		return fmt.Errorf("failed to extract Zig: %w", err)
	}

	linkCmd := ExecSudoCommand(ctx, sudoPassword,
		"ln -sf /opt/zig-linux-x86_64-0.11.0/zig /usr/local/bin/zig")
	return u.runWithProgress(linkCmd, progressChan, PhaseSystemPackages, 0.86, 0.87)
}

func (u *UbuntuDistribution) installGo(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if u.commandExists("go") {
		return nil
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.87,
		Step:        "Adding Go PPA repository...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo add-apt-repository ppa:longsleep/golang-backports",
	}

	addPPACmd := ExecSudoCommand(ctx, sudoPassword,
		"add-apt-repository -y ppa:longsleep/golang-backports")
	if err := u.runWithProgress(addPPACmd, progressChan, PhaseSystemPackages, 0.87, 0.88); err != nil {
		return fmt.Errorf("failed to add Go PPA: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.88,
		Step:        "Updating package lists...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get update",
	}

	updateCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get update")
	if err := u.runWithProgress(updateCmd, progressChan, PhaseSystemPackages, 0.88, 0.89); err != nil {
		return fmt.Errorf("failed to update package lists after adding Go PPA: %w", err)
	}

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.89,
		Step:        "Installing Go...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "sudo apt-get install golang-go",
	}

	installCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get install -y golang-go")
	return u.runWithProgress(installCmd, progressChan, PhaseSystemPackages, 0.89, 0.90)
}

func (u *UbuntuDistribution) installGhosttyUbuntu(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	u.log("Installing Ghostty using Ubuntu installer script...")

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.1,
		Step:        "Running Ghostty Ubuntu installer...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: "curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh | sudo bash",
		LogOutput:   "Installing Ghostty using pre-built Ubuntu package",
	}

	installCmd := ExecSudoCommand(ctx, sudoPassword,
		"/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)\"")

	if err := u.runWithProgress(installCmd, progressChan, PhaseSystemPackages, 0.1, 0.9); err != nil {
		return fmt.Errorf("failed to install Ghostty: %w", err)
	}

	u.log("Ghostty installed successfully using Ubuntu installer")
	return nil
}

func (u *UbuntuDistribution) InstallManualPackages(ctx context.Context, packages []string, variantMap map[string]deps.PackageVariant, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	u.log(fmt.Sprintf("Installing manual packages: %s", strings.Join(packages, ", ")))

	for _, pkg := range packages {
		switch pkg {
		case "ghostty":
			if err := u.installGhosttyUbuntu(ctx, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install ghostty: %w", err)
			}
		default:
			if err := u.ManualPackageInstaller.InstallManualPackages(ctx, []string{pkg}, variantMap, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install %s: %w", pkg, err)
			}
		}
	}

	return nil
}
