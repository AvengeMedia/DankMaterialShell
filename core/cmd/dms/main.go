//go:build !distro_binary

package main

import (
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/clipboard"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
)

var Version = "dev"

func init() {
	authCmd.AddCommand(authSyncCmd, authResolveLockCmd, authListServicesCmd, authValidateCmd)
	setupCmd.AddCommand(setupHeadlessCmd, setupBindsCmd, setupLayoutCmd, setupColorsCmd, setupAlttabCmd, setupOutputsCmd, setupCursorCmd, setupWindowrulesCmd)
	updateCmd.AddCommand(updateCheckCmd)
	pluginsCmd.AddCommand(pluginsBrowseCmd, pluginsListCmd, pluginsInstallCmd, pluginsUninstallCmd, pluginsUpdateCmd, pluginsLockCmd, pluginsRestoreCmd)
	registryCmd.AddCommand(registryListCmd, registryAddCmd, registryRemoveCmd)
	rootCmd.AddCommand(getCommonCommands()...)

	rootCmd.AddCommand(authCmd)
	rootCmd.AddCommand(updateCmd)

	rootCmd.SetHelpTemplate(getHelpTemplate())
}

func main() {
	disableMemProfilingUnlessRequested()
	clipboard.MaybeServeAndExit()

	if os.Geteuid() == 0 && !isReadOnlyCommand(os.Args) {
		log.Fatal("This program should not be run as root. Exiting.")
	}

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
