package main

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/plugins"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/server"
	"github.com/spf13/cobra"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show version information",
	Run:   runVersion,
}

var runCmd = &cobra.Command{
	Use:     "run",
	Short:   "Launch quickshell with DMS configuration",
	Long:    "Launch quickshell with DMS configuration (qs -c dms)",
	PreRunE: findConfig,
	Run: func(cmd *cobra.Command, args []string) {
		daemon, _ := cmd.Flags().GetBool("daemon")
		session, _ := cmd.Flags().GetBool("session")
		if daemon {
			runShellDaemon(session)
		} else {
			runShellInteractive(session)
		}
	},
}

var restartCmd = &cobra.Command{
	Use:     "restart",
	Short:   "Restart quickshell with DMS configuration",
	Long:    "Kill existing DMS shell processes and restart quickshell with DMS configuration",
	PreRunE: findConfig,
	Run: func(cmd *cobra.Command, args []string) {
		restartShell()
	},
}

var restartDetachedCmd = &cobra.Command{
	Use:     "restart-detached <pid>",
	Hidden:  true,
	Args:    cobra.ExactArgs(1),
	PreRunE: findConfig,
	Run: func(cmd *cobra.Command, args []string) {
		runDetachedRestart(args[0])
	},
}

var killCmd = &cobra.Command{
	Use:   "kill",
	Short: "Kill running DMS shell processes",
	Long:  "Kill all running quickshell processes with DMS configuration",
	Run: func(cmd *cobra.Command, args []string) {
		killShell()
	},
}

var ipcCmd = &cobra.Command{
	Use:     "ipc",
	Short:   "Send IPC commands to running DMS shell",
	Long:    "Send IPC commands to running DMS shell (qs -c dms ipc <args>)",
	PreRunE: findConfig,
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		_ = findConfig(cmd, args)
		return getShellIPCCompletions(args, toComplete), cobra.ShellCompDirectiveNoFileComp
	},
	Run: func(cmd *cobra.Command, args []string) {
		runShellIPCCommand(args)
	},
}

var debugSrvCmd = &cobra.Command{
	Use:   "debug-srv",
	Short: "Start the debug server",
	Long:  "Start the Unix socket debug server for DMS",
	Run: func(cmd *cobra.Command, args []string) {
		if err := startDebugServer(); err != nil {
			log.Fatalf("Error starting debug server: %v", err)
		}
	},
}

var pluginsCmd = &cobra.Command{
	Use:   "plugins",
	Short: "Manage DMS plugins",
	Long:  "Browse and manage DMS plugins from the registry",
}

var pluginsBrowseCmd = &cobra.Command{
	Use:   "browse",
	Short: "Browse available plugins",
	Long:  "Browse available plugins from the DMS plugin registry",
	Run: func(cmd *cobra.Command, args []string) {
		if err := browsePlugins(); err != nil {
			log.Fatalf("Error browsing plugins: %v", err)
		}
	},
}

var pluginsListCmd = &cobra.Command{
	Use:   "list",
	Short: "List installed plugins",
	Long:  "List all installed DMS plugins",
	Run: func(cmd *cobra.Command, args []string) {
		if err := listInstalledPlugins(); err != nil {
			log.Fatalf("Error listing plugins: %v", err)
		}
	},
}

var pluginsInstallCmd = &cobra.Command{
	Use:   "install <plugin-id>",
	Short: "Install a plugin by ID",
	Long:  "Install a DMS plugin from the registry using its ID (e.g., 'myPlugin'). Plugin names with spaces are also supported for backward compatibility.",
	Args:  cobra.ExactArgs(1),
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getAvailablePluginIDs(), cobra.ShellCompDirectiveNoFileComp
	},
	Run: func(cmd *cobra.Command, args []string) {
		if err := installPluginCLI(args[0]); err != nil {
			log.Fatalf("Error installing plugin: %v", err)
		}
	},
}

