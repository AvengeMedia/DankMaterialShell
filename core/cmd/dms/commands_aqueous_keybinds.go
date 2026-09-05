package main

import (
	"encoding/json"
	"fmt"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds/providers"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/spf13/cobra"
)

func runAqueousBindEdit(cmd *cobra.Command, args []string, remove bool) {
	generation, _ := cmd.Flags().GetString("expected-generation")
	edit := providers.AqueousBindEdit{Generation: generation, Key: args[1], Remove: remove}
	if !remove {
		for _, flag := range []string{"desc", "allow-when-locked", "cooldown-ms", "no-repeat", "no-inhibiting", "flags"} {
			if cmd.Flags().Changed(flag) {
				log.Fatalf("Aqueous does not support --%s in this provider", flag)
			}
		}
		edit.Action = args[2]
		edit.OriginalKey, _ = cmd.Flags().GetString("replace-key")
	}
	result, err := providers.NewAqueousProvider().Edit(cmd.Context(), edit)
	if err != nil {
		log.Fatalf("Failed to save Aqueous keybind: %v", err)
	}
	data, _ := json.Marshal(map[string]any{"success": true, "generation": result.String("generation"), "key": edit.Key})
	fmt.Fprintln(cmd.OutOrStdout(), string(data))
}
