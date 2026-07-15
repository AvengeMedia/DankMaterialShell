package pam

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/distros"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/privesc"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

const (
	GreeterPamManagedBlockStart = "# BEGIN DMS GREETER AUTH (managed by dms greeter sync)"
	GreeterPamManagedBlockEnd   = "# END DMS GREETER AUTH"

	LockscreenPamManagedBlockStart = "# BEGIN DMS LOCKSCREEN AUTH (managed by dms greeter sync)"
	LockscreenPamManagedBlockEnd   = "# END DMS LOCKSCREEN AUTH"

	LockscreenU2FPamManagedBlockStart = "# BEGIN DMS LOCKSCREEN U2F AUTH (managed by dms auth sync)"
	LockscreenU2FPamManagedBlockEnd   = "# END DMS LOCKSCREEN U2F AUTH"

	legacyGreeterPamFprintComment = "# DMS greeter fingerprint"
	legacyGreeterPamU2FComment    = "# DMS greeter U2F"

	GreetdPamPath       = "/etc/pam.d/greetd"
	DankshellPamPath    = "/etc/pam.d/dankshell"
	DankshellU2FPamPath = "/etc/pam.d/dankshell-u2f"
)

// lockscreenPamEntryCandidates are the /etc/pam.d entry-point services tried in
// order. "login" is first so systems that ship it behave exactly as before; the
// rest cover distros (or minimal installs) with no /etc/pam.d/login.
// lockscreenPamBaseDirs mirrors libpam's search order: /etc overrides, then the
// vendor dir (/usr/lib) and the stateless-distro default (/usr/share).
var lockscreenPamBaseDirs = []string{"/etc/pam.d", "/usr/lib/pam.d", "/usr/share/pam.d"}

// Standalone auth+account services, most universal first. login exists almost
// everywhere (util-linux); system-* cover Fedora/Arch/Gentoo/SUSE-Leap.
var lockscreenPamEntryCandidates = []string{
	"login",
	"system-auth",
	"system-login",
	"system-local-login",
}

// Fallback for distros with no standalone login service, only shared building
// blocks: openSUSE/Debian (common-*), Alpine/postmarketOS (base-*).
var lockscreenPamSharedIncludePairs = []struct {
	auth    string
	account string
}{
	{auth: "common-auth", account: "common-account"},
	{auth: "base-auth", account: "base-account"},
}

var includedPamAuthFiles = []string{
	"system-auth",
	"common-auth",
	"password-auth",
	"system-login",
	"system-local-login",
	"common-auth-pc",
	"login",
}

type AuthSettings struct {
	EnableFprint                bool `json:"enableFprint"`
	EnableU2f                   bool `json:"enableU2f"`
	GreeterEnableFprint         bool `json:"greeterEnableFprint"`
	GreeterEnableU2f            bool `json:"greeterEnableU2f"`
	GreeterPamExternallyManaged bool `json:"greeterPamExternallyManaged"`
}

type SyncAuthOptions struct {
	HomeDir          string
	ForceGreeterAuth bool
}

type syncDeps struct {
	pamDir                             string
	greetdPath                         string
	dankshellPath                      string
	dankshellU2fPath                   string
	isNixOS                            func() bool
	readFile                           func(string) ([]byte, error)
	stat                               func(string) (os.FileInfo, error)
	createTemp                         func(string, string) (*os.File, error)
	removeFile                         func(string) error
	runSudoCmd                         func(string, string, ...string) error
	pamModuleExists                    func(string) bool
	fingerprintAvailableForCurrentUser func() bool
}

type lockscreenPamIncludeDirective struct {
	target     string
	filterType string
}

type lockscreenPamResolver struct {
	baseDirs []string
	readFile func(string) ([]byte, error)
}

// locate resolves a service/include name across baseDirs (libpam vendor-dir
// fallback). Targets may not escape the base dirs.
func (r lockscreenPamResolver) locate(target string) (string, error) {
	target = strings.TrimSpace(target)
	if target == "" {
		return "", fmt.Errorf("empty PAM include target")
	}

	if filepath.IsAbs(target) {
		clean := filepath.Clean(target)
		for _, dir := range r.baseDirs {
			if filepath.Dir(clean) == filepath.Clean(dir) {
				return clean, nil
			}
		}
		return "", fmt.Errorf("unsupported PAM include outside PAM dirs: %s", target)
	}

	clean := filepath.Clean(target)
	if clean == "." || clean == ".." || strings.HasPrefix(clean, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("invalid PAM include target: %s", target)
	}

	var firstErr error
	for _, dir := range r.baseDirs {
		path := filepath.Join(filepath.Clean(dir), clean)
		if _, err := r.readFile(path); err != nil {
			if firstErr == nil {
				firstErr = err
			}
			continue
		}
		return path, nil
	}
	if firstErr == nil {
		firstErr = os.ErrNotExist
	}
	return "", firstErr
}

