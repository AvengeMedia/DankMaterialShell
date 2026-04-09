package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/headless"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
)

var Version = "dev"

// Flag variables bound via pflag
var (
	compositor        string
	term              string
	includeDeps       []string
	excludeDeps       []string
	replaceConfigs    []string
	replaceConfigsAll bool
	yes               bool
)

var rootCmd = &cobra.Command{
	Use:   "dankinstall",
	Short: "Install DankMaterialShell and its dependencies",
	Long: `dankinstall sets up DankMaterialShell with your chosen compositor and terminal.

Without flags, it launches an interactive TUI. When --compositor and --term
are provided, it runs in headless (unattended) mode suitable for scripting.

Headless mode requires cached sudo credentials. Run 'sudo -v' beforehand, or
configure passwordless sudo for your user.`,
	Args:          cobra.NoArgs,
	RunE:          runDankinstall,
	SilenceErrors: true,
	SilenceUsage:  true,
}

func init() {
	rootCmd.Flags().StringVarP(&compositor, "compositor", "c", "", "Compositor/WM to install: niri or hyprland (enables headless mode)")
	rootCmd.Flags().StringVarP(&term, "term", "t", "", "Terminal emulator to install: ghostty, kitty, or alacritty (enables headless mode)")
	rootCmd.Flags().StringSliceVar(&includeDeps, "include-deps", []string{}, "Optional deps to enable (e.g. dms-greeter)")
	rootCmd.Flags().StringSliceVar(&excludeDeps, "exclude-deps", []string{}, "Deps to skip during installation")
	rootCmd.Flags().StringSliceVar(&replaceConfigs, "replace-configs", []string{}, "Deploy only named configs (e.g. niri,ghostty)")
	rootCmd.Flags().BoolVar(&replaceConfigsAll, "replace-configs-all", false, "Deploy and replace all configurations")
	rootCmd.Flags().BoolVarP(&yes, "yes", "y", false, "Auto-confirm all prompts")
}

func main() {
	if os.Getuid() == 0 {
		fmt.Fprintln(os.Stderr, "Error: dankinstall must not be run as root")
		os.Exit(1)
	}

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runDankinstall(cmd *cobra.Command, args []string) error {
	headlessMode := compositor != "" || term != ""

	if !headlessMode {
		// Reject headless-only flags when running in TUI mode.
		headlessOnly := []string{
			"include-deps",
			"exclude-deps",
			"replace-configs",
			"replace-configs-all",
			"yes",
		}
		var set []string
		for _, name := range headlessOnly {
			if cmd.Flags().Changed(name) {
				set = append(set, "--"+name)
			}
		}
		if len(set) > 0 {
			return fmt.Errorf("flags %s are only valid in headless mode (requires both --compositor and --term)", strings.Join(set, ", "))
		}
	}

	if headlessMode {
		return runHeadless()
	}
	return runTUI()
}

func runHeadless() error {
	// Validate required flags
	if compositor == "" {
		return fmt.Errorf("--compositor is required for headless mode (niri or hyprland)")
	}
	if term == "" {
		return fmt.Errorf("--term is required for headless mode (ghostty, kitty, or alacritty)")
	}

	cfg := headless.Config{
		Compositor:        compositor,
		Terminal:          term,
		IncludeDeps:       includeDeps,
		ExcludeDeps:       excludeDeps,
		ReplaceConfigs:    replaceConfigs,
		ReplaceConfigsAll: replaceConfigsAll,
		Yes:               yes,
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
		if fileLogger != nil {
			fmt.Fprintf(os.Stderr, "\nFull logs are available at: %s\n", fileLogger.GetLogPath())
		}
		return err
	}

	if fileLogger != nil {
		fmt.Printf("\nFull logs are available at: %s\n", fileLogger.GetLogPath())
	}
	return nil
}

func runTUI() error {
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
		if logFilePath != "" {
			fmt.Fprintf(os.Stderr, "\nFull logs are available at: %s\n", logFilePath)
		}
		return fmt.Errorf("error running program: %w", err)
	}

	if logFilePath != "" {
		fmt.Printf("\nFull logs are available at: %s\n", logFilePath)
	}
	return nil
}
