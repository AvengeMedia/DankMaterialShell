package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/matugen"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server/models"
	"github.com/spf13/cobra"
)

var matugenCmd = &cobra.Command{
	Use:   "matugen",
	Short: "Generate Material Design themes",
	Long:  "Generate Material Design themes using matugen with dank16 color integration",
}

var matugenGenerateCmd = &cobra.Command{
	Use:   "generate",
	Short: "Generate theme synchronously",
	Run:   runMatugenGenerate,
}

var matugenQueueCmd = &cobra.Command{
	Use:   "queue",
	Short: "Queue theme generation (uses socket if available)",
	Run:   runMatugenQueue,
}

var matugenCheckCmd = &cobra.Command{
	Use:   "check",
	Short: "Check which template apps are detected",
	Run:   runMatugenCheck,
}

func init() {
	matugenCmd.AddCommand(matugenGenerateCmd)
	matugenCmd.AddCommand(matugenQueueCmd)
	matugenCmd.AddCommand(matugenCheckCmd)

	for _, cmd := range []*cobra.Command{matugenGenerateCmd, matugenQueueCmd} {
		cmd.Flags().String("state-dir", "", "State directory for cache files")
		cmd.Flags().String("shell-dir", "", "DMS shell installation directory")
		cmd.Flags().String("config-dir", "", "User config directory")
		cmd.Flags().String("kind", "image", "Source type: image or hex")
		cmd.Flags().String("value", "", "Wallpaper path or hex color")
		cmd.Flags().String("mode", "dark", "Color mode: dark or light")
		cmd.Flags().String("icon-theme", "System Default", "Icon theme name")
		cmd.Flags().String("matugen-type", "scheme-tonal-spot", "Matugen scheme type")
		cmd.Flags().Bool("run-user-templates", true, "Run user matugen templates")
		cmd.Flags().String("stock-colors", "", "Stock theme colors JSON")
		cmd.Flags().Bool("sync-mode-with-portal", false, "Sync color scheme with GNOME portal")
		cmd.Flags().Bool("terminals-always-dark", false, "Force terminal themes to dark variant")
		cmd.Flags().String("skip-templates", "", "Comma-separated list of templates to skip")
	}

	matugenQueueCmd.Flags().Bool("wait", true, "Wait for completion")
	matugenQueueCmd.Flags().Duration("timeout", 30*time.Second, "Timeout for waiting")
}

func buildMatugenOptions(cmd *cobra.Command) matugen.Options {
	stateDir, _ := cmd.Flags().GetString("state-dir")
	shellDir, _ := cmd.Flags().GetString("shell-dir")
	configDir, _ := cmd.Flags().GetString("config-dir")
	kind, _ := cmd.Flags().GetString("kind")
	value, _ := cmd.Flags().GetString("value")
	mode, _ := cmd.Flags().GetString("mode")
	iconTheme, _ := cmd.Flags().GetString("icon-theme")
	matugenType, _ := cmd.Flags().GetString("matugen-type")
	runUserTemplates, _ := cmd.Flags().GetBool("run-user-templates")
	stockColors, _ := cmd.Flags().GetString("stock-colors")
	syncModeWithPortal, _ := cmd.Flags().GetBool("sync-mode-with-portal")
	terminalsAlwaysDark, _ := cmd.Flags().GetBool("terminals-always-dark")
	skipTemplates, _ := cmd.Flags().GetString("skip-templates")

	return matugen.Options{
		StateDir:            stateDir,
		ShellDir:            shellDir,
		ConfigDir:           configDir,
		Kind:                kind,
		Value:               value,
		Mode:                matugen.ColorMode(mode),
		IconTheme:           iconTheme,
		MatugenType:         matugenType,
		RunUserTemplates:    runUserTemplates,
		StockColors:         stockColors,
		SyncModeWithPortal:  syncModeWithPortal,
		TerminalsAlwaysDark: terminalsAlwaysDark,
		SkipTemplates:       skipTemplates,
	}
}

func runMatugenGenerate(cmd *cobra.Command, args []string) {
	opts := buildMatugenOptions(cmd)
	err := matugen.Run(opts)
	switch {
	case errors.Is(err, matugen.ErrNoChanges):
		os.Exit(2)
	case err != nil:
		log.Fatalf("Theme generation failed: %v", err)
	}
}

func runMatugenQueue(cmd *cobra.Command, args []string) {
	opts := buildMatugenOptions(cmd)
	wait, _ := cmd.Flags().GetBool("wait")
	timeout, _ := cmd.Flags().GetDuration("timeout")

	request := models.Request{
		ID:     1,
		Method: "matugen.queue",
		Params: map[string]any{
			"stateDir":            opts.StateDir,
			"shellDir":            opts.ShellDir,
			"configDir":           opts.ConfigDir,
			"kind":                opts.Kind,
			"value":               opts.Value,
			"mode":                opts.Mode,
			"iconTheme":           opts.IconTheme,
			"matugenType":         opts.MatugenType,
			"runUserTemplates":    opts.RunUserTemplates,
			"stockColors":         opts.StockColors,
			"syncModeWithPortal":  opts.SyncModeWithPortal,
			"terminalsAlwaysDark": opts.TerminalsAlwaysDark,
			"skipTemplates":       opts.SkipTemplates,
			"wait":                wait,
		},
	}

	if !wait {
		if err := sendServerRequestFireAndForget(request); err != nil {
			log.Info("Server unavailable, running synchronously")
			err := matugen.Run(opts)
			switch {
			case errors.Is(err, matugen.ErrNoChanges):
				os.Exit(2)
			case err != nil:
				log.Fatalf("Theme generation failed: %v", err)
			}
			return
		}
		fmt.Println("Theme generation queued")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	resultCh := make(chan error, 1)
	go func() {
		resp, ok := tryServerRequest(request)
		if !ok {
			log.Info("Server unavailable, running synchronously")
			err := matugen.Run(opts)
			switch {
			case errors.Is(err, matugen.ErrNoChanges):
				resultCh <- matugen.ErrNoChanges
			case err != nil:
				resultCh <- err
			default:
				resultCh <- nil
			}
			return
		}
		if resp.Error != "" {
			resultCh <- fmt.Errorf("server error: %s", resp.Error)
			return
		}
		resultCh <- nil
	}()

	select {
	case err := <-resultCh:
		switch {
		case errors.Is(err, matugen.ErrNoChanges):
			os.Exit(2)
		case err != nil:
			log.Fatalf("Theme generation failed: %v", err)
		}
		fmt.Println("Theme generation completed")
	case <-ctx.Done():
		log.Fatalf("Timeout waiting for theme generation")
	}
}

func runMatugenCheck(cmd *cobra.Command, args []string) {
	checks := matugen.CheckTemplates(nil)
	data, err := json.Marshal(checks)
	if err != nil {
		log.Fatalf("Failed to marshal check results: %v", err)
	}
	fmt.Println(string(data))
}
