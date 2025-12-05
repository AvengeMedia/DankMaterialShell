package greeter

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
)

// DetectDMSPath checks for DMS installation following XDG Base Directory specification
func DetectDMSPath() (string, error) {
	return config.LocateDMSConfig()
}

// DetectCompositors checks which compositors are installed
func DetectCompositors() []string {
	var compositors []string

	if commandExists("niri") {
		compositors = append(compositors, "niri")
	}
	if commandExists("Hyprland") {
		compositors = append(compositors, "Hyprland")
	}

	return compositors
}

// PromptCompositorChoice asks user to choose between compositors
func PromptCompositorChoice(compositors []string) (string, error) {
	fmt.Println("\nMultiple compositors detected:")
	for i, comp := range compositors {
		fmt.Printf("%d) %s\n", i+1, comp)
	}

	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Choose compositor for greeter (1-2): ")
	response, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("error reading input: %w", err)
	}

	response = strings.TrimSpace(response)
	switch response {
	case "1":
		return compositors[0], nil
	case "2":
		if len(compositors) > 1 {
			return compositors[1], nil
		}
		return "", fmt.Errorf("invalid choice")
	default:
		return "", fmt.Errorf("invalid choice")
	}
}

// EnsureGreetdInstalled checks if greetd is installed and installs it if not
func EnsureGreetdInstalled(logFunc func(string), sudoPassword string) error {
	if commandExists("greetd") {
		logFunc("✓ greetd is already installed")
		return nil
	}

	logFunc("greetd is not installed. Installing...")

	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return fmt.Errorf("failed to detect OS: %w", err)
	}

	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return fmt.Errorf("unsupported distribution for automatic greetd installation: %s", osInfo.Distribution.ID)
	}

	ctx := context.Background()
	var installCmd *exec.Cmd

	switch config.Family {
	case distros.FamilyArch:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword,
				"pacman -S --needed --noconfirm greetd")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "pacman", "-S", "--needed", "--noconfirm", "greetd")
		}

	case distros.FamilyFedora:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword,
				"dnf install -y greetd")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "dnf", "install", "-y", "greetd")
		}

	case distros.FamilySUSE:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword,
				"zypper install -y greetd")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "zypper", "install", "-y", "greetd")
		}

	case distros.FamilyUbuntu:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword,
				"apt-get install -y greetd")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "apt-get", "install", "-y", "greetd")
		}

	case distros.FamilyDebian:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword,
				"apt-get install -y greetd")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "apt-get", "install", "-y", "greetd")
		}

	case distros.FamilyNix:
		return fmt.Errorf("on NixOS, please add greetd to your configuration.nix")

	default:
		return fmt.Errorf("unsupported distribution family for automatic greetd installation: %s", config.Family)
	}

	installCmd.Stdout = os.Stdout
	installCmd.Stderr = os.Stderr

	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install greetd: %w", err)
	}

	logFunc("✓ greetd installed successfully")
	return nil
}

// CopyGreeterFiles installs the dms-greeter wrapper and sets up cache directory
func CopyGreeterFiles(dmsPath, compositor string, logFunc func(string), sudoPassword string) error {
	// Check if dms-greeter is already in PATH
	if commandExists("dms-greeter") {
		logFunc("✓ dms-greeter wrapper already installed")
	} else {
		// Install the wrapper script
		assetsDir := filepath.Join(dmsPath, "Modules", "Greetd", "assets")
		wrapperSrc := filepath.Join(assetsDir, "dms-greeter")

		if _, err := os.Stat(wrapperSrc); os.IsNotExist(err) {
			return fmt.Errorf("dms-greeter wrapper not found at %s", wrapperSrc)
		}

		wrapperDst := "/usr/local/bin/dms-greeter"
		if err := runSudoCmd(sudoPassword, "cp", wrapperSrc, wrapperDst); err != nil {
			return fmt.Errorf("failed to copy dms-greeter wrapper: %w", err)
		}
		logFunc(fmt.Sprintf("✓ Installed dms-greeter wrapper to %s", wrapperDst))

		if err := runSudoCmd(sudoPassword, "chmod", "+x", wrapperDst); err != nil {
			return fmt.Errorf("failed to make wrapper executable: %w", err)
		}

		// Set SELinux context on Fedora and openSUSE
		osInfo, err := distros.GetOSInfo()
		if err == nil {
			if config, exists := distros.Registry[osInfo.Distribution.ID]; exists && (config.Family == distros.FamilyFedora || config.Family == distros.FamilySUSE) {
				if err := runSudoCmd(sudoPassword, "semanage", "fcontext", "-a", "-t", "bin_t", wrapperDst); err != nil {
					logFunc(fmt.Sprintf("⚠ Warning: Failed to set SELinux fcontext: %v", err))
				} else {
					logFunc("✓ Set SELinux fcontext for dms-greeter")
				}

				if err := runSudoCmd(sudoPassword, "restorecon", "-v", wrapperDst); err != nil {
					logFunc(fmt.Sprintf("⚠ Warning: Failed to restore SELinux context: %v", err))
				} else {
					logFunc("✓ Restored SELinux context for dms-greeter")
				}
			}
		}
	}

	// Create cache directory with proper permissions
	cacheDir := "/var/cache/dms-greeter"
	if err := runSudoCmd(sudoPassword, "mkdir", "-p", cacheDir); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "chown", "greeter:greeter", cacheDir); err != nil {
		return fmt.Errorf("failed to set cache directory owner: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "chmod", "750", cacheDir); err != nil {
		return fmt.Errorf("failed to set cache directory permissions: %w", err)
	}
	logFunc(fmt.Sprintf("✓ Created cache directory %s (owner: greeter:greeter, permissions: 750)", cacheDir))

	return nil
}

