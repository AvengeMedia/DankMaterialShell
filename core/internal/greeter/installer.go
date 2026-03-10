package greeter

import (
	"bufio"
	"context"
	_ "embed"
	"encoding/json"
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

var appArmorProfileData []byte

const appArmorProfileDest = "/etc/apparmor.d/usr.bin.dms-greeter"

const (
	GreeterCacheDir = "/var/cache/dms-greeter"

	GreeterPamManagedBlockStart = "# BEGIN DMS GREETER AUTH (managed by dms greeter sync)"
	GreeterPamManagedBlockEnd   = "# END DMS GREETER AUTH"

	legacyGreeterPamFprintComment = "# DMS greeter fingerprint"
	legacyGreeterPamU2FComment    = "# DMS greeter U2F"
)

var includedPamAuthFiles = []string{"system-auth", "common-auth", "password-auth"}

func DetectDMSPath() (string, error) {
	return config.LocateDMSConfig()
}

// IsNixOS returns true when running on NixOS, which manages PAM configs through
// its module system. The DMS PAM managed block must not be written on NixOS.
func IsNixOS() bool {
	_, err := os.Stat("/etc/NIXOS")
	return err == nil
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

func hasPasswdUser(passwdData, user string) bool {
	prefix := user + ":"
	for line := range strings.SplitSeq(passwdData, "\n") {
		if strings.HasPrefix(line, prefix) {
			return true
		}
	}
	return false
}

func findPasswdUser(passwdData string, candidates ...string) (string, bool) {
	for _, candidate := range candidates {
		if hasPasswdUser(passwdData, candidate) {
			return candidate, true
		}
	}
	return "", false
}

func stripTomlComment(line string) string {
	trimmed := strings.TrimSpace(line)
	if idx := strings.Index(trimmed, "#"); idx >= 0 {
		return strings.TrimSpace(trimmed[:idx])
	}
	return trimmed
}

func parseTomlSection(line string) (string, bool) {
	trimmed := stripTomlComment(line)
	if len(trimmed) < 3 || !strings.HasPrefix(trimmed, "[") || !strings.HasSuffix(trimmed, "]") {
		return "", false
	}
	return strings.TrimSpace(trimmed[1 : len(trimmed)-1]), true
}

func extractDefaultSessionUser(configContent string) string {
	inDefaultSession := false
	for line := range strings.SplitSeq(configContent, "\n") {
		if section, ok := parseTomlSection(line); ok {
			inDefaultSession = section == "default_session"
			continue
		}

		if !inDefaultSession {
			continue
		}

		trimmed := stripTomlComment(line)
		if !strings.HasPrefix(trimmed, "user =") && !strings.HasPrefix(trimmed, "user=") {
			continue
		}

		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) != 2 {
			continue
		}
		user := strings.Trim(strings.TrimSpace(parts[1]), `"`)
		if user != "" {
			return user
		}
	}

	return ""
}

func upsertDefaultSession(configContent, greeterUser, command string) string {
	lines := strings.Split(configContent, "\n")
	var out []string

	inDefaultSession := false
	foundDefaultSession := false
	defaultSessionUserSet := false
	defaultSessionCommandSet := false

	appendDefaultSessionFields := func() {
		if !defaultSessionUserSet {
			out = append(out, fmt.Sprintf(`user = "%s"`, greeterUser))
		}
		if !defaultSessionCommandSet {
			out = append(out, command)
		}
	}

	for _, line := range lines {
		if section, ok := parseTomlSection(line); ok {
			if inDefaultSession {
				appendDefaultSessionFields()
			}

			inDefaultSession = section == "default_session"
			if inDefaultSession {
				foundDefaultSession = true
				defaultSessionUserSet = false
				defaultSessionCommandSet = false
			}

			out = append(out, line)
			continue
		}

		if inDefaultSession {
			trimmed := stripTomlComment(line)
			if strings.HasPrefix(trimmed, "user =") || strings.HasPrefix(trimmed, "user=") {
				out = append(out, fmt.Sprintf(`user = "%s"`, greeterUser))
				defaultSessionUserSet = true
				continue
			}

			if strings.HasPrefix(trimmed, "command =") || strings.HasPrefix(trimmed, "command=") {
				if !defaultSessionCommandSet {
					out = append(out, command)
					defaultSessionCommandSet = true
				}
				continue
			}
		}

		out = append(out, line)
	}

	if inDefaultSession {
		appendDefaultSessionFields()
	}

	if !foundDefaultSession {
		if len(out) > 0 && strings.TrimSpace(out[len(out)-1]) != "" {
			out = append(out, "")
		}
		out = append(out, "[default_session]")
		out = append(out, fmt.Sprintf(`user = "%s"`, greeterUser))
		out = append(out, command)
	}

	return strings.Join(out, "\n")
}

func DetectGreeterUser() string {
	passwdData, err := os.ReadFile("/etc/passwd")
	if err == nil {
		passwdContent := string(passwdData)

		if configData, cfgErr := os.ReadFile("/etc/greetd/config.toml"); cfgErr == nil {
			if configured := extractDefaultSessionUser(string(configData)); configured != "" && hasPasswdUser(passwdContent, configured) {
				return configured
			}
		}

		if user, found := findPasswdUser(passwdContent, "greeter", "greetd", "_greeter"); found {
			return user
		}
	} else {
		fmt.Fprintln(os.Stderr, "⚠ Warning: could not read /etc/passwd, defaulting greeter user to 'greeter'")
	}

	if configData, cfgErr := os.ReadFile("/etc/greetd/config.toml"); cfgErr == nil {
		if configured := extractDefaultSessionUser(string(configData)); configured != "" {
			return configured
		}
	}

	fmt.Fprintln(os.Stderr, "⚠ Warning: no greeter user found, defaulting to 'greeter'")
	return "greeter"
}

func resolveGreeterWrapperPath() string {
	if override := strings.TrimSpace(os.Getenv("DMS_GREETER_WRAPPER_CMD")); override != "" {
		return override
	}

	// Packaged installs only use the official wrapper; never fall back to /usr/local/bin.
	if IsGreeterPackaged() {
		packagedWrapper := "/usr/bin/dms-greeter"
		if info, err := os.Stat(packagedWrapper); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
			return packagedWrapper
		}
		fmt.Fprintln(os.Stderr, "⚠ Warning: packaged dms-greeter detected, but /usr/bin/dms-greeter is missing or not executable")
		return packagedWrapper
	}

	for _, candidate := range []string{"/usr/bin/dms-greeter", "/usr/local/bin/dms-greeter"} {
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() && (info.Mode()&0o111) != 0 {
			return candidate
		}
	}

	if path, err := exec.LookPath("dms-greeter"); err == nil {
		resolved := path
		if realPath, realErr := filepath.EvalSymlinks(path); realErr == nil {
			resolved = realPath
		}
		if strings.HasPrefix(resolved, "/home/") || strings.HasPrefix(resolved, "/tmp/") {
			fmt.Fprintf(os.Stderr, "⚠ Warning: ignoring non-system dms-greeter on PATH: %s\n", path)
		} else {
			return path
		}
	}

	return "/usr/bin/dms-greeter"
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
	if IsGreeterPackaged() {
		logFunc("✓ dms-greeter package already installed")
	} else {
		if dmsPath == "" {
			return fmt.Errorf("dms path is required for manual dms-greeter wrapper installs")
		}

		assetsDir := filepath.Join(dmsPath, "Modules", "Greetd", "assets")
		wrapperSrc := filepath.Join(assetsDir, "dms-greeter")

		if _, err := os.Stat(wrapperSrc); os.IsNotExist(err) {
			return fmt.Errorf("dms-greeter wrapper not found at %s", wrapperSrc)
		}

		wrapperDst := "/usr/local/bin/dms-greeter"
		action := "Installed"
		if info, err := os.Stat(wrapperDst); err == nil && !info.IsDir() {
			action = "Updated"
		}
		if err := runSudoCmd(sudoPassword, "cp", wrapperSrc, wrapperDst); err != nil {
			return fmt.Errorf("failed to copy dms-greeter wrapper: %w", err)
		}
		logFunc(fmt.Sprintf("✓ %s dms-greeter wrapper at %s", action, wrapperDst))

		if err := runSudoCmd(sudoPassword, "chmod", "+x", wrapperDst); err != nil {
			return fmt.Errorf("failed to make wrapper executable: %w", err)
		}

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

	if err := EnsureGreeterCacheDir(logFunc, sudoPassword); err != nil {
		return err
	}

	return nil
}

// EnsureGreeterCacheDir creates /var/cache/dms-greeter with correct ownership if it does not exist.
// It is safe to call multiple times (idempotent) and will repair ownership/mode
// when the directory already exists with stale permissions.
func EnsureGreeterCacheDir(logFunc func(string), sudoPassword string) error {
	cacheDir := GreeterCacheDir
	created := false
	if info, err := os.Stat(cacheDir); err != nil {
		if !os.IsNotExist(err) {
			return fmt.Errorf("failed to stat cache directory: %w", err)
		}
		if err := runSudoCmd(sudoPassword, "mkdir", "-p", cacheDir); err != nil {
			return fmt.Errorf("failed to create cache directory: %w", err)
		}
		created = true
	} else if !info.IsDir() {
		return fmt.Errorf("cache path exists but is not a directory: %s", cacheDir)
	}

	group := DetectGreeterGroup()
	daemonUser := DetectGreeterUser()
	preferredOwner := fmt.Sprintf("%s:%s", daemonUser, group)
	owner := preferredOwner
	if err := runSudoCmd(sudoPassword, "chown", owner, cacheDir); err != nil {
		// Some setups may not have a matching daemon user at this moment; fall back
		// to root:<group> while still allowing group-writable greeter runtime access.
		fallbackOwner := fmt.Sprintf("root:%s", group)
		if fallbackErr := runSudoCmd(sudoPassword, "chown", fallbackOwner, cacheDir); fallbackErr != nil {
			return fmt.Errorf("failed to set cache directory owner (preferred %s: %v; fallback %s: %w)", preferredOwner, err, fallbackOwner, fallbackErr)
		}
		owner = fallbackOwner
	}

	if err := runSudoCmd(sudoPassword, "chmod", "2770", cacheDir); err != nil {
		return fmt.Errorf("failed to set cache directory permissions: %w", err)
	}

	runtimeDirs := []string{
		filepath.Join(cacheDir, ".local"),
		filepath.Join(cacheDir, ".local", "state"),
		filepath.Join(cacheDir, ".local", "share"),
		filepath.Join(cacheDir, ".cache"),
	}
	for _, dir := range runtimeDirs {
		if err := runSudoCmd(sudoPassword, "mkdir", "-p", dir); err != nil {
			return fmt.Errorf("failed to create cache runtime directory %s: %w", dir, err)
		}
		if err := runSudoCmd(sudoPassword, "chown", owner, dir); err != nil {
			return fmt.Errorf("failed to set owner for cache runtime directory %s: %w", dir, err)
		}
		if err := runSudoCmd(sudoPassword, "chmod", "2770", dir); err != nil {
			return fmt.Errorf("failed to set permissions for cache runtime directory %s: %w", dir, err)
		}
	}

	legacyMemoryPath := filepath.Join(cacheDir, "memory.json")
	stateMemoryPath := filepath.Join(cacheDir, ".local", "state", "memory.json")
	if err := ensureGreeterMemoryCompatLink(logFunc, sudoPassword, legacyMemoryPath, stateMemoryPath); err != nil {
		return err
	}

	if isSELinuxEnforcing() && utils.CommandExists("restorecon") {
		if err := runSudoCmd(sudoPassword, "restorecon", "-Rv", cacheDir); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to restore SELinux context for %s: %v", cacheDir, err))
		}
	}

	if created {
		logFunc(fmt.Sprintf("✓ Created cache directory %s (owner: %s, mode: 2770)", cacheDir, owner))
	} else {
		logFunc(fmt.Sprintf("✓ Ensured cache directory %s permissions (owner: %s, mode: 2770)", cacheDir, owner))
	}
	return nil
}