func defaultSyncDeps() syncDeps {
	return syncDeps{
		pamDir:           "/etc/pam.d",
		greetdPath:       GreetdPamPath,
		dankshellPath:    DankshellPamPath,
		dankshellU2fPath: DankshellU2FPamPath,
		isNixOS:          IsNixOS,
		readFile:         os.ReadFile,
		stat:             os.Stat,
		createTemp:       os.CreateTemp,
		removeFile:       os.Remove,
		runSudoCmd: func(password, command string, args ...string) error {
			return privesc.Run(context.Background(), password, append([]string{command}, args...)...)
		},
		pamModuleExists:                    pamModuleExists,
		fingerprintAvailableForCurrentUser: FingerprintAuthAvailableForCurrentUser,
	}
}

func IsNixOS() bool {
	_, err := os.Stat("/etc/NIXOS")
	return err == nil
}

func ReadAuthSettings(homeDir string) (AuthSettings, error) {
	settingsPath := filepath.Join(homeDir, ".config", "DankMaterialShell", "settings.json")
	data, err := os.ReadFile(settingsPath)
	if err != nil {
		if os.IsNotExist(err) {
			return AuthSettings{}, nil
		}
		return AuthSettings{}, fmt.Errorf("failed to read settings at %s: %w", settingsPath, err)
	}
	if strings.TrimSpace(string(data)) == "" {
		return AuthSettings{}, nil
	}

	var settings AuthSettings
	if err := json.Unmarshal(data, &settings); err != nil {
		return AuthSettings{}, fmt.Errorf("failed to parse settings at %s: %w", settingsPath, err)
	}
	return settings, nil
}

func ReadGreeterAuthToggles(homeDir string) (enableFprint bool, enableU2f bool, err error) {
	settings, err := ReadAuthSettings(homeDir)
	if err != nil {
		return false, false, err
	}
	return settings.GreeterEnableFprint, settings.GreeterEnableU2f, nil
}

func SyncAuthConfig(logFunc func(string), sudoPassword string, options SyncAuthOptions) error {
	return syncAuthConfigWithDeps(logFunc, sudoPassword, options, defaultSyncDeps())
}

func RemoveManagedGreeterPamBlock(logFunc func(string), sudoPassword string) error {
	return removeManagedGreeterPamBlockWithDeps(logFunc, sudoPassword, defaultSyncDeps())
}

func syncAuthConfigWithDeps(logFunc func(string), sudoPassword string, options SyncAuthOptions, deps syncDeps) error {
	homeDir := strings.TrimSpace(options.HomeDir)
	if homeDir == "" {
		var err error
		homeDir, err = os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("failed to get user home directory: %w", err)
		}
	}

	settings, err := ReadAuthSettings(homeDir)
	if err != nil {
		return err
	}

	if err := syncLockscreenPamConfigWithDeps(logFunc, sudoPassword, deps); err != nil {
		return err
	}
	if err := syncLockscreenU2FPamConfigWithDeps(logFunc, sudoPassword, settings.EnableU2f, deps); err != nil {
		return err
	}

	if _, err := deps.stat(deps.greetdPath); err != nil {
		if os.IsNotExist(err) {
			logFunc("ℹ /etc/pam.d/greetd not found. Skipping greeter PAM sync.")
			return nil
		}
		return fmt.Errorf("failed to inspect %s: %w", deps.greetdPath, err)
	}

	if settings.GreeterPamExternallyManaged {
		if err := removeManagedGreeterPamBlockWithDeps(logFunc, sudoPassword, deps); err != nil {
			return err
		}
		logFunc("ℹ /etc/pam.d/greetd is externally managed. Skipping DMS greeter PAM sync.")
		return nil
	}

	if err := syncGreeterPamConfigWithDeps(logFunc, sudoPassword, settings, options.ForceGreeterAuth, deps); err != nil {
		return err
	}

	return nil
}

