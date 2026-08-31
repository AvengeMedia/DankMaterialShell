package tui

import (
	"github.com/charmbracelet/lipgloss"
)

type AppTheme struct {
	Primary    string
	Secondary  string
	Accent     string
	Text       string
	Subtle     string
	Error      string
	Warning    string
	Success    string
	Background string
	Surface    string
}

func TerminalTheme() AppTheme {
	return AppTheme{
		Primary:    "6",
		Secondary:  "5",
		Accent:     "12",
		Text:       "7",
		Subtle:     "8",
		Error:      "1",
		Warning:    "3",
		Success:    "2",
		Background: "15",
		Surface:    "8",
	}
}

type Styles struct {
	Title           lipgloss.Style
	Normal          lipgloss.Style
	Bold            lipgloss.Style
	Subtle          lipgloss.Style
	SubtleItalic    lipgloss.Style
	Warning         lipgloss.Style
	Error           lipgloss.Style
	StatusBar       lipgloss.Style
	Key             lipgloss.Style
	SpinnerStyle    lipgloss.Style
	Success         lipgloss.Style
	HighlightButton lipgloss.Style
	SelectedOption  lipgloss.Style
	CodeBlock       lipgloss.Style
	Accent          lipgloss.Style
	AccentItalic    lipgloss.Style
	Highlight       lipgloss.Style
	Banner          lipgloss.Style
	TitleBox        lipgloss.Style
	InfoBox         lipgloss.Style
	ErrorBox        lipgloss.Style
}

func NewStyles(theme AppTheme) Styles {
	return Styles{
		Title: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Primary)).
			Bold(true).
			MarginLeft(1).
			MarginBottom(1),

		Normal: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Text)),

		Bold: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Text)).
			Bold(true),

		Subtle: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Subtle)),

		SubtleItalic: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Subtle)).
			Italic(true),

		Error: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Error)),

		Warning: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Warning)),

		StatusBar: lipgloss.NewStyle().
			Foreground(lipgloss.Color("#33275e")).
			Background(lipgloss.Color(theme.Primary)).
			Padding(0, 1),

		Key: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Accent)).
			Bold(true),

		SpinnerStyle: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Primary)),

		Success: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Success)).
			Bold(true),

		HighlightButton: lipgloss.NewStyle().
			Foreground(lipgloss.Color("#33275e")).
			Background(lipgloss.Color(theme.Primary)).
			Padding(0, 2).
			Bold(true),

		SelectedOption: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Accent)).
			Bold(true),

		CodeBlock: lipgloss.NewStyle().
			Background(lipgloss.Color(theme.Surface)).
			Foreground(lipgloss.Color(theme.Text)).
			Padding(1, 2).
			MarginLeft(2),

		Accent: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Accent)),

		AccentItalic: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Accent)).
			Italic(true),

		Highlight: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Primary)).
			Bold(true),

		Banner: lipgloss.NewStyle().
			Foreground(lipgloss.Color(theme.Primary)).
			Bold(true).
			MarginBottom(1),

		TitleBox: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(theme.Primary)).
			Padding(0, 2).
			MarginBottom(1),

		InfoBox: lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color(theme.Subtle)).
			Padding(0, 1).
			MarginBottom(1),

		ErrorBox: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color(theme.Error)).
			Padding(1, 2).
			MarginBottom(1),
	}
}
