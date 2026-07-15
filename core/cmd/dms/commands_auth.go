package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	sharedpam "github.com/AvengeMedia/DankMaterialShell/core/internal/pam"
	"github.com/spf13/cobra"
)

var authCmd = &cobra.Command{
	Use:   "auth",
	Short: "Manage DMS authentication sync",
	Long:  "Manage shared PAM/authentication setup for DMS greeter and lock screen",
}

var authSyncCmd = &cobra.Command{
	Use:     "sync",
	Short:   "Sync DMS authentication configuration",
	Long:    "Apply shared PAM/authentication changes for the lock screen and greeter based on current DMS settings",
	PreRunE: preRunPrivileged,
	Run: func(cmd *cobra.Command, args []string) {
		yes, _ := cmd.Flags().GetBool("yes")
		term, _ := cmd.Flags().GetBool("terminal")
		if term {
			if err := syncAuthInTerminal(yes); err != nil {
				log.Fatalf("Error launching auth sync in terminal: %v", err)
			}
			return
		}
		if err := syncAuth(yes); err != nil {
			log.Fatalf("Error syncing authentication: %v", err)
		}
	},
}

var authResolveLockCmd = &cobra.Command{
	Use:   "resolve-lock",
	Short: "Generate the lock-screen PAM config from the system auth stack",
	Long: "Resolve the distribution's PAM auth stack into a self-contained lock-screen config under the user state directory.\n" +
		"Runs unprivileged (reads /etc/pam.d, writes to the user's state dir) and is used by the shell as a fallback when /etc/pam.d/dankshell is not managed.\n" +
		"Prints the path of the generated file.",
	Run: func(cmd *cobra.Command, args []string) {
		quiet, _ := cmd.Flags().GetBool("quiet")
		logFunc := func(msg string) {
			if !quiet {
				fmt.Println(msg)
			}
		}
		path, err := sharedpam.WriteUserLockscreenPamConfig(logFunc)
		if err != nil {
			log.Fatalf("Error resolving lock-screen PAM config: %v", err)
		}
		fmt.Println(path)
	},
}

var authListServicesCmd = &cobra.Command{
	Use:   "list-services",
	Short: "List candidate lock-screen PAM services available on this system",
	Long:  "Enumerate the lock-screen PAM services that exist on this system and report their resolved auth stack (whether it has an auth directive and whether fingerprint/U2F modules appear inline).",
	Run: func(cmd *cobra.Command, args []string) {
		asJSON, _ := cmd.Flags().GetBool("json")
		services := sharedpam.ListLockscreenPamServices()

		if asJSON {
			payload := struct {
				Services []sharedpam.LockscreenPamServiceInfo `json:"services"`
			}{Services: services}
			data, err := json.MarshalIndent(payload, "", "  ")
			if err != nil {
				log.Fatalf("Error encoding services: %v", err)
			}
			fmt.Println(string(data))
			return
		}

		if len(services) == 0 {
			fmt.Println("No candidate lock-screen PAM services found.")
			return
		}
		for _, s := range services {
			fmt.Printf("%-20s %-30s auth=%-5t fingerprint=%-5t u2f=%t\n", s.Name, s.Path, s.HasAuth, s.InlineFingerprint, s.InlineU2f)
		}
	},
}

var authValidateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate a PAM service file for use as the DMS lock-screen password stack",
	Long:  "Validate one PAM service (by --service NAME or --path /abs/file) for use as the DMS lock-screen password stack. Exits 1 when the file is not usable.",
	Run: func(cmd *cobra.Command, args []string) {
		path, _ := cmd.Flags().GetString("path")
		service, _ := cmd.Flags().GetString("service")
		asJSON, _ := cmd.Flags().GetBool("json")

		if (path == "") == (service == "") {
			log.Fatalf("Error: exactly one of --path or --service is required")
		}

		var result sharedpam.LockscreenPamValidation
		if path != "" {
			if !filepath.IsAbs(path) {
				result = sharedpam.LockscreenPamValidation{
					Path:           path,
					MissingModules: []string{},
					Warnings:       []string{},
					Errors:         []string{"--path must be an absolute file path"},
				}
			} else {
				result = sharedpam.ValidateLockscreenPamPath(path)
			}
		} else {
			result = sharedpam.ValidateLockscreenPamService(service)
		}

		if asJSON {
			data, err := json.MarshalIndent(result, "", "  ")
			if err != nil {
				log.Fatalf("Error encoding validation: %v", err)
			}
			fmt.Println(string(data))
		} else {
			printLockscreenPamValidation(result)
		}

		if !result.Valid {
			os.Exit(1)
		}
	},
}

func printLockscreenPamValidation(result sharedpam.LockscreenPamValidation) {
	fmt.Printf("Path:               %s\n", result.Path)
	fmt.Printf("Valid:              %t\n", result.Valid)
	fmt.Printf("Has auth:           %t\n", result.HasAuth)
	fmt.Printf("Inline fingerprint: %t\n", result.InlineFingerprint)
	fmt.Printf("Inline U2F:         %t\n", result.InlineU2f)
	if len(result.MissingModules) > 0 {
		fmt.Printf("Missing modules:    %s\n", strings.Join(result.MissingModules, ", "))
	}
	for _, w := range result.Warnings {
		fmt.Println("⚠ " + w)
	}
	for _, e := range result.Errors {
		fmt.Println("✗ " + e)
	}
}

func init() {
	authSyncCmd.Flags().BoolP("yes", "y", false, "Non-interactive mode: skip prompts")
	authSyncCmd.Flags().BoolP("terminal", "t", false, "Run auth sync in a new terminal (for entering sudo password)")
	authResolveLockCmd.Flags().BoolP("quiet", "q", false, "Only print the resulting file path")

	authListServicesCmd.Flags().Bool("json", false, "Output as JSON")

	authValidateCmd.Flags().String("path", "", "Absolute path to a PAM service file to validate")
	authValidateCmd.Flags().String("service", "", "Name of a PAM service to resolve across the system PAM dirs")
	authValidateCmd.Flags().Bool("json", false, "Output as JSON")
}

func syncAuth(nonInteractive bool) error {
	if !nonInteractive {
		fmt.Println("=== DMS Authentication Sync ===")
		fmt.Println()
	}

	logFunc := func(msg string) {
		fmt.Println(msg)
	}

	if err := sharedpam.SyncAuthConfig(logFunc, "", sharedpam.SyncAuthOptions{}); err != nil {
		return err
	}

	if !nonInteractive {
		fmt.Println("\n=== Authentication Sync Complete ===")
		fmt.Println("\nAuthentication changes have been applied.")
	}

	return nil
}

func syncAuthInTerminal(nonInteractive bool) error {
	syncFlags := make([]string, 0, 1)
	if nonInteractive {
		syncFlags = append(syncFlags, "--yes")
	}

	shellSyncCmd := "dms auth sync"
	if len(syncFlags) > 0 {
		shellSyncCmd += " " + strings.Join(syncFlags, " ")
	}
	shellCmd := shellSyncCmd + `; echo; echo "Authentication sync finished. Closing in 3 seconds..."; sleep 3`
	return runCommandInTerminal(shellCmd)
}
