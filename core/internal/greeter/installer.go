package greeter

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/config"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/sblinch/kdl-go"
	"github.com/sblinch/kdl-go/document"
)

func DetectDMSPath() (string, error) {
	return config.LocateDMSConfig()
}

func DetectGreeterGroup() string {
	data, err := os.ReadFile("/etc/group")
	if err != nil {
		fmt.Fprintln(os.Stderr, "⚠ Warning: could not read /etc/group, defaulting to greeter")
		return "greeter"
	}

	if group, found := utils.FindGroupData(string(data), "greeter", "greetd", "_greeter"); found {
		return group
	}

	fmt.Fprintln(os.Stderr, "⚠ Warning: no greeter group found in /etc/group, defaulting to greeter")
	return "greeter"
}

func DetectCompositors() []string {
	var compositors []string

	if utils.CommandExists("niri") {
		compositors = append(compositors, "niri")
	}
	if utils.CommandExists("Hyprland") {
		compositors = append(compositors, "Hyprland")
	}

	return compositors
}

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

// EnsureGreetdInstalled checks if greetd is installed - greetd is a daemon in /usr/sbin on Debian/Ubuntu
func EnsureGreetdInstalled(logFunc func(string), sudoPassword string) error {
	greetdFound := utils.CommandExists("greetd")
	if !greetdFound {
		for _, p := range []string{"/usr/sbin/greetd", "/sbin/greetd"} {
			if _, err := os.Stat(p); err == nil {
				greetdFound = true
				break
			}
		}
	}
	if greetdFound {
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

	case distros.FamilyGentoo:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword,
				"emerge --ask n sys-apps/greetd")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "emerge", "--ask", "n", "sys-apps/greetd")
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

// IsGreeterPackaged returns true if dms-greeter was installed from a system package.
func IsGreeterPackaged() bool {
	if !utils.CommandExists("dms-greeter") {
		return false
	}
	packagedPath := "/usr/share/quickshell/dms-greeter"
	info, err := os.Stat(packagedPath)
	return err == nil && info.IsDir()
}

// HasLegacyLocalGreeterWrapper returns true when a manually installed wrapper exists.
func HasLegacyLocalGreeterWrapper() bool {
	info, err := os.Stat("/usr/local/bin/dms-greeter")
	return err == nil && !info.IsDir()
}