var pluginsUninstallCmd = &cobra.Command{
	Use:   "uninstall <plugin-id>",
	Short: "Uninstall a plugin by ID",
	Long:  "Uninstall a DMS plugin using its ID (e.g., 'myPlugin'). Plugin names with spaces are also supported for backward compatibility.",
	Args:  cobra.ExactArgs(1),
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getInstalledPluginIDs(), cobra.ShellCompDirectiveNoFileComp
	},
	Run: func(cmd *cobra.Command, args []string) {
		if err := uninstallPluginCLI(args[0]); err != nil {
			log.Fatalf("Error uninstalling plugin: %v", err)
		}
	},
}

var pluginsUpdateCmd = &cobra.Command{
	Use:   "update <plugin-id>",
	Short: "Update a plugin by ID",
	Long:  "Update an installed DMS plugin using its ID (e.g., 'myPlugin'). Plugin names are also supported.",
	Args:  cobra.ExactArgs(1),
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		return getInstalledPluginIDs(), cobra.ShellCompDirectiveNoFileComp
	},
	Run: func(cmd *cobra.Command, args []string) {
		if err := updatePluginCLI(args[0]); err != nil {
			log.Fatalf("Error updating plugin: %v", err)
		}
	},
}

func runVersion(cmd *cobra.Command, args []string) {
	fmt.Printf("%s\n", formatVersion(Version))
}

// Git builds: dms (git) v0.6.2-XXXX
// Stable releases: dms v0.6.2
func formatVersion(version string) string {
	// Arch/Debian/Ubuntu/OpenSUSE git format: 0.6.2+git2264.c5c5ce84
	re := regexp.MustCompile(`^([\d.]+)\+git(\d+)\.`)
	if matches := re.FindStringSubmatch(version); matches != nil {
		return fmt.Sprintf("dms (git) v%s-%s", matches[1], matches[2])
	}

	// Fedora COPR git format: 0.0.git.2267.d430cae9
	re = regexp.MustCompile(`^[\d.]+\.git\.(\d+)\.`)
	if matches := re.FindStringSubmatch(version); matches != nil {
		baseVersion := getBaseVersion()
		return fmt.Sprintf("dms (git) v%s-%s", baseVersion, matches[1])
	}

	// Stable release format: 0.6.2
	re = regexp.MustCompile(`^([\d.]+)$`)
	if matches := re.FindStringSubmatch(version); matches != nil {
		return fmt.Sprintf("dms v%s", matches[1])
	}

	return fmt.Sprintf("dms %s", version)
}

func getBaseVersion() string {
	paths := []string{
		"/usr/share/quickshell/dms/VERSION",
		"/usr/local/share/quickshell/dms/VERSION",
		"/etc/xdg/quickshell/dms/VERSION",
	}

	for _, path := range paths {
		if content, err := os.ReadFile(path); err == nil {
			ver := strings.TrimSpace(string(content))
			ver = strings.TrimPrefix(ver, "v")
			if re := regexp.MustCompile(`^([\d.]+)`); re.MatchString(ver) {
				if matches := re.FindStringSubmatch(ver); matches != nil {
					return matches[1]
				}
			}
		}
	}

	// Fallback
	return "1.0.2"
}

func startDebugServer() error {
	server.CLIVersion = Version
	return server.Start(true)
}

