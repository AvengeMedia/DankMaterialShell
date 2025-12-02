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

func init() {
	keybindsShowCmd.Flags().String("path", "", "Override config path for the provider")

	keybindsCmd.AddCommand(keybindsListCmd)
	keybindsCmd.AddCommand(keybindsShowCmd)

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

func runKeybindsList(cmd *cobra.Command, args []string) {
	registry := keybinds.GetDefaultRegistry()
	providers := registry.List()

	if len(providers) == 0 {
		fmt.Fprintln(os.Stdout, "No providers available")
		return
	}

	fmt.Fprintln(os.Stdout, "Available providers:")
	for _, name := range providers {
		fmt.Fprintf(os.Stdout, "  - %s\n", name)
	}
}

func runKeybindsShow(cmd *cobra.Command, args []string) {
	providerName := args[0]
	registry := keybinds.GetDefaultRegistry()

	customPath, _ := cmd.Flags().GetString("path")
	if customPath != "" {
		var provider keybinds.Provider
		switch providerName {
		case "hyprland":
			provider = providers.NewHyprlandProvider(customPath)
		case "mangowc":
			provider = providers.NewMangoWCProvider(customPath)
		case "sway":
			provider = providers.NewSwayProvider(customPath)
		case "niri":
			provider = providers.NewNiriProvider(customPath)
		default:
			log.Fatalf("Provider %s does not support custom path", providerName)
		}

		sheet, err := provider.GetCheatSheet()
		if err != nil {
			log.Fatalf("Error getting cheatsheet: %v", err)
		}

		output, err := json.MarshalIndent(sheet, "", "  ")
		if err != nil {
			log.Fatalf("Error generating JSON: %v", err)
		}

		fmt.Fprintln(os.Stdout, string(output))
		return
	}

	provider, err := registry.Get(providerName)
	if err != nil {
		log.Fatalf("Error: %v", err)
	}

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
