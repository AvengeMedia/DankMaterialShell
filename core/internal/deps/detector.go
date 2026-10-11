package deps

import (
	"context"
)

type DependencyStatus int

const (
	StatusMissing DependencyStatus = iota
	StatusInstalled
	StatusNeedsUpdate
	StatusNeedsReinstall
)

type PackageVariant int

const (
	VariantStable PackageVariant = iota
	VariantGit
)

type Dependency struct {
	Name        string
	Status      DependencyStatus
	Version     string
	Description string
	Required    bool
	Variant     PackageVariant
	CanToggle   bool
}

type WindowManager int

const (
	WindowManagerHyprland WindowManager = iota
	WindowManagerNiri
	WindowManagerMango
)

type Terminal int

const (
	TerminalGhostty Terminal = iota
	TerminalKitty
	TerminalAlacritty
)

func (t Terminal) Command() string {
	switch t {
	case TerminalKitty:
		return "kitty"
	case TerminalAlacritty:
		return "alacritty"
	default:
		return "ghostty"
	}
}

type DependencyDetector interface {
	DetectDependencies(ctx context.Context, wm WindowManager) ([]Dependency, error)
	DetectDependenciesWithTerminal(ctx context.Context, wm WindowManager, terminal Terminal) ([]Dependency, error)
}