// TryInstallGreeterPackage attempts to install dms-greeter from the distro's official repo.
func TryInstallGreeterPackage(logFunc func(string), sudoPassword string) bool {
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return false
	}
	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return false
	}

	if IsGreeterPackaged() {
		logFunc("✓ dms-greeter package already installed")
		return true
	}

	ctx := context.Background()
	var installCmd *exec.Cmd
	var failHint string

	switch config.Family {
	case distros.FamilyDebian:
		obsSlug := getDebianOBSSlug(osInfo)
		keyURL := fmt.Sprintf("https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/%s/Release.key", obsSlug)
		repoLine := fmt.Sprintf("deb [signed-by=/etc/apt/keyrings/danklinux.gpg] https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/%s/ /", obsSlug)
		failHint = fmt.Sprintf("⚠ dms-greeter install failed. Add OBS repo manually:\ncurl -fsSL %s | sudo gpg --dearmor -o /etc/apt/keyrings/danklinux.gpg\necho '%s' | sudo tee /etc/apt/sources.list.d/danklinux.list\nsudo apt update && sudo apt install dms-greeter", keyURL, repoLine)
		logFunc(fmt.Sprintf("Adding DankLinux OBS repository (%s)...", obsSlug))
		addKeyCmd := exec.CommandContext(ctx, "bash", "-c",
			fmt.Sprintf(`curl -fsSL %s | sudo gpg --dearmor -o /etc/apt/keyrings/danklinux.gpg`, keyURL))
		addKeyCmd.Stdout = os.Stdout
		addKeyCmd.Stderr = os.Stderr
		addKeyCmd.Run()
		addRepoCmd := exec.CommandContext(ctx, "bash", "-c",
			fmt.Sprintf(`echo '%s' | sudo tee /etc/apt/sources.list.d/danklinux.list`, repoLine))
		addRepoCmd.Stdout = os.Stdout
		addRepoCmd.Stderr = os.Stderr
		addRepoCmd.Run()
		exec.CommandContext(ctx, "sudo", "apt-get", "update").Run()
		installCmd = exec.CommandContext(ctx, "sudo", "apt-get", "install", "-y", "dms-greeter")
	case distros.FamilySUSE:
		repoURL := getOpenSUSEOBSRepoURL(osInfo)
		failHint = fmt.Sprintf("⚠ dms-greeter install failed. Add OBS repo manually:\nsudo zypper addrepo %s\nsudo zypper refresh && sudo zypper install dms-greeter", repoURL)
		logFunc("Adding DankLinux OBS repository...")
		addRepoCmd := exec.CommandContext(ctx, "sudo", "zypper", "addrepo", repoURL)
		addRepoCmd.Stdout = os.Stdout
		addRepoCmd.Stderr = os.Stderr
		addRepoCmd.Run()
		exec.CommandContext(ctx, "sudo", "zypper", "refresh").Run()
		installCmd = exec.CommandContext(ctx, "sudo", "zypper", "install", "-y", "dms-greeter")
	case distros.FamilyUbuntu:
		failHint = "⚠ dms-greeter install failed. Add PPA manually: sudo add-apt-repository ppa:avengemedia/danklinux && sudo apt-get update && sudo apt-get install dms-greeter"
		logFunc("Enabling PPA ppa:avengemedia/danklinux...")
		ppacmd := exec.CommandContext(ctx, "sudo", "add-apt-repository", "-y", "ppa:avengemedia/danklinux")
		ppacmd.Stdout = os.Stdout
		ppacmd.Stderr = os.Stderr
		ppacmd.Run()
		exec.CommandContext(ctx, "sudo", "apt-get", "update").Run()
		installCmd = exec.CommandContext(ctx, "sudo", "apt-get", "install", "-y", "dms-greeter")
	case distros.FamilyFedora:
		failHint = "⚠ dms-greeter install failed. Enable COPR manually: sudo dnf copr enable avengemedia/danklinux && sudo dnf install dms-greeter"
		logFunc("Enabling COPR avengemedia/danklinux...")
		coprcmd := exec.CommandContext(ctx, "sudo", "dnf", "copr", "enable", "-y", "avengemedia/danklinux")
		coprcmd.Stdout = os.Stdout
		coprcmd.Stderr = os.Stderr
		coprcmd.Run()
		installCmd = exec.CommandContext(ctx, "sudo", "dnf", "install", "-y", "dms-greeter")
	case distros.FamilyArch:
		aurHelper := ""
		for _, helper := range []string{"paru", "yay"} {
			if _, err := exec.LookPath(helper); err == nil {
				aurHelper = helper
				break
			}
		}
		if aurHelper == "" {
			logFunc("⚠ No AUR helper found (paru/yay). Install greetd-dms-greeter-git from AUR: https://aur.archlinux.org/packages/greetd-dms-greeter-git")
			return false
		}
		failHint = fmt.Sprintf("⚠ dms-greeter install failed. Install from AUR: %s -S greetd-dms-greeter-git", aurHelper)
		installCmd = exec.CommandContext(ctx, aurHelper, "-S", "--noconfirm", "greetd-dms-greeter-git")
	default:
		return false
	}

	logFunc("Installing dms-greeter from official repository...")
	installCmd.Stdout = os.Stdout
	installCmd.Stderr = os.Stderr

	if err := installCmd.Run(); err != nil {
		logFunc(failHint)
		return false
	}

	logFunc("✓ dms-greeter package installed")
	return true
}

