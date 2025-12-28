package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/greeter"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/spf13/cobra"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
)

var greeterCmd = &cobra.Command{
	Use:   "greeter",
	Short: "Manage DMS greeter",
	Long:  "Manage DMS greeter (greetd)",
}

var greeterInstallCmd = &cobra.Command{
	Use:   "install",
	Short: "Install and configure DMS greeter",
	Long:  "Install greetd and configure it to use DMS as the greeter interface",
	Run: func(cmd *cobra.Command, args []string) {
		if err := installGreeter(); err != nil {
			log.Fatalf("Error installing greeter: %v", err)
		}
	},
}

var greeterSyncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Sync DMS theme and settings with greeter",
	Long:  "Synchronize your current user's DMS theme, settings, and wallpaper configuration with the login greeter screen",
	Run: func(cmd *cobra.Command, args []string) {
		if err := syncGreeter(); err != nil {
			log.Fatalf("Error syncing greeter: %v", err)
		}
	},
}

var greeterEnableCmd = &cobra.Command{
	Use:   "enable",
	Short: "Enable DMS greeter in greetd config",
	Long:  "Configure greetd to use DMS as the greeter",
	Run: func(cmd *cobra.Command, args []string) {
		if err := enableGreeter(); err != nil {
			log.Fatalf("Error enabling greeter: %v", err)
		}
	},
}

var greeterStatusCmd = &cobra.Command{
	Use:   "status",
	Short: "Check greeter sync status",
	Long:  "Check the status of greeter installation and configuration sync",
	Run: func(cmd *cobra.Command, args []string) {
		if err := checkGreeterStatus(); err != nil {
			log.Fatalf("Error checking greeter status: %v", err)
		}
	},
}

