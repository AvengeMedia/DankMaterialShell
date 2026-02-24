//go:build distro_binary

package main

import (
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

var Version = "dev"

func init() {
	// Add flags
	runCmd.Flags().BoolP("daemon", "d", false, "Run in daemon mode")
	runCmd.Flags().Bool("daemon-child", false, "Internal flag for daemon child process")
	runCmd.Flags().Bool("session", false, "Session managed (like as a systemd unit)")
	runCmd.Flags().MarkHidden("daemon-child")

	// Add subcommands to greeter
	greeterCmd.AddCommand(greeterInstallCmd, greeterSyncCmd, greeterEnableCmd, greeterStatusCmd)

	// Add subcommands to setup
	setupCmd.AddCommand(setupBindsCmd, setupLayoutCmd, setupColorsCmd, setupAlttabCmd, setupOutputsCmd, setupCursorCmd, setupWindowrulesCmd)

	// Add subcommands to plugins
	pluginsCmd.AddCommand(pluginsBrowseCmd, pluginsListCmd, pluginsInstallCmd, pluginsUninstallCmd, pluginsUpdateCmd)

	// Add common commands to root
	rootCmd.AddCommand(getCommonCommands()...)

	rootCmd.SetHelpTemplate(getHelpTemplate())
}

func main() {
	// Block root
	if os.Geteuid() == 0 {
		log.Fatal("This program should not be run as root. Exiting.")
	}

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