func isSELinuxEnforcing() bool {
	data, err := os.ReadFile("/sys/fs/selinux/enforce")
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(data)) == "1"
}

func ensureGreeterMemoryCompatLink(logFunc func(string), sudoPassword, legacyPath, statePath string) error {
	info, err := os.Lstat(legacyPath)
	if err == nil && info.Mode().IsRegular() {
		if _, stateErr := os.Stat(statePath); os.IsNotExist(stateErr) {
			if copyErr := runSudoCmd(sudoPassword, "cp", "-f", legacyPath, statePath); copyErr != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Failed to migrate legacy greeter memory file to %s: %v", statePath, copyErr))
			}
		}
	}

	if err := runSudoCmd(sudoPassword, "ln", "-sfn", statePath, legacyPath); err != nil {
		return fmt.Errorf("failed to create greeter memory compatibility symlink %s -> %s: %w", legacyPath, statePath, err)
	}

	return nil
}

// IsAppArmorEnabled reports whether AppArmor is active on the running kernel.
func IsAppArmorEnabled() bool {
	data, err := os.ReadFile("/sys/module/apparmor/parameters/enabled")
	if err != nil {
		return false
	}
	return strings.HasPrefix(strings.TrimSpace(strings.ToLower(string(data))), "y")
}

// InstallAppArmorProfile installs the bundled AppArmor profile and reloads it. No-op on NixOS or non-AppArmor systems.
func InstallAppArmorProfile(logFunc func(string), sudoPassword string) error {
	if IsNixOS() {
		logFunc("  ℹ Skipping AppArmor profile on NixOS (manage via security.apparmor.policies)")
		return nil
	}

	if !IsAppArmorEnabled() {
		return nil
	}

	if err := runSudoCmd(sudoPassword, "mkdir", "-p", "/etc/apparmor.d"); err != nil {
		return fmt.Errorf("failed to create /etc/apparmor.d: %w", err)
	}

	tmp, err := os.CreateTemp("", "dms-apparmor-*")
	if err != nil {
		return fmt.Errorf("failed to create temp file for AppArmor profile: %w", err)
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	if _, err := tmp.Write(appArmorProfileData); err != nil {
		tmp.Close()
		return fmt.Errorf("failed to write AppArmor profile: %w", err)
	}
	tmp.Close()

	if err := runSudoCmd(sudoPassword, "cp", tmpPath, appArmorProfileDest); err != nil {
		return fmt.Errorf("failed to install AppArmor profile to %s: %w", appArmorProfileDest, err)
	}
	if err := runSudoCmd(sudoPassword, "chmod", "644", appArmorProfileDest); err != nil {
		return fmt.Errorf("failed to set AppArmor profile permissions: %w", err)
	}

	if utils.CommandExists("apparmor_parser") {
		if err := runSudoCmd(sudoPassword, "apparmor_parser", "-r", appArmorProfileDest); err != nil {
			logFunc(fmt.Sprintf("  ⚠ AppArmor profile installed but reload failed: %v", err))
			logFunc("    Run: sudo apparmor_parser -r " + appArmorProfileDest)
		} else {
			logFunc("  ✓ AppArmor profile installed and loaded (complain mode)")
		}
	} else {
		logFunc("  ✓ AppArmor profile installed at " + appArmorProfileDest)
		logFunc("    apparmor_parser not found — profile will be loaded on next boot")
	}

	return nil
}

// RemoveGreeterPamManagedBlock strips the DMS managed auth block from /etc/pam.d/greetd
func RemoveGreeterPamManagedBlock(logFunc func(string), sudoPassword string) error {
	if IsNixOS() {
		return nil
	}
	const greetdPamPath = "/etc/pam.d/greetd"
	data, err := os.ReadFile(greetdPamPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("failed to read %s: %w", greetdPamPath, err)
	}

	stripped, removed := stripManagedGreeterPamBlock(string(data))
	strippedAgain, removedLegacy := stripLegacyGreeterPamLines(stripped)
	if !removed && !removedLegacy {
		return nil
	}

	tmp, err := os.CreateTemp("", "dms-pam-greetd-*")
	if err != nil {
		return fmt.Errorf("failed to create temp PAM file: %w", err)
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)

	if _, err := tmp.WriteString(strippedAgain); err != nil {
		tmp.Close()
		return fmt.Errorf("failed to write temp PAM file: %w", err)
	}
	tmp.Close()

	if err := runSudoCmd(sudoPassword, "cp", tmpPath, greetdPamPath); err != nil {
		return fmt.Errorf("failed to write PAM config: %w", err)
	}
	if err := runSudoCmd(sudoPassword, "chmod", "644", greetdPamPath); err != nil {
		return fmt.Errorf("failed to set PAM config permissions: %w", err)
	}
	logFunc("  ✓ Removed DMS managed PAM block from " + greetdPamPath)
	return nil
}

// UninstallAppArmorProfile removes the DMS AppArmor profile and reloads AppArmor.
// It is a no-op when AppArmor is not active or the profile does not exist.
func UninstallAppArmorProfile(logFunc func(string), sudoPassword string) error {
	if IsNixOS() {
		return nil
	}
	if _, err := os.Stat("/sys/module/apparmor"); os.IsNotExist(err) {
		return nil
	}
	if _, err := os.Stat(appArmorProfileDest); os.IsNotExist(err) {
		return nil
	}

	if utils.CommandExists("apparmor_parser") {
		_ = runSudoCmd(sudoPassword, "apparmor_parser", "--remove", appArmorProfileDest)
	}
	if err := runSudoCmd(sudoPassword, "rm", "-f", appArmorProfileDest); err != nil {
		return fmt.Errorf("failed to remove AppArmor profile: %w", err)
	}
	logFunc("  ✓ Removed DMS AppArmor profile")
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

	group := DetectGreeterGroup()

	logFunc("\nSetting up parent directory ACLs for greeter user access...")

	for _, dir := range parentDirs {
		if _, err := os.Stat(dir.path); os.IsNotExist(err) {
			if err := os.MkdirAll(dir.path, 0o755); err != nil {
				logFunc(fmt.Sprintf("⚠ Warning: Could not create %s: %v", dir.desc, err))
				continue
			}
		}

		// Group ACL covers daemon users regardless of username (e.g. greetd ≠ greeter on Fedora).
		if err := runSudoCmd(sudoPassword, "setfacl", "-m", fmt.Sprintf("g:%s:rX", group), dir.path); err != nil {
			logFunc(fmt.Sprintf("⚠ Warning: Failed to set ACL on %s: %v", dir.desc, err))
			logFunc(fmt.Sprintf("  You may need to run manually: setfacl -m g:%s:rX %s", group, dir.path))
			continue
		}

		logFunc(fmt.Sprintf("✓ Set ACL on %s", dir.desc))
	}

	return nil
}

// RemediateStaleACLs removes user-based ACLs left by older binary versions. Best-effort.
func RemediateStaleACLs(logFunc func(string), sudoPassword string) {
	if !utils.CommandExists("setfacl") {
		return
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return
	}

	passwdData, err := os.ReadFile("/etc/passwd")
	if err != nil {
		return
	}

	dirs := []string{
		homeDir,
		filepath.Join(homeDir, ".config"),
		filepath.Join(homeDir, ".config", "DankMaterialShell"),
		filepath.Join(homeDir, ".cache"),
		filepath.Join(homeDir, ".cache", "DankMaterialShell"),
		filepath.Join(homeDir, ".local"),
		filepath.Join(homeDir, ".local", "state"),
		filepath.Join(homeDir, ".local", "share"),
	}

	passwdContent := string(passwdData)
	staleUsers := []string{"greeter", "greetd", "_greeter"}
	existingUsers := make([]string, 0, len(staleUsers))
	for _, user := range staleUsers {
		if hasPasswdUser(passwdContent, user) {
			existingUsers = append(existingUsers, user)
		}
	}
	if len(existingUsers) == 0 {
		return
	}

	cleaned := false
	for _, dir := range dirs {
		if _, err := os.Stat(dir); err != nil {
			continue
		}
		for _, user := range existingUsers {
			_ = runSudoCmd(sudoPassword, "setfacl", "-x", fmt.Sprintf("u:%s", user), dir)
			cleaned = true
		}
	}
	if cleaned {
		logFunc("✓ Cleaned up stale user-based ACLs from previous versions")
	}
}

// RemediateStaleAppArmor removes any AppArmor profile installed by an older binary on
// systems where AppArmor is not active.
func RemediateStaleAppArmor(logFunc func(string), sudoPassword string) {
	if IsAppArmorEnabled() {
		return
	}
	if _, err := os.Stat(appArmorProfileDest); os.IsNotExist(err) {
		return
	}
	logFunc("ℹ Removing stale AppArmor profile (AppArmor is not active on this system)")
	_ = UninstallAppArmorProfile(logFunc, sudoPassword)
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

	// Create the group if it doesn't exist yet (e.g. before greetd package is installed).
	if !utils.HasGroup(group) {
		if err := runSudoCmd(sudoPassword, "groupadd", "-r", group); err != nil {
			return fmt.Errorf("failed to create %s group: %w", group, err)
		}
		logFunc(fmt.Sprintf("✓ Created system group %s", group))
	}

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

	// Also add the daemon user (e.g. greetd on Fedora) so group ACLs apply to the running process.
	daemonUser := DetectGreeterUser()
	if daemonUser != currentUser {
		daemonGroupsCmd := exec.Command("groups", daemonUser)
		daemonGroupsOutput, daemonGroupsErr := daemonGroupsCmd.Output()
		if daemonGroupsErr == nil {
			if strings.Contains(string(daemonGroupsOutput), group) {
				logFunc(fmt.Sprintf("✓ Greeter daemon user %s is already in %s group", daemonUser, group))
			} else {
				if err := runSudoCmd(sudoPassword, "usermod", "-aG", group, daemonUser); err != nil {
					logFunc(fmt.Sprintf("⚠ Warning: could not add %s to %s group: %v", daemonUser, group, err))
				} else {
					logFunc(fmt.Sprintf("✓ Added greeter daemon user %s to %s group", daemonUser, group))
				}
			}
		}
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

func SyncDMSConfigs(dmsPath, compositor string, logFunc func(string), sudoPassword string, forceAuth bool) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	cacheDir := GreeterCacheDir

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
				return fmt.Errorf("failed to create source directory %s for %s: %w", sourceDir, link.desc, err)
			}
		}

		if _, err := os.Stat(link.source); os.IsNotExist(err) {
			if err := os.WriteFile(link.source, []byte("{}"), 0o644); err != nil {
				return fmt.Errorf("failed to create source file %s for %s: %w", link.source, link.desc, err)
			}
		}

		_ = runSudoCmd(sudoPassword, "rm", "-f", link.target)

		if err := runSudoCmd(sudoPassword, "ln", "-sf", link.source, link.target); err != nil {
			return fmt.Errorf("failed to create symlink for %s (%s -> %s): %w", link.desc, link.target, link.source, err)
		}

		logFunc(fmt.Sprintf("✓ Synced %s", link.desc))
	}

	if err := syncGreeterWallpaperOverride(homeDir, cacheDir, logFunc, sudoPassword); err != nil {
		return fmt.Errorf("greeter wallpaper override sync failed: %w", err)
	}

	if err := syncGreeterPamConfig(homeDir, logFunc, sudoPassword, forceAuth); err != nil {
		return fmt.Errorf("greeter PAM config sync failed: %w", err)
	}

	if strings.ToLower(compositor) != "niri" {
		return nil
	}

	if err := syncNiriGreeterConfig(logFunc, sudoPassword); err != nil {
		logFunc(fmt.Sprintf("⚠ Warning: Failed to sync niri greeter config: %v", err))
	}

	return nil
}

