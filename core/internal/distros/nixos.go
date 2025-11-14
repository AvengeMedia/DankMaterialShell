package distros

import (
	"context"
	"fmt"
	"os/exec"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/deps"
)

func init() {
	Register("nixos", "#7EBAE4", FamilyNix, func(config DistroConfig, logChan chan<- string) Distribution {
		return NewNixOSDistribution(config, logChan)
	})
}

type NixOSDistribution struct {
	*BaseDistribution
	config DistroConfig
}

func NewNixOSDistribution(config DistroConfig, logChan chan<- string) *NixOSDistribution {
	base := NewBaseDistribution(logChan)
	return &NixOSDistribution{
		BaseDistribution: base,
		config:           config,
	}
}

func (n *NixOSDistribution) GetID() string {
	return n.config.ID
}

func (n *NixOSDistribution) GetColorHex() string {
	return n.config.ColorHex
}

func (n *NixOSDistribution) GetFamily() DistroFamily {
	return n.config.Family
}

func (n *NixOSDistribution) GetPackageManager() PackageManagerType {
	return PackageManagerNix
}

func (n *NixOSDistribution) DetectDependencies(ctx context.Context, wm deps.WindowManager) ([]deps.Dependency, error) {
	return n.DetectDependenciesWithTerminal(ctx, wm, deps.TerminalGhostty)
}

func (n *NixOSDistribution) DetectDependenciesWithTerminal(ctx context.Context, wm deps.WindowManager, terminal deps.Terminal) ([]deps.Dependency, error) {
	var dependencies []deps.Dependency

	// DMS at the top (shell is prominent)
	dependencies = append(dependencies, n.detectDMS())

	// Terminal with choice support
	dependencies = append(dependencies, n.detectSpecificTerminal(terminal))

	// Common detections using base methods
	dependencies = append(dependencies, n.detectGit())
	dependencies = append(dependencies, n.detectWindowManager(wm))
	dependencies = append(dependencies, n.detectQuickshell())
	dependencies = append(dependencies, n.detectXDGPortal())
	dependencies = append(dependencies, n.detectPolkitAgent())
	dependencies = append(dependencies, n.detectAccountsService())

	// Hyprland-specific tools
	if wm == deps.WindowManagerHyprland {
		dependencies = append(dependencies, n.detectHyprlandTools()...)
	}

	// Niri-specific tools
	if wm == deps.WindowManagerNiri {
		dependencies = append(dependencies, n.detectXwaylandSatellite())
	}

	// Base detections (common across distros)
	dependencies = append(dependencies, n.detectMatugen())
	dependencies = append(dependencies, n.detectDgop())
	dependencies = append(dependencies, n.detectHyprpicker())
	dependencies = append(dependencies, n.detectClipboardTools()...)

	return dependencies, nil
}

func (n *NixOSDistribution) detectDMS() deps.Dependency {
	status := deps.StatusMissing

	// For NixOS, check if quickshell can find the dms config
	cmd := exec.Command("qs", "-c", "dms", "--list")
	if err := cmd.Run(); err == nil {
		status = deps.StatusInstalled
	} else if n.packageInstalled("DankMaterialShell") {
		// Fallback: check if flake is in profile
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "dms (DankMaterialShell)",
		Status:      status,
		Description: "Desktop Management System configuration (installed as flake)",
		Required:    true,
	}
}

func (n *NixOSDistribution) detectXDGPortal() deps.Dependency {
	status := deps.StatusMissing
	if n.packageInstalled("xdg-desktop-portal-gtk") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xdg-desktop-portal-gtk",
		Status:      status,
		Description: "Desktop integration portal for GTK",
		Required:    true,
	}
}

