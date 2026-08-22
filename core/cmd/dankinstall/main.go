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
	privescTool       string
	gitAll            bool
	gitDeps           []string
	allFeatures       bool
	noFeatures        bool
	dmsGreeter        bool
	includeDeps       []string
	excludeDeps       []string
	replaceConfigs    []string
	replaceConfigsAll bool
	yes               bool
	danksearch        bool
	dankcalendar      bool
)

var rootCmd = &cobra.Command{
	Use:   "dankinstall",
	Short: "Install DankMaterialShell and its dependencies",
	Long: `dankinstall sets up DankMaterialShell with your chosen compositor and terminal.

Without flags, it launches an interactive TUI. Providing either --compositor
or --term activates headless (unattended) mode, which requires both flags.

Headless mode requires cached credentials or passwordless privilege escalation.`,
	Args:          cobra.NoArgs,
	RunE:          runDankinstall,
	SilenceErrors: true,
	SilenceUsage:  true,
}

func init() {
	rootCmd.Flags().StringVarP(&compositor, "compositor", "c", "", "Compositor/WM to install: niri, hyprland, or mango (enables headless mode)")
	rootCmd.Flags().StringVarP(&term, "term", "t", "", "Terminal emulator to install: ghostty, kitty, or alacritty (enables headless mode)")
	rootCmd.Flags().StringVarP(&privescTool, "privesc", "p", "", "Privilege escalation tool: sudo, doas, or run0")
	rootCmd.Flags().BoolVar(&gitAll, "git-all", false, "Use git/development versions for all supported components")
	rootCmd.Flags().BoolVar(&gitAll, "git", false, "Use git/development versions for all supported components (alias for --git-all)")
	rootCmd.Flags().StringSliceVar(&gitDeps, "git-deps", []string{}, "Comma-separated list of dependencies to use git versions for")
	rootCmd.Flags().BoolVarP(&allFeatures, "all-features", "a", false, "Install all optional features and dependencies")
	rootCmd.Flags().BoolVar(&allFeatures, "all", false, "Install all optional features and dependencies (alias for --all-features)")
	rootCmd.Flags().BoolVar(&noFeatures, "no-features", false, "Skip all optional features and dependencies")
	rootCmd.Flags().BoolVar(&dmsGreeter, "dms-greeter", false, "Install dms-greeter optional package")
	rootCmd.Flags().StringSliceVar(&includeDeps, "include-deps", []string{}, "Optional deps to enable (e.g. dms-greeter, danksearch)")
	rootCmd.Flags().StringSliceVar(&excludeDeps, "exclude-deps", []string{}, "Deps to skip during installation")
	rootCmd.Flags().StringSliceVar(&replaceConfigs, "replace-configs", []string{}, "Deploy only named configs (e.g. niri,ghostty)")
	rootCmd.Flags().BoolVar(&replaceConfigsAll, "replace-configs-all", false, "Deploy and replace all configurations")
	rootCmd.Flags().BoolVarP(&yes, "yes", "y", false, "Auto-confirm all prompts")
	rootCmd.Flags().BoolVar(&danksearch, "danksearch", false, "Install danksearch and enable its user indexing service")
	rootCmd.Flags().BoolVar(&dankcalendar, "dankcalendar", false, "Install dankcalendar")
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
			"privesc",
			"git-all",
			"git",
			"git-deps",
			"all-features",
			"all",
			"no-features",
			"dms-greeter",
			"include-deps",
			"exclude-deps",
			"replace-configs",
			"replace-configs-all",
			"yes",
			"danksearch",
			"dankcalendar",
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
		return fmt.Errorf("--compositor is required for headless mode (niri, hyprland, or mango)")
	}
	if term == "" {
		return fmt.Errorf("--term is required for headless mode (ghostty, kitty, or alacritty)")
	}

	cfg := headless.Config{
		Compositor:        compositor,
		Terminal:          term,
		PrivescTool:       privescTool,
		GitAll:            gitAll,
		GitDeps:           gitDeps,
		AllFeatures:       allFeatures,
		NoFeatures:        noFeatures,
		DmsGreeter:        dmsGreeter,
		IncludeDeps:       includeDeps,
		ExcludeDeps:       excludeDeps,
		ReplaceConfigs:    replaceConfigs,
		ReplaceConfigsAll: replaceConfigsAll,
		Yes:               yes,
		DankSearch:        danksearch,
		DankCalendar:      dankcalendar,
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
	} else {
		// Drain the log channel to prevent blocking sends from deadlocking
		// downstream components (distros, config deployer) that write to it.
		// Use an explicit stop signal because this code does not own the
		// runner log channel and cannot assume it will be closed.
		defer drainLogChan(runner.GetLogChan())()
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
	} else {
		// Drain the log channel to prevent blocking sends from deadlocking
		// downstream components (distros, config deployer) that write to it.
		// Use an explicit stop signal because this code does not own the
		// model log channel and cannot assume it will be closed.
		defer drainLogChan(model.GetLogChan())()
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

// drainLogChan starts a goroutine that discards all messages from logCh,
// preventing blocking sends from deadlocking downstream components. It returns
// a cleanup function that signals the goroutine to stop and waits for it to
// exit. Callers should defer the returned function.
func drainLogChan(logCh <-chan string) func() {
	drainStop := make(chan struct{})
	drainDone := make(chan struct{})
	go func() {
		defer close(drainDone)
		for {
			select {
			case <-drainStop:
				return
			case _, ok := <-logCh:
				if !ok {
					return
				}
			}
		}
	}()
	return func() {
		close(drainStop)
		<-drainDone
	}
}
