package main

import (
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
)

var Version = "dev"

func main() {
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
