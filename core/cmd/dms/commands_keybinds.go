package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds/providers"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/spf13/cobra"
)

var keybindsCmd = &cobra.Command{
	Use:     "keybinds",
	Aliases: []string{"cheatsheet", "chsht"},
	Short:   "Manage keybinds and cheatsheets",
	Long:    "Display and manage keybinds and cheatsheets for various applications",
}

var keybindsListCmd = &cobra.Command{
	Use:   "list",
	Short: "List available providers",
	Long:  "List all available keybind/cheatsheet providers",
	Run:   runKeybindsList,
}

var keybindsShowCmd = &cobra.Command{
	Use:   "show <provider>",
	Short: "Show keybinds for a provider",
	Long:  "Display keybinds/cheatsheet for the specified provider",
	Args:  cobra.ExactArgs(1),
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		if len(args) != 0 {
			return nil, cobra.ShellCompDirectiveNoFileComp
		}
		registry := keybinds.GetDefaultRegistry()
		return registry.List(), cobra.ShellCompDirectiveNoFileComp
	},
	Run: runKeybindsShow,
}

var keybindsSetCmd = &cobra.Command{
	Use:   "set <provider> <key> <action>",
	Short: "Set a keybind override",
	Long:  "Create or update a keybind override for the specified provider",
	Args:  cobra.ExactArgs(3),
	Run:   runKeybindsSet,
}

var keybindsRemoveCmd = &cobra.Command{
	Use:   "remove <provider> <key>",
	Short: "Remove a keybind override",
	Long:  "Remove a keybind override from the specified provider",
	Args:  cobra.ExactArgs(2),
	Run:   runKeybindsRemove,
}

func init() {
	keybindsShowCmd.Flags().String("path", "", "Override config path for the provider")
	keybindsSetCmd.Flags().String("desc", "", "Description for hotkey overlay")
	keybindsSetCmd.Flags().Bool("allow-when-locked", false, "Allow when screen is locked")
	keybindsSetCmd.Flags().Int("cooldown-ms", 0, "Cooldown in milliseconds")
	keybindsSetCmd.Flags().Bool("no-repeat", false, "Disable key repeat")
	keybindsSetCmd.Flags().String("replace-key", "", "Original key to replace (removes old key)")

	keybindsCmd.AddCommand(keybindsListCmd)
	keybindsCmd.AddCommand(keybindsShowCmd)
	keybindsCmd.AddCommand(keybindsSetCmd)
	keybindsCmd.AddCommand(keybindsRemoveCmd)

	keybinds.SetJSONProviderFactory(func(filePath string) (keybinds.Provider, error) {
		return providers.NewJSONFileProvider(filePath)
	})

	initializeProviders()
}

func initializeProviders() {
	registry := keybinds.GetDefaultRegistry()

	hyprlandProvider := providers.NewHyprlandProvider("$HOME/.config/hypr")
	if err := registry.Register(hyprlandProvider); err != nil {
		log.Warnf("Failed to register Hyprland provider: %v", err)
	}

	mangowcProvider := providers.NewMangoWCProvider("$HOME/.config/mango")
	if err := registry.Register(mangowcProvider); err != nil {
		log.Warnf("Failed to register MangoWC provider: %v", err)
	}

	scrollProvider := providers.NewSwayProvider("$HOME/.config/scroll")
	if err := registry.Register(scrollProvider); err != nil {
		log.Warnf("Failed to register Scroll provider: %v", err)
	}

	swayProvider := providers.NewSwayProvider("$HOME/.config/sway")
	if err := registry.Register(swayProvider); err != nil {
		log.Warnf("Failed to register Sway provider: %v", err)
	}

	niriProvider := providers.NewNiriProvider("")
	if err := registry.Register(niriProvider); err != nil {
		log.Warnf("Failed to register Niri provider: %v", err)
	}

	config := keybinds.DefaultDiscoveryConfig()
	if err := keybinds.AutoDiscoverProviders(registry, config); err != nil {
		log.Warnf("Failed to auto-discover providers: %v", err)
	}
}