func syncGreeterWallpaperOverride(homeDir, cacheDir string, logFunc func(string), sudoPassword string) error {
	settingsPath := filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json")
	data, err := os.ReadFile(settingsPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("failed to read settings at %s: %w", settingsPath, err)
	}
	var settings struct {
		GreeterWallpaperPath string `json:"greeterWallpaperPath"`
	}
	if err := json.Unmarshal(data, &settings); err != nil {
		return fmt.Errorf("failed to parse settings at %s: %w", settingsPath, err)
	}
	destPath := filepath.Join(cacheDir, "greeter_wallpaper_override.jpg")
	if settings.GreeterWallpaperPath == "" {
		if err := runSudoCmd(sudoPassword, "rm", "-f", destPath); err != nil {
			return fmt.Errorf("failed to clear override file %s: %w", destPath, err)
		}
		logFunc("✓ Cleared greeter wallpaper override")
		return nil
	}
	if err := runSudoCmd(sudoPassword, "rm", "-f", destPath); err != nil {
		return fmt.Errorf("failed to remove old override file %s: %w", destPath, err)
	}
	src := settings.GreeterWallpaperPath
	if !filepath.IsAbs(src) {
		src = filepath.Join(homeDir, src)
	}
	st, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("configured greeter wallpaper not found at %s: %w", src, err)
	}
	if st.IsDir() {
		return fmt.Errorf("configured greeter wallpaper path points to a directory: %s", src)
	}
	if err := runSudoCmd(sudoPassword, "cp", src, destPath); err != nil {
		return fmt.Errorf("failed to copy override wallpaper to %s: %w", destPath, err)
	}
	greeterGroup := DetectGreeterGroup()
	daemonUser := DetectGreeterUser()
	if err := runSudoCmd(sudoPassword, "chown", daemonUser+":"+greeterGroup, destPath); err != nil {
		if fallbackErr := runSudoCmd(sudoPassword, "chown", "root:"+greeterGroup, destPath); fallbackErr != nil {
			return fmt.Errorf("failed to set override ownership on %s: %w", destPath, err)
		}
	}
	if err := runSudoCmd(sudoPassword, "chmod", "644", destPath); err != nil {
		return fmt.Errorf("failed to set override permissions on %s: %w", destPath, err)
	}
	logFunc("✓ Synced greeter wallpaper override")
	return nil
}