func removeManagedGreeterPamBlockWithDeps(logFunc func(string), sudoPassword string, deps syncDeps) error {
	if deps.isNixOS() {
		return nil
	}

	data, err := deps.readFile(deps.greetdPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("failed to read %s: %w", deps.greetdPath, err)
	}

	originalContent := string(data)
	stripped, removed := stripManagedGreeterPamBlock(originalContent)
	strippedAgain, removedLegacy := stripLegacyGreeterPamLines(stripped)
	if !removed && !removedLegacy {
		return nil
	}

	if err := writeManagedPamFile(strippedAgain, deps.greetdPath, sudoPassword, deps); err != nil {
		return fmt.Errorf("failed to write %s: %w", deps.greetdPath, err)
	}

	logFunc("✓ Removed DMS managed PAM block from " + deps.greetdPath)
	return nil
}

func ParseManagedGreeterPamAuth(pamText string) (managed bool, fingerprint bool, u2f bool, legacy bool) {
	if pamText == "" {
		return false, false, false, false
	}

	lines := strings.Split(pamText, "\n")
	inManaged := false
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		switch trimmed {
		case GreeterPamManagedBlockStart:
			managed = true
			inManaged = true
			continue
		case GreeterPamManagedBlockEnd:
			inManaged = false
			continue
		}

		if strings.HasPrefix(trimmed, legacyGreeterPamFprintComment) || strings.HasPrefix(trimmed, legacyGreeterPamU2FComment) {
			legacy = true
		}
		if !inManaged {
			continue
		}
		if strings.Contains(trimmed, "pam_fprintd") {
			fingerprint = true
		}
		if strings.Contains(trimmed, "pam_u2f") {
			u2f = true
		}
	}

	return managed, fingerprint, u2f, legacy
}

func StripManagedGreeterPamContent(pamText string) (string, bool) {
	stripped, removed := stripManagedGreeterPamBlock(pamText)
	stripped, removedLegacy := stripLegacyGreeterPamLines(stripped)
	return stripped, removed || removedLegacy
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
	return pamContentHasModule(string(data), module)
}

func DetectIncludedPamModule(pamText, module string) string {
	return detectIncludedPamModule(pamText, module, defaultSyncDeps())
}

func detectIncludedPamModule(pamText, module string, deps syncDeps) string {
	for _, includedFile := range includedPamAuthFiles {
		if !PamTextIncludesFile(pamText, includedFile) {
			continue
		}
		path := filepath.Join(deps.pamDir, includedFile)
		data, err := deps.readFile(path)
		if err != nil {
			continue
		}
		if pamContentHasModule(string(data), module) {
			return includedFile
		}
	}
	return ""
}

