package greeter

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

var monitorWallpaperSanitizer = regexp.MustCompile(`[^a-zA-Z0-9]+`)

func userGreeterCacheDir(cacheDir, username string) string {
	return filepath.Join(cacheDir, "users", username)
}

func isUserOwnedGreeterCacheSlot(path, username string) bool {
	if strings.TrimSpace(username) == "" {
		return false
	}
	userDir, err := filepath.Abs(userGreeterCacheDir(GreeterCacheDir, username))
	if err != nil {
		return false
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return false
	}
	return abs == userDir || strings.HasPrefix(abs, userDir+string(filepath.Separator))
}

func UserIsInGreeterGroup(username string) bool {
	group := DetectGreeterGroup()
	if !utils.HasGroup(group) {
		return false
	}
	groupsCmd := exec.Command("groups", username)
	groupsOutput, err := groupsCmd.Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(groupsOutput), group)
}

func CanSyncOwnUserGreeterProfile(username string) bool {
	currentUser, err := user.Current()
	if err != nil || currentUser.Username != username {
		return false
	}
	if !UserIsInGreeterGroup(username) {
		return false
	}
	usersDir := filepath.Join(GreeterCacheDir, "users")
	if st, err := os.Stat(usersDir); err != nil || !st.IsDir() {
		return false
	}
	testFile := filepath.Join(usersDir, ".write-test-"+username)
	file, err := os.OpenFile(testFile, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o660)
	if err != nil {
		return false
	}
	_ = file.Close()
	_ = os.Remove(testFile)
	return true
}

func GreeterProfileSyncReady() bool {
	if command := readGreeterSessionCommand(); command != "" && strings.Contains(command, "dms-greeter") {
		return true
	}
	usersDir := filepath.Join(GreeterCacheDir, "users")
	st, err := os.Stat(usersDir)
	return err == nil && st.IsDir()
}

func readGreeterSessionCommand() string {
	data, err := os.ReadFile("/etc/greetd/config.toml")
	if err != nil {
		return ""
	}
	inDefaultSession := false
	for line := range strings.SplitSeq(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			inDefaultSession = strings.EqualFold(strings.Trim(trimmed, "[]"), "default_session")
			continue
		}
		if !inDefaultSession {
			continue
		}
		if idx := strings.Index(trimmed, "#"); idx >= 0 {
			trimmed = strings.TrimSpace(trimmed[:idx])
		}
		if !strings.HasPrefix(trimmed, "command") {
			continue
		}
		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) != 2 {
			continue
		}
		command := strings.Trim(strings.TrimSpace(parts[1]), `"`)
		if command != "" {
			return command
		}
	}
	return ""
}