func pamModuleExists(module string) bool {
	for _, libDir := range []string{
		"/usr/lib64/security",
		"/usr/lib/security",
		"/lib/x86_64-linux-gnu/security",
		"/usr/lib/x86_64-linux-gnu/security",
		"/usr/lib/aarch64-linux-gnu/security",
	} {
		if _, err := os.Stat(filepath.Join(libDir, module)); err == nil {
			return true
		}
	}
	return false
}

func stripManagedGreeterPamBlock(content string) (string, bool) {
	lines := strings.Split(content, "\n")
	filtered := make([]string, 0, len(lines))
	inManagedBlock := false
	removed := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == GreeterPamManagedBlockStart {
			inManagedBlock = true
			removed = true
			continue
		}
		if trimmed == GreeterPamManagedBlockEnd {
			inManagedBlock = false
			removed = true
			continue
		}
		if inManagedBlock {
			removed = true
			continue
		}
		filtered = append(filtered, line)
	}

	return strings.Join(filtered, "\n"), removed
}

func stripLegacyGreeterPamLines(content string) (string, bool) {
	lines := strings.Split(content, "\n")
	filtered := make([]string, 0, len(lines))
	removed := false

	for i := 0; i < len(lines); i++ {
		trimmed := strings.TrimSpace(lines[i])
		if strings.HasPrefix(trimmed, legacyGreeterPamFprintComment) || strings.HasPrefix(trimmed, legacyGreeterPamU2FComment) {
			removed = true
			if i+1 < len(lines) {
				nextLine := strings.TrimSpace(lines[i+1])
				if strings.HasPrefix(nextLine, "auth") &&
					(strings.Contains(nextLine, "pam_fprintd") || strings.Contains(nextLine, "pam_u2f")) {
					i++
				}
			}
			continue
		}
		filtered = append(filtered, lines[i])
	}

	return strings.Join(filtered, "\n"), removed
}