func runKeybindsList(_ *cobra.Command, _ []string) {
	providerList := keybinds.GetDefaultRegistry().List()
	if len(providerList) == 0 {
		fmt.Fprintln(os.Stdout, "No providers available")
		return
	}
	fmt.Fprintln(os.Stdout, "Available providers:")
	for _, name := range providerList {
		fmt.Fprintf(os.Stdout, "  - %s\n", name)
	}
}

func makeProviderWithPath(name, path string) keybinds.Provider {
	switch name {
	case "hyprland":
		return providers.NewHyprlandProvider(path)
	case "mangowc":
		return providers.NewMangoWCProvider(path)
	case "sway":
		return providers.NewSwayProvider(path)
	case "scroll":
		return providers.NewSwayProvider(path)
	case "niri":
		return providers.NewNiriProvider(path)
	default:
		return nil
	}
}

func printCheatSheet(provider keybinds.Provider) {
	sheet, err := provider.GetCheatSheet()
	if err != nil {
		log.Fatalf("Error getting cheatsheet: %v", err)
	}
	output, err := json.MarshalIndent(sheet, "", "  ")
	if err != nil {
		log.Fatalf("Error generating JSON: %v", err)
	}
	fmt.Fprintln(os.Stdout, string(output))
}

func runKeybindsShow(cmd *cobra.Command, args []string) {
	providerName := args[0]
	customPath, _ := cmd.Flags().GetString("path")

	if customPath != "" {
		provider := makeProviderWithPath(providerName, customPath)
		if provider == nil {
			log.Fatalf("Provider %s does not support custom path", providerName)
		}
		printCheatSheet(provider)
		return
	}

	provider, err := keybinds.GetDefaultRegistry().Get(providerName)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	printCheatSheet(provider)
}

func getWritableProvider(name string) keybinds.WritableProvider {
	provider, err := keybinds.GetDefaultRegistry().Get(name)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}
	writable, ok := provider.(keybinds.WritableProvider)
	if !ok {
		log.Fatalf("Provider %s does not support writing keybinds", name)
	}
	return writable
}

func runKeybindsSet(cmd *cobra.Command, args []string) {
	providerName, key, action := args[0], args[1], args[2]
	writable := getWritableProvider(providerName)

	if replaceKey, _ := cmd.Flags().GetString("replace-key"); replaceKey != "" && replaceKey != key {
		_ = writable.RemoveBind(replaceKey)
	}

	options := make(map[string]any)
	if v, _ := cmd.Flags().GetBool("allow-when-locked"); v {
		options["allow-when-locked"] = true
	}
	if v, _ := cmd.Flags().GetInt("cooldown-ms"); v > 0 {
		options["cooldown-ms"] = v
	}
	if v, _ := cmd.Flags().GetBool("no-repeat"); v {
		options["repeat"] = false
	}

	desc, _ := cmd.Flags().GetString("desc")
	if err := writable.SetBind(key, action, desc, options); err != nil {
		log.Fatalf("Error setting keybind: %v", err)
	}

	output, _ := json.MarshalIndent(map[string]any{
		"success": true,
		"key":     key,
		"action":  action,
		"path":    writable.GetOverridePath(),
	}, "", "  ")
	fmt.Fprintln(os.Stdout, string(output))
}

func runKeybindsRemove(_ *cobra.Command, args []string) {
	providerName, key := args[0], args[1]
	writable := getWritableProvider(providerName)

	if err := writable.RemoveBind(key); err != nil {
		log.Fatalf("Error removing keybind: %v", err)
	}

	output, _ := json.MarshalIndent(map[string]any{
		"success": true,
		"key":     key,
		"removed": true,
	}, "", "  ")
	fmt.Fprintln(os.Stdout, string(output))
}