func pamContentHasModule(content, module string) bool {
	lines := strings.Split(content, "\n")
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

func hasManagedLockscreenPamFile(content string) bool {
	return strings.Contains(content, LockscreenPamManagedBlockStart) &&
		strings.Contains(content, LockscreenPamManagedBlockEnd)
}

func hasManagedLockscreenU2FPamFile(content string) bool {
	return strings.Contains(content, LockscreenU2FPamManagedBlockStart) &&
		strings.Contains(content, LockscreenU2FPamManagedBlockEnd)
}

func pamDirectiveType(line string) string {
	fields := strings.Fields(line)
	if len(fields) == 0 {
		return ""
	}

	directiveType := strings.TrimPrefix(fields[0], "-")
	switch directiveType {
	case "auth", "account", "password", "session":
		return directiveType
	default:
		return ""
	}
}

func isExcludedLockscreenPamLine(line string) bool {
	for _, field := range strings.Fields(line) {
		if strings.HasPrefix(field, "#") {
			break
		}
		if strings.Contains(field, "pam_u2f") || strings.Contains(field, "pam_fprintd") {
			return true
		}
	}
	return false
}

func parseLockscreenPamIncludeDirective(trimmed string, inheritedFilter string) (lockscreenPamIncludeDirective, bool) {
	fields := strings.Fields(trimmed)
	if len(fields) >= 2 && fields[0] == "@include" {
		return lockscreenPamIncludeDirective{
			target:     fields[1],
			filterType: inheritedFilter,
		}, true
	}

	if len(fields) >= 3 && (fields[1] == "include" || fields[1] == "substack") {
		lineType := pamDirectiveType(trimmed)
		if lineType == "" {
			return lockscreenPamIncludeDirective{}, false
		}
		return lockscreenPamIncludeDirective{
			target:     fields[2],
			filterType: lineType,
		}, true
	}

	if len(fields) >= 3 && fields[1] == "@include" {
		lineType := pamDirectiveType(trimmed)
		if lineType == "" {
			return lockscreenPamIncludeDirective{}, false
		}
		return lockscreenPamIncludeDirective{
			target:     fields[2],
			filterType: lineType,
		}, true
	}

	return lockscreenPamIncludeDirective{}, false
}

func (r lockscreenPamResolver) resolveService(serviceName string, filterType string, stack []string) ([]string, error) {
	path, err := r.locate(serviceName)
	if err != nil {
		return nil, fmt.Errorf("failed to read PAM file %s: %w", serviceName, err)
	}

	for _, seen := range stack {
		if seen == path {
			chain := append(append([]string{}, stack...), path)
			display := make([]string, 0, len(chain))
			for _, item := range chain {
				display = append(display, filepath.Base(item))
			}
			return nil, fmt.Errorf("cyclic PAM include detected: %s", strings.Join(display, " -> "))
		}
	}

	data, err := r.readFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read PAM file %s: %w", path, err)
	}

	var resolved []string
	for _, rawLine := range strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n") {
		rawLine = strings.TrimRight(rawLine, "\r")
		trimmed := strings.TrimSpace(rawLine)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") || trimmed == "#%PAM-1.0" {
			continue
		}

		if include, ok := parseLockscreenPamIncludeDirective(trimmed, filterType); ok {
			lineType := pamDirectiveType(trimmed)
			if filterType != "" && lineType != "" && lineType != filterType {
				continue
			}

			nested, err := r.resolveService(include.target, include.filterType, append(stack, path))
			if err != nil {
				return nil, err
			}
			resolved = append(resolved, nested...)
			continue
		}

		lineType := pamDirectiveType(trimmed)
		if lineType == "" {
			return nil, fmt.Errorf("unsupported PAM directive in %s: %s", filepath.Base(path), trimmed)
		}
		if filterType != "" && lineType != filterType {
			continue
		}
		if isExcludedLockscreenPamLine(trimmed) {
			continue
		}

		resolved = append(resolved, rawLine)
	}

	return resolved, nil
}

func resolvedLinesHaveAuth(lines []string) bool {
	for _, line := range lines {
		if pamDirectiveType(strings.TrimSpace(line)) == "auth" {
			return true
		}
	}
	return false
}

func (r lockscreenPamResolver) resolveLines() ([]string, error) {
	var lastErr error

	// Standalone login-like services: an existing one is authoritative.
	for _, service := range lockscreenPamEntryCandidates {
		if _, err := r.locate(service); err != nil {
			lastErr = err
			continue
		}
		lines, err := r.resolveService(service, "", nil)
		if err != nil {
			return nil, err
		}
		if !resolvedLinesHaveAuth(lines) {
			return nil, fmt.Errorf("no auth directives remained after filtering %s", service)
		}
		return lines, nil
	}

	// Shared building blocks for distros without a login service (openSUSE,
	// Alpine): stitch the auth stanza to the account stanza when present.
	for _, pair := range lockscreenPamSharedIncludePairs {
		if _, err := r.locate(pair.auth); err != nil {
			lastErr = err
			continue
		}
		authLines, err := r.resolveService(pair.auth, "auth", nil)
		if err != nil {
			return nil, err
		}
		if !resolvedLinesHaveAuth(authLines) {
			lastErr = fmt.Errorf("no auth directives remained after filtering %s", pair.auth)
			continue
		}

		resolved := append([]string{}, authLines...)
		if _, err := r.locate(pair.account); err == nil {
			acctLines, err := r.resolveService(pair.account, "account", nil)
			if err != nil {
				return nil, err
			}
			resolved = append(resolved, acctLines...)
		}
		return resolved, nil
	}

	if lastErr != nil {
		return nil, fmt.Errorf("no usable PAM auth service found: %w", lastErr)
	}
	return nil, fmt.Errorf("no usable PAM auth service found")
}

func buildManagedLockscreenPamContent(baseDirs []string, readFile func(string) ([]byte, error)) (string, error) {
	resolver := lockscreenPamResolver{baseDirs: baseDirs, readFile: readFile}

	resolvedLines, err := resolver.resolveLines()
	if err != nil {
		return "", err
	}

	var b strings.Builder
	b.WriteString("#%PAM-1.0\n")
	b.WriteString(LockscreenPamManagedBlockStart + "\n")
	for _, line := range resolvedLines {
		b.WriteString(line)
		b.WriteByte('\n')
	}
	b.WriteString(LockscreenPamManagedBlockEnd + "\n")
	return b.String(), nil
}