// CopyGreeterFiles installs the dms-greeter wrapper and sets up cache directory
func CopyGreeterFiles(dmsPath, compositor string, logFunc func(string), sudoPassword string) error {
	if utils.CommandExists("dms-greeter") {
		logFunc("✓ dms-greeter wrapper already installed")
	} else {
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

	cacheDir := "/var/cache/dms-greeter"
	if err := runSudoCmd(sudoPassword, "mkdir", "-p", cacheDir); err != nil {
		return fmt.Errorf("failed to create cache directory: %w", err)
	}

	group := DetectGreeterGroup()
	owner := fmt.Sprintf("%s:%s", group, group)

	if err := runSudoCmd(sudoPassword, "chown", owner, cacheDir); err != nil {
		return fmt.Errorf("failed to set cache directory owner: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "chmod", "755", cacheDir); err != nil {
		return fmt.Errorf("failed to set cache directory permissions: %w", err)
	}
	logFunc(fmt.Sprintf("✓ Created cache directory %s (owner: %s, permissions: 755)", cacheDir, owner))

	return nil
}

// EnsureACLInstalled installs the acl package (setfacl/getfacl) if not already present
func EnsureACLInstalled(logFunc func(string), sudoPassword string) error {
	if utils.CommandExists("setfacl") {
		return nil
	}

	logFunc("setfacl not found – installing acl package...")

	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return fmt.Errorf("failed to detect OS: %w", err)
	}

	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return fmt.Errorf("unsupported distribution for automatic acl installation: %s", osInfo.Distribution.ID)
	}

	ctx := context.Background()
	var installCmd *exec.Cmd

	switch config.Family {
	case distros.FamilyArch:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword, "pacman -S --needed --noconfirm acl")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "pacman", "-S", "--needed", "--noconfirm", "acl")
		}

	case distros.FamilyFedora:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword, "dnf install -y acl")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "dnf", "install", "-y", "acl")
		}

	case distros.FamilySUSE:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword, "zypper install -y acl")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "zypper", "install", "-y", "acl")
		}

	case distros.FamilyUbuntu, distros.FamilyDebian:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword, "apt-get install -y acl")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "apt-get", "install", "-y", "acl")
		}

	case distros.FamilyGentoo:
		if sudoPassword != "" {
			installCmd = distros.ExecSudoCommand(ctx, sudoPassword, "emerge --ask n sys-fs/acl")
		} else {
			installCmd = exec.CommandContext(ctx, "sudo", "emerge", "--ask", "n", "sys-fs/acl")
		}

	case distros.FamilyNix:
		return fmt.Errorf("on NixOS, please add pkgs.acl to your configuration.nix")

	default:
		return fmt.Errorf("unsupported distribution family for automatic acl installation: %s", config.Family)
	}

	installCmd.Stdout = os.Stdout
	installCmd.Stderr = os.Stderr
	if err := installCmd.Run(); err != nil {
		return fmt.Errorf("failed to install acl: %w", err)
	}

	logFunc("✓ acl package installed")
	return nil
}

// SetupParentDirectoryACLs sets ACLs on parent directories to allow traversal
func SetupParentDirectoryACLs(logFunc func(string), sudoPassword string) error {
	if err := EnsureACLInstalled(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: could not install acl package: %v", err))
		logFunc("  ACL permissions will be skipped; theme sync may not work correctly.")
		return nil
	}
	if !utils.CommandExists("setfacl") {
		// setfacl still not found after install attempt (e.g. unsupported filesystem)
		logFunc("⚠ Warning: setfacl still not available after install attempt; skipping ACL setup.")
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

	owner := DetectGreeterGroup()

	logFunc("\nSetting up parent directory ACLs for greeter user access...")

	for _, dir := range parentDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0o755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", dir.desc, err))
				continue
			}
		}

		if err := runSudoCmd(sudoPassword, "setfacl", "-m", fmt.Sprintf("u:%s:rx", owner), dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set ACL on %s: %v", dir.desc, err))
			logFunc(fmt.Sprintf("  You may need to run manually: setfacl -m u:%s:x %s", owner, dir.path))
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

	group := DetectGreeterGroup()

	// Check if user is already in greeter group
	groupsCmd := exec.Command("groups", currentUser)
	groupsOutput, err := groupsCmd.Output()
	if err == nil && strings.Contains(string(groupsOutput), group) {
		logFunc(fmt.Sprintf("✓ %s is already in %s group", currentUser, group))
	} else {
		if err := runSudoCmd(sudoPassword, "usermod", "-aG", group, currentUser); err != nil {
			return fmt.Errorf("failed to add %s to %s group: %w", currentUser, group, err)
		}
		logFunc(fmt.Sprintf("✓ Added %s to %s group (logout/login required for changes to take effect)", currentUser, group))
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
			if err := os.MkdirAll(dir.path, 0o755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", dir.path, err))
				continue
			}
		}

		if err := runSudoCmd(sudoPassword, "chgrp", "-R", group, dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set group for %s: %v", dir.desc, err))
			continue
		}

		if err := runSudoCmd(sudoPassword, "chmod", "-R", "g+rX", dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set permissions for %s: %v", dir.desc, err))
			continue
		}

		logFunc(fmt.Sprintf("✓ Set group permissions for %s", dir.desc))
	}

	if err := SetupParentDirectoryACLs(logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to setup parent directory ACLs: %w", err)
	}

	return nil
}