// SetupParentDirectoryACLs sets ACLs on parent directories to allow traversal
func SetupParentDirectoryACLs(logFunc func(string), sudoPassword string) error {
	if !commandExists("setfacl") {
		logFunc("⚠ Warning: setfacl command not found. ACL support may not be available on this filesystem.")
		logFunc("  If theme sync doesn't work, you may need to install acl package:")
		logFunc("  - Fedora/RHEL: sudo dnf install acl")
		logFunc("  - Debian/Ubuntu: sudo apt-get install acl")
		logFunc("  - Arch: sudo pacman -S acl")
		return nil
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	parentDirs := []struct {
		path string
		desc string
	}{
		{homeDir, "home directory"},
		{filepath.Join(homeDir, ".config"), ".config directory"},
		{filepath.Join(homeDir, ".local"), ".local directory"},
		{filepath.Join(homeDir, ".cache"), ".cache directory"},
		{filepath.Join(homeDir, ".local", "state"), ".local/state directory"},
		{filepath.Join(homeDir, ".local", "share"), ".local/share directory"},
	}

	logFunc("\nSetting up parent directory ACLs for greeter user access...")

	for _, dir := range parentDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", dir.desc, err))
				continue
			}
		}

		// Set ACL to allow greeter user read+execute permission (for session discovery)
		if err := runSudoCmd(sudoPassword, "setfacl", "-m", "u:greeter:rx", dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set ACL on %s: %v", dir.desc, err))
			logFunc(fmt.Sprintf("  You may need to run manually: setfacl -m u:greeter:x %s", dir.path))
			continue
		}

		logFunc(fmt.Sprintf("✓ Set ACL on %s", dir.desc))
	}

	return nil
}

func SetupDMSGroup(logFunc func(string), sudoPassword string) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	currentUser := os.Getenv("USER")
	if currentUser == "" {
		currentUser = os.Getenv("LOGNAME")
	}
	if currentUser == "" {
		return fmt.Errorf("failed to determine current user")
	}

	// Check if user is already in greeter group
	groupsCmd := exec.Command("groups", currentUser)
	groupsOutput, err := groupsCmd.Output()
	if err == nil && strings.Contains(string(groupsOutput), "greeter") {
		logFunc(fmt.Sprintf("✓ %s is already in greeter group", currentUser))
	} else {
		// Add current user to greeter group for file access permissions
		if err := runSudoCmd(sudoPassword, "usermod", "-aG", "greeter", currentUser); err != nil {
			return fmt.Errorf("failed to add %s to greeter group: %w", currentUser, err)
		}
		logFunc(fmt.Sprintf("✓ Added %s to greeter group (logout/login required for changes to take effect)", currentUser))
	}

	configDirs := []struct {
		path string
		desc string
	}{
		{filepath.Join(homeDir, ".config", "DankMaterialShell"), "DankMaterialShell config"},
		{filepath.Join(homeDir, ".local", "state", "DankMaterialShell"), "DankMaterialShell state"},
		{filepath.Join(homeDir, ".cache", "quickshell"), "quickshell cache"},
		{filepath.Join(homeDir, ".config", "quickshell"), "quickshell config"},
		{filepath.Join(homeDir, ".local", "share", "wayland-sessions"), "wayland sessions"},
		{filepath.Join(homeDir, ".local", "share", "xsessions"), "xsessions"},
	}

	for _, dir := range configDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", dir.path, err))
				continue
			}
		}

		if err := runSudoCmd(sudoPassword, "chgrp", "-R", "greeter", dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set group for %s: %v", dir.desc, err))
			continue
		}

		if err := runSudoCmd(sudoPassword, "chmod", "-R", "g+rX", dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set permissions for %s: %v", dir.desc, err))
			continue
		}

		logFunc(fmt.Sprintf("✓ Set group permissions for %s", dir.desc))
	}

	// Set up ACLs on parent directories to allow greeter user traversal
	if err := SetupParentDirectoryACLs(logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to setup parent directory ACLs: %w", err)
	}

	return nil
}