var lockscreenPamCandidateServices = []string{
	"login",
	"system-auth",
	"system-login",
	"system-local-login",
	"common-auth",
	"base-auth",
}

type LockscreenPamServiceInfo struct {
	Name              string `json:"name"`
	Dir               string `json:"dir"`
	Path              string `json:"path"`
	HasAuth           bool   `json:"hasAuth"`
	InlineFingerprint bool   `json:"inlineFingerprint"`
	InlineU2f         bool   `json:"inlineU2f"`
}

type LockscreenPamValidation struct {
	Valid             bool     `json:"valid"`
	Path              string   `json:"path"`
	HasAuth           bool     `json:"hasAuth"`
	InlineFingerprint bool     `json:"inlineFingerprint"`
	InlineU2f         bool     `json:"inlineU2f"`
	MissingModules    []string `json:"missingModules"`
	Warnings          []string `json:"warnings"`
	Errors            []string `json:"errors"`
}

type lockscreenPamValidateDeps struct {
	baseDirs        []string
	readFile        func(string) ([]byte, error)
	stat            func(string) (os.FileInfo, error)
	pamModuleExists func(string) bool
}

func defaultValidateDeps() lockscreenPamValidateDeps {
	return lockscreenPamValidateDeps{
		baseDirs:        lockscreenPamBaseDirs,
		readFile:        os.ReadFile,
		stat:            os.Stat,
		pamModuleExists: pamModuleExists,
	}
}

// lockscreenPamAnalysis is a non-destructive walk of a PAM service. Unlike
// resolveService it detects (rather than strips) pam_fprintd/pam_u2f and
// records unknown directives instead of hard-failing on them.
type lockscreenPamAnalysis struct {
	lines             []string
	hasAuth           bool
	inlineFingerprint bool
	inlineU2f         bool
	modules           []string
	unknownDirectives []string
	err               error
}

func (r lockscreenPamResolver) analyzePath(path string) lockscreenPamAnalysis {
	var acc lockscreenPamAnalysis
	if err := r.analyzeInto(filepath.Clean(path), "", nil, &acc); err != nil {
		acc.err = err
	}
	return acc
}

func (r lockscreenPamResolver) analyzeInto(path string, filterType string, stack []string, acc *lockscreenPamAnalysis) error {
	for _, seen := range stack {
		if seen == path {
			chain := append(append([]string{}, stack...), path)
			display := make([]string, 0, len(chain))
			for _, item := range chain {
				display = append(display, filepath.Base(item))
			}
			return fmt.Errorf("cyclic PAM include detected: %s", strings.Join(display, " -> "))
		}
	}

	data, err := r.readFile(path)
	if err != nil {
		return fmt.Errorf("failed to read PAM file %s: %w", path, err)
	}

	for _, rawLine := range strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n") {
		rawLine = strings.TrimRight(rawLine, "\r")
		trimmed := strings.TrimSpace(rawLine)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}

		if include, ok := parseLockscreenPamIncludeDirective(trimmed, filterType); ok {
			lineType := pamDirectiveType(trimmed)
			if filterType != "" && lineType != "" && lineType != filterType {
				continue
			}
			nestedPath := include.target
			if filepath.IsAbs(nestedPath) {
				nestedPath = filepath.Clean(nestedPath)
			} else {
				located, err := r.locate(include.target)
				if err != nil {
					return fmt.Errorf("failed to read PAM file %s: %w", include.target, err)
				}
				nestedPath = located
			}
			if err := r.analyzeInto(nestedPath, include.filterType, append(stack, path), acc); err != nil {
				return err
			}
			continue
		}

		lineType := pamDirectiveType(trimmed)
		if lineType == "" {
			acc.unknownDirectives = append(acc.unknownDirectives, trimmed)
			continue
		}
		if filterType != "" && lineType != filterType {
			continue
		}

		acc.lines = append(acc.lines, rawLine)
		if lineType == "auth" {
			acc.hasAuth = true
		}

		foundModule := false
		for _, field := range strings.Fields(trimmed) {
			if strings.HasPrefix(field, "#") {
				break
			}
			if strings.Contains(field, "pam_fprintd") {
				acc.inlineFingerprint = true
			}
			if strings.Contains(field, "pam_u2f") {
				acc.inlineU2f = true
			}
			if !foundModule && strings.HasSuffix(field, ".so") {
				acc.modules = append(acc.modules, field)
				foundModule = true
			}
		}
	}

	return nil
}