func SyncDMSConfigs(dmsPath, compositor string, logFunc func(string), sudoPassword string) error {
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
			if err := os.MkdirAll(sourceDir, 0o755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create directory %s: %v", sourceDir, err))
				continue
			}
		}

		if _, err := os.Stat(link.source); os.IsNotExist(err) {
			if err := os.WriteFile(link.source, []byte("{}"), 0o644); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", link.source, err))
				continue
			}
		}

		_ = runSudoCmd(sudoPassword, "rm", "-f", link.target)

		if err := runSudoCmd(sudoPassword, "ln", "-sf", link.source, link.target); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to create symlink for %s: %v", link.desc, err))
			continue
		}

		logFunc(fmt.Sprintf("✓ Synced %s", link.desc))
	}

	if strings.ToLower(compositor) != "niri" {
		return nil
	}

	if err := syncNiriGreeterConfig(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: Failed to sync niri greeter config: %v", err))
	}

	return nil
}

type niriGreeterSync struct {
	processed   map[string]bool
	nodes       []*document.Node
	inputCount  int
	outputCount int
	cursorCount int
	debugCount  int
	cursorNode  *document.Node
}

func syncNiriGreeterConfig(logFunc func(string), sudoPassword string) error {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return fmt.Errorf("failed to resolve user config directory: %w", err)
	}

	configPath := filepath.Join(configDir, "niri", "config.kdl")
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		logFunc("ℹ Niri config not found; skipping greeter niri sync")
		return nil
	} else if err != nil {
		return fmt.Errorf("failed to stat niri config: %w", err)
	}

	extractor := &niriGreeterSync{
		processed: make(map[string]bool),
	}

	if err := extractor.processFile(configPath); err != nil {
		return err
	}

	if len(extractor.nodes) == 0 {
		logFunc("ℹ No niri input/output sections found; skipping greeter niri sync")
		return nil
	}

	content := extractor.render()
	if strings.TrimSpace(content) == "" {
		logFunc("ℹ No niri input/output content to sync; skipping greeter niri sync")
		return nil
	}

	greeterDir := "/etc/greetd/niri"
	greeterGroup := DetectGreeterGroup()
	if err := runSudoCmd(sudoPassword, "mkdir", "-p", greeterDir); err != nil {
		return fmt.Errorf("failed to create greetd niri directory: %w", err)
	}
	if err := runSudoCmd(sudoPassword, "chown", fmt.Sprintf("root:%s", greeterGroup), greeterDir); err != nil {
		return fmt.Errorf("failed to set greetd niri directory ownership: %w", err)
	}
	if err := runSudoCmd(sudoPassword, "chmod", "755", greeterDir); err != nil {
		return fmt.Errorf("failed to set greetd niri directory permissions: %w", err)
	}

	dmsTemp, err := os.CreateTemp("", "dms-greeter-niri-dms-*.kdl")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(dmsTemp.Name())

	if _, err := dmsTemp.WriteString(content); err != nil {
		_ = dmsTemp.Close()
		return fmt.Errorf("failed to write temp niri config: %w", err)
	}
	if err := dmsTemp.Close(); err != nil {
		return fmt.Errorf("failed to close temp niri config: %w", err)
	}

	dmsPath := filepath.Join(greeterDir, "dms.kdl")
	if err := backupFileIfExists(sudoPassword, dmsPath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup %s: %w", dmsPath, err)
	}
	if err := runSudoCmd(sudoPassword, "install", "-o", "root", "-g", greeterGroup, "-m", "0644", dmsTemp.Name(), dmsPath); err != nil {
		return fmt.Errorf("failed to install greetd niri dms config: %w", err)
	}

	mainContent := fmt.Sprintf("%s\ninclude \"%s\"\n", config.NiriGreeterConfig, dmsPath)
	mainTemp, err := os.CreateTemp("", "dms-greeter-niri-main-*.kdl")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(mainTemp.Name())

	if _, err := mainTemp.WriteString(mainContent); err != nil {
		_ = mainTemp.Close()
		return fmt.Errorf("failed to write temp niri main config: %w", err)
	}
	if err := mainTemp.Close(); err != nil {
		return fmt.Errorf("failed to close temp niri main config: %w", err)
	}

	mainPath := filepath.Join(greeterDir, "config.kdl")
	if err := backupFileIfExists(sudoPassword, mainPath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup %s: %w", mainPath, err)
	}
	if err := runSudoCmd(sudoPassword, "install", "-o", "root", "-g", greeterGroup, "-m", "0644", mainTemp.Name(), mainPath); err != nil {
		return fmt.Errorf("failed to install greetd niri main config: %w", err)
	}

	if err := ensureGreetdNiriConfig(logFunc, sudoPassword, mainPath); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: Failed to update greetd config for niri: %v", err))
	}

	logFunc(fmt.Sprintf("✓ Synced niri greeter config (%d input, %d output, %d cursor, %d debug) to %s", extractor.inputCount, extractor.outputCount, extractor.cursorCount, extractor.debugCount, dmsPath))
	return nil
}

