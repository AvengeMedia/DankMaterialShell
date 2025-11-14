package distros

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
)

func init() {
	Register("fedora", "#0B57A4", FamilyFedora, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewFedoraDistribution(config, logChan)
	})
	Register("nobara", "#0B57A4", FamilyFedora, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewFedoraDistribution(config, logChan)
	})
	Register("fedora-asahi-remix", "#0B57A4", FamilyFedora, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewFedoraDistribution(config, logChan)
	})

	Register("bluefin", "#0B57A4", FamilyFedora, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewFedoraDistribution(config, logChan)
	})
}

type FedoraDistribution struct {
	*BaseDistribution
	*ManualPackageInstaller
	config DistroConfig
}

func NewFedoraDistribution(config DistroConfig, logChan chan<- string) *FedoraDistribution {
	base := NewBaseDistribution(logChan)
	return &FedoraDistribution{
		BaseDistribution:       base,
		ManualPackageInstaller: &ManualPackageInstaller{BaseDistribution: base},
		config:                 config,
	}
}

func (f *FedoraDistribution) GetID() string {
	return f.config.ID
}

func (f *FedoraDistribution) GetColorHex() string {
	return f.config.ColorHex
}

func (f *FedoraDistribution) GetFamily() DistroFamily {
	return f.config.Family
}

func (f *FedoraDistribution) GetPackageManager() PackageManagerType {
	return PackageManagerDNF
}

func (f *FedoraDistribution) DetectDependencies(ctx context.Context, wm deps.WindowManager) ([]deps.Dependency, error) {
	return f.DetectDependenciesWithTerminal(ctx, wm, deps.TerminalGhostty)
}

func (f *FedoraDistribution) DetectDependenciesWithTerminal(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal) ([]deps.Dependency, error) {
	var dependencies []deps.Dependency

	// DMS at the top (shell is prominent)
	dependencies = append(dependencies, f.detectDMS())

	// Terminal with choice support
	dependencies = append(dependencies, f.detectSpecificTerminal(terminal))

	// Common detections using base methods
	dependencies = append(dependencies, f.detectGit())
	dependencies = append(dependencies, f.detectWindowManager(wm))
	dependencies = append(dependencies, f.detectQuickshell())
	dependencies = append(dependencies, f.detectXDGPortal())
	dependencies = append(dependencies, f.detectPolkitAgent())
	dependencies = append(dependencies, f.detectAccountsService())

	// Hyprland-specific tools
	if wm == deps.WindowManagerHyprland {
		dependencies = append(dependencies, f.detectHyprlandTools()...)
	}

	// Niri-specific tools
	if wm == deps.WindowManagerNiri {
		dependencies = append(dependencies, f.detectXwaylandSatellite())
	}

	// Base detections (common across distros)
	dependencies = append(dependencies, f.detectMatugen())
	dependencies = append(dependencies, f.detectDgop())
	dependencies = append(dependencies, f.detectHyprpicker())
	dependencies = append(dependencies, f.detectClipboardTools()...)

	return dependencies, nil
}

func (f *FedoraDistribution) detectXDGPortal() deps.Dependency {
	status := deps.StatusMissing
	if f.packageInstalled("xdg-desktop-portal-gtk") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xdg-desktop-portal-gtk",
		Status:      status,
		Description: "Desktop integration portal for GTK",
		Required:    true,
	}
}

func (f *FedoraDistribution) detectPolkitAgent() deps.Dependency {
	status := deps.StatusMissing
	if f.packageInstalled("mate-polkit") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "mate-polkit",
		Status:      status,
		Description: "PolicyKit authentication agent",
		Required:    true,
	}
}

func (f *FedoraDistribution) packageInstalled(pkg string) bool {
	cmd := exec.Command("rpm", "-q", pkg)
	err := cmd.Run()
	return err == nil
}

func (f *FedoraDistribution) GetPackageMapping(wm deps.WindowManager) map[string]PackageMapping {
	return f.GetPackageMappingWithVariants(wm, make(map[string]deps.PackageVariant))
}