func insertManagedGreeterPamBlock(content string, blockLines []string, greetdPamPath string) (string, error) {
	lines := strings.Split(content, "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed != "" && !strings.HasPrefix(trimmed, "#") && strings.HasPrefix(trimmed, "auth") {
			block := strings.Join(blockLines, "\n")
			prefix := strings.Join(lines[:i], "\n")
			suffix := strings.Join(lines[i:], "\n")
			switch {
			case prefix == "":
				return block + "\n" + suffix, nil
			case suffix == "":
				return prefix + "\n" + block, nil
			default:
				return prefix + "\n" + block + "\n" + suffix, nil
			}
		}
	}
	return "", fmt.Errorf("no auth directive found in %s", greetdPamPath)
}

func PamTextIncludesFile(pamText, filename string) bool {
	lines := strings.Split(pamText, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		if strings.Contains(trimmed, filename) &&
			(strings.Contains(trimmed, "include") || strings.Contains(trimmed, "substack") || strings.HasPrefix(trimmed, "@include")) {
			return true
		}
	}
	return false
}

func PamFileHasModule(pamFilePath, module string) bool {
	data, err := os.ReadFile(pamFilePath)
	if err != nil {
		return false
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		if strings.Contains(trimmed, module) {
			return true
		}
	}
	return false
}

