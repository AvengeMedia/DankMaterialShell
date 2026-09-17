package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/startup"
	"github.com/spf13/cobra"
)

var startupCmd = &cobra.Command{
	Use:   "startup",
	Short: "Manage user-facing startup applications",
	Long:  "List and manage XDG autostart applications and safely classified user systemd application services.",
}

var startupListJSON bool

var startupListCmd = &cobra.Command{
	Use:   "list",
	Short: "List manageable startup applications",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, _ []string) error {
		entries, err := startup.NewManager().List(cmd.Context())
		if err != nil {
			return err
		}
		if startupListJSON {
			return json.NewEncoder(os.Stdout).Encode(entries)
		}
		for _, entry := range entries {
			state := "disabled"
			if entry.Enabled {
				state = "enabled"
			}
			fmt.Printf("%s\t%s\t%s\n", entry.ID, state, entry.Name)
		}
		return nil
	},
}

var startupEnableCmd = &cobra.Command{
	Use:   "enable <entry-id>",
	Short: "Enable a startup application for future sessions",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		return startup.NewManager().SetEnabled(cmd.Context(), args[0], true)
	},
}

var startupDisableCmd = &cobra.Command{
	Use:   "disable <entry-id>",
	Short: "Disable a startup application for future sessions",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		return startup.NewManager().SetEnabled(cmd.Context(), args[0], false)
	},
}

var (
	startupAddName string
	startupAddExec string
	startupAddIcon string
)

var startupAddCmd = &cobra.Command{
	Use:   "add",
	Short: "Add a user XDG startup application",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, _ []string) error {
		_, err := startup.NewManager().Add(startupAddName, startupAddExec, startupAddIcon)
		return err
	},
}

var startupRemoveCmd = &cobra.Command{
	Use:   "remove <entry-id>",
	Short: "Remove a user-created XDG startup application",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		return startup.NewManager().Remove(args[0])
	},
}

func init() {
	startupListCmd.Flags().BoolVar(&startupListJSON, "json", false, "Return startup applications as JSON")
	startupAddCmd.Flags().StringVar(&startupAddName, "name", "", "Application display name")
	startupAddCmd.Flags().StringVar(&startupAddExec, "exec", "", "Desktop entry Exec value")
	startupAddCmd.Flags().StringVar(&startupAddIcon, "icon", "", "Optional application icon name")
	_ = startupAddCmd.MarkFlagRequired("name")
	_ = startupAddCmd.MarkFlagRequired("exec")
	startupCmd.AddCommand(startupListCmd, startupEnableCmd, startupDisableCmd, startupAddCmd, startupRemoveCmd)
}