func (f *FedoraDistribution) GetPackageMappingWithVariants(wm deps.WindowManager, variants map[string]deps.PackageVariant) map[string]PackageMapping {
	packages := map[string]PackageMapping{
		// Standard DNF packages
		"git":                    {Name: "git", Repository: RepoTypeSystem},
		"ghostty":                {Name: "ghostty", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"},
		"kitty":                  {Name: "kitty", Repository: RepoTypeSystem},
		"alacritty":              {Name: "alacritty", Repository: RepoTypeSystem},
		"wl-clipboard":           {Name: "wl-clipboard", Repository: RepoTypeSystem},
		"xdg-desktop-portal-gtk": {Name: "xdg-desktop-portal-gtk", Repository: RepoTypeSystem},
		"mate-polkit":            {Name: "mate-polkit", Repository: RepoTypeSystem},
		"accountsservice":        {Name: "accountsservice", Repository: RepoTypeSystem},
		"hyprpicker":             f.getHyprpickerMapping(variants["hyprland"]),

		// COPR packages
		"quickshell":              f.getQuickshellMapping(variants["quickshell"]),
		"matugen":                 {Name: "matugen", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"},
		"cliphist":                {Name: "cliphist", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"},
		"dms (DankMaterialShell)": f.getDmsMapping(variants["dms (DankMaterialShell)"]),
		"dgop":                    {Name: "dgop", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"},
	}

	switch wm {
	case deps.WindowManagerHyprland:
		packages["hyprland"] = f.getHyprlandMapping(variants["hyprland"])
		packages["grim"] = PackageMapping{Name: "grim", Repository: RepoTypeSystem}
		packages["slurp"] = PackageMapping{Name: "slurp", Repository: RepoTypeSystem}
		packages["hyprctl"] = f.getHyprlandMapping(variants["hyprland"])
		packages["grimblast"] = PackageMapping{Name: "grimblast", Repository: RepoTypeManual, BuildFunc: "installGrimblast"}
		packages["jq"] = PackageMapping{Name: "jq", Repository: RepoTypeSystem}
	case deps.WindowManagerNiri:
		packages["niri"] = f.getNiriMapping(variants["niri"])
		packages["xwayland-satellite"] = PackageMapping{Name: "xwayland-satellite", Repository: RepoTypeCOPR, RepoURL: "yalter/niri"}
	}

	return packages
}

func (f *FedoraDistribution) getQuickshellMapping(variant deps.PackageVariant) PackageMapping {
	if forceQuickshellGit || variant == deps.VariantGit {
		return PackageMapping{Name: "quickshell-git", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"}
	}
	return PackageMapping{Name: "quickshell", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"}
}

func (f *FedoraDistribution) getDmsMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "dms", Repository: RepoTypeCOPR, RepoURL: "avengemedia/dms-git"}
	}
	return PackageMapping{Name: "dms", Repository: RepoTypeCOPR, RepoURL: "avengemedia/dms"}
}

func (f *FedoraDistribution) getHyprlandMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "hyprland-git", Repository: RepoTypeCOPR, RepoURL: "solopasha/hyprland"}
	}
	return PackageMapping{Name: "hyprland", Repository: RepoTypeCOPR, RepoURL: "solopasha/hyprland"}
}

func (f *FedoraDistribution) getHyprpickerMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "hyprpicker-git", Repository: RepoTypeCOPR, RepoURL: "solopasha/hyprland"}
	}
	return PackageMapping{Name: "hyprpicker", Repository: RepoTypeCOPR, RepoURL: "avengemedia/danklinux"}
}

func (f *FedoraDistribution) getNiriMapping(variant deps.PackageVariant) PackageMapping {
	if variant == deps.VariantGit {
		return PackageMapping{Name: "niri", Repository: RepoTypeCOPR, RepoURL: "yalter/niri-git"}
	}
	return PackageMapping{Name: "niri", Repository: RepoTypeCOPR, RepoURL: "yalter/niri"}
}

func (f *FedoraDistribution) detectXwaylandSatellite() deps.Dependency {
	status := deps.StatusMissing
	if f.commandExists("xwayland-satellite") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xwayland-satellite",
		Status:      status,
		Description: "Xwayland support",
		Required:    true,
	}
}

func (f *FedoraDistribution) detectAccountsService() deps.Dependency {
	status := deps.StatusMissing
	if f.packageInstalled("accountsservice") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "accountsservice",
		Status:      status,
		Description: "D-Bus interface for user account query and manipulation",
		Required:    true,
	}
}

func (f *FedoraDistribution) getPrerequisites() []string {
	return []string{
		"dnf-plugins-core",
		"make",
		"unzip",
		"libwayland-server",
	}
}