func DetectIncludedPamModule(pamText, module string) string {
	for _, includedFile := range includedPamAuthFiles {
		if PamTextIncludesFile(pamText, includedFile) && PamFileHasModule("/etc/pam.d/"+includedFile, module) {
			return includedFile
		}
	}
	return ""
}

type greeterAuthSettings struct {
	GreeterEnableFprint bool `json:"greeterEnableFprint"`
	GreeterEnableU2f    bool `json:"greeterEnableU2f"`
}

func readGreeterAuthSettings(homeDir string) (greeterAuthSettings, error) {
	settingsPath := filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json")
	data, err := os.ReadFile(settingsPath)
	if err != nil {
		if os.IsNotExist(err) {
			return greeterAuthSettings{}, nil
		}
		return greeterAuthSettings{}, fmt.Errorf("failed to read settings at %s: %w", settingsPath, err)
	}
	if strings.TrimSpace(string(data)) == "" {
		return greeterAuthSettings{}, nil
	}
	var settings greeterAuthSettings
	if err := json.Unmarshal(data, &settings); err != nil {
		return greeterAuthSettings{}, fmt.Errorf("failed to parse settings at %s: %w", settingsPath, err)
	}
	return settings, nil
}

func ReadGreeterAuthToggles(homeDir string) (enableFprint bool, enableU2f bool, err error) {
	settings, err := readGreeterAuthSettings(homeDir)
	if err != nil {
		return false, false, err
	}
	return settings.GreeterEnableFprint, settings.GreeterEnableU2f, nil
}

func hasEnrolledFingerprintOutput(output string) bool {
	lower := strings.ToLower(output)
	if strings.Contains(lower, "no fingers enrolled") ||
		strings.Contains(lower, "no fingerprints enrolled") ||
		strings.Contains(lower, "no prints enrolled") {
		return false
	}
	if strings.Contains(lower, "has fingers enrolled") ||
		strings.Contains(lower, "has fingerprints enrolled") {
		return true
	}
	for _, line := range strings.Split(lower, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "finger:") {
			return true
		}
		if strings.HasPrefix(trimmed, "- ") && strings.Contains(trimmed, "finger") {
			return true
		}
	}
	return false
}

func FingerprintAuthAvailableForUser(username string) bool {
	username = strings.TrimSpace(username)
	if username == "" {
		return false
	}
	if !pamModuleExists("pam_fprintd.so") {
		return false
	}
	if _, err := exec.LookPath("fprintd-list"); err != nil {
		return false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "fprintd-list", username).CombinedOutput()
	if err != nil {
		return false
	}
	return hasEnrolledFingerprintOutput(string(out))
}

func FingerprintAuthAvailableForCurrentUser() bool {
	username := strings.TrimSpace(os.Getenv("SUDO_USER"))
	if username == "" {
		username = strings.TrimSpace(os.Getenv("USER"))
	}
	if username == "" {
		out, err := exec.Command("id", "-un").Output()
		if err == nil {
			username = strings.TrimSpace(string(out))
		}
	}
	return FingerprintAuthAvailableForUser(username)
}

