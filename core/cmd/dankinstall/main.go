package main

import (
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/headless"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
)

var Version = "dev"

// Flag variables bound via pflag
var (
	compositor  string
	term        string
	includeDeps []string
	excludeDeps []string
	yes         bool
)

var rootCmd = &cobra.Command{
	Use:   "dankinstall",
	Short: "Install DankMaterialShell and its dependencies",
	Long: `dankinstall sets up DankMaterialShell with your chosen compositor and terminal.

Without flags, it launches an interactive TUI. When --compositor and --term
are provided, it runs in headless (unattended) mode suitable for scripting.

Headless mode requires cached sudo credentials. Run 'sudo -v' beforehand, or
configure passwordless sudo for your user.`,
	Run: runDankinstall,
}

func init() {
	rootCmd.Flags().StringVarP(&compositor, "compositor", "c", "", "Compositor/WM to install: niri or hyprland (enables headless mode)")
	rootCmd.Flags().StringVarP(&term, "term", "t", "", "Terminal emulator to install: ghostty, kitty, or alacritty (enables headless mode)")
	rootCmd.Flags().StringSliceVar(&includeDeps, "include-deps", []string{}, "Optional deps to enable (e.g. dms-greeter)")
	rootCmd.Flags().StringSliceVar(&excludeDeps, "exclude-deps", []string{}, "Deps to skip during installation")
	rootCmd.Flags().BoolVarP(&yes, "yes", "y", false, "Auto-confirm all prompts")
}

func main() {
	if os.Getuid() == 0 {
		fmt.Fprintln(os.Stderr, "Error: dankinstall must not be run as root")
		os.Exit(1)
	}

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func runDankinstall(cmd *cobra.Command, args []string) {
	headlessMode := compositor != "" || term != ""

	if headlessMode {
		runHeadless()
	} else {
		runTUI()
	}
}

func runHeadless() {
	// Validate required flags
	if compositor == "" {
		fmt.Fprintln(os.Stderr, "Error: --compositor is required for headless mode (niri or hyprland)")
		os.Exit(1)
	}
	if term == "" {
		fmt.Fprintln(os.Stderr, "Error: --term is required for headless mode (ghostty, kitty, or alacritty)")
		os.Exit(1)
	}

	cfg := headless.Config{
		Compositor:  compositor,
		Terminal:    term,
		IncludeDeps: includeDeps,
		ExcludeDeps: excludeDeps,
		Yes:         yes,
	}

	runner := headless.NewRunner(cfg)

	// Set up file logging
	fileLogger, err := log.NewFileLogger()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Warning: Failed to create log file: %v\n", err)
	}

	if fileLogger != nil {
		fmt.Printf("Logging to: %s\n", fileLogger.GetLogPath())
		fileLogger.StartListening(runner.GetLogChan())
		defer func() {
			if err := fileLogger.Close(); err != nil {
				fmt.Fprintf(os.Stderr, "Warning: Failed to close log file: %v\n", err)
			}
		}()
	}

	if err := runner.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		if fileLogger != nil {
			fmt.Fprintf(os.Stderr, "\nFull logs are available at: %s\n", fileLogger.GetLogPath())
		}
		os.Exit(1)
	}

	if fileLogger != nil {
		fmt.Printf("\nFull logs are available at: %s\n", fileLogger.GetLogPath())
	}
}

func runTUI() {
	fileLogger, err := log.NewFileLogger()
	if err != nil {
		fmt.Printf("Warning: Failed to create log file: %v\n", err)
		fmt.Println("Continuing without file logging...")
	}

	logFilePath := ""
	if fileLogger != nil {
		logFilePath = fileLogger.GetLogPath()
		fmt.Printf("Logging to: %s\n", logFilePath)
		defer func() {
			if err := fileLogger.Close(); err != nil {
				fmt.Printf("Warning: Failed to close log file: %v\n", err)
			}
		}()
	}

	model := tui.NewModel(Version, logFilePath)

	if fileLogger != nil {
		fileLogger.StartListening(model.GetLogChan())
	}

	p := tea.NewProgram(model, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error running program: %v\n", err)
		if logFilePath != "" {
			fmt.Printf("\nFull logs are available at: %s\n", logFilePath)
		}
		os.Exit(1)
	}

	if logFilePath != "" {
		fmt.Printf("\nFull logs are available at: %s\n", logFilePath)
	}
}
