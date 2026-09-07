package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

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
	Run:   runKeybindsEdit,
}

var keybindsRemoveCmd = &cobra.Command{
	Use:   "remove <provider> <key>",
	Short: "Remove a keybind",
	Long:  "Remove a keybind. For Hyprland this writes a negative override to dms/binds-user.lua so the key stays unbound across DMS updates. For other providers it deletes the entry from the managed file.",
	Args:  cobra.ExactArgs(2),
	Run:   runKeybindsEdit,
}

var keybindsResetCmd = &cobra.Command{
	Use:   "reset <provider> <key>",
	Short: "Reset a keybind override to its DMS default",
	Long:  "Drop the user override for the given key so the DMS default re-applies. For providers without a separate default file (Niri, MangoWC) this is equivalent to remove.",
	Args:  cobra.ExactArgs(2),
	Run:   runKeybindsEdit,
}

func init() {
	keybindsCmd.PersistentFlags().String("expected-generation", "", "Configuration generation observed when editing Aqueous bindings")
	for _, command := range []*cobra.Command{keybindsSetCmd, keybindsRemoveCmd, keybindsResetCmd} {
		command.Flags().Bool("json", false, "Return structured mutation results, including errors")
	}
	keybindsListCmd.Flags().BoolP("json", "j", false, "Output as JSON")
	keybindsShowCmd.Flags().String("path", "", "Override config path for the provider")
	keybindsSetCmd.Flags().String("desc", "", "Description for hotkey overlay")
	keybindsSetCmd.Flags().Bool("allow-when-locked", false, "Allow when screen is locked")
	keybindsSetCmd.Flags().Int("cooldown-ms", 0, "Cooldown in milliseconds")
	keybindsSetCmd.Flags().Bool("no-repeat", false, "Disable key repeat")
	keybindsSetCmd.Flags().Bool("no-inhibiting", false, "Keep bind active when shortcuts are inhibited (allow-inhibiting=false)")
	keybindsSetCmd.Flags().String("replace-key", "", "Original key to replace (removes old key)")
	keybindsSetCmd.Flags().String("flags", "", "Hyprland bind flags (e.g., 'e' for repeat, 'l' for locked, 'r' for release)")

	keybindsCmd.AddCommand(keybindsListCmd)
	keybindsCmd.AddCommand(keybindsShowCmd)
	keybindsCmd.AddCommand(keybindsSetCmd)
	keybindsCmd.AddCommand(keybindsRemoveCmd)
	keybindsCmd.AddCommand(keybindsResetCmd)

	keybinds.SetJSONProviderFactory(func(filePath string) (keybinds.Provider, error) {
		return providers.NewJSONFileProvider(filePath)
	})

	initializeProviders()
}

func initializeProviders() {
	registry := keybinds.GetDefaultRegistry()

	hyprlandProvider := providers.NewHyprlandProvider("")
	if err := registry.Register(providers.NewAqueousProvider()); err != nil {
		log.Warnf("Failed to register Aqueous provider: %v", err)
	}
	if err := registry.Register(hyprlandProvider); err != nil {
		log.Warnf("Failed to register Hyprland provider: %v", err)
	}

	mangowcProvider := providers.NewMangoWCProvider("")
	if err := registry.Register(mangowcProvider); err != nil {
		log.Warnf("Failed to register MangoWC provider: %v", err)
	}

	configDir, _ := os.UserConfigDir()

	if configDir != "" {
		scrollProvider := providers.NewSwayProvider(filepath.Join(configDir, "scroll"))
		if err := registry.Register(scrollProvider); err != nil {
			log.Warnf("Failed to register Scroll provider: %v", err)
		}
	}

	miracleProvider := providers.NewMiracleProvider("")
	if err := registry.Register(miracleProvider); err != nil {
		log.Warnf("Failed to register Miracle WM provider: %v", err)
	}

	if configDir != "" {
		swayProvider := providers.NewSwayProvider(filepath.Join(configDir, "sway"))
		if err := registry.Register(swayProvider); err != nil {
			log.Warnf("Failed to register Sway provider: %v", err)
		}
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

func runKeybindsList(cmd *cobra.Command, _ []string) {
	providerList := keybinds.GetDefaultRegistry().List()
	asJSON, _ := cmd.Flags().GetBool("json")

	if asJSON {
		output, _ := json.Marshal(providerList)
		fmt.Fprintln(os.Stdout, string(output))
		return
	}

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
	case "miracle":
		return providers.NewMiracleProvider(path)
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

func keybindEditFailure(err error) map[string]any {
	code := "command_failed"
	var helperError *providers.AqueousError
	if errors.As(err, &helperError) {
		code = helperError.Code
	}
	return map[string]any{"success": false, "code": code, "message": err.Error()}
}

func runKeybindsEdit(cmd *cobra.Command, args []string) {
	result, err := editKeybind(cmd, args)
	if err == nil {
		_ = json.NewEncoder(cmd.OutOrStdout()).Encode(result)
		return
	}
	structured, _ := cmd.Flags().GetBool("json")
	if !structured {
		log.Fatalf("Failed to save keybind: %v", err)
		return
	}
	_ = json.NewEncoder(cmd.OutOrStdout()).Encode(keybindEditFailure(err))
	os.Exit(1)
}

func editKeybind(cmd *cobra.Command, args []string) (map[string]any, error) {
	provider, err := keybinds.GetDefaultRegistry().Get(args[0])
	if err != nil {
		return nil, err
	}
	key := args[1]
	if aqueous, ok := provider.(*providers.AqueousProvider); ok {
		generation, _ := cmd.Flags().GetString("expected-generation")
		edit := providers.AqueousBindEdit{Generation: generation, Key: key, Remove: cmd.Name() != "set"}
		if !edit.Remove {
			for _, flag := range []string{"desc", "allow-when-locked", "cooldown-ms", "no-repeat", "no-inhibiting", "flags"} {
				if cmd.Flags().Changed(flag) {
					return nil, fmt.Errorf("aqueous does not support --%s in this provider", flag)
				}
			}
			edit.Action = args[2]
			edit.OriginalKey, _ = cmd.Flags().GetString("replace-key")
		}
		result, err := aqueous.Edit(cmd.Context(), edit)
		if err != nil {
			return nil, err
		}
		return map[string]any{"success": true, "code": "applied", "generation": result.String("generation"), "key": key}, nil
	}
	writable, ok := provider.(keybinds.WritableProvider)
	if !ok {
		return nil, fmt.Errorf("provider %s does not support writing keybinds", args[0])
	}
	result := map[string]any{"success": true, "key": key}
	switch cmd.Name() {
	case "set":
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
		if v, _ := cmd.Flags().GetBool("no-inhibiting"); v {
			options["allow-inhibiting"] = false
		}
		if v, _ := cmd.Flags().GetString("flags"); v != "" {
			options["flags"] = v
		}
		if replaceKey, _ := cmd.Flags().GetString("replace-key"); replaceKey != "" && replaceKey != key {
			_ = writable.RemoveBind(replaceKey)
		}
		desc, _ := cmd.Flags().GetString("desc")
		err = writable.SetBind(key, args[2], desc, options)
		result["action"] = args[2]
		result["path"] = writable.GetOverridePath()
	case "remove":
		err = writable.RemoveBind(key)
		result["removed"] = true
	case "reset":
		err = writable.ResetBind(key)
		result["reset"] = true
	default:
		return nil, fmt.Errorf("unsupported keybind operation: %s", cmd.Name())
	}
	return result, err
}