func (f *FedoraDistribution) InstallPrerequisites(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	prerequisites := f.getPrerequisites()
	var missingPkgs []string

	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.06,
		Step:       "Checking prerequisites...",
		IsComplete: false,
		LogOutput:  "Checking prerequisite packages",
	}

	for _, pkg := range prerequisites {
		checkCmd := exec.CommandContext(ctx, "rpm", "-q", pkg)
		if err := checkCmd.Run(); err != nil {
			missingPkgs = append(missingPkgs, pkg)
		}
	}

	_, err := exec.LookPath("go")
	if err != nil {
		f.log("go not found in PATH, will install golang-bin")
		missingPkgs = append(missingPkgs, "golang-bin")
	} else {
		f.log("go already available in PATH")
	}

	if len(missingPkgs) == 0 {
		f.log("All prerequisites already installed")
		return nil
	}

	f.log(fmt.Sprintf("Installing prerequisites: %s", strings.Join(missingPkgs, ", ")))
	progressChan <- InstallProgressMsg{
		Phase:       PhasePrerequisites,
		Progress:    0.08,
		Step:        fmt.Sprintf("Installing %d prerequisites...", len(missingPkgs)),
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: fmt.Sprintf("sudo dnf install -y %s", strings.Join(missingPkgs, " ")),
		LogOutput:   fmt.Sprintf("Installing prerequisites: %s", strings.Join(missingPkgs, ", ")),
	}

	args := []string{"dnf", "install", "-y"}
	args = append(args, missingPkgs...)
	cmd := ExecSudoCommand(ctx, sudoPassword, strings.Join(args, " "))
	output, err := cmd.CombinedOutput()
	if err != nil {
		f.logError("failed to install prerequisites", err)
		f.log(fmt.Sprintf("Prerequisites command output: %s", string(output)))
		return fmt.Errorf("failed to install prerequisites: %w", err)
	}
	f.log(fmt.Sprintf("Prerequisites install output: %s", string(output)))

	return nil
}