func pamManagerHintForCurrentDistro() string {
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return "Disable it in your PAM manager (authselect/pam-auth-update) or in the included PAM stack to force password-only greeter login."
	}
	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return "Disable it in your PAM manager (authselect/pam-auth-update) or in the included PAM stack to force password-only greeter login."
	}

	switch config.Family {
	case distros.FamilyFedora:
		return "Disable it in authselect to force password-only greeter login."
	case distros.FamilyDebian, distros.FamilyUbuntu:
		return "Disable it in pam-auth-update to force password-only greeter login."
	default:
		return "Disable it in your distro PAM manager (authselect/pam-auth-update) or in the included PAM stack to force password-only greeter login."
	}
}

func syncGreeterPamConfig(homeDir string, logFunc func(string), sudoPassword string, forceAuth bool) error {
	var wantFprint, wantU2f bool
	fprintToggleEnabled := forceAuth
	u2fToggleEnabled := forceAuth
	if forceAuth {
		wantFprint = pamModuleExists("pam_fprintd.so")
		wantU2f = pamModuleExists("pam_u2f.so")
	} else {
		settings, err := readGreeterAuthSettings(homeDir)
		if err != nil {
			return err
		}
		fprintToggleEnabled = settings.GreeterEnableFprint
		u2fToggleEnabled = settings.GreeterEnableU2f
		fprintModule := pamModuleExists("pam_fprintd.so")
		u2fModule := pamModuleExists("pam_u2f.so")
		wantFprint = settings.GreeterEnableFprint && fprintModule
		wantU2f = settings.GreeterEnableU2f && u2fModule
		if settings.GreeterEnableFprint && !fprintModule {
			logFunc("⚠ Warning: greeter fingerprint toggle is enabled, but pam_fprintd.so was not found.")
		}
		if settings.GreeterEnableU2f && !u2fModule {
			logFunc("⚠ Warning: greeter security key toggle is enabled, but pam_u2f.so was not found.")
		}
	}

	if IsNixOS() {
		logFunc("ℹ NixOS detected: PAM config is managed by NixOS modules. Skipping DMS PAM block write.")
		logFunc("  Configure fingerprint/U2F auth via your greetd NixOS module options (e.g. security.pam.services.greetd).")
		return nil
	}

	greetdPamPath := "/etc/pam.d/greetd"
	pamData, err := os.ReadFile(greetdPamPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", greetdPamPath, err)
	}
	originalContent := string(pamData)
	content, _ := stripManagedGreeterPamBlock(originalContent)
	content, _ = stripLegacyGreeterPamLines(content)

	includedFprintFile := DetectIncludedPamModule(content, "pam_fprintd.so")
	includedU2fFile := DetectIncludedPamModule(content, "pam_u2f.so")
	fprintAvailableForCurrentUser := FingerprintAuthAvailableForCurrentUser()
	if wantFprint && includedFprintFile != "" {
		logFunc("⚠ pam_fprintd already present in included " + includedFprintFile + " (managed by authselect/pam-auth-update). Skipping DMS fprint block to avoid double-fingerprint auth.")
		wantFprint = false
	}
	if wantU2f && includedU2fFile != "" {
		logFunc("⚠ pam_u2f already present in included " + includedU2fFile + " (managed by authselect/pam-auth-update). Skipping DMS U2F block to avoid double security-key auth.")
		wantU2f = false
	}
	if !wantFprint && includedFprintFile != "" {
		if fprintToggleEnabled {
			logFunc("ℹ Fingerprint auth is still enabled via included " + includedFprintFile + ".")
			if fprintAvailableForCurrentUser {
				logFunc("  DMS toggle is enabled, and effective auth is provided by the included PAM stack.")
			} else {
				logFunc("  No enrolled fingerprints detected for the current user; password auth remains the effective path.")
			}
		} else {
			if fprintAvailableForCurrentUser {
				logFunc("ℹ Fingerprint auth is active via included " + includedFprintFile + " while DMS fingerprint toggle is off.")
				logFunc("  Password login will work but may be delayed while the fingerprint module runs first.")
				logFunc("  To eliminate the delay, " + pamManagerHintForCurrentDistro())
			} else {
				logFunc("ℹ pam_fprintd is present via included " + includedFprintFile + ", but no enrolled fingerprints were detected for the current user.")
				logFunc("  Password auth remains the effective login path.")
			}
		}
	}
	if !wantU2f && includedU2fFile != "" {
		if u2fToggleEnabled {
			logFunc("ℹ Security-key auth is still enabled via included " + includedU2fFile + ".")
			logFunc("  DMS toggle is enabled, but effective auth is provided by the included PAM stack.")
		} else {
			logFunc("⚠ Security-key auth is active via included " + includedU2fFile + " while DMS security-key toggle is off.")
			logFunc("  " + pamManagerHintForCurrentDistro())
		}
	}

	if wantFprint || wantU2f {
		blockLines := []string{GreeterPamManagedBlockStart}
		if wantFprint {
			blockLines = append(blockLines, "auth sufficient pam_fprintd.so max-tries=1 timeout=5")
		}
		if wantU2f {
			blockLines = append(blockLines, "auth sufficient pam_u2f.so cue nouserok timeout=10")
		}
		blockLines = append(blockLines, GreeterPamManagedBlockEnd)

		content, err = insertManagedGreeterPamBlock(content, blockLines, greetdPamPath)
		if err != nil {
			return err
		}
	}

	if content == originalContent {
		return nil
	}

	tmpFile, err := os.CreateTemp("", "greetd-pam-*.conf")
	if err != nil {
		return err
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)
	if _, err := tmpFile.WriteString(content); err != nil {
		tmpFile.Close()
		return err
	}
	if err := tmpFile.Close(); err != nil {
		return err
	}
	if err := runSudoCmd(sudoPassword, "cp", tmpPath, greetdPamPath); err != nil {
		return fmt.Errorf("failed to install updated PAM config at %s: %w", greetdPamPath, err)
	}
	if err := runSudoCmd(sudoPassword, "chmod", "644", greetdPamPath); err != nil {
		return fmt.Errorf("failed to set permissions on %s: %w", greetdPamPath, err)
	}
	if wantFprint || wantU2f {
		logFunc("✓ Configured greetd PAM for fingerprint/U2F")
	} else {
		logFunc("✓ Cleared DMS-managed greeter PAM auth block")
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
	inputNode   *document.Node
	outputNodes map[string]*document.Node
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
		processed:   make(map[string]bool),
		outputNodes: make(map[string]*document.Node),
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
		command = stripConfigFlag(command)
		command = stripCacheDirFlag(command)
		command = strings.TrimSpace(command + " --cache-dir " + GreeterCacheDir)

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
	if err := runSudoCmd(sudoPassword, "cp", path, backupPath); err != nil {
		return err
	}
	return runSudoCmd(sudoPassword, "chmod", "644", backupPath)
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
			if s.inputNode == nil {
				s.inputNode = node
				s.inputNode.Children = dedupeCursorChildren(s.inputNode.Children)
				s.nodes = append(s.nodes, node)
			} else if len(node.Children) > 0 {
				s.inputNode.Children = mergeInputChildren(s.inputNode.Children, node.Children)
			}
			s.inputCount++
		case "output":
			key := outputNodeKey(node)
			if existing, ok := s.outputNodes[key]; ok {
				*existing = *node
			} else {
				s.outputNodes[key] = node
				s.nodes = append(s.nodes, node)
			}
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

func mergeInputChildren(existing []*document.Node, incoming []*document.Node) []*document.Node {
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

func outputNodeKey(node *document.Node) string {
	if len(node.Arguments) > 0 {
		return strings.Trim(node.Arguments[0].String(), "\"")
	}
	return ""
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

	backupPath := fmt.Sprintf("%s.backup-%s", configPath, time.Now().Format("20060102-150405"))
	if err := backupFileIfExists(sudoPassword, configPath, ".backup"); err != nil {
		return fmt.Errorf("failed to backup greetd config: %w", err)
	}
	if _, err := os.Stat(configPath); err == nil {
		logFunc(fmt.Sprintf("✓ Backed up existing config to %s", backupPath))
	}

	greeterUser := DetectGreeterUser()

	var configContent string
	if data, err := os.ReadFile(configPath); err == nil {
		configContent = string(data)
	} else if os.IsNotExist(err) {
		configContent = `[terminal]
vt = 1

[default_session]
`
	} else {
		return fmt.Errorf("failed to read greetd config: %w", err)
	}

	wrapperCmd := resolveGreeterWrapperPath()

	// Build command based on compositor and dms path
	// When dmsPath is empty (packaged greeter), omit -p; wrapper finds /usr/share/quickshell/dms-greeter
	compositorLower := strings.ToLower(compositor)
	commandValue := fmt.Sprintf("%s --command %s --cache-dir %s", wrapperCmd, compositorLower, GreeterCacheDir)
	if dmsPath != "" {
		commandValue = fmt.Sprintf("%s -p %s", commandValue, dmsPath)
	}

	commandLine := fmt.Sprintf(`command = "%s"`, commandValue)
	newConfig := upsertDefaultSession(configContent, greeterUser, commandLine)

	tmpFile, err := os.CreateTemp("", "greetd-config-*.toml")
	if err != nil {
		return fmt.Errorf("failed to create temp greetd config: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(newConfig); err != nil {
		_ = tmpFile.Close()
		return fmt.Errorf("failed to write temp greetd config: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return fmt.Errorf("failed to close temp greetd config: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "mkdir", "-p", "/etc/greetd"); err != nil {
		return fmt.Errorf("failed to create /etc/greetd: %w", err)
	}

	if err := runSudoCmd(sudoPassword, "install", "-o", "root", "-g", "root", "-m", "0644", tmpFile.Name(), configPath); err != nil {
		return fmt.Errorf("failed to install greetd config: %w", err)
	}

	logFunc(fmt.Sprintf("✓ Updated greetd configuration (user: %s, command: %s)", greeterUser, commandValue))
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

func stripCacheDirFlag(command string) string {
	fields := strings.Fields(command)
	if len(fields) == 0 {
		return strings.TrimSpace(command)
	}

	filtered := make([]string, 0, len(fields))
	for i := 0; i < len(fields); i++ {
		token := fields[i]
		if token == "--cache-dir" {
			if i+1 < len(fields) {
				i++
			}
			continue
		}
		if strings.HasPrefix(token, "--cache-dir=") {
			continue
		}
		filtered = append(filtered, token)
	}

	return strings.Join(filtered, " ")
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
	if err := SyncDMSConfigs(dmsPath, compositor, logFunc, sudoPassword, false); err != nil {
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