func (n *NixOSDistribution) detectWindowManager(wm deps.WindowManager) deps.Dependency {
	switch wm {
	case deps.WindowManagerHyprland:
		status := deps.StatusMissing
		description := "Dynamic tiling Wayland compositor"
		if n.commandExists("hyprland") || n.commandExists("Hyprland") {
			status = deps.StatusInstalled
		} else {
			description = "Install system-wide: programs.hyprland.enable = true; in configuration.nix"
		}
		return deps.Dependency{
			Name:        "hyprland",
			Status:      status,
			Description: description,
			Required:    true,
		}
	case deps.WindowManagerNiri:
		status := deps.StatusMissing
		description := "Scrollable-tiling Wayland compositor"
		if n.commandExists("niri") {
			status = deps.StatusInstalled
		} else {
			description = "Install system-wide: environment.systemPackages = [ pkgs.niri ]; in configuration.nix"
		}
		return deps.Dependency{
			Name:        "niri",
			Status:      status,
			Description: description,
			Required:    true,
		}
	default:
		return deps.Dependency{
			Name:        "unknown-wm",
			Status:      deps.StatusMissing,
			Description: "Unknown window manager",
			Required:    true,
		}
	}
}

func (n *NixOSDistribution) detectHyprlandTools() []deps.Dependency {
	var dependencies []deps.Dependency

	tools := []struct {
		name        string
		description string
	}{
		{"grim", "Screenshot utility for Wayland"},
		{"slurp", "Region selection utility for Wayland"},
		{"hyprctl", "Hyprland control utility (comes with system Hyprland)"},
		{"hyprpicker", "Color picker for Hyprland"},
		{"grimblast", "Screenshot script for Hyprland"},
		{"jq", "JSON processor"},
	}

	for _, tool := range tools {
		status := deps.StatusMissing

		// Special handling for hyprctl - it comes with system hyprland
		if tool.name == "hyprctl" {
			if n.commandExists("hyprctl") {
				status = deps.StatusInstalled
			}
		} else {
			if n.commandExists(tool.name) {
				status = deps.StatusInstalled
			}
		}

		dependencies = append(dependencies, deps.Dependency{
			Name:        tool.name,
			Status:      status,
			Description: tool.description,
			Required:    true,
		})
	}

	return dependencies
}

func (n *NixOSDistribution) detectXwaylandSatellite() deps.Dependency {
	status := deps.StatusMissing
	if n.commandExists("xwayland-satellite") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "xwayland-satellite",
		Status:      status,
		Description: "Xwayland support",
		Required:    true,
	}
}

func (n *NixOSDistribution) detectPolkitAgent() deps.Dependency {
	status := deps.StatusMissing
	if n.packageInstalled("mate-polkit") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "mate-polkit",
		Status:      status,
		Description: "PolicyKit authentication agent",
		Required:    true,
	}
}

func (n *NixOSDistribution) detectAccountsService() deps.Dependency {
	status := deps.StatusMissing
	if n.packageInstalled("accountsservice") {
		status = deps.StatusInstalled
	}

	return deps.Dependency{
		Name:        "accountsservice",
		Status:      status,
		Description: "D-Bus interface for user account query and manipulation",
		Required:    true,
	}
}

func (n *NixOSDistribution) packageInstalled(pkg string) bool {
	cmd := exec.Command("nix", "profile", "list")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(output), pkg)
}