func installGreeter() error {
	fmt.Println("=== DMS Greeter Installation ===")

	logFunc := func(msg string) {
		fmt.Println(msg)
	}

	if err := greeter.EnsureGreetdInstalled(logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\nDetecting DMS installation...")
	dmsPath, err := greeter.DetectDMSPath()
	if err != nil {
		return err
	}
	fmt.Printf("✓ Found DMS at: %s\n", dmsPath)

	fmt.Println("\nDetecting installed compositors...")
	compositors := greeter.DetectCompositors()
	if len(compositors) == 0 {
		return fmt.Errorf("no supported compositors found (niri or Hyprland required)")
	}

	var selectedCompositor string
	if len(compositors) == 1 {
		selectedCompositor = compositors[0]
		fmt.Printf("✓ Found compositor: %s\n", selectedCompositor)
	} else {
		var err error
		selectedCompositor, err = greeter.PromptCompositorChoice(compositors)
		if err != nil {
			return err
		}
		fmt.Printf("✓ Selected compositor: %s\n", selectedCompositor)
	}

	fmt.Println("\nSetting up dms-greeter group and permissions...")
	if err := greeter.SetupDMSGroup(logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\nCopying greeter files...")
	if err := greeter.CopyGreeterFiles(dmsPath, selectedCompositor, logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\nConfiguring greetd...")
	if err := greeter.ConfigureGreetd(dmsPath, selectedCompositor, logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\nSynchronizing DMS configurations...")
	if err := greeter.SyncDMSConfigs(dmsPath, logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\n=== Installation Complete ===")
	fmt.Println("\nTo test the greeter, run:")
	fmt.Println("  sudo systemctl start greetd")
	fmt.Println("\nTo enable on boot, run:")
	fmt.Println("  sudo systemctl enable --now greetd")

	return nil
}

func syncGreeter() error {
	fmt.Println("=== DMS Greeter Theme Sync ===")
	fmt.Println()

	logFunc := func(msg string) {
		fmt.Println(msg)
	}

	fmt.Println("Detecting DMS installation...")
	dmsPath, err := greeter.DetectDMSPath()
	if err != nil {
		return err
	}
	fmt.Printf("✓ Found DMS at: %s\n", dmsPath)

	cacheDir := "/var/cache/dms-greeter"
	if _, err := os.Stat(cacheDir); os.IsNotExist(err) {
		return fmt.Errorf("greeter cache directory not found at %s\nPlease install the greeter first", cacheDir)
	}

	greeterGroupExists := checkGroupExists("greeter")
	if greeterGroupExists {
		currentUser, err := user.Current()
		if err != nil {
			return fmt.Errorf("failed to get current user: %w", err)
		}

		groupsCmd := exec.Command("groups", currentUser.Username)
		groupsOutput, err := groupsCmd.Output()
		if err != nil {
			return fmt.Errorf("failed to check groups: %w", err)
		}

		inGreeterGroup := strings.Contains(string(groupsOutput), "greeter")
		if !inGreeterGroup {
			fmt.Println("\n⚠ Warning: You are not in the greeter group.")
			fmt.Print("Would you like to add your user to the greeter group? (y/N): ")

			var response string
			fmt.Scanln(&response)
			response = strings.ToLower(strings.TrimSpace(response))

			if response == "y" || response == "yes" {
				fmt.Println("\nAdding user to greeter group...")
				addUserCmd := exec.Command("sudo", "usermod", "-aG", "greeter", currentUser.Username)
				addUserCmd.Stdout = os.Stdout
				addUserCmd.Stderr = os.Stderr
				if err := addUserCmd.Run(); err != nil {
					return fmt.Errorf("failed to add user to greeter group: %w", err)
				}
				fmt.Println("✓ User added to greeter group")
				fmt.Println("⚠ You will need to log out and back in for the group change to take effect")
			}
		}
	}

	fmt.Println("\nSetting up permissions and ACLs...")
	if err := greeter.SetupDMSGroup(logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\nSynchronizing DMS configurations...")
	if err := greeter.SyncDMSConfigs(dmsPath, logFunc, ""); err != nil {
		return err
	}

	fmt.Println("\n=== Sync Complete ===")
	fmt.Println("\nYour theme, settings, and wallpaper configuration have been synced with the greeter.")
	fmt.Println("The changes will be visible on the next login screen.")

	return nil
}

func checkGroupExists(groupName string) bool {
	data, err := os.ReadFile("/etc/group")
	if err != nil {
		return false
	}

	lines := strings.SplitSeq(string(data), "\n")
	for line := range lines {
		if strings.HasPrefix(line, groupName+":") {
			return true
		}
	}
	return false
}

func disableDisplayManager(dmName string) (bool, error) {
	state, err := getSystemdServiceState(dmName)
	if err != nil {
		return false, fmt.Errorf("failed to check %s state: %w", dmName, err)
	}

	if !state.Exists {
		return false, nil
	}

	fmt.Printf("\nChecking %s...\n", dmName)
	fmt.Printf("  Current state: enabled=%s\n", state.EnabledState)

	actionTaken := false

	if state.NeedsDisable {
		var disableCmd *exec.Cmd
		var actionVerb string

		if state.EnabledState == "static" {
			fmt.Printf("  Masking %s (static service cannot be disabled)...\n", dmName)
			disableCmd = exec.Command("sudo", "systemctl", "mask", dmName)
			actionVerb = "masked"
		} else {
			fmt.Printf("  Disabling %s...\n", dmName)
			disableCmd = exec.Command("sudo", "systemctl", "disable", dmName)
			actionVerb = "disabled"
		}

		disableCmd.Stdout = os.Stdout
		disableCmd.Stderr = os.Stderr
		if err := disableCmd.Run(); err != nil {
			return actionTaken, fmt.Errorf("failed to disable/mask %s: %w", dmName, err)
		}

		enabledState, shouldDisable, verifyErr := checkSystemdServiceEnabled(dmName)
		if verifyErr != nil {
			fmt.Printf("  ⚠ Warning: Could not verify %s was %s: %v\n", dmName, actionVerb, verifyErr)
		} else if shouldDisable {
			return actionTaken, fmt.Errorf("%s is still in state '%s' after %s operation", dmName, enabledState, actionVerb)
		} else {
			fmt.Printf("  ✓ %s %s (now: %s)\n", cases.Title(language.English).String(actionVerb), dmName, enabledState)
		}

		actionTaken = true
	} else {
		if state.EnabledState == "masked" || state.EnabledState == "masked-runtime" {
			fmt.Printf("  ✓ %s is already masked\n", dmName)
		} else {
			fmt.Printf("  ✓ %s is already disabled\n", dmName)
		}
	}

	return actionTaken, nil
}

func ensureGreetdEnabled() error {
	fmt.Println("\nChecking greetd service status...")

	state, err := getSystemdServiceState("greetd")
	if err != nil {
		return fmt.Errorf("failed to check greetd state: %w", err)
	}

	if !state.Exists {
		return fmt.Errorf("greetd service not found. Please install greetd first")
	}

	fmt.Printf("  Current state: %s\n", state.EnabledState)

	if state.EnabledState == "masked" || state.EnabledState == "masked-runtime" {
		fmt.Println("  Unmasking greetd...")
		unmaskCmd := exec.Command("sudo", "systemctl", "unmask", "greetd")
		unmaskCmd.Stdout = os.Stdout
		unmaskCmd.Stderr = os.Stderr
		if err := unmaskCmd.Run(); err != nil {
			return fmt.Errorf("failed to unmask greetd: %w", err)
		}
		fmt.Println("  ✓ Unmasked greetd")
	}

	switch state.EnabledState {
	case "disabled", "masked", "masked-runtime":
		fmt.Println("  Enabling greetd service...")
		enableCmd := exec.Command("sudo", "systemctl", "enable", "greetd")
		enableCmd.Stdout = os.Stdout
		enableCmd.Stderr = os.Stderr
		if err := enableCmd.Run(); err != nil {
			return fmt.Errorf("failed to enable greetd: %w", err)
		}
		fmt.Println("  ✓ Enabled greetd service")
	case "enabled", "enabled-runtime":
		fmt.Println("  ✓ greetd is already enabled")
	default:
		fmt.Printf("  ℹ greetd is in state '%s' (should work, no action needed)\n", state.EnabledState)
	}

	return nil
}

func ensureGraphicalTarget() error {
	getDefaultCmd := exec.Command("systemctl", "get-default")
	currentTarget, err := getDefaultCmd.Output()
	if err != nil {
		fmt.Println("⚠ Warning: Could not detect current default systemd target")
		return nil
	}

	currentTargetStr := strings.TrimSpace(string(currentTarget))
	if currentTargetStr != "graphical.target" {
		fmt.Printf("\nSetting graphical.target as default (current: %s)...\n", currentTargetStr)
		setDefaultCmd := exec.Command("sudo", "systemctl", "set-default", "graphical.target")
		setDefaultCmd.Stdout = os.Stdout
		setDefaultCmd.Stderr = os.Stderr
		if err := setDefaultCmd.Run(); err != nil {
			fmt.Println("⚠ Warning: Failed to set graphical.target as default")
			fmt.Println("  Greeter may not start on boot. Run manually:")
			fmt.Println("  sudo systemctl set-default graphical.target")
			return nil
		}
		fmt.Println("✓ Set graphical.target as default")
	} else {
		fmt.Println("✓ Default target already set to graphical.target")
	}

	return nil
}

func handleConflictingDisplayManagers() error {
	fmt.Println("\n=== Checking for Conflicting Display Managers ===")

	conflictingDMs := []string{"gdm", "gdm3", "lightdm", "sddm", "lxdm", "xdm"}

	disabledAny := false
	var errors []string

	for _, dm := range conflictingDMs {
		actionTaken, err := disableDisplayManager(dm)
		if err != nil {
			errMsg := fmt.Sprintf("Failed to handle %s: %v", dm, err)
			errors = append(errors, errMsg)
			fmt.Printf("  ⚠⚠⚠ ERROR: %s\n", errMsg)
			continue
		}
		if actionTaken {
			disabledAny = true
		}
	}

	if len(errors) > 0 {
		fmt.Println("\n╔════════════════════════════════════════════════════════════╗")
		fmt.Println("║           ⚠⚠⚠ ERRORS OCCURRED ⚠⚠⚠                      ║")
		fmt.Println("╚════════════════════════════════════════════════════════════╝")
		fmt.Println("\nSome display managers could not be disabled:")
		for _, err := range errors {
			fmt.Printf("  ✗ %s\n", err)
		}
		fmt.Println("\nThis may prevent greetd from starting properly.")
		fmt.Println("You may need to manually disable them before greetd will work.")
		fmt.Println("\nManual commands to try:")
		for _, dm := range conflictingDMs {
			fmt.Printf("  sudo systemctl disable %s\n", dm)
			fmt.Printf("  sudo systemctl mask %s\n", dm)
		}
		fmt.Print("\nContinue with greeter enablement anyway? (Y/n): ")

		var response string
		fmt.Scanln(&response)
		response = strings.ToLower(strings.TrimSpace(response))

		if response == "n" || response == "no" {
			return fmt.Errorf("aborted due to display manager conflicts")
		}
		fmt.Println("\nContinuing despite errors...")
	}

	if !disabledAny && len(errors) == 0 {
		fmt.Println("\n✓ No conflicting display managers found")
	} else if disabledAny && len(errors) == 0 {
		fmt.Println("\n✓ Successfully handled all conflicting display managers")
	}

	return nil
}

func enableGreeter() error {
	fmt.Println("=== DMS Greeter Enable ===")
	fmt.Println()

	configPath := "/etc/greetd/config.toml"
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return fmt.Errorf("greetd config not found at %s\nPlease install greetd first", configPath)
	}

	data, err := os.ReadFile(configPath)
	if err != nil {
		return fmt.Errorf("failed to read greetd config: %w", err)
	}

	configContent := string(data)
	configAlreadyCorrect := strings.Contains(configContent, "dms-greeter")

	if configAlreadyCorrect {
		fmt.Println("✓ Greeter is already configured with dms-greeter")

		if err := ensureGraphicalTarget(); err != nil {
			return err
		}

		if err := handleConflictingDisplayManagers(); err != nil {
			return err
		}

		if err := ensureGreetdEnabled(); err != nil {
			return err
		}

		fmt.Println("\n=== Enable Complete ===")
		fmt.Println("\nGreeter configuration verified and system state corrected.")
		fmt.Println("To start the greeter now, run:")
		fmt.Println("  sudo systemctl start greetd")
		fmt.Println("\nOr reboot to see the greeter at boot time.")

		return nil
	}

	fmt.Println("Detecting installed compositors...")
	compositors := greeter.DetectCompositors()

	if utils.CommandExists("sway") {
		compositors = append(compositors, "sway")
	}

	if len(compositors) == 0 {
		return fmt.Errorf("no supported compositors found (niri, Hyprland, or sway required)")
	}

	var selectedCompositor string
	if len(compositors) == 1 {
		selectedCompositor = compositors[0]
		fmt.Printf("✓ Found compositor: %s\n", selectedCompositor)
	} else {
		var err error
		selectedCompositor, err = promptCompositorChoice(compositors)
		if err != nil {
			return err
		}
		fmt.Printf("✓ Selected compositor: %s\n", selectedCompositor)
	}

	backupPath := configPath + ".backup"
	backupCmd := exec.Command("sudo", "cp", configPath, backupPath)
	if err := backupCmd.Run(); err != nil {
		return fmt.Errorf("failed to backup config: %w", err)
	}
	fmt.Printf("✓ Backed up config to %s\n", backupPath)

	lines := strings.Split(configContent, "\n")
	var newLines []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "command =") && !strings.HasPrefix(trimmed, "command=") {
			newLines = append(newLines, line)
		}
	}

	wrapperCmd, err := findCommandPath("dms-greeter")
	if err != nil {
		return fmt.Errorf("dms-greeter not found in PATH. Please ensure it is installed and accessible")
	}

	compositorLower := strings.ToLower(selectedCompositor)
	commandLine := fmt.Sprintf(`command = "%s --command %s"`, wrapperCmd, compositorLower)

	var finalLines []string
	inDefaultSession := false
	commandAdded := false

	for _, line := range newLines {
		finalLines = append(finalLines, line)
		trimmed := strings.TrimSpace(line)

		if trimmed == "[default_session]" {
			inDefaultSession = true
		}

		if inDefaultSession && !commandAdded {
			if strings.HasPrefix(trimmed, "user =") || strings.HasPrefix(trimmed, "user=") {
				finalLines = append(finalLines, commandLine)
				commandAdded = true
			}
		}
	}

	if !commandAdded {
		finalLines = append(finalLines, commandLine)
	}

	newConfig := strings.Join(finalLines, "\n")

	tmpFile := "/tmp/greetd-config.toml"
	if err := os.WriteFile(tmpFile, []byte(newConfig), 0o644); err != nil {
		return fmt.Errorf("failed to write temp config: %w", err)
	}

	moveCmd := exec.Command("sudo", "mv", tmpFile, configPath)
	if err := moveCmd.Run(); err != nil {
		return fmt.Errorf("failed to update config: %w", err)
	}

	fmt.Printf("✓ Updated greetd configuration to use %s\n", selectedCompositor)

	if err := ensureGraphicalTarget(); err != nil {
		return err
	}

	if err := handleConflictingDisplayManagers(); err != nil {
		return err
	}

	if err := ensureGreetdEnabled(); err != nil {
		return err
	}

	fmt.Println("\n=== Enable Complete ===")
	fmt.Println("\nTo start the greeter now, run:")
	fmt.Println("  sudo systemctl start greetd")
	fmt.Println("\nOr reboot to see the greeter at boot time.")

	return nil
}

func promptCompositorChoice(compositors []string) (string, error) {
	fmt.Println("\nMultiple compositors detected:")
	for i, comp := range compositors {
		fmt.Printf("%d) %s\n", i+1, comp)
	}

	var response string
	fmt.Print("Choose compositor for greeter: ")
	fmt.Scanln(&response)
	response = strings.TrimSpace(response)

	choice := 0
	fmt.Sscanf(response, "%d", &choice)

	if choice < 1 || choice > len(compositors) {
		return "", fmt.Errorf("invalid choice")
	}

	return compositors[choice-1], nil
}

func checkGreeterStatus() error {
	fmt.Println("=== DMS Greeter Status ===")
	fmt.Println()

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	currentUser, err := user.Current()
	if err != nil {
		return fmt.Errorf("failed to get current user: %w", err)
	}

	configPath := "/etc/greetd/config.toml"
	fmt.Println("Greeter Configuration:")
	if data, err := os.ReadFile(configPath); err == nil {
		configContent := string(data)
		if strings.Contains(configContent, "dms-greeter") {
			lines := strings.SplitSeq(configContent, "\n")
			for line := range lines {
				trimmed := strings.TrimSpace(line)
				if strings.HasPrefix(trimmed, "command =") || strings.HasPrefix(trimmed, "command=") {
					parts := strings.SplitN(trimmed, "=", 2)
					if len(parts) == 2 {
						command := strings.Trim(strings.TrimSpace(parts[1]), `"`)
						fmt.Println("  ✓ Greeter is enabled")

						if strings.Contains(command, "--command niri") {
							fmt.Println("  Compositor: niri")
						} else if strings.Contains(command, "--command hyprland") {
							fmt.Println("  Compositor: Hyprland")
						} else if strings.Contains(command, "--command sway") {
							fmt.Println("  Compositor: sway")
						} else {
							fmt.Println("  Compositor: unknown")
						}
					}
					break
				}
			}
		} else {
			fmt.Println("  ✗ Greeter is NOT enabled")
			fmt.Println("    Run 'dms greeter enable' to enable it")
		}
	} else {
		fmt.Println("  ✗ Greeter config not found")
		fmt.Println("    Run 'dms greeter install' to install greeter")
	}

	fmt.Println("\nGroup Membership:")
	groupsCmd := exec.Command("groups", currentUser.Username)
	groupsOutput, err := groupsCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check groups: %w", err)
	}

	inGreeterGroup := strings.Contains(string(groupsOutput), "greeter")
	if inGreeterGroup {
		fmt.Println("  ✓ User is in greeter group")
	} else {
		fmt.Println("  ✗ User is NOT in greeter group")
		fmt.Println("    Run 'dms greeter install' to add user to greeter group")
	}

	cacheDir := "/var/cache/dms-greeter"
	fmt.Println("\nGreeter Cache Directory:")
	if stat, err := os.Stat(cacheDir); err == nil && stat.IsDir() {
		fmt.Printf("  ✓ %s exists\n", cacheDir)
	} else {
		fmt.Printf("  ✗ %s not found\n", cacheDir)
		fmt.Println("    Run 'dms greeter install' to create cache directory")
		return nil
	}

	fmt.Println("\nConfiguration Symlinks:")
	symlinks := []struct {
		source string
		target string
		desc   string
	}{
		{
			source: filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json"),
			target: filepath.Join(cacheDir, "settings.json"),
			desc:   "Settings",
		},
		{
			source: filepath.Join(homeDir, ".local", "state", "DankMaterialShell", "session.json"),
			target: filepath.Join(cacheDir, "session.json"),
			desc:   "Session state",
		},
		{
			source: filepath.Join(homeDir, ".cache", "DankMaterialShell", "dms-colors.json"),
			target: filepath.Join(cacheDir, "colors.json"),
			desc:   "Color theme",
		},
	}

	allGood := true
	for _, link := range symlinks {
		targetInfo, err := os.Lstat(link.target)
		if err != nil {
			fmt.Printf("  ✗ %s: symlink not found at %s\n", link.desc, link.target)
			allGood = false
			continue
		}

		if targetInfo.Mode()&os.ModeSymlink == 0 {
			fmt.Printf("  ✗ %s: %s is not a symlink\n", link.desc, link.target)
			allGood = false
			continue
		}

		linkDest, err := os.Readlink(link.target)
		if err != nil {
			fmt.Printf("  ✗ %s: failed to read symlink\n", link.desc)
			allGood = false
			continue
		}

		if linkDest != link.source {
			fmt.Printf("  ✗ %s: symlink points to wrong location\n", link.desc)
			fmt.Printf("    Expected: %s\n", link.source)
			fmt.Printf("    Got: %s\n", linkDest)
			allGood = false
			continue
		}

		if _, err := os.Stat(link.source); os.IsNotExist(err) {
			fmt.Printf("  ⚠ %s: symlink OK, but source file doesn't exist yet\n", link.desc)
			fmt.Printf("    Will be created when you run DMS\n")
			continue
		}

		fmt.Printf("  ✓ %s: synced correctly\n", link.desc)
	}

	fmt.Println()
	if allGood && inGreeterGroup {
		fmt.Println("✓ All checks passed! Greeter is properly configured.")
	} else if !allGood {
		fmt.Println("⚠ Some issues detected. Run 'dms greeter sync' to fix symlinks.")
	}

	return nil
}