func ensureGreetdNiriConfig(logFunc func(string), sudoPassword string, niriConfigPath string) error {
	configPath := "/etc/greetd/config.toml"
	data, err := os.ReadFile(configPath)
	if os.IsNotExist(err) {
		logFunc("ℹ greetd config not found; skipping niri config wiring")
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to read greetd config: %w", err)
	}

	lines := strings.Split(string(data), "\n")
	updated := false
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "command") {
			continue
		}

		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) != 2 {
			continue
		}

		command := strings.Trim(strings.TrimSpace(parts[1]), "\"")
		if !strings.Contains(command, "dms-greeter") {
			continue
		}
		if !strings.Contains(command, "--command niri") {
			continue
		}
		// Strip existing -C or --config and their arguments
		command = stripConfigFlag(command)

		newCommand := fmt.Sprintf("%s -C %s", command, niriConfigPath)
		idx := strings.Index(line, "command")
		leading := ""
		if idx > 0 {
			leading = line[:idx]
		}
		lines[i] = fmt.Sprintf("%scommand = \"%s\"", leading, newCommand)
		updated = true
		break
	}

	if !updated {
		return nil
	}

	if err := backupFileIfExists(sudoPassword, configPath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup greetd config: %w", err)
	}

	tmpFile, err := os.CreateTemp("", "greetd-config-*.toml")
	if err != nil {
		return fmt.Errorf("failed to create temp greetd config: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(strings.Join(lines, "\n")); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("failed to write temp greetd config: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp greetd config: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "mv", tmpFile.Name(), configPath); err != nil {
		return fmt.Errorf("failed to update greetd config: %w", err)
	}

	logFunc(fmt.Sprintf("✓ Updated greetd config to use niri config %s", niriConfigPath))
	return nil
}

func backupFileIfExists(sudoPassword string, path string, suffix string) error {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}

	backupPath := fmt.Sprintf("%s%s-%s", path, suffix, time.Now().Format("20060102-150405"))
	return runSudoCmd(sudoPassword, "cp", "-p", path, backupPath)
}