func browsePlugins() error {
	registry, err := plugins.NewRegistry()
	if err != nil {
		return fmt.Errorf("failed to create registry: %w", err)
	}

	manager, err := plugins.NewManager()
	if err != nil {
		return fmt.Errorf("failed to create manager: %w", err)
	}

	fmt.Println("Fetching plugin registry...")
	pluginList, err := registry.List()
	if err != nil {
		return fmt.Errorf("failed to list plugins: %w", err)
	}

	if len(pluginList) == 0 {
		fmt.Println("No plugins found in registry.")
		return nil
	}

	fmt.Printf("\nAvailable Plugins (%d):\n\n", len(pluginList))
	for _, plugin := range pluginList {
		installed, _ := manager.IsInstalled(plugin)
		installedMarker := ""
		if installed {
			installedMarker = " [Installed]"
		}

		fmt.Printf("  %s%s\n", plugin.Name, installedMarker)
		fmt.Printf("    ID: %s\n", plugin.ID)
		fmt.Printf("    Category: %s\n", plugin.Category)
		fmt.Printf("    Author: %s\n", plugin.Author)
		fmt.Printf("    Description: %s\n", plugin.Description)
		fmt.Printf("    Repository: %s\n", plugin.Repo)
		if len(plugin.Capabilities) > 0 {
			fmt.Printf("    Capabilities: %s\n", strings.Join(plugin.Capabilities, ", "))
		}
		if len(plugin.Compositors) > 0 {
			fmt.Printf("    Compositors: %s\n", strings.Join(plugin.Compositors, ", "))
		}
		if len(plugin.Dependencies) > 0 {
			fmt.Printf("    Dependencies: %s\n", strings.Join(plugin.Dependencies, ", "))
		}
		fmt.Println()
	}

	return nil
}

func listInstalledPlugins() error {
	manager, err := plugins.NewManager()
	if err != nil {
		return fmt.Errorf("failed to create manager: %w", err)
	}

	registry, err := plugins.NewRegistry()
	if err != nil {
		return fmt.Errorf("failed to create registry: %w", err)
	}

	installedNames, err := manager.ListInstalled()
	if err != nil {
		return fmt.Errorf("failed to list installed plugins: %w", err)
	}

	if len(installedNames) == 0 {
		fmt.Println("No plugins installed.")
		return nil
	}

	allPlugins, err := registry.List()
	if err != nil {
		return fmt.Errorf("failed to list plugins: %w", err)
	}

	pluginMap := make(map[string]plugins.Plugin)
	for _, p := range allPlugins {
		pluginMap[p.ID] = p
	}

	fmt.Printf("\nInstalled Plugins (%d):\n\n", len(installedNames))
	for _, id := range installedNames {
		if plugin, ok := pluginMap[id]; ok {
			fmt.Printf("  %s\n", plugin.Name)
			fmt.Printf("    ID: %s\n", plugin.ID)
			fmt.Printf("    Category: %s\n", plugin.Category)
			fmt.Printf("    Author: %s\n", plugin.Author)
			fmt.Println()
		} else {
			fmt.Printf("  %s (not in registry)\n\n", id)
		}
	}

	return nil
}

func installPluginCLI(idOrName string) error {
	registry, err := plugins.NewRegistry()
	if err != nil {
		return fmt.Errorf("failed to create registry: %w", err)
	}

	manager, err := plugins.NewManager()
	if err != nil {
		return fmt.Errorf("failed to create manager: %w", err)
	}

	pluginList, err := registry.List()
	if err != nil {
		return fmt.Errorf("failed to list plugins: %w", err)
	}

	// First, try to find by ID (preferred method)
	var plugin *plugins.Plugin
	for _, p := range pluginList {
		if p.ID == idOrName {
			plugin = &p
			break
		}
	}

	// Fallback to name for backward compatibility
	if plugin == nil {
		for _, p := range pluginList {
			if p.Name == idOrName {
				plugin = &p
				break
			}
		}
	}

	if plugin == nil {
		return fmt.Errorf("plugin not found: %s", idOrName)
	}

	installed, err := manager.IsInstalled(*plugin)
	if err != nil {
		return fmt.Errorf("failed to check install status: %w", err)
	}

	if installed {
		return fmt.Errorf("plugin already installed: %s", plugin.Name)
	}

	fmt.Printf("Installing plugin: %s (ID: %s)\n", plugin.Name, plugin.ID)
	if err := manager.Install(*plugin); err != nil {
		return fmt.Errorf("failed to install plugin: %w", err)
	}

	fmt.Printf("Plugin installed successfully: %s\n", plugin.Name)
	return nil
}