func (n *NixOSDistribution) GetPackageMapping(wm deps.WindowManager) map[string]PackageMapping {
	packages := map[string]PackageMapping{
		"git":                     {Name: "nixpkgs#git", Repository: RepoTypeSystem},
		"quickshell":              {Name: "github:quickshell-mirror/quickshell", Repository: RepoTypeFlake},
		"matugen":                 {Name: "github:InioX/matugen", Repository: RepoTypeFlake},
		"dgop":                    {Name: "github:AvengeMedia/dgop", Repository: RepoTypeFlake},
		"dms (DankMaterialShell)": {Name: "github:AvengeMedia/DankMaterialShell", Repository: RepoTypeFlake},
		"ghostty":                 {Name: "nixpkgs#ghostty", Repository: RepoTypeSystem},
		"alacritty":               {Name: "nixpkgs#alacritty", Repository: RepoTypeSystem},
		"cliphist":                {Name: "nixpkgs#cliphist", Repository: RepoTypeSystem},
		"wl-clipboard":            {Name: "nixpkgs#wl-clipboard", Repository: RepoTypeSystem},
		"xdg-desktop-portal-gtk":  {Name: "nixpkgs#xdg-desktop-portal-gtk", Repository: RepoTypeSystem},
		"mate-polkit":             {Name: "nixpkgs#mate.mate-polkit", Repository: RepoTypeSystem},
		"accountsservice":         {Name: "nixpkgs#accountsservice", Repository: RepoTypeSystem},
		"hyprpicker":              {Name: "nixpkgs#hyprpicker", Repository: RepoTypeSystem},
	}

	// Note: Window managers (hyprland/niri) should be installed system-wide on NixOS
	// We only install the tools here
	switch wm {
	case deps.WindowManagerHyprland:
		// Skip hyprland itself - should be installed system-wide
		packages["grim"] = PackageMapping{Name: "nixpkgs#grim", Repository: RepoTypeSystem}
		packages["slurp"] = PackageMapping{Name: "nixpkgs#slurp", Repository: RepoTypeSystem}
		packages["grimblast"] = PackageMapping{Name: "github:hyprwm/contrib#grimblast", Repository: RepoTypeFlake}
		packages["jq"] = PackageMapping{Name: "nixpkgs#jq", Repository: RepoTypeSystem}
	case deps.WindowManagerNiri:
		// Skip niri itself - should be installed system-wide
		packages["xwayland-satellite"] = PackageMapping{Name: "nixpkgs#xwayland-satellite", Repository: RepoTypeFlake}
	}

	return packages
}

func (n *NixOSDistribution) InstallPrerequisites(ctx context.Context, sudoPassword string, progressChan chan<- InstallProgressMsg) error {
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.10,
		Step:       "NixOS prerequisites ready",
		IsComplete: false,
		LogOutput:  "NixOS package manager is ready to use",
	}
	return nil
}

func (n *NixOSDistribution) InstallPackages(ctx context.Context, dependencies []deps.Dependency, wm deps.WindowManager, sudoPassword string, reinstallFlags map[string]bool, disabledFlags map[string]bool, skipGlobalUseFlags bool, progressChan chan<- InstallProgressMsg) error {
	// Phase 1: Check Prerequisites
	progressChan <- InstallProgressMsg{
		Phase:      PhasePrerequisites,
		Progress:   0.05,
		Step:       "Checking system prerequisites...",
		IsComplete: false,
		LogOutput:  "Starting prerequisite check...",
	}

	if err := n.InstallPrerequisites(ctx, sudoPassword, progressChan); err != nil {
		return fmt.Errorf("failed to install prerequisites: %w", err)
	}

	nixpkgsPkgs, flakePkgs, _ := n.categorizePackages(dependencies, wm, reinstallFlags, disabledFlags)

	// Phase 2: Nixpkgs Packages
	if len(nixpkgsPkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseSystemPackages,
			Progress:   0.35,
			Step:       fmt.Sprintf("Installing %d packages from nixpkgs...", len(nixpkgsPkgs)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Installing nixpkgs packages: %s", strings.Join(nixpkgsPkgs, ", ")),
		}
		if err := n.installNixpkgsPackages(ctx, nixpkgsPkgs, progressChan); err != nil {
			return fmt.Errorf("failed to install nixpkgs packages: %w", err)
		}
	}

	// Phase 3: Flake Packages
	if len(flakePkgs) > 0 {
		progressChan <- InstallProgressMsg{
			Phase:      PhaseAURPackages,
			Progress:   0.65,
			Step:       fmt.Sprintf("Installing %d packages from flakes...", len(flakePkgs)),
			IsComplete: false,
			LogOutput:  fmt.Sprintf("Installing flake packages: %s", strings.Join(flakePkgs, ", ")),
		}
		if err := n.installFlakePackages(ctx, flakePkgs, progressChan); err != nil {
			return fmt.Errorf("failed to install flake packages: %w", err)
		}
	}

	// Phase 4: Configuration
	progressChan <- InstallProgressMsg{
		Phase:      PhaseConfiguration,
		Progress:   0.90,
		Step:       "Configuring system...",
		IsComplete: false,
		LogOutput:  "Starting post-installation configuration...",
	}
	if err := n.postInstallConfig(progressChan); err != nil {
		return fmt.Errorf("failed to configure system: %w", err)
	}

	// Phase 5: Complete
	progressChan <- InstallProgressMsg{
		Phase:      PhaseComplete,
		Progress:   1.0,
		Step:       "Installation complete!",
		IsComplete: true,
		LogOutput:  "All packages installed and configured successfully",
	}

	return nil
}

