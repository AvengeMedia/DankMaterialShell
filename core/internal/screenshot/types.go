package screenshot

import "fmt"

type Mode int

const (
	ModeRegion Mode = iota
	ModeWindow
	ModeFullScreen
	ModeAllScreens
	ModeOutput
	ModeLastRegion
	ModeScroll
)

type Format int

const (
	FormatPNG Format = iota
	FormatJPEG
	FormatPPM
)

type CursorMode int

const (
	CursorOff CursorMode = iota
	CursorOn
)

type Region struct {
	X      int32  `json:"x"`
	Y      int32  `json:"y"`
	Width  int32  `json:"width"`
	Height int32  `json:"height"`
	Output string `json:"output,omitempty"`
}

func (r Region) IsEmpty() bool {
	return r.Width <= 0 || r.Height <= 0
}

func (r Region) GeometryString() string {
	return fmt.Sprintf("%d,%d %dx%d", r.X, r.Y, r.Width, r.Height)
}

type Output struct {
	Name            string
	X, Y            int32
	Width           int32
	Height          int32
	Scale           int32
	FractionalScale float64
	Transform       int32
}

type Config struct {
	Mode          Mode
	OutputName    string
	Cursor        CursorMode
	NoConfirm     bool
	Reset         bool
	Format        Format
	Quality       int
	OutputDir     string
	Filename      string
	Clipboard     bool
	SaveFile      bool
	Notify        bool
	Stdout        bool
	Geometry      bool
	AllowMultiple bool
	IntervalMs    int
	// SelectorHook runs as the interactive selector starts (true) and ends (false).
	SelectorHook func(begin bool)
}

func DefaultConfig() Config {
	return Config{
		Mode:      ModeRegion,
		Cursor:    CursorOff,
		NoConfirm: false,
		Reset:     false,
		Format:    FormatPNG,
		Quality:   90,
		OutputDir: "",
		Filename:  "",
		Clipboard: true,
		SaveFile:  true,
		Notify:    true,
	}
}
