package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/dms"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
)

var customConfigPath string
var configPath string

var rootCmd = &cobra.Command{
	Use:   "dms",
	Short: "dms CLI",
	Long:  "dms is the DankMaterialShell management CLI and backend server.",
	Run:   runInteractiveMode,
}

func init() {
	// Add the -c flag
	rootCmd.PersistentFlags().StringVarP(&customConfigPath, "config", "c", "", "Specify a custom path to the DMS config directory")
}

func findConfig(cmd *cobra.Command, args []string) error {
	if customConfigPath != "" {
		log.Debug("Custom config path provided via -c flag: %s", customConfigPath)
		shellPath := filepath.Join(customConfigPath, "shell.qml")

		info, statErr := os.Stat(shellPath)

		if statErr == nil && !info.IsDir() {
			configPath = customConfigPath
			log.Debug("Using config from: %s", configPath)
			return nil // <-- Guard statement
		}

		if statErr != nil {
			return fmt.Errorf("custom config path error: %w", statErr)
		}

		return fmt.Errorf("path is a directory, not a file: %s", shellPath)
	}

	configStateFile := filepath.Join(getRuntimeDir(), "danklinux.path")
	if data, readErr := os.ReadFile(configStateFile); readErr == nil {
		if len(getAllDMSPIDs()) == 0 {
			os.Remove(configStateFile)
		} else {
			statePath := strings.TrimSpace(string(data))
			shellPath := filepath.Join(statePath, "shell.qml")

			if info, statErr := os.Stat(shellPath); statErr == nil && !info.IsDir() {
				log.Debug("Using config from active session state file: %s", statePath)
				configPath = statePath
				log.Debug("Using config from: %s", configPath)
				return nil
			}
			os.Remove(configStateFile)
		}
	}

	log.Debug("No custom path or active session, searching default XDG locations...")
	var err error
	configPath, err = config.LocateDMSConfig()
	if err != nil {
		return err
	}

	log.Debug("Using config from: %s", configPath)
	return nil
}
func runInteractiveMode(cmd *cobra.Command, args []string) {
	detector, _ := dms.NewDetector()

	if !detector.IsDMSInstalled() {
		log.Error("DankMaterialShell (DMS) is not detected as installed on this system.")
		log.Info("Please install DMS using dankinstall before using this management interface.")
		os.Exit(1)
	}

	model := dms.NewModel(Version)
	p := tea.NewProgram(model, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		log.Fatalf("Error running program: %v", err)
	}
}