func getAvailablePluginIDs() []string {
	registry, err := plugins.NewRegistry()
	if err != nil {
		return nil
	}

	pluginList, err := registry.List()
	if err != nil {
		return nil
	}

	var ids []string
	for _, p := range pluginList {
		ids = append(ids, p.ID)
	}
	return ids
}

func getInstalledPluginIDs() []string {
	manager, err := plugins.NewManager()
	if err != nil {
		return nil
	}

	installed, err := manager.ListInstalled()
	if err != nil {
		return nil
	}

	return installed
}

func uninstallPluginCLI(idOrName string) error {
	manager, err := plugins.NewManager()
	if err != nil {
		return fmt.Errorf("failed to create manager: %w", err)
	}

	registry, err := plugins.NewRegistry()
	if err != nil {
		return fmt.Errorf("failed to create registry: %w", err)
	}

	pluginList, _ := registry.List()
	plugin := plugins.FindByIDOrName(idOrName, pluginList)

	if plugin != nil {
		installed, err := manager.IsInstalled(*plugin)
		if err != nil {
			return fmt.Errorf("failed to check install status: %w", err)
		}
		if !installed {
			return fmt.Errorf("plugin not installed: %s", plugin.Name)
		}

		fmt.Printf("Uninstalling plugin: %s (ID: %s)\n", plugin.Name, plugin.ID)
		if err := manager.Uninstall(*plugin); err != nil {
			return fmt.Errorf("failed to uninstall plugin: %w", err)
		}
		fmt.Printf("Plugin uninstalled successfully: %s\n", plugin.Name)
		return nil
	}

	fmt.Printf("Uninstalling plugin: %s\n", idOrName)
	if err := manager.UninstallByIDOrName(idOrName); err != nil {
		return err
	}
	fmt.Printf("Plugin uninstalled successfully: %s\n", idOrName)
	return nil
}

func updatePluginCLI(idOrName string) error {
	manager, err := plugins.NewManager()
	if err != nil {
		return fmt.Errorf("failed to create manager: %w", err)
	}

	registry, err := plugins.NewRegistry()
	if err != nil {
		return fmt.Errorf("failed to create registry: %w", err)
	}

	pluginList, _ := registry.List()
	plugin := plugins.FindByIDOrName(idOrName, pluginList)

	if plugin != nil {
		installed, err := manager.IsInstalled(*plugin)
		if err != nil {
			return fmt.Errorf("failed to check install status: %w", err)
		}
		if !installed {
			return fmt.Errorf("plugin not installed: %s", plugin.Name)
		}

		fmt.Printf("Updating plugin: %s (ID: %s)\n", plugin.Name, plugin.ID)
		if err := manager.Update(*plugin); err != nil {
			return fmt.Errorf("failed to update plugin: %w", err)
		}
		fmt.Printf("Plugin updated successfully: %s\n", plugin.Name)
		return nil
	}

	fmt.Printf("Updating plugin: %s\n", idOrName)
	if err := manager.UpdateByIDOrName(idOrName); err != nil {
		return err
	}
	fmt.Printf("Plugin updated successfully: %s\n", idOrName)
	return nil
}

func getCommonCommands() []*cobra.Command {
	return []*cobra.Command{
		versionCmd,
		runCmd,
		restartCmd,
		restartDetachedCmd,
		killCmd,
		ipcCmd,
		debugSrvCmd,
		pluginsCmd,
		dank16Cmd,
		brightnessCmd,
		dpmsCmd,
		keybindsCmd,
		greeterCmd,
		setupCmd,
		colorCmd,
		screenshotCmd,
		notifyActionCmd,
		matugenCmd,
		clipboardCmd,
	}
}
