package distros

import (
	"context"
	"fmt"
	"os/exec"
	"runtime"
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
	dependencies = append(dependencies, d.detectDMSGreeter())
	dependencies = append(dependencies, d.detectXDGPortal())
	dependencies = append(dependencies, d.detectAccountsService())

	if wm == deps.WindowManagerNiri {
		dependencies = append(dependencies, d.detectXwaylandSatellite())
	}

	dependencies = append(dependencies, d.detectMatugen())
	dependencies = append(dependencies, d.detectDgop())

	return dependencies, nil
}

func (d *DebianDistribution) detectXDGPortal() deps.Dependency {
	return d.detectPackage("xdg-desktop-portal-gtk", "Desktop integration portal for GTK", d.packageInstalled("xdg-desktop-portal-gtk"))
}

func (d *DebianDistribution) detectXwaylandSatellite() deps.Dependency {
	return d.detectCommand("xwayland-satellite", "Xwayland support")
}

func (d *DebianDistribution) detectAccountsService() deps.Dependency {
	return d.detectPackage("accountsservice", "D-Bus interface for user account query and manipulation", d.packageInstalled("accountsservice"))
}

func (d *DebianDistribution) detectDMSGreeter() deps.Dependency {
	return d.detectOptionalPackage("dms-greeter", "DankMaterialShell greetd greeter", d.packageInstalled("dms-greeter"))
}

func (d *DebianDistribution) packageInstalled(pkg string) bool {
	cmd := exec.Command("dpkg", "-l", pkg)
	err := cmd.Run()
	return err == nil
}

func (d *DebianDistribution) GetPackageMapping(wm deps.WindowManager) map[string]PackageMapping {
	return d.GetPackageMappingWithVariants(wm, make(map[string]deps.PackageVariant))
}

func (d *DebianDistribution) GetPackageMappingWithVariants(wm deps.WindowManager, variants map[string]deps.PackageVariant) map[string]PackageMapping {
	packages := map[string]PackageMapping{
		// Standard APT packages
		"git":                    {Name: "git", Repository: RepoTypeSystem},
		"kitty":                  {Name: "kitty", Repository: RepoTypeSystem},
		"alacritty":              {Name: "alacritty", Repository: RepoTypeSystem},
		"xdg-desktop-portal-gtk": {Name: "xdg-desktop-portal-gtk", Repository: RepoTypeSystem},
		"accountsservice":        {Name: "accountsservice", Repository: RepoTypeSystem},

		// DMS packages from OBS with variant support
		"dms (DankMaterialShell)": d.getDmsMapping(variants["dms (DankMaterialShell)"]),
		"quickshell":              d.getQuickshellMapping(variants["quickshell"]),
		"dms-greeter":             {Name: "dms-greeter", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"},
		"matugen":                 {Name: "matugen", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"},
		"dgop":                    {Name: "dgop", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"},
		"ghostty":                 {Name: "ghostty", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"},
	}

	if wm == deps.WindowManagerNiri {
		niriVariant := variants["niri"]
		packages["niri"] = d.getNiriMapping(niriVariant)
		packages["xwayland-satellite"] = d.getXwaylandSatelliteMapping(niriVariant)
	}

	return packages
}

func (d *DebianDistribution) getDmsMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "dms-git", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:dms-git"}
	}
	return PackageMapping{Name: "dms", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:dms"}
}

func (d *DebianDistribution) getQuickshellMapping(variant deps.PackageVariant) PackageMapping {
	if forceQuickshellGit || variant == deps.VariantGit {
		return PackageMapping{Name: "quickshell-git", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"}
	}
	return PackageMapping{Name: "quickshell", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"}
}

func (d *DebianDistribution) getNiriMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "niri-git", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"}
	}
	return PackageMapping{Name: "niri", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"}
}

func (d *DebianDistribution) getXwaylandSatelliteMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "xwayland-satellite-git", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"}
	}
	return PackageMapping{Name: "xwayland-satellite", Repository: RepoTypeOBS, RepoURL: "home:AvengeMedia:danklinux"}
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
		cmd := ExecSudoCommand(ctx, sudoPassword, "DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential")
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
		"DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget git cmake ninja-build pkg-config libxcb-cursor-dev libglib2.0-dev libpolkit-agent-1-dev libjpeg-dev libpugixml-dev")
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

	systemPkgs, obsPkgs, manualPkgs, variantMap := d.categorizePackages(dependencies, wm, reinstallFlags, disabledFlags)

	// Enable OBS repositories
	if len(obsPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.15,
			Step:       "Enabling OBS repositories...",
			IsComplete: false,
			LogOutput:  "Setting up OBS repositories for additional packages",
		}
		if err := d.enableOBSRepos(ctx, obsPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to enable OBS repositories: %w", err)
		}
	}

	// System Packages
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

	// OBS Packages
	obsPkgNames := d.extractPackageNames(obsPkgs)
	if len(obsPkgNames) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseAURPackages,
			Progress:   0.65,
			Step:       fmt.Sprintf("Installing %d OBS packages...", len(obsPkgNames)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Installing OBS packages: %s", strings.Join(obsPkgNames, ", ")),
		}
		if err := d.installAPTPackages(ctx, obsPkgNames, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install OBS packages: %w", err)
		}
	}

	// Manual Builds
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

	terminal := d.DetectTerminalFromDeps(dependencies)
	if err := d.WriteEnvironmentConfig(terminal); err != nil {
		d.log(fmt.Sprintf("Warning: failed to write environment config: %v", err))
	}

	if err := d.WriteWindowManagerConfig(wm); err != nil {
		d.log(fmt.Sprintf("Warning: failed to write window manager config: %v", err))
	}

	if err := d.EnableDMSService(ctx, wm); err != nil {
		d.log(fmt.Sprintf("Warning: failed to enable dms service: %v", err))
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

func (d *DebianDistribution) categorizePackages(dependencies []deps.Dependency, wm deps.WindowManager, reinstallFlags map[string]bool, disabledFlags map[string]bool) ([]string, []PackageMapping, []string, map[string]deps.PackageVariant) {
	systemPkgs := []string{}
	obsPkgs := []PackageMapping{}
	manualPkgs := []string{}

	variantMap := make(map[string]deps.PackageVariant)
	for _, dep := range dependencies {
		variantMap[dep.Name] = dep.Variant
	}

	packageMap := d.GetPackageMappingWithVariants(wm, variantMap)

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
		case RepoTypeOBS:
			obsPkgs = append(obsPkgs, pkgInfo)
		case RepoTypeManual:
			manualPkgs = append(manualPkgs, dep.Name)
		}
	}

	return systemPkgs, obsPkgs, manualPkgs, variantMap
}