func SyncDMSConfigs(dmsPath string, logFunc func(string), sudoPassword string) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	cacheDir := "/var/cache/dms-greeter"

	symlinks := []struct {
		source string
		target string
		desc   string
	}{
		{
			source: filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json"),
			target: filepath.Join(cacheDir, "settings.json"),
			desc:   "core settings (theme, clock formats, etc)",
		},
		{
			source: filepath.Join(homeDir, ".local", "state", "DankMaterialShell", "session.json"),
			target: filepath.Join(cacheDir, "session.json"),
			desc:   "state (wallpaper configuration)",
		},
		{
			source: filepath.Join(homeDir, ".cache", "DankMaterialShell", "dms-colors.json"),
			target: filepath.Join(cacheDir, "colors.json"),
			desc:   "wallpaper based theming",
		},
	}

	for _, link := range symlinks {
		sourceDir := filepath.Dir(link.source)
		if _, err := os.Stat(sourceDir); os.IsNotExist(err) {
			if err := os.MkdirAll(sourceDir, 0755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create directory %s: %v", sourceDir, err))
				continue
			}
		}

		if _, err := os.Stat(link.source); os.IsNotExist(err) {
			if err := os.WriteFile(link.source, []byte("{}"), 0644); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", link.source, err))
				continue
			}
		}

		runSudoCmd(sudoPassword, "rm", "-f", link.target) //nolint:errcheck

		if err := runSudoCmd(sudoPassword, "ln", "-sf", link.source, link.target); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to create symlink for %s: %v", link.desc, err))
			continue
		}

		logFunc(fmt.Sprintf("✓ Synced %s", link.desc))
	}

	return nil
}

func ConfigureGreetd(dmsPath, compositor string, logFunc func(string), sudoPassword string) error {
	configPath := "/etc/greetd/config.toml"

	if _, err := os.Stat(configPath); err == nil {
		backupPath := configPath + ".backup"
		if err := runSudoCmd(sudoPassword, "cp", configPath, backupPath); err != nil {
			return fmt.Errorf("failed to backup config: %w", err)
		}
		logFunc(fmt.Sprintf("✓ Backed up existing config to %s", backupPath))
	}

	var configContent string
	if data, err := os.ReadFile(configPath); err == nil {
		configContent = string(data)
	} else {
		configContent = `[terminal]
vt = 1

[default_session]

user = "greeter"
`
	}

	lines := strings.Split(configContent, "\n")
	var newLines []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "command =") && !strings.HasPrefix(trimmed, "command=") {
			if strings.HasPrefix(trimmed, "user =") || strings.HasPrefix(trimmed, "user=") {
				newLines = append(newLines, `user = "greeter"`)
			} else {
				newLines = append(newLines, line)
			}
		}
	}

	// Determine wrapper command path
	wrapperCmd := "dms-greeter"
	if !commandExists("dms-greeter") {
		wrapperCmd = "/usr/local/bin/dms-greeter"
	}

	// Build command based on compositor and dms path
	compositorLower := strings.ToLower(compositor)
	command := fmt.Sprintf(`command = "%s --command %s -p %s"`, wrapperCmd, compositorLower, dmsPath)

	var finalLines []string
	inDefaultSession := false
	commandAdded := false

	for _, line := range newLines {
		finalLines = append(finalLines, line)
		trimmed := strings.TrimSpace(line)

		if trimmed == "[default_session]" {
			inDefaultSession = true
		}

		if inDefaultSession && !commandAdded && trimmed != "" && !strings.HasPrefix(trimmed, "[") {
			if !strings.HasPrefix(trimmed, "#") && !strings.HasPrefix(trimmed, "user") {
				finalLines = append(finalLines, command)
				commandAdded = true
			}
		}
	}

	if !commandAdded {
		finalLines = append(finalLines, command)
	}

	newConfig := strings.Join(finalLines, "\n")

	tmpFile := "/tmp/greetd-config.toml"
	if err := os.WriteFile(tmpFile, []byte(newConfig), 0644); err != nil {
		return fmt.Errorf("failed to write temp config: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "mv", tmpFile, configPath); err != nil {
		return fmt.Errorf("failed to move config to /etc/greetd: %w", err)
	}

	logFunc(fmt.Sprintf("✓ Updated greetd configuration (user: greeter, command: %s --command %s -p %s)", wrapperCmd, compositorLower, dmsPath))
	return nil
}

func runSudoCmd(sudoPassword string, command string, args ...string) error {
	var cmd *exec.Cmd

	if sudoPassword != "" {
		fullArgs := append([]string{command}, args...)
		quotedArgs := make([]string, len(fullArgs))
		for i, arg := range fullArgs {
			quotedArgs[i] = "'" + strings.ReplaceAll(arg, "'", "'\\''") + "'"
		}
		cmdStr := strings.Join(quotedArgs, " ")

		cmd = distros.ExecSudoCommand(context.Background(), sudoPassword, cmdStr)
	} else {
		cmd = exec.Command("sudo", append([]string{command}, args...)...)
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}