func (f *FedoraDistribution) InstallPackages(ctx context.Context, dependencies []deps.Dependency, wm deps.WindowManager, sudoPassword string, reinstallFlags map[string]bool, disabledFlags map[string]bool, skipGlobalUseFlags bool, progressChan chan<- InstallProgressMsg) error {
	// Phase 1: Check Prerequisites
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.05,
		Step:       "Checking system prerequisites...",
		IsComplete: false,
		LogOutput:  "Starting prerequisite check...",
	}

	if err := f.InstallPrerequisites(ctx, sudoPassword, progressChan); err != nil {
		return fmt.Errorf("failed to install prerequisites: %w", err)
	}

	dnfPkgs, coprPkgs, manualPkgs, variantMap := f.categorizePackages(dependencies, wm, reinstallFlags, disabledFlags)

	// Phase 2: Enable COPR repositories
	if len(coprPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.15,
			Step:       "Enabling COPR repositories...",
			IsComplete: false,
			LogOutput:  "Setting up COPR repositories for additional packages",
		}
		if err := f.enableCOPRRepos(ctx, coprPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to enable COPR repositories: %w", err)
		}
	}

	// Phase 3: System Packages (DNF)
	if len(dnfPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.35,
			Step:       fmt.Sprintf("Installing %d system packages...", len(dnfPkgs)),
			IsComplete: false,
			NeedsSudo:  true,
			LogOutput:  fmt.Sprintf("Installing system packages: %s", strings.Join(dnfPkgs, ", ")),
		}
		if err := f.installDNFPackages(ctx, dnfPkgs, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install DNF packages: %w", err)
		}
	}

	// Phase 4: COPR Packages
	coprPkgNames := f.extractPackageNames(coprPkgs)
	if len(coprPkgNames) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseAURPackages, // Reusing AUR phase for COPR
			Progress:   0.65,
			Step:       fmt.Sprintf("Installing %d COPR packages...", len(coprPkgNames)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Installing COPR packages: %s", strings.Join(coprPkgNames, ", ")),
		}
		if err := f.installCOPRPackages(ctx, coprPkgNames, sudoPassword, progressChan); err != nil {
			return fmt.Errorf("failed to install COPR packages: %w", err)
		}
	}

	// Phase 5: Manual Builds
	if len(manualPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.85,
			Step:       fmt.Sprintf("Building %d packages from source...", len(manualPkgs)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Building from source: %s", strings.Join(manualPkgs, ", ")),
		}
		if err := f.InstallManualPackages(ctx, manualPkgs, variantMap, sudoPassword, progressChan); err != nil {
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

func (f *FedoraDistribution) categorizePackages(dependencies []deps.Dependency, wm deps.WindowManager, reinstallFlags map[string]bool, disabledFlags map[string]bool) ([]string, []PackageMapping, []string, map[string]deps.PackageVariant) {
	dnfPkgs := []string{}
	coprPkgs := []PackageMapping{}
	manualPkgs := []string{}

	variantMap := make(map[string]deps.PackageVariant)
	for _, dep := range dependencies {
		variantMap[dep.Name] = dep.Variant
	}

	packageMap := f.GetPackageMappingWithVariants(wm, variantMap)

	for _, dep := range dependencies {
		if disabledFlags[dep.Name] {
			continue
		}

		if dep.Status == deps.StatusInstalled && !reinstallFlags[dep.Name] {
			continue
		}

		pkgInfo, exists := packageMap[dep.Name]
		if !exists {
			f.log(fmt.Sprintf("Warning: No package mapping for %s", dep.Name))
			continue
		}

		switch pkgInfo.Repository {
		case RepoTypeSystem:
			dnfPkgs = append(dnfPkgs, pkgInfo.Name)
		case RepoTypeCOPR:
			coprPkgs = append(coprPkgs, pkgInfo)
		case RepoTypeManual:
			manualPkgs = append(manualPkgs, dep.Name)
		}
	}

	return dnfPkgs, coprPkgs, manualPkgs, variantMap
}

func (f *FedoraDistribution) extractPackageNames(packages []PackageMapping) []string {
	names := make([]string, len(packages))
	for i, pkg := range packages {
		names[i] = pkg.Name
	}
	return names
}

func (f *FedoraDistribution) enableCOPRRepos(ctx context.Context, coprPkgs []PackageMapping, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	enabledRepos := make(map[string]bool)

	for _, pkg := range coprPkgs {
		if pkg.RepoURL != "" && !enabledRepos[pkg.RepoURL] {
			f.log(fmt.Sprintf("Enabling COPR repository: %s", pkg.RepoURL))
			progressChan <- InstallProgressMsg{
				Phase:       PhaseSystemPackages,
				Progress:    0.20,
				Step:        fmt.Sprintf("Enabling COPR repo %s...", pkg.RepoURL),
				IsComplete:  false,
				NeedsSudo:   true,
				CommandInfo: fmt.Sprintf("sudo dnf copr enable -y %s", pkg.RepoURL),
			}

			cmd := ExecSudoCommand(ctx, sudoPassword,
				fmt.Sprintf("dnf copr enable -y %s 2>&1", pkg.RepoURL))
			output, err := cmd.CombinedOutput()
			if err != nil {
				f.logError(fmt.Sprintf("failed to enable COPR repo %s", pkg.RepoURL), err)
				f.log(fmt.Sprintf("COPR enable command output: %s", string(output)))
				return fmt.Errorf("failed to enable COPR repo %s: %w", pkg.RepoURL, err)
			}
			f.log(fmt.Sprintf("COPR repo %s enabled successfully: %s", pkg.RepoURL, string(output)))
			enabledRepos[pkg.RepoURL] = true

			// Special handling for niri COPR repo - set priority=1
			if pkg.RepoURL == "yalter/niri-git" {
				f.log("Setting priority=1 for niri-git COPR repo...")
				repoFile := "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo"
				progressChan <- InstallProgressMsg{
					Phase:       PhaseSystemPackages,
					Progress:    0.22,
					Step:        "Setting niri COPR repo priority...",
					IsComplete:  false,
					NeedsSudo:   true,
					CommandInfo: fmt.Sprintf("echo \"priority=1\" | sudo tee -a %s", repoFile),
				}

				priorityCmd := ExecSudoCommand(ctx, sudoPassword,
					fmt.Sprintf("bash -c 'echo \"priority=1\" | tee -a %s'", repoFile))
				priorityOutput, err := priorityCmd.CombinedOutput()
				if err != nil {
					f.logError("failed to set niri COPR repo priority", err)
					f.log(fmt.Sprintf("Priority command output: %s", string(priorityOutput)))
					return fmt.Errorf("failed to set niri COPR repo priority: %w", err)
				}
				f.log(fmt.Sprintf("niri COPR repo priority set successfully: %s", string(priorityOutput)))
			}
		}
	}

	return nil
}

func (f *FedoraDistribution) installDNFPackages(ctx context.Context, packages []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	f.log(fmt.Sprintf("Installing DNF packages: %s", strings.Join(packages, ", ")))

	args := []string{"dnf", "install", "-y"}
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
	return f.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.40, 0.60)
}

func (f *FedoraDistribution) installCOPRPackages(ctx context.Context, packages []string, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	f.log(fmt.Sprintf("Installing COPR packages: %s", strings.Join(packages, ", ")))

	args := []string{"dnf", "install", "-y"}

	for _, pkg := range packages {
		if pkg == "niri" || pkg == "niri-git" {
			args = append(args, "--setopt=install_weak_deps=False")
			break
		}
	}

	args = append(args, packages...)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseAURPackages,
		Progress:    0.70,
		Step:        "Installing COPR packages...",
		IsComplete:  false,
		NeedsSudo:   true,
		CommandInfo: fmt.Sprintf("sudo %s", strings.Join(args, " ")),
	}

	cmd := ExecSudoCommand(ctx, sudoPassword, strings.Join(args, " "))
	return f.runWithProgress(cmd, progressChan, PhaseAURPackages, 0.70, 0.85)
}