func (d *DebianDistribution) extractPackageNames(packages []PackageMapping) []string {
	names := make([]string, len(packages))
	for i, pkg := range packages {
		names[i] = pkg.Name
	}
	return names
}

func (d *DebianDistribution) enableOBSRepos(ctx context.Context, obsPkgs []PackageMapping, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	enabledRepos := make(map[string]bool)

	osInfo, err := GetOSInfo()
	if err != nil {
		return fmt.Errorf("failed to get OS info: %w", err)
	}

	// Determine Debian version for OBS repository URL
	debianVersion := "Debian_13"
	if osInfo.VersionID == "testing" {
		debianVersion = "Debian_Testing"
	} else if osInfo.VersionCodename == "sid" || osInfo.VersionID == "sid" || strings.Contains(strings.ToLower(osInfo.PrettyName), "sid") || strings.Contains(strings.ToLower(osInfo.PrettyName), "unstable") {
		debianVersion = "Debian_Unstable"
	}

	for _, pkg := range obsPkgs {
		if pkg.RepoURL != "" && !enabledRepos[pkg.RepoURL] {
			d.log(fmt.Sprintf("Enabling OBS repository: %s", pkg.RepoURL))

			// RepoURL format: "home:AvengeMedia:danklinux"
			repoPath := strings.ReplaceAll(pkg.RepoURL, ":", ":/")
			repoName := strings.ReplaceAll(pkg.RepoURL, ":", "-")
			baseURL := fmt.Sprintf("https://download.opensuse.org/repositories/%s/%s", repoPath, debianVersion)

			// Check if repository already exists
			listFile := fmt.Sprintf("/etc/apt/sources.list.d/%s.list", repoName)
			checkCmd := exec.CommandContext(ctx, "test", "-f", listFile)
			if checkCmd.Run() == nil {
				d.log(fmt.Sprintf("OBS repo %s already exists, skipping", pkg.RepoURL))
				enabledRepos[pkg.RepoURL] = true
				continue
			}

			keyringPath := fmt.Sprintf("/etc/apt/keyrings/%s.gpg", repoName)

			// Create keyrings directory if it doesn't exist
			mkdirCmd := ExecSudoCommand(ctx, sudoPassword, "mkdir -p /etc/apt/keyrings")
			if err := mkdirCmd.Run(); err != nil {
				d.log(fmt.Sprintf("Warning: failed to create keyrings directory: %v", err))
			}

			progressChan <- InstallProgressMsg{
				Phase:       PhaseSystemPackages,
				Progress:    0.18,
				Step:        fmt.Sprintf("Adding OBS GPG key for %s...", pkg.RepoURL),
				NeedsSudo:   true,
				CommandInfo: fmt.Sprintf("curl & gpg to add key for %s", pkg.RepoURL),
			}

			keyCmd := fmt.Sprintf("bash -c 'rm -f %s && curl -fsSL %s/Release.key | gpg --batch --dearmor -o %s'", keyringPath, baseURL, keyringPath)
			cmd := ExecSudoCommand(ctx, sudoPassword, keyCmd)
			if err := d.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.18, 0.20); err != nil {
				return fmt.Errorf("failed to add OBS GPG key for %s: %w", pkg.RepoURL, err)
			}

			// Add repository
			repoLine := fmt.Sprintf("deb [signed-by=%s arch=%s] %s/ /", keyringPath, runtime.GOARCH, baseURL)

			progressChan <- InstallProgressMsg{
				Phase:       PhaseSystemPackages,
				Progress:    0.20,
				Step:        fmt.Sprintf("Adding OBS repository %s...", pkg.RepoURL),
				NeedsSudo:   true,
				CommandInfo: fmt.Sprintf("echo '%s' | sudo tee %s", repoLine, listFile),
			}

			addRepoCmd := ExecSudoCommand(ctx, sudoPassword,
				fmt.Sprintf("bash -c \"echo '%s' | tee %s\"", repoLine, listFile))
			if err := d.runWithProgress(addRepoCmd, progressChan, PhaseSystemPackages, 0.20, 0.22); err != nil {
				return fmt.Errorf("failed to add OBS repo %s: %w", pkg.RepoURL, err)
			}

			enabledRepos[pkg.RepoURL] = true
			d.log(fmt.Sprintf("OBS repo %s enabled successfully", pkg.RepoURL))
		}
	}

	if len(enabledRepos) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:       PhaseSystemPackages,
			Progress:    0.25,
			Step:        "Updating package lists...",
			NeedsSudo:   true,
			CommandInfo: "sudo apt-get update",
		}

		updateCmd := ExecSudoCommand(ctx, sudoPassword, "apt-get update")
		if err := d.runWithProgress(updateCmd, progressChan, PhaseSystemPackages, 0.25, 0.27); err != nil {
			return fmt.Errorf("failed to update package lists after adding OBS repos: %w", err)
		}
	}

	return nil
}

func (d *DebianDistribution) installAPTPackages(ctx context.Context, packages []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	d.log(fmt.Sprintf("Installing APT packages: %s", strings.Join(packages, ", ")))

	args := []string{"DEBIAN_FRONTEND=noninteractive", "apt-get", "install", "-y"}
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
		case "dgop":
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

	rustupInstallCmd := ExecSudoCommand(ctx, sudoPassword, "DEBIAN_FRONTEND=noninteractive apt-get install -y rustup")
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

	installCmd := ExecSudoCommand(ctx, sudoPassword, "DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go")
	return d.runWithProgress(installCmd, progressChan, PhaseSystemPackages, 0.87, 0.90)
}

func (d *DebianDistribution) InstallManualPackages(ctx context.Context, packages []string, variantMap map[string]deps.PackageVariant, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	d.log(fmt.Sprintf("Installing manual packages: %s", strings.Join(packages, ", ")))

	for _, pkg := range packages {
		switch pkg {
		default:
			if err := d.ManualPackageInstaller.InstallManualPackages(ctx, []string{pkg}, variantMap, sudoPassword, progressChan); err != nil {
				return fmt.Errorf("failed to install %s: %w", pkg, err)
			}
		}
	}

	return nil
}