// Earlier base dir wins per name (libpam precedence).
func ListLockscreenPamServices() []LockscreenPamServiceInfo {
	return listLockscreenPamServices(lockscreenPamBaseDirs, os.ReadFile)
}

func listLockscreenPamServices(baseDirs []string, readFile func(string) ([]byte, error)) []LockscreenPamServiceInfo {
	resolver := lockscreenPamResolver{baseDirs: baseDirs, readFile: readFile}
	out := make([]LockscreenPamServiceInfo, 0, len(lockscreenPamCandidateServices))
	for _, name := range lockscreenPamCandidateServices {
		path, err := resolver.locate(name)
		if err != nil {
			continue
		}
		info := LockscreenPamServiceInfo{
			Name: name,
			Dir:  filepath.Dir(path),
			Path: path,
		}
		if analysis := resolver.analyzePath(path); analysis.err == nil {
			info.HasAuth = analysis.hasAuth
			info.InlineFingerprint = analysis.inlineFingerprint
			info.InlineU2f = analysis.inlineU2f
		}
		out = append(out, info)
	}
	return out
}

func ValidateLockscreenPamService(name string) LockscreenPamValidation {
	return validateLockscreenPam(name, "", defaultValidateDeps())
}

func ValidateLockscreenPamPath(path string) LockscreenPamValidation {
	return validateLockscreenPam("", path, defaultValidateDeps())
}

func validateLockscreenPam(serviceName string, path string, deps lockscreenPamValidateDeps) LockscreenPamValidation {
	result := LockscreenPamValidation{
		MissingModules: []string{},
		Warnings:       []string{},
		Errors:         []string{},
	}
	resolver := lockscreenPamResolver{baseDirs: deps.baseDirs, readFile: deps.readFile}

	var analysis lockscreenPamAnalysis
	if path != "" {
		result.Path = path
		analysis = resolver.analyzePath(path)
	} else {
		located, err := resolver.locate(serviceName)
		if err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("PAM service %q not found: %v", serviceName, err))
			return result
		}
		result.Path = located
		analysis = resolver.analyzePath(located)
	}

	if analysis.err != nil {
		result.Errors = append(result.Errors, analysis.err.Error())
		return result
	}

	result.HasAuth = analysis.hasAuth
	result.InlineFingerprint = analysis.inlineFingerprint
	result.InlineU2f = analysis.inlineU2f

	if !analysis.hasAuth {
		result.Errors = append(result.Errors, "no auth directives found after include resolution")
	}

	for _, directive := range analysis.unknownDirectives {
		result.Warnings = append(result.Warnings, "unsupported PAM directive (libpam may still handle it at runtime): "+directive)
	}

	seen := map[string]bool{}
	for _, ref := range analysis.modules {
		name := filepath.Base(ref)
		if seen[name] {
			continue
		}
		seen[name] = true
		if moduleReferenceExists(ref, deps) {
			continue
		}
		result.MissingModules = append(result.MissingModules, name)
		result.Warnings = append(result.Warnings, "referenced PAM module not found: "+name)
	}

	if analysis.inlineFingerprint {
		result.Warnings = append(result.Warnings, "pam_fprintd is present in the resolved stack; may double-prompt with DMS's separate fingerprint context")
	}
	if analysis.inlineU2f {
		result.Warnings = append(result.Warnings, "pam_u2f is present in the resolved stack; may double-prompt with DMS's separate U2F context")
	}

	result.Valid = len(result.Errors) == 0
	return result
}

func moduleReferenceExists(ref string, deps lockscreenPamValidateDeps) bool {
	if filepath.IsAbs(ref) {
		_, err := deps.stat(ref)
		return err == nil
	}
	return deps.pamModuleExists(ref)
}

const UserLockscreenPamService = "dankshell"

func UserLockscreenPamDir() string {
	return filepath.Join(utils.XDGStateHome(), "DankMaterialShell", "pam")
}