// SyncUserProfileCache writes the current user's theme slot under users/<username>/
// without modifying greetd or other system configuration. Requires membership in the
// greeter group and a prior full greeter setup by an administrator.
func SyncUserProfileCache(logFunc func(string)) error {
	if logFunc == nil {
		logFunc = func(string) {}
	}
	if !GreeterProfileSyncReady() {
		return fmt.Errorf("greeter is not set up on this system yet; an administrator must run 'dms greeter install' or 'dms greeter sync' once first")
	}

	currentUser, err := user.Current()
	if err != nil {
		return fmt.Errorf("failed to resolve current user: %w", err)
	}
	if !CanSyncOwnUserGreeterProfile(currentUser.Username) {
		group := DetectGreeterGroup()
		return fmt.Errorf("cannot sync greeter profile: you must be in the %s group with write access to %s/users\nAsk an administrator to run:\n  sudo usermod -aG %s %s\nThen log out and back in before running:\n  dms greeter sync --profile",
			group, GreeterCacheDir, group, currentUser.Username)
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	state, err := resolveGreeterThemeSyncState(homeDir)
	if err != nil {
		return fmt.Errorf("failed to resolve greeter color source: %w", err)
	}

	if err := syncUserGreeterCacheSlot(homeDir, GreeterCacheDir, currentUser.Username, state, logFunc, userSlotSyncOpts{
		profileOnly: true,
	}); err != nil {
		return err
	}

	logFunc(fmt.Sprintf("  → %s/users/%s/", GreeterCacheDir, currentUser.Username))
	return nil
}

func canWriteUserGreeterCacheSlot(dest, username string) bool {
	return isUserOwnedGreeterCacheSlot(dest, username) && CanSyncOwnUserGreeterProfile(username)
}

type userSlotSyncOpts struct {
	sudoPassword string
	profileOnly  bool
	username     string
}

func (o userSlotSyncOpts) useDirectWrite(dest string) bool {
	if !o.profileOnly {
		return false
	}
	return canWriteUserGreeterCacheSlot(dest, o.username)
}

func isGreeterCachePath(path string) bool {
	abs, err := filepath.Abs(path)
	if err != nil {
		return true
	}
	cacheAbs, err := filepath.Abs(GreeterCacheDir)
	if err != nil {
		return true
	}
	if abs == cacheAbs {
		return true
	}
	return strings.HasPrefix(abs, cacheAbs+string(filepath.Separator))
}

func greeterCacheOwner() string {
	greeterGroup := DetectGreeterGroup()
	daemonUser := DetectGreeterUser()
	return daemonUser + ":" + greeterGroup
}

func ensureGreeterCacheSubdir(dir string, opts userSlotSyncOpts) error {
	if opts.useDirectWrite(dir) {
		if err := os.MkdirAll(dir, 0o770); err != nil {
			return fmt.Errorf("failed to create cache directory %s: %w", dir, err)
		}
		return nil
	}

	if err := privesc.Run(context.Background(), opts.sudoPassword, "mkdir", "-p", dir); err != nil {
		return fmt.Errorf("failed to create cache directory %s: %w", dir, err)
	}

	owner := greeterCacheOwner()
	if err := privesc.Run(context.Background(), opts.sudoPassword, "chown", owner, dir); err != nil {
		if fallbackErr := privesc.Run(context.Background(), opts.sudoPassword, "chown", "root:"+DetectGreeterGroup(), dir); fallbackErr != nil {
			return fmt.Errorf("failed to set ownership on %s: %w", dir, err)
		}
	}
	if err := privesc.Run(context.Background(), opts.sudoPassword, "chmod", "2770", dir); err != nil {
		return fmt.Errorf("failed to set permissions on %s: %w", dir, err)
	}
	return nil
}

func setGreeterCacheFileOwnership(path, sudoPassword string) error {
	owner := greeterCacheOwner()
	if err := privesc.Run(context.Background(), sudoPassword, "chown", owner, path); err != nil {
		if fallbackErr := privesc.Run(context.Background(), sudoPassword, "chown", "root:"+DetectGreeterGroup(), path); fallbackErr != nil {
			return fmt.Errorf("failed to set ownership on %s: %w", path, err)
		}
	}
	if err := privesc.Run(context.Background(), sudoPassword, "chmod", "644", path); err != nil {
		return fmt.Errorf("failed to set permissions on %s: %w", path, err)
	}
	return nil
}

func syncUserGreeterCacheSlot(homeDir, cacheDir, username string, state greeterThemeSyncState, logFunc func(string), opts userSlotSyncOpts) error {
	if strings.TrimSpace(username) == "" {
		return nil
	}
	opts.username = username

	userDir := userGreeterCacheDir(cacheDir, username)
	if err := ensureGreeterCacheSubdir(userDir, opts); err != nil {
		return err
	}

	settingsPath := filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json")
	settingsBytes, err := os.ReadFile(settingsPath)
	if err != nil {
		return fmt.Errorf("failed to read settings for user cache slot: %w", err)
	}

	settingsMap := map[string]any{}
	if strings.TrimSpace(string(settingsBytes)) != "" {
		if err := json.Unmarshal(settingsBytes, &settingsMap); err != nil {
			return fmt.Errorf("failed to parse settings for user cache slot: %w", err)
		}
	}

	if customTheme, ok := settingsMap["customThemeFile"].(string); ok && strings.TrimSpace(customTheme) != "" {
		resolvedTheme := customTheme
		if !filepath.IsAbs(resolvedTheme) {
			resolvedTheme = filepath.Join(homeDir, resolvedTheme)
		}
		if st, statErr := os.Stat(resolvedTheme); statErr == nil && !st.IsDir() {
			destTheme := filepath.Join(userDir, "custom-theme.json")
			if err := copyFileWithPrivesc(resolvedTheme, destTheme, opts); err != nil {
				return err
			}
			settingsMap["customThemeFile"] = destTheme
		}
	}

	settingsBytes, err = json.Marshal(settingsMap)
	if err != nil {
		return fmt.Errorf("failed to marshal settings for user cache slot: %w", err)
	}
	if err := writeFileWithPrivesc(filepath.Join(userDir, "settings.json"), settingsBytes, opts); err != nil {
		return err
	}

	sessionPath := filepath.Join(homeDir, ".local", "state", "DankMaterialShell", "session.json")
	sessionBytes, err := os.ReadFile(sessionPath)
	if err != nil {
		return fmt.Errorf("failed to read session for user cache slot: %w", err)
	}

	sessionMap := map[string]any{}
	if strings.TrimSpace(string(sessionBytes)) != "" {
		if err := json.Unmarshal(sessionBytes, &sessionMap); err != nil {
			return fmt.Errorf("failed to parse session for user cache slot: %w", err)
		}
	}

	if err := localizeSessionWallpapers(sessionMap, userDir, opts); err != nil {
		return err
	}

	sessionBytes, err = json.Marshal(sessionMap)
	if err != nil {
		return fmt.Errorf("failed to marshal session for user cache slot: %w", err)
	}
	if err := writeFileWithPrivesc(filepath.Join(userDir, "session.json"), sessionBytes, opts); err != nil {
		return err
	}

	colorsSource := state.effectiveColorsSource(homeDir)
	if err := copyFileWithPrivesc(colorsSource, filepath.Join(userDir, "colors.json"), opts); err != nil {
		return fmt.Errorf("failed to copy colors for user cache slot: %w", err)
	}

	if err := syncUserProfileImage(homeDir, userDir, opts); err != nil {
		return err
	}

	rootOverride := filepath.Join(cacheDir, "greeter_wallpaper_override.jpg")
	userOverride := filepath.Join(userDir, "greeter_wallpaper_override.jpg")
	if st, statErr := os.Stat(rootOverride); statErr == nil && !st.IsDir() {
		if err := copyFileWithPrivesc(rootOverride, userOverride, opts); err != nil {
			return fmt.Errorf("failed to copy greeter wallpaper override for user cache slot: %w", err)
		}
	} else if opts.useDirectWrite(userOverride) {
		_ = os.Remove(userOverride)
	} else {
		_ = privesc.Run(context.Background(), opts.sudoPassword, "rm", "-f", userOverride)
	}

	logFunc(fmt.Sprintf("✓ Synced per-user greeter cache for %s", username))
	return nil
}

func localizeSessionWallpapers(session map[string]any, userDir string, opts userSlotSyncOpts) error {
	stringKeys := []struct {
		key    string
		prefix string
	}{
		{"wallpaperPath", "wallpaper"},
		{"wallpaperPathLight", "wallpaper-light"},
		{"wallpaperPathDark", "wallpaper-dark"},
	}
	for _, item := range stringKeys {
		if err := localizeWallpaperStringField(session, item.key, userDir, item.prefix, opts); err != nil {
			return err
		}
	}

	mapKeys := []struct {
		key    string
		prefix string
	}{
		{"monitorWallpapers", "wallpaper-monitor"},
		{"monitorWallpapersLight", "wallpaper-monitor-light"},
		{"monitorWallpapersDark", "wallpaper-monitor-dark"},
	}
	for _, item := range mapKeys {
		if err := localizeWallpaperMapField(session, item.key, userDir, item.prefix, opts); err != nil {
			return err
		}
	}

	return nil
}

func localizeWallpaperStringField(session map[string]any, key, userDir, prefix string, opts userSlotSyncOpts) error {
	raw, ok := session[key]
	if !ok {
		return nil
	}
	path, ok := raw.(string)
	if !ok || strings.TrimSpace(path) == "" {
		return nil
	}
	dest, err := copyWallpaperIntoUserCache(path, userDir, prefix, opts)
	if err != nil {
		return err
	}
	if dest != "" {
		session[key] = dest
	}
	return nil
}

func localizeWallpaperMapField(session map[string]any, key, userDir, prefix string, opts userSlotSyncOpts) error {
	raw, ok := session[key]
	if !ok || raw == nil {
		return nil
	}
	values, ok := raw.(map[string]any)
	if !ok {
		return nil
	}
	for monitor, rawPath := range values {
		path, ok := rawPath.(string)
		if !ok || strings.TrimSpace(path) == "" {
			continue
		}
		safeMonitor := monitorWallpaperSanitizer.ReplaceAllString(monitor, "-")
		dest, err := copyWallpaperIntoUserCache(path, userDir, prefix+"-"+safeMonitor, opts)
		if err != nil {
			return err
		}
		if dest != "" {
			values[monitor] = dest
		}
	}
	return nil
}

func copyWallpaperIntoUserCache(srcPath, userDir, prefix string, opts userSlotSyncOpts) (string, error) {
	if strings.TrimSpace(srcPath) == "" {
		return "", nil
	}
	st, err := os.Stat(srcPath)
	if err != nil || st.IsDir() {
		return "", nil
	}
	ext := filepath.Ext(srcPath)
	if ext == "" {
		ext = ".jpg"
	}
	dest := filepath.Join(userDir, prefix+ext)
	if err := copyFileWithPrivesc(srcPath, dest, opts); err != nil {
		return "", err
	}
	return dest, nil
}

func copyFileWithPrivesc(src, dest string, opts userSlotSyncOpts) error {
	if opts.useDirectWrite(dest) {
		if err := os.MkdirAll(filepath.Dir(dest), 0o770); err != nil {
			return fmt.Errorf("failed to create parent dir for %s: %w", dest, err)
		}
		data, err := os.ReadFile(src)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", src, err)
		}
		if err := os.WriteFile(dest, data, 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", dest, err)
		}
		return nil
	}

	if !isGreeterCachePath(dest) {
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return fmt.Errorf("failed to create parent dir for %s: %w", dest, err)
		}
		data, err := os.ReadFile(src)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", src, err)
		}
		if err := os.WriteFile(dest, data, 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", dest, err)
		}
		return nil
	}

	_ = privesc.Run(context.Background(), opts.sudoPassword, "rm", "-f", dest)
	if err := privesc.Run(context.Background(), opts.sudoPassword, "cp", src, dest); err != nil {
		return fmt.Errorf("failed to copy %s to %s: %w", src, dest, err)
	}
	return setGreeterCacheFileOwnership(dest, opts.sudoPassword)
}

