//go:build !distro_binary

package main

import (
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/clipboard"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

var Version = "dev"

func init() {
	runCmd.Flags().BoolP("daemon", "d", false, "Run in daemon mode")
	runCmd.Flags().Bool("daemon-child", false, "Internal flag for daemon child process")
	runCmd.Flags().Bool("session", false, "Session managed (like as a systemd unit)")
	runCmd.Flags().String("log-level", "", "Log level: debug, info, warn, error, fatal (overrides DMS_LOG_LEVEL)")
	runCmd.Flags().String("log-file", "", "Append logs to this file in addition to stderr (overrides DMS_LOG_FILE)")
	runCmd.Flags().MarkHidden("daemon-child")

	greeterCmd.AddCommand(greeterInstallCmd, greeterSyncCmd, greeterEnableCmd, greeterStatusCmd, greeterUninstallCmd)
	authCmd.AddCommand(authSyncCmd)
	setupCmd.AddCommand(setupBindsCmd, setupLayoutCmd, setupColorsCmd, setupAlttabCmd, setupOutputsCmd, setupCursorCmd, setupWindowrulesCmd)
	updateCmd.AddCommand(updateCheckCmd)
	pluginsCmd.AddCommand(pluginsBrowseCmd, pluginsListCmd, pluginsInstallCmd, pluginsUninstallCmd, pluginsUpdateCmd)
	rootCmd.AddCommand(getCommonCommands()...)

	rootCmd.AddCommand(authCmd)
	rootCmd.AddCommand(updateCmd)

	rootCmd.SetHelpTemplate(getHelpTemplate())
}

func main() {
	clipboard.MaybeServeAndExit()

	if os.Geteuid() == 0 && !isReadOnlyCommand(os.Args) {
		log.Fatal("This program should not be run as root. Exiting.")
	}

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