func (n *NixOSDistribution) categorizePackages(dependencies []deps.Dependency, wm deps.WindowManager, reinstallFlags map[string]bool, disabledFlags map[string]bool) ([]string, []string, map[string]deps.PackageVariant) {
	nixpkgsPkgs := []string{}
	flakePkgs := []string{}

	variantMap := make(map[string]deps.PackageVariant)
	for _, dep := range dependencies {
		variantMap[dep.Name] = dep.Variant
	}

	packageMap := n.GetPackageMapping(wm)

	for _, dep := range dependencies {
		if disabledFlags[dep.Name] {
			continue
		}

		if dep.Status == deps.StatusInstalled && !reinstallFlags[dep.Name] {
			continue
		}

		pkgInfo, exists := packageMap[dep.Name]
		if !exists {
			n.log(fmt.Sprintf("Warning: No package mapping found for %s", dep.Name))
			continue
		}

		switch pkgInfo.Repository {
		case RepoTypeSystem:
			nixpkgsPkgs = append(nixpkgsPkgs, pkgInfo.Name)
		case RepoTypeFlake:
			flakePkgs = append(flakePkgs, pkgInfo.Name)
		}
	}

	return nixpkgsPkgs, flakePkgs, variantMap
}

func (n *NixOSDistribution) installNixpkgsPackages(ctx context.Context, packages []string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	n.log(fmt.Sprintf("Installing nixpkgs packages: %s", strings.Join(packages, ", ")))

	args := []string{"profile", "install"}
	args = append(args, packages...)

	progressChan <- InstallProgressMsg{
		Phase:       PhaseSystemPackages,
		Progress:    0.40,
		Step:        "Installing nixpkgs packages...",
		IsComplete:  false,
		CommandInfo: fmt.Sprintf("nix %s", strings.Join(args, " ")),
	}

	cmd := exec.CommandContext(ctx, "nix", args...)
	return n.runWithProgress(cmd, progressChan, PhaseSystemPackages, 0.40, 0.60)
}

func (n *NixOSDistribution) installFlakePackages(ctx context.Context, packages []string, progressChan chan<- InstallProgressMsg) error {
	if len(packages) == 0 {
		return nil
	}

	n.log(fmt.Sprintf("Installing flake packages: %s", strings.Join(packages, ", ")))

	baseProgress := 0.65
	progressStep := 0.20 / float64(len(packages))

	for i, pkg := range packages {
		currentProgress := baseProgress + (float64(i) * progressStep)

		progressChan <- InstallProgressMsg{
			Phase:       PhaseAURPackages,
			Progress:    currentProgress,
			Step:        fmt.Sprintf("Installing flake package %s (%d/%d)...", pkg, i+1, len(packages)),
			IsComplete:  false,
			CommandInfo: fmt.Sprintf("nix profile install %s", pkg),
		}

		cmd := exec.CommandContext(ctx, "nix", "profile", "install", pkg)
		if err := n.runWithProgress(cmd, progressChan, PhaseAURPackages, currentProgress, currentProgress+progressStep); err != nil {
			return fmt.Errorf("failed to install flake package %s: %w", pkg, err)
		}
	}

	return nil
}

func (n *NixOSDistribution) postInstallConfig(progressChan chan<- InstallProgressMsg) error {
	// For NixOS, DMS is installed as a flake package, so we skip both the binary installation and git clone
	// The flake installation handles both the binary and config files correctly
	progressChan <- InstallProgressMsg{
		Phase:      PhaseConfiguration,
		Progress:   0.95,
		Step:       "NixOS configuration complete",
		IsComplete: false,
		LogOutput:  "DMS installed via flake - binary and config handled by Nix",
	}

	return nil
}
