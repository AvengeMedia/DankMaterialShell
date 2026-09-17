package startup

import (
	"context"
	"errors"
)

type Source string

const (
	SourceXDG     Source = "xdg"
	SourceSystemd Source = "systemd"
)

type Category string

const (
	CategoryApplication Category = "application"
	CategoryProtected   Category = "protected"
)

var (
	ErrInvalidEntry = errors.New("name and command must be non-empty single-line values")
	ErrNotFound     = errors.New("startup entry not found")
	ErrProtected    = errors.New("service is protected and cannot be managed by Startup Apps")
)

type Entry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description,omitempty"`
	Icon        string   `json:"icon,omitempty"`
	Source      Source   `json:"source"`
	Enabled     bool     `json:"enabled"`
	Category    Category `json:"category"`
	Mutable     bool     `json:"mutable"`
	Removable   bool     `json:"removable,omitempty"`
}

type Application struct {
	ID   string
	Name string
	Exec string
	Icon string
}

type SystemdUnit struct {
	Name                string
	Description         string
	LoadState           string
	UnitFileState       string
	FragmentPath        string
	SourcePath          string
	ExecStart           string
	Before              []string
	Requires            []string
	Requisite           []string
	BindsTo             []string
	PartOf              []string
	RequiredBy          []string
	InstallTargets      []string
	Transient           bool
	DefaultDependencies bool
}

type SystemdBackend interface {
	List(context.Context) ([]SystemdUnit, error)
	SetEnabled(context.Context, string, bool) error
}
