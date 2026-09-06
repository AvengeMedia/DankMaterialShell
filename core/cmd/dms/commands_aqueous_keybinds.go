package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds/providers"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/spf13/cobra"
)

func aqueousBindFailure(err error) map[string]any {
	code := "command_failed"
	var helperError *providers.AqueousError
	if errors.As(err, &helperError) {
		code = helperError.Code
	}
	return map[string]any{"success": false, "code": code, "message": err.Error()}
}

func failAqueousBindEdit(cmd *cobra.Command, err error) {
	structured, _ := cmd.Flags().GetBool("json")
	if !structured {
		log.Fatalf("Failed to save Aqueous keybind: %v", err)
		return
	}
	_ = json.NewEncoder(cmd.OutOrStdout()).Encode(aqueousBindFailure(err))
	os.Exit(1)
}

func runAqueousBindEdit(cmd *cobra.Command, args []string, remove bool) {
	generation, _ := cmd.Flags().GetString("expected-generation")
	edit := providers.AqueousBindEdit{Generation: generation, Key: args[1], Remove: remove}
	if !remove {
		for _, flag := range []string{"desc", "allow-when-locked", "cooldown-ms", "no-repeat", "no-inhibiting", "flags"} {
			if cmd.Flags().Changed(flag) {
				failAqueousBindEdit(cmd, fmt.Errorf("Aqueous does not support --%s in this provider", flag))
				return
			}
		}
		edit.Action = args[2]
		edit.OriginalKey, _ = cmd.Flags().GetString("replace-key")
	}
	result, err := providers.NewAqueousProvider().Edit(cmd.Context(), edit)
	if err != nil {
		failAqueousBindEdit(cmd, err)
		return
	}
	data, _ := json.Marshal(map[string]any{"success": true, "code": "applied", "generation": result.String("generation"), "key": edit.Key})
	fmt.Fprintln(cmd.OutOrStdout(), string(data))
}