func (s *niriGreeterSync) processFile(filePath string) error {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return fmt.Errorf("failed to resolve path %s: %w", filePath, err)
	}

	if s.processed[absPath] {
		return nil
	}
	s.processed[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", absPath, err)
	}

	doc, err := kdl.Parse(strings.NewReader(string(data)))
	if err != nil {
		return fmt.Errorf("failed to parse KDL in %s: %w", absPath, err)
	}

	baseDir := filepath.Dir(absPath)
	for _, node := range doc.Nodes {
		name := node.Name.String()
		switch name {
		case "include":
			if err := s.handleInclude(node, baseDir); err != nil {
				return err
			}
		case "input":
			s.nodes = append(s.nodes, node)
			s.inputCount++
		case "output":
			s.nodes = append(s.nodes, node)
			s.outputCount++
		case "cursor":
			if s.cursorNode == nil {
				s.cursorNode = node
				s.cursorNode.Children = dedupeCursorChildren(s.cursorNode.Children)
				s.nodes = append(s.nodes, node)
				s.cursorCount++
			} else if len(node.Children) > 0 {
				s.cursorNode.Children = mergeCursorChildren(s.cursorNode.Children, node.Children)
			}
		case "debug":
			s.nodes = append(s.nodes, node)
			s.debugCount++
		}
	}

	return nil
}

func mergeCursorChildren(existing []*document.Node, incoming []*document.Node) []*document.Node {
	if len(incoming) == 0 {
		return existing
	}

	indexByName := make(map[string]int, len(existing))
	for i, child := range existing {
		indexByName[child.Name.String()] = i
	}

	for _, child := range incoming {
		name := child.Name.String()
		if idx, ok := indexByName[name]; ok {
			existing[idx] = child
			continue
		}
		indexByName[name] = len(existing)
		existing = append(existing, child)
	}

	return existing
}

func dedupeCursorChildren(children []*document.Node) []*document.Node {
	if len(children) == 0 {
		return children
	}

	var result []*document.Node
	indexByName := make(map[string]int, len(children))
	for _, child := range children {
		name := child.Name.String()
		if idx, ok := indexByName[name]; ok {
			result[idx] = child
			continue
		}
		indexByName[name] = len(result)
		result = append(result, child)
	}

	return result
}

func (s *niriGreeterSync) handleInclude(node *document.Node, baseDir string) error {
	if len(node.Arguments) == 0 {
		return nil
	}

	includePath := strings.Trim(node.Arguments[0].String(), "\"")
	if includePath == "" {
		return nil
	}

	fullPath := includePath
	if !filepath.IsAbs(includePath) {
		fullPath = filepath.Join(baseDir, includePath)
	}

	if _, err := os.Stat(fullPath); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return fmt.Errorf("failed to stat include %s: %w", fullPath, err)
	}

	return s.processFile(fullPath)
}

func (s *niriGreeterSync) render() string {
	if len(s.nodes) == 0 {
		return ""
	}

	var builder strings.Builder
	for _, node := range s.nodes {
		_, _ = node.WriteToOptions(&builder, document.NodeWriteOptions{
			LeadingTrailingSpace: true,
			NameAndType:          true,
			Depth:                0,
			Indent:               []byte("    "),
			IgnoreFlags:          false,
		})
		builder.WriteString("\n")
	}

	return builder.String()
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

	greeterUser := DetectGreeterGroup()

	var configContent string
	if data, err := os.ReadFile(configPath); err == nil {
		configContent = string(data)
	} else {
		configContent = fmt.Sprintf(`[terminal]
vt = 1

[default_session]

user = "%s"
`, greeterUser)
	}

	lines := strings.Split(configContent, "\n")
	var newLines []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "command =") && !strings.HasPrefix(trimmed, "command=") {
			if strings.HasPrefix(trimmed, "user =") || strings.HasPrefix(trimmed, "user=") {
				newLines = append(newLines, fmt.Sprintf(`user = "%s"`, greeterUser))
			} else {
				newLines = append(newLines, line)
			}
		}
	}

	// If dmsPath is empty (packaged greeter), omit -p; wrapper finds /usr/share/quickshell/dms-greeter
	wrapperCmd := "dms-greeter"
	if !utils.CommandExists("dms-greeter") {
		wrapperCmd = "/usr/local/bin/dms-greeter"
	}

	compositorLower := strings.ToLower(compositor)
	var command string
	if dmsPath == "" {
		command = fmt.Sprintf(`command = "%s --command %s"`, wrapperCmd, compositorLower)
	} else {
		command = fmt.Sprintf(`command = "%s --command %s -p %s"`, wrapperCmd, compositorLower, dmsPath)
	}

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
	if err := os.WriteFile(tmpFile, []byte(newConfig), 0o644); err != nil {
		return fmt.Errorf("failed to write temp config: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "mv", tmpFile, configPath); err != nil {
		return fmt.Errorf("failed to move config to /etc/greetd: %w", err)
	}

	cmdDesc := fmt.Sprintf("%s --command %s", wrapperCmd, compositorLower)
	if dmsPath != "" {
		cmdDesc = fmt.Sprintf("%s -p %s", cmdDesc, dmsPath)
	}
	logFunc(fmt.Sprintf("✓ Updated greetd configuration (user: %s, command: %s)", greeterUser, cmdDesc))
	return nil
}