func writeFileWithPrivesc(path string, data []byte, opts userSlotSyncOpts) error {
	if opts.useDirectWrite(path) {
		if err := os.MkdirAll(filepath.Dir(path), 0o770); err != nil {
			return fmt.Errorf("failed to create parent dir for %s: %w", path, err)
		}
		if err := os.WriteFile(path, data, 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", path, err)
		}
		return nil
	}

	if !isGreeterCachePath(path) {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			return fmt.Errorf("failed to create parent dir for %s: %w", path, err)
		}
		if err := os.WriteFile(path, data, 0o644); err != nil {
			return fmt.Errorf("failed to write %s: %w", path, err)
		}
		return nil
	}

	tmp, err := os.CreateTemp("", "dms-greeter-user-cache-*")
	if err != nil {
		return fmt.Errorf("failed to create temp file for %s: %w", path, err)
	}
	tmpPath := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		_ = os.Remove(tmpPath)
		return fmt.Errorf("failed to write temp file for %s: %w", path, err)
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("failed to close temp file for %s: %w", path, err)
	}
	defer os.Remove(tmpPath)

	_ = privesc.Run(context.Background(), opts.sudoPassword, "rm", "-f", path)
	if err := privesc.Run(context.Background(), opts.sudoPassword, "cp", tmpPath, path); err != nil {
		return fmt.Errorf("failed to install %s: %w", path, err)
	}
	return setGreeterCacheFileOwnership(path, opts.sudoPassword)
}

