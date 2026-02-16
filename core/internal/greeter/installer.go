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

// DetectDMSPath checks for DMS installation following XDG Base Directory specification
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

// DetectCompositors checks which compositors are installed
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
	if utils.CommandExists("greetd") {
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
	if utils.CommandExists("dms-greeter") {
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

// SetupParentDirectoryACLs sets ACLs on parent directories to allow traversal
func SetupParentDirectoryACLs(logFunc func(string), sudoPassword string) error {
	if !utils.CommandExists("setfacl") {
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

	owner := DetectGreeterGroup()

	logFunc("\nSetting up parent directory ACLs for greeter user access...")

	for _, dir := range parentDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0o755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", dir.desc, err))
				continue
			}
		}

		// Set ACL to allow greeter user read+execute permission (for session discovery)
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
		// Add current user to greeter group for file access permissions
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

	// Set up ACLs on parent directories to allow greeter user traversal
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

		runSudoCmd(sudoPassword, "rm", "-f", link.target) //nolint:errcheck

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

	// Determine wrapper command path
	wrapperCmd := "dms-greeter"
	if !utils.CommandExists("dms-greeter") {
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
	if err := os.WriteFile(tmpFile, []byte(newConfig), 0o644); err != nil {
		return fmt.Errorf("failed to write temp config: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "mv", tmpFile, configPath); err != nil {
		return fmt.Errorf("failed to move config to /etc/greetd: %w", err)
	}

	logFunc(fmt.Sprintf("✓ Updated greetd configuration (user: %s, command: %s --command %s -p %s)", greeterUser, wrapperCmd, compositorLower, dmsPath))
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