func stripConfigFlag(command string) string {
	for _, flag := range []string{" -C ", " --config "} {
		idx := strings.Index(command, flag)
		if idx == -1 {
			continue
		}

		before := command[:idx]
		after := command[idx+len(flag):]

		switch {
		case strings.HasPrefix(after, `"`):
			if end := strings.Index(after[1:], `"`); end != -1 {
				after = after[end+2:]
			} else {
				after = ""
			}
		default:
			if space := strings.Index(after, " "); space != -1 {
				after = after[space:]
			} else {
				after = ""
			}
		}

		command = strings.TrimSpace(before + after)
	}

	return command
}

// getDebianOBSSlug returns the OBS repository slug for the running Debian version.
func getDebianOBSSlug(osInfo *distros.OSInfo) string {
	versionID := strings.ToLower(osInfo.VersionID)
	codename := strings.ToLower(osInfo.VersionCodename)
	prettyName := strings.ToLower(osInfo.PrettyName)

	if strings.Contains(prettyName, "sid") || strings.Contains(prettyName, "unstable") ||
		codename == "sid" || versionID == "sid" {
		return "Debian_Unstable"
	}
	if versionID == "testing" || codename == "testing" {
		return "Debian_Testing"
	}
	if versionID != "" {
		return "Debian_" + versionID // "Debian_13"
	}
	return "Debian_Unstable"
}

// getOpenSUSEOBSRepoURL returns the OBS .repo file URL for the running openSUSE variant.
func getOpenSUSEOBSRepoURL(osInfo *distros.OSInfo) string {
	const base = "https://download.opensuse.org/repositories/home:AvengeMedia:danklinux"
	var slug string
	switch osInfo.Distribution.ID {
	case "opensuse-leap":
		v := osInfo.VersionID
		if v != "" && !strings.Contains(v, ".") {
			v += ".0" // "16" → "16.0"
		}
		if v == "" {
			v = "16.0"
		}
		slug = v
	case "opensuse-slowroll":
		slug = "openSUSE_Slowroll"
	default: // opensuse-tumbleweed || unknown version
		slug = "openSUSE_Tumbleweed"
	}
	return fmt.Sprintf("%s/%s/home:AvengeMedia:danklinux.repo", base, slug)
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

func checkSystemdEnabled(service string) (string, error) {
	cmd := exec.Command("systemctl", "is-enabled", service)
	output, _ := cmd.Output()
	return strings.TrimSpace(string(output)), nil
}

func DisableConflictingDisplayManagers(sudoPassword string, logFunc func(string)) error {
	conflictingDMs := []string{"gdm", "gdm3", "lightdm", "sddm", "lxdm", "xdm", "cosmic-greeter"}
	for _, dm := range conflictingDMs {
		state, err := checkSystemdEnabled(dm)
		if err != nil || state == "" || state == "not-found" {
			continue
		}
		switch state {
		case "enabled", "enabled-runtime", "static", "indirect", "alias":
			logFunc(fmt.Sprintf("Disabling conflicting display manager: %s", dm))
			if err := runSudoCmd(sudoPassword, "systemctl", "disable", "--now", dm); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Failed to disable %s: %v", dm, err))
			} else {
				logFunc(fmt.Sprintf("✓ Disabled %s", dm))
			}
		}
	}
	return nil
}