func resolveUserProfileImageSource(homeDir string) string {
	candidates := []string{
		filepath.Join(homeDir, ".face"),
		filepath.Join(homeDir, ".face.icon"),
	}
	if homeDir != "" {
		username := filepath.Base(homeDir)
		if username != "" && username != "." && username != string(filepath.Separator) {
			candidates = append([]string{filepath.Join("/var/lib/AccountsService/icons", username)}, candidates...)
		}
	}
	for _, src := range candidates {
		st, err := os.Stat(src)
		if err == nil && !st.IsDir() && st.Size() > 0 {
			return src
		}
	}
	return ""
}

func syncUserProfileImage(homeDir, userDir string, opts userSlotSyncOpts) error {
	for _, name := range []string{"profile.jpg", "profile.jpeg", "profile.png", "profile.webp"} {
		path := filepath.Join(userDir, name)
		if opts.useDirectWrite(path) {
			_ = os.Remove(path)
		} else {
			_ = privesc.Run(context.Background(), opts.sudoPassword, "rm", "-f", path)
		}
	}

	src := resolveUserProfileImageSource(homeDir)
	if src == "" {
		return nil
	}

	ext := filepath.Ext(src)
	if ext == "" {
		ext = ".jpg"
	}
	dest := filepath.Join(userDir, "profile"+ext)
	if err := copyFileWithPrivesc(src, dest, opts); err != nil {
		return fmt.Errorf("failed to copy profile image for user cache slot: %w", err)
	}
	return nil
}