// WriteUserLockscreenPamConfig resolves the distro's real auth stack into a
// self-contained lock-screen service under the user state dir, unprivileged
// (reads world-readable PAM dirs, writes the user's own state dir). Rewrites
// only on change to avoid inotify churn. Returns the written path.
func WriteUserLockscreenPamConfig(logFunc func(string)) (string, error) {
	content, err := buildManagedLockscreenPamContent(lockscreenPamBaseDirs, os.ReadFile)
	if err != nil {
		return "", fmt.Errorf("failed to resolve system PAM auth stack: %w", err)
	}

	dir := UserLockscreenPamDir()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", fmt.Errorf("failed to create %s: %w", dir, err)
	}

	path := filepath.Join(dir, UserLockscreenPamService)
	if existing, err := os.ReadFile(path); err == nil && string(existing) == content {
		return path, nil
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		return "", fmt.Errorf("failed to write %s: %w", path, err)
	}

	if logFunc != nil {
		logFunc("✓ Wrote lock-screen PAM config " + path)
	}
	return path, nil
}

func buildManagedLockscreenU2FPamContent() string {
	var b strings.Builder
	b.WriteString("#%PAM-1.0\n")
	b.WriteString(LockscreenU2FPamManagedBlockStart + "\n")
	b.WriteString("auth    required    pam_u2f.so  cue nouserok timeout=10\n")
	b.WriteString("account required    pam_permit.so\n")
	b.WriteString("password required   pam_deny.so\n")
	b.WriteString("session required    pam_permit.so\n")
	b.WriteString(LockscreenU2FPamManagedBlockEnd + "\n")
	return b.String()
}

func syncLockscreenPamConfigWithDeps(logFunc func(string), sudoPassword string, deps syncDeps) error {
	if deps.isNixOS() {
		logFunc("ℹ NixOS detected. DMS continues to use /etc/pam.d/login for lock screen password auth on NixOS unless you declare security.pam.services.dankshell yourself. U2F and fingerprint are handled separately and should not be included in dankshell.")
		return nil
	}

	existingData, err := deps.readFile(deps.dankshellPath)
	if err == nil {
		if !hasManagedLockscreenPamFile(string(existingData)) {
			logFunc("ℹ Custom /etc/pam.d/dankshell found (no DMS block). Skipping.")
			return nil
		}
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("failed to read %s: %w", deps.dankshellPath, err)
	}

	content, err := buildManagedLockscreenPamContent([]string{deps.pamDir}, deps.readFile)
	if err != nil {
		return fmt.Errorf("failed to build %s from %s: %w", deps.dankshellPath, filepath.Join(deps.pamDir, "login"), err)
	}

	if err := writeManagedPamFile(content, deps.dankshellPath, sudoPassword, deps); err != nil {
		return fmt.Errorf("failed to write %s: %w", deps.dankshellPath, err)
	}

	logFunc("✓ Created or updated /etc/pam.d/dankshell for lock screen authentication")
	return nil
}

func syncLockscreenU2FPamConfigWithDeps(logFunc func(string), sudoPassword string, enabled bool, deps syncDeps) error {
	if deps.isNixOS() {
		logFunc("ℹ NixOS detected. DMS does not manage /etc/pam.d/dankshell-u2f on NixOS. Keep using the bundled U2F helper or configure a custom PAM service yourself.")
		return nil
	}

	existingData, err := deps.readFile(deps.dankshellU2fPath)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to read %s: %w", deps.dankshellU2fPath, err)
	}

	if enabled {
		if err == nil && !hasManagedLockscreenU2FPamFile(string(existingData)) {
			logFunc("ℹ Custom /etc/pam.d/dankshell-u2f found (no DMS block). Skipping.")
			return nil
		}
		if err := writeManagedPamFile(buildManagedLockscreenU2FPamContent(), deps.dankshellU2fPath, sudoPassword, deps); err != nil {
			return fmt.Errorf("failed to write %s: %w", deps.dankshellU2fPath, err)
		}
		logFunc("✓ Created or updated /etc/pam.d/dankshell-u2f for lock screen security-key authentication")
		return nil
	}

	if os.IsNotExist(err) {
		return nil
	}
	if err == nil && !hasManagedLockscreenU2FPamFile(string(existingData)) {
		logFunc("ℹ Custom /etc/pam.d/dankshell-u2f found (no DMS block). Leaving it untouched.")
		return nil
	}

	if err := deps.runSudoCmd(sudoPassword, "rm", "-f", deps.dankshellU2fPath); err != nil {
		return fmt.Errorf("failed to remove %s: %w", deps.dankshellU2fPath, err)
	}
	logFunc("✓ Removed DMS-managed /etc/pam.d/dankshell-u2f")
	return nil
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