// EnableGreetd unmasks and enables greetd, forcing it over any other DM.
func EnableGreetd(sudoPassword string, logFunc func(string)) error {
	state, err := checkSystemdEnabled("greetd")
	if err != nil {
		return fmt.Errorf("failed to check greetd state: %w", err)
	}
	if state == "not-found" {
		return fmt.Errorf("greetd service not found; ensure greetd is installed")
	}
	if state == "masked" || state == "masked-runtime" {
		logFunc("  Unmasking greetd...")
		if err := runSudoCmd(sudoPassword, "systemctl", "unmask", "greetd"); err != nil {
			return fmt.Errorf("failed to unmask greetd: %w", err)
		}
		logFunc("  ✓ Unmasked greetd")
	}
	logFunc("  Enabling greetd service (--force)...")
	if err := runSudoCmd(sudoPassword, "systemctl", "enable", "--force", "greetd"); err != nil {
		return fmt.Errorf("failed to enable greetd: %w", err)
	}
	logFunc("✓ greetd enabled")
	return nil
}

func EnsureGraphicalTarget(sudoPassword string, logFunc func(string)) error {
	cmd := exec.Command("systemctl", "get-default")
	output, err := cmd.Output()
	if err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: could not get default systemd target: %v", err))
		return nil
	}
	current := strings.TrimSpace(string(output))
	if current == "graphical.target" {
		logFunc("✓ Default target is already graphical.target")
		return nil
	}
	logFunc(fmt.Sprintf("  Setting default target to graphical.target (was: %s)...", current))
	if err := runSudoCmd(sudoPassword, "systemctl", "set-default", "graphical.target"); err != nil {
		return fmt.Errorf("failed to set graphical target: %w", err)
	}
	logFunc("✓ Default target set to graphical.target")
	return nil
}

// AutoSetupGreeter performs the full non-interactive greeter setup
func AutoSetupGreeter(compositor, sudoPassword string, logFunc func(string)) error {
	if IsGreeterPackaged() && HasLegacyLocalGreeterWrapper() {
		return fmt.Errorf("legacy manual wrapper detected at /usr/local/bin/dms-greeter; " +
			"remove it before using packaged dms-greeter: sudo rm -f /usr/local/bin/dms-greeter")
	}

	logFunc("Ensuring greetd is installed...")
	if err := EnsureGreetdInstalled(logFunc, sudoPassword); err != nil {
		return fmt.Errorf("greetd install failed: %w", err)
	}

	dmsPath := ""
	if !IsGreeterPackaged() {
		detected, err := DetectDMSPath()
		if err != nil {
			return fmt.Errorf("DMS installation not found: %w", err)
		}
		dmsPath = detected
		logFunc(fmt.Sprintf("✓ Found DMS at: %s", dmsPath))
	} else {
		logFunc("✓ Using packaged dms-greeter (/usr/share/quickshell/dms-greeter)")
	}

	logFunc("Setting up dms-greeter group and permissions...")
	if err := SetupDMSGroup(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: group/permissions setup error: %v", err))
	}

	logFunc("Copying greeter files...")
	if err := CopyGreeterFiles(dmsPath, compositor, logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to copy greeter files: %w", err)
	}

	logFunc("Configuring greetd...")
	greeterPathForConfig := ""
	if !IsGreeterPackaged() {
		greeterPathForConfig = dmsPath
	}
	if err := ConfigureGreetd(greeterPathForConfig, compositor, logFunc, sudoPassword); err != nil {
		return fmt.Errorf("failed to configure greetd: %w", err)
	}

	logFunc("Synchronizing DMS configurations...")
	if err := SyncDMSConfigs(dmsPath, compositor, logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: config sync error: %v", err))
	}

	logFunc("Checking for conflicting display managers...")
	if err := DisableConflictingDisplayManagers(sudoPassword, logFunc); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: %v", err))
	}

	logFunc("Enabling greetd service...")
	if err := EnableGreetd(sudoPassword, logFunc); err != nil {
		return fmt.Errorf("failed to enable greetd: %w", err)
	}

	logFunc("Ensuring graphical.target as default...")
	if err := EnsureGraphicalTarget(sudoPassword, logFunc); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: %v", err))
	}

	logFunc("✓ DMS greeter setup complete")
	return nil
}