func syncGreeterPamConfigWithDeps(logFunc func(string), sudoPassword string, settings AuthSettings, forceAuth bool, deps syncDeps) error {
	var wantFprint, wantU2f bool
	fprintToggleEnabled := forceAuth
	u2fToggleEnabled := forceAuth
	if forceAuth {
		wantFprint = deps.pamModuleExists("pam_fprintd.so")
		wantU2f = deps.pamModuleExists("pam_u2f.so")
	} else {
		fprintToggleEnabled = settings.GreeterEnableFprint
		u2fToggleEnabled = settings.GreeterEnableU2f
		fprintModule := deps.pamModuleExists("pam_fprintd.so")
		u2fModule := deps.pamModuleExists("pam_u2f.so")
		wantFprint = settings.GreeterEnableFprint && fprintModule
		wantU2f = settings.GreeterEnableU2f && u2fModule
		if settings.GreeterEnableFprint && !fprintModule {
			logFunc("⚠ Warning: greeter fingerprint toggle is enabled, but pam_fprintd.so was not found.")
		}
		if settings.GreeterEnableU2f && !u2fModule {
			logFunc("⚠ Warning: greeter security key toggle is enabled, but pam_u2f.so was not found.")
		}
	}

	if deps.isNixOS() {
		logFunc("ℹ NixOS detected: PAM config is managed by NixOS modules. Skipping DMS PAM block write.")
		logFunc("  Configure fingerprint/U2F auth via your greetd NixOS module options (e.g. security.pam.services.greetd).")
		return nil
	}

	pamData, err := deps.readFile(deps.greetdPath)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", deps.greetdPath, err)
	}
	originalContent := string(pamData)
	content, _ := stripManagedGreeterPamBlock(originalContent)
	content, _ = stripLegacyGreeterPamLines(content)

	includedFprintFile := detectIncludedPamModule(content, "pam_fprintd.so", deps)
	includedU2fFile := detectIncludedPamModule(content, "pam_u2f.so", deps)
	fprintAvailableForCurrentUser := deps.fingerprintAvailableForCurrentUser()
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
			blockLines = append(blockLines, "auth sufficient pam_fprintd.so max-tries=2 timeout=10")
		}
		if wantU2f {
			blockLines = append(blockLines, "auth sufficient pam_u2f.so cue nouserok timeout=10")
		}
		blockLines = append(blockLines, GreeterPamManagedBlockEnd)

		content, err = insertManagedGreeterPamBlock(content, blockLines, deps.greetdPath)
		if err != nil {
			return err
		}
	}

	if content == originalContent {
		return nil
	}

	if err := writeManagedPamFile(content, deps.greetdPath, sudoPassword, deps); err != nil {
		return fmt.Errorf("failed to install updated PAM config at %s: %w", deps.greetdPath, err)
	}
	if wantFprint || wantU2f {
		logFunc("✓ Configured greetd PAM for fingerprint/U2F")
	} else {
		logFunc("✓ Cleared DMS-managed greeter PAM auth block")
	}
	return nil
}

func writeManagedPamFile(content string, destPath string, sudoPassword string, deps syncDeps) error {
	tmpFile, err := deps.createTemp("", "dms-pam-*.conf")
	if err != nil {
		return err
	}
	tmpPath := tmpFile.Name()
	defer func() {
		_ = deps.removeFile(tmpPath)
	}()

	if _, err := tmpFile.WriteString(content); err != nil {
		tmpFile.Close()
		return err
	}
	if err := tmpFile.Close(); err != nil {
		return err
	}
	if err := deps.runSudoCmd(sudoPassword, "cp", tmpPath, destPath); err != nil {
		return err
	}
	if err := deps.runSudoCmd(sudoPassword, "chmod", "644", destPath); err != nil {
		return fmt.Errorf("failed to set permissions on %s: %w", destPath, err)
	}
	return nil
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

func pamModuleExists(module string) bool {
	for _, libDir := range []string{
		"/usr/lib64/security",
		"/usr/lib/security",
		"/lib64/security",
		"/lib/security",
		"/lib/x86_64-linux-gnu/security",
		"/usr/lib/x86_64-linux-gnu/security",
		"/lib/aarch64-linux-gnu/security",
		"/usr/lib/aarch64-linux-gnu/security",
		"/run/current-system/sw/lib64/security",
		"/run/current-system/sw/lib/security",
	} {
		if _, err := os.Stat(filepath.Join(libDir, module)); err == nil {
			return true
		}
	}
	return false
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
	return fingerprintAuthAvailableForUser(username)
}

func fingerprintAuthAvailableForUser(username string) bool {
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
