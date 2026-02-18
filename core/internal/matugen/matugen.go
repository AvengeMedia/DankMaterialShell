package matugen

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/dank16"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/lucasb-eyer/go-colorful"
)

type ColorMode string

const (
	ColorModeDark  ColorMode = "dark"
	ColorModeLight ColorMode = "light"
)

type TemplateKind int

const (
	TemplateKindNormal TemplateKind = iota
	TemplateKindTerminal
	TemplateKindGTK
	TemplateKindVSCode
	TemplateKindEmacs
)

type TemplateDef struct {
	ID                 string
	Commands           []string
	Flatpaks           []string
	ConfigFile         string
	Kind               TemplateKind
	RunUnconditionally bool
}

var templateRegistry = []TemplateDef{
	{ID: "gtk", Kind: TemplateKindGTK, RunUnconditionally: true},
	{ID: "niri", Commands: []string{"niri"}, ConfigFile: "niri.toml"},
	{ID: "hyprland", Commands: []string{"Hyprland"}, ConfigFile: "hyprland.toml"},
	{ID: "mangowc", Commands: []string{"mango"}, ConfigFile: "mangowc.toml"},
	{ID: "qt5ct", Commands: []string{"qt5ct"}, ConfigFile: "qt5ct.toml"},
	{ID: "qt6ct", Commands: []string{"qt6ct"}, ConfigFile: "qt6ct.toml"},
	{ID: "firefox", Commands: []string{"firefox"}, ConfigFile: "firefox.toml"},
	{ID: "pywalfox", Commands: []string{"pywalfox"}, ConfigFile: "pywalfox.toml"},
	{ID: "zenbrowser", Commands: []string{"zen", "zen-browser"}, Flatpaks: []string{"app.zen_browser.zen"}, ConfigFile: "zenbrowser.toml"},
	{ID: "vesktop", Commands: []string{"vesktop"}, Flatpaks: []string{"dev.vencord.Vesktop"}, ConfigFile: "vesktop.toml"},
	{ID: "equibop", Commands: []string{"equibop"}, ConfigFile: "equibop.toml"},
	{ID: "ghostty", Commands: []string{"ghostty"}, ConfigFile: "ghostty.toml", Kind: TemplateKindTerminal},
	{ID: "kitty", Commands: []string{"kitty"}, ConfigFile: "kitty.toml", Kind: TemplateKindTerminal},
	{ID: "foot", Commands: []string{"foot"}, ConfigFile: "foot.toml", Kind: TemplateKindTerminal},
	{ID: "alacritty", Commands: []string{"alacritty"}, ConfigFile: "alacritty.toml", Kind: TemplateKindTerminal},
	{ID: "wezterm", Commands: []string{"wezterm"}, ConfigFile: "wezterm.toml", Kind: TemplateKindTerminal},
	{ID: "nvim", Commands: []string{"nvim"}, ConfigFile: "neovim.toml", Kind: TemplateKindTerminal},
	{ID: "dgop", Commands: []string{"dgop"}, ConfigFile: "dgop.toml"},
	{ID: "kcolorscheme", ConfigFile: "kcolorscheme.toml", RunUnconditionally: true},
	{ID: "vscode", Kind: TemplateKindVSCode},
	{ID: "emacs", Commands: []string{"emacs"}, ConfigFile: "emacs.toml", Kind: TemplateKindEmacs},
}

func (c *ColorMode) GTKTheme() string {
	switch *c {
	case ColorModeDark:
		return "adw-gtk3-dark"
	default:
		return "adw-gtk3"
	}
}

var (
	matugenVersionMu   sync.Mutex
	matugenVersionOK   bool
	matugenSupportsCOE bool
	matugenIsV4        bool
)

type Options struct {
	StateDir            string
	ShellDir            string
	ConfigDir           string
	Kind                string
	Value               string
	Mode                ColorMode
	IconTheme           string
	MatugenType         string
	RunUserTemplates    bool
	StockColors         string
	SyncModeWithPortal  bool
	TerminalsAlwaysDark bool
	SkipTemplates       string
	AppChecker          utils.AppChecker
}

type ColorsOutput struct {
	Colors struct {
		Dark  map[string]string `json:"dark"`
		Light map[string]string `json:"light"`
	} `json:"colors"`
}

func (o *Options) ColorsOutput() string {
	return filepath.Join(o.StateDir, "dms-colors.json")
}

func (o *Options) ShouldSkipTemplate(name string) bool {
	if o.SkipTemplates == "" {
		return false
	}
	for _, skip := range strings.Split(o.SkipTemplates, ",") {
		if strings.TrimSpace(skip) == name {
			return true
		}
	}
	return false
}

func Run(opts Options) error {
	if opts.StateDir == "" {
		return fmt.Errorf("state-dir is required")
	}
	if opts.ShellDir == "" {
		return fmt.Errorf("shell-dir is required")
	}
	if opts.ConfigDir == "" {
		return fmt.Errorf("config-dir is required")
	}
	if opts.Kind == "" {
		return fmt.Errorf("kind is required")
	}
	if opts.Value == "" {
		return fmt.Errorf("value is required")
	}
	if opts.Mode == "" {
		opts.Mode = ColorModeDark
	}
	if opts.MatugenType == "" {
		opts.MatugenType = "scheme-tonal-spot"
	}
	if opts.IconTheme == "" {
		opts.IconTheme = "System Default"
	}
	if opts.AppChecker == nil {
		opts.AppChecker = utils.DefaultAppChecker{}
	}

	if err := os.MkdirAll(opts.StateDir, 0o755); err != nil {
		return fmt.Errorf("failed to create state dir: %w", err)
	}

	log.Infof("Building theme: %s %s (%s)", opts.Kind, opts.Value, opts.Mode)

	if err := buildOnce(&opts); err != nil {
		return err
	}

	if opts.SyncModeWithPortal {
		syncColorScheme(opts.Mode)
	}

	log.Info("Done")
	return nil
}

func buildOnce(opts *Options) error {
	cfgFile, err := os.CreateTemp("", "matugen-config-*.toml")
	if err != nil {
		return fmt.Errorf("failed to create temp config: %w", err)
	}
	defer os.Remove(cfgFile.Name())
	defer cfgFile.Close()

	tmpDir, err := os.MkdirTemp("", "matugen-templates-*")
	if err != nil {
		return fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	if err := buildMergedConfig(opts, cfgFile, tmpDir); err != nil {
		return fmt.Errorf("failed to build config: %w", err)
	}
	cfgFile.Close()

	var primaryDark, primaryLight, surface string
	var dank16JSON string
	var importArgs []string

	if opts.StockColors != "" {
		log.Info("Using stock/custom theme colors with matugen base")
		primaryDark = extractNestedColor(opts.StockColors, "primary", "dark")
		primaryLight = extractNestedColor(opts.StockColors, "primary", "light")
		surface = extractNestedColor(opts.StockColors, "surface", "dark")

		if primaryDark == "" {
			return fmt.Errorf("failed to extract primary dark from stock colors")
		}
		if primaryLight == "" {
			primaryLight = primaryDark
		}

		dank16JSON = generateDank16Variants(primaryDark, primaryLight, surface, opts.Mode)
		importData := fmt.Sprintf(`{"colors": %s, "dank16": %s}`, opts.StockColors, dank16JSON)
		importArgs = []string{"--import-json-string", importData}

		log.Info("Running matugen color hex with stock color overrides")
		args := []string{"color", "hex", primaryDark, "-m", string(opts.Mode), "-t", opts.MatugenType, "-c", cfgFile.Name()}
		args = append(args, importArgs...)
		if err := runMatugen(args); err != nil {
			return err
		}
	} else {
		log.Infof("Using dynamic theme from %s: %s", opts.Kind, opts.Value)

		matJSON, err := runMatugenDryRun(opts)
		if err != nil {
			return fmt.Errorf("matugen dry-run failed: %w", err)
		}

		primaryDark = extractMatugenColor(matJSON, "primary", "dark")
		primaryLight = extractMatugenColor(matJSON, "primary", "light")
		surface = extractMatugenColor(matJSON, "surface", "dark")

		if primaryDark == "" {
			return fmt.Errorf("failed to extract primary color")
		}
		if primaryLight == "" {
			primaryLight = primaryDark
		}

		dank16JSON = generateDank16Variants(primaryDark, primaryLight, surface, opts.Mode)
		importData := fmt.Sprintf(`{"dank16": %s}`, dank16JSON)
		importArgs = []string{"--import-json-string", importData}

		log.Infof("Running matugen %s with dank16 injection", opts.Kind)
		var args []string
		switch opts.Kind {
		case "hex":
			args = []string{"color", "hex", opts.Value}
		default:
			args = []string{opts.Kind, opts.Value}
		}
		args = append(args, "-m", string(opts.Mode), "-t", opts.MatugenType, "-c", cfgFile.Name())
		args = append(args, importArgs...)
		if err := runMatugen(args); err != nil {
			return err
		}
	}

	if isDMSGTKActive(opts.ConfigDir) {
		switch opts.Mode {
		case ColorModeLight:
			syncAccentColor(primaryLight)
		default:
			syncAccentColor(primaryDark)
		}
		refreshGTK(opts.Mode)
		refreshGTK4()
	}

	if !opts.ShouldSkipTemplate("qt6ct") && appExists(opts.AppChecker, []string{"qt6ct"}, nil) {
		refreshQt6ct()
	}

	signalTerminals(opts)

	return nil
}

func buildMergedConfig(opts *Options, cfgFile *os.File, tmpDir string) error {
	userConfigPath := filepath.Join(opts.ConfigDir, "matugen", "config.toml")

	wroteConfig := false
	if opts.RunUserTemplates {
		if data, err := os.ReadFile(userConfigPath); err == nil {
			configSection := extractTOMLSection(string(data), "[config]", "[templates]")
			if configSection != "" {
				cfgFile.WriteString(configSection)
				cfgFile.WriteString("\n")
				wroteConfig = true
			}
		}
	}
	if !wroteConfig {
		cfgFile.WriteString("[config]\n\n")
	}

	baseConfigPath := filepath.Join(opts.ShellDir, "matugen", "configs", "base.toml")
	if data, err := os.ReadFile(baseConfigPath); err == nil {
		content := string(data)
		lines := strings.Split(content, "\n")
		for _, line := range lines {
			if strings.TrimSpace(line) == "[config]" {
				continue
			}
			cfgFile.WriteString(substituteVars(line, opts.ShellDir) + "\n")
		}
		cfgFile.WriteString("\n")
	}

	fmt.Fprintf(cfgFile, `[templates.dank]
input_path = '%s/matugen/templates/dank.json'
output_path = '%s'

`, opts.ShellDir, opts.ColorsOutput())

	homeDir, _ := os.UserHomeDir()
	for _, tmpl := range templateRegistry {
		if opts.ShouldSkipTemplate(tmpl.ID) {
			continue
		}

		switch tmpl.Kind {
		case TemplateKindGTK:
			switch opts.Mode {
			case ColorModeLight:
				appendConfig(opts, cfgFile, nil, nil, "gtk3-light.toml")
			default:
				appendConfig(opts, cfgFile, nil, nil, "gtk3-dark.toml")
			}
		case TemplateKindTerminal:
			appendTerminalConfig(opts, cfgFile, tmpDir, tmpl.Commands, tmpl.Flatpaks, tmpl.ConfigFile)
		case TemplateKindVSCode:
			appendVSCodeConfig(cfgFile, "vscode", filepath.Join(homeDir, ".vscode/extensions"), opts.ShellDir)
			appendVSCodeConfig(cfgFile, "codium", filepath.Join(homeDir, ".vscode-oss/extensions"), opts.ShellDir)
			appendVSCodeConfig(cfgFile, "codeoss", filepath.Join(homeDir, ".config/Code - OSS/extensions"), opts.ShellDir)
			appendVSCodeConfig(cfgFile, "cursor", filepath.Join(homeDir, ".cursor/extensions"), opts.ShellDir)
			appendVSCodeConfig(cfgFile, "windsurf", filepath.Join(homeDir, ".windsurf/extensions"), opts.ShellDir)
			appendVSCodeConfig(cfgFile, "vscode-insiders", filepath.Join(homeDir, ".vscode-insiders/extensions"), opts.ShellDir)
		case TemplateKindEmacs:
			if utils.EmacsConfigDir() != "" {
				appendConfig(opts, cfgFile, tmpl.Commands, tmpl.Flatpaks, tmpl.ConfigFile)
			}
		default:
			appendConfig(opts, cfgFile, tmpl.Commands, tmpl.Flatpaks, tmpl.ConfigFile)
		}
	}

	if opts.RunUserTemplates {
		if data, err := os.ReadFile(userConfigPath); err == nil {
			templatesSection := extractTOMLSection(string(data), "[templates]", "")
			if templatesSection != "" {
				cfgFile.WriteString(templatesSection)
				cfgFile.WriteString("\n")
			}
		}
	}

	userPluginConfigDir := filepath.Join(opts.ConfigDir, "matugen", "dms", "configs")
	if entries, err := os.ReadDir(userPluginConfigDir); err == nil {
		for _, entry := range entries {
			if !strings.HasSuffix(entry.Name(), ".toml") {
				continue
			}
			if data, err := os.ReadFile(filepath.Join(userPluginConfigDir, entry.Name())); err == nil {
				cfgFile.WriteString(string(data))
				cfgFile.WriteString("\n")
			}
		}
	}

	return nil
}

func appendConfig(
	opts *Options,
	cfgFile *os.File,
	checkCmd []string,
	checkFlatpaks []string,
	fileName string,
) {
	configPath := filepath.Join(opts.ShellDir, "matugen", "configs", fileName)
	if _, err := os.Stat(configPath); err != nil {
		return
	}
	if !appExists(opts.AppChecker, checkCmd, checkFlatpaks) {
		return
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return
	}
	cfgFile.WriteString(substituteVars(string(data), opts.ShellDir))
	cfgFile.WriteString("\n")
}

func appendTerminalConfig(opts *Options, cfgFile *os.File, tmpDir string, checkCmd []string, checkFlatpaks []string, fileName string) {
	configPath := filepath.Join(opts.ShellDir, "matugen", "configs", fileName)
	if _, err := os.Stat(configPath); err != nil {
		return
	}
	if !appExists(opts.AppChecker, checkCmd, checkFlatpaks) {
		return
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return
	}

	content := string(data)

	if !opts.TerminalsAlwaysDark {
		cfgFile.WriteString(substituteVars(content, opts.ShellDir))
		cfgFile.WriteString("\n")
		return
	}

	lines := strings.Split(content, "\n")
	for _, line := range lines {
		if !strings.Contains(line, "input_path") || !strings.Contains(line, "SHELL_DIR/matugen/templates/") {
			continue
		}

		start := strings.Index(line, "'SHELL_DIR/matugen/templates/")
		if start == -1 {
			continue
		}
		end := strings.Index(line[start+1:], "'")
		if end == -1 {
			continue
		}
		templateName := line[start+len("'SHELL_DIR/matugen/templates/") : start+1+end]
		origPath := filepath.Join(opts.ShellDir, "matugen", "templates", templateName)

		origData, err := os.ReadFile(origPath)
		if err != nil {
			continue
		}

		modified := strings.ReplaceAll(string(origData), ".default.", ".dark.")
		tmpPath := filepath.Join(tmpDir, templateName)
		if err := os.WriteFile(tmpPath, []byte(modified), 0o644); err != nil {
			continue
		}

		content = strings.ReplaceAll(content,
			fmt.Sprintf("'SHELL_DIR/matugen/templates/%s'", templateName),
			fmt.Sprintf("'%s'", tmpPath))
	}

	cfgFile.WriteString(substituteVars(content, opts.ShellDir))
	cfgFile.WriteString("\n")
}

func appExists(checker utils.AppChecker, checkCmd []string, checkFlatpaks []string) bool {
	// Both nil is treated as "skip check" / unconditionally run
	if checkCmd == nil && checkFlatpaks == nil {
		return true
	}
	if checkCmd != nil && checker.AnyCommandExists(checkCmd...) {
		return true
	}
	if checkFlatpaks != nil && checker.AnyFlatpakExists(checkFlatpaks...) {
		return true
	}
	return false
}

func appendVSCodeConfig(cfgFile *os.File, name, extBaseDir, shellDir string) {
	pattern := filepath.Join(extBaseDir, "danklinux.dms-theme-*")
	matches, err := filepath.Glob(pattern)
	if err != nil || len(matches) == 0 {
		return
	}

	extDir := matches[0]
	templateDir := filepath.Join(shellDir, "matugen", "templates")
	fmt.Fprintf(cfgFile, `[templates.dms%sdefault]
input_path = '%s/vscode-color-theme-default.json'
output_path = '%s/themes/dankshell-default.json'

[templates.dms%sdark]
input_path = '%s/vscode-color-theme-dark.json'
output_path = '%s/themes/dankshell-dark.json'

[templates.dms%slight]
input_path = '%s/vscode-color-theme-light.json'
output_path = '%s/themes/dankshell-light.json'

`, name, templateDir, extDir,
		name, templateDir, extDir,
		name, templateDir, extDir)
	log.Infof("Added %s theme config (extension found at %s)", name, extDir)
}

func substituteVars(content, shellDir string) string {
	result := strings.ReplaceAll(content, "'SHELL_DIR/", "'"+shellDir+"/")
	result = strings.ReplaceAll(result, "'CONFIG_DIR/", "'"+utils.XDGConfigHome()+"/")
	result = strings.ReplaceAll(result, "'DATA_DIR/", "'"+utils.XDGDataHome()+"/")
	result = strings.ReplaceAll(result, "'CACHE_DIR/", "'"+utils.XDGCacheHome()+"/")
	if emacsDir := utils.EmacsConfigDir(); emacsDir != "" {
		result = strings.ReplaceAll(result, "'EMACS_DIR/", "'"+emacsDir+"/")
	}
	return result
}

func extractTOMLSection(content, startMarker, endMarker string) string {
	startIdx := strings.Index(content, startMarker)
	if startIdx == -1 {
		return ""
	}

	if endMarker == "" {
		return content[startIdx:]
	}

	endIdx := strings.Index(content[startIdx:], endMarker)
	if endIdx == -1 {
		return content[startIdx:]
	}
	return content[startIdx : startIdx+endIdx]
}

type matugenFlags struct {
	supportsCOE bool
	isV4        bool
}

func detectMatugenVersion() (matugenFlags, error) {
	matugenVersionMu.Lock()
	defer matugenVersionMu.Unlock()

	if matugenVersionOK {
		return matugenFlags{matugenSupportsCOE, matugenIsV4}, nil
	}

	return detectMatugenVersionLocked()
}

func redetectMatugenVersion(old matugenFlags) (matugenFlags, bool) {
	matugenVersionMu.Lock()
	defer matugenVersionMu.Unlock()

	matugenVersionOK = false
	flags, err := detectMatugenVersionLocked()
	if err != nil {
		return old, false
	}
	changed := flags.supportsCOE != old.supportsCOE || flags.isV4 != old.isV4
	return flags, changed
}

func detectMatugenVersionLocked() (matugenFlags, error) {
	cmd := exec.Command("matugen", "--version")
	output, err := cmd.Output()
	if err != nil {
		return matugenFlags{}, fmt.Errorf("failed to get matugen version: %w", err)
	}

	versionStr := strings.TrimSpace(string(output))
	versionStr = strings.TrimPrefix(versionStr, "matugen ")

	parts := strings.Split(versionStr, ".")
	if len(parts) < 2 {
		return matugenFlags{}, fmt.Errorf("unexpected matugen version format: %q", versionStr)
	}

	major, err := strconv.Atoi(parts[0])
	if err != nil {
		return matugenFlags{}, fmt.Errorf("failed to parse matugen major version %q: %w", parts[0], err)
	}

	minor, err := strconv.Atoi(parts[1])
	if err != nil {
		return matugenFlags{}, fmt.Errorf("failed to parse matugen minor version %q: %w", parts[1], err)
	}

	matugenSupportsCOE = major > 3 || (major == 3 && minor >= 1)
	matugenIsV4 = major >= 4
	matugenVersionOK = true

	if matugenSupportsCOE {
		log.Infof("Matugen %s supports --continue-on-error", versionStr)
	}
	if matugenIsV4 {
		log.Infof("Matugen %s: using v4 flags", versionStr)
	}
	return matugenFlags{matugenSupportsCOE, matugenIsV4}, nil
}

func buildMatugenArgs(baseArgs []string, flags matugenFlags) []string {
	args := make([]string, 0, len(baseArgs)+4)
	if flags.supportsCOE {
		args = append(args, "--continue-on-error")
	}
	args = append(args, baseArgs...)
	if flags.isV4 {
		args = append(args, "--source-color-index", "0")
	}
	return args
}

func runMatugen(baseArgs []string) error {
	flags, err := detectMatugenVersion()
	if err != nil {
		return err
	}

	args := buildMatugenArgs(baseArgs, flags)
	cmd := exec.Command("matugen", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	runErr := cmd.Run()
	if runErr == nil {
		return nil
	}

	log.Warnf("Matugen failed (v4=%v): %v", flags.isV4, runErr)

	newFlags, changed := redetectMatugenVersion(flags)
	if !changed {
		return runErr
	}

	log.Warnf("Matugen version changed (v4: %v -> %v), retrying", flags.isV4, newFlags.isV4)
	args = buildMatugenArgs(baseArgs, newFlags)
	retryCmd := exec.Command("matugen", args...)
	retryCmd.Stdout = os.Stdout
	retryCmd.Stderr = os.Stderr
	return retryCmd.Run()
}

func runMatugenDryRun(opts *Options) (string, error) {
	flags, err := detectMatugenVersion()
	if err != nil {
		return "", err
	}

	output, dryErr := execDryRun(opts, flags)
	if dryErr == nil {
		return output, nil
	}

	log.Warnf("Matugen dry-run failed (v4=%v): %v", flags.isV4, dryErr)

	newFlags, changed := redetectMatugenVersion(flags)
	if !changed {
		return "", dryErr
	}

	log.Warnf("Matugen version changed (v4: %v -> %v), retrying dry-run", flags.isV4, newFlags.isV4)
	return execDryRun(opts, newFlags)
}

func execDryRun(opts *Options, flags matugenFlags) (string, error) {
	var baseArgs []string
	switch opts.Kind {
	case "hex":
		baseArgs = []string{"color", "hex", opts.Value}
	default:
		baseArgs = []string{opts.Kind, opts.Value}
	}
	baseArgs = append(baseArgs, "-m", "dark", "-t", opts.MatugenType, "--json", "hex", "--dry-run")
	if flags.isV4 {
		baseArgs = append(baseArgs, "--source-color-index", "0", "--old-json-output")
	}

	cmd := exec.Command("matugen", baseArgs...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	output, err := cmd.Output()
	if err != nil {
		if stderr.Len() > 0 {
			return "", fmt.Errorf("matugen %v failed (v4=%v): %s", baseArgs, flags.isV4, strings.TrimSpace(stderr.String()))
		}
		return "", fmt.Errorf("matugen %v failed (v4=%v): %w", baseArgs, flags.isV4, err)
	}
	return strings.ReplaceAll(string(output), "\n", ""), nil
}

func extractMatugenColor(jsonStr, colorName, variant string) string {
	var data map[string]any
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		return ""
	}

	colors, ok := data["colors"].(map[string]any)
	if !ok {
		return ""
	}

	colorData, ok := colors[colorName].(map[string]any)
	if !ok {
		return ""
	}

	variantData, ok := colorData[variant].(string)
	if !ok {
		return ""
	}

	return variantData
}

func extractNestedColor(jsonStr, colorName, variant string) string {
	var data map[string]any
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		return ""
	}

	colorData, ok := data[colorName].(map[string]any)
	if !ok {
		return ""
	}

	variantData, ok := colorData[variant].(map[string]any)
	if !ok {
		return ""
	}

	color, ok := variantData["color"].(string)
	if !ok {
		return ""
	}

	return color
}

func generateDank16Variants(primaryDark, primaryLight, surface string, mode ColorMode) string {
	variantOpts := dank16.VariantOptions{
		PrimaryDark:  primaryDark,
		PrimaryLight: primaryLight,
		Background:   surface,
		UseDPS:       true,
		IsLightMode:  mode == ColorModeLight,
	}
	variantColors := dank16.GenerateVariantPalette(variantOpts)
	return dank16.GenerateVariantJSON(variantColors)
}

func isDMSGTKActive(configDir string) bool {
	gtkCSS := filepath.Join(configDir, "gtk-3.0", "gtk.css")

	info, err := os.Lstat(gtkCSS)
	if err != nil {
		return false
	}

	if info.Mode()&os.ModeSymlink != 0 {
		target, err := os.Readlink(gtkCSS)
		return err == nil && strings.Contains(target, "dank-colors.css")
	}

	data, err := os.ReadFile(gtkCSS)
	return err == nil && strings.Contains(string(data), "dank-colors.css")
}

func refreshGTK(mode ColorMode) {
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "gtk-theme", ""); err != nil {
		log.Warnf("Failed to reset gtk-theme: %v", err)
	}
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "gtk-theme", mode.GTKTheme()); err != nil {
		log.Warnf("Failed to set gtk-theme: %v", err)
	}
}

func refreshGTK4() {
	output, err := utils.GsettingsGet("org.gnome.desktop.interface", "color-scheme")
	if err != nil {
		return
	}
	current := strings.Trim(output, "'")

	var toggle string
	if current == "prefer-dark" {
		toggle = "default"
	} else {
		toggle = "prefer-dark"
	}

	if err := utils.GsettingsSet("org.gnome.desktop.interface", "color-scheme", toggle); err != nil {
		log.Warnf("Failed to toggle color-scheme for GTK4 refresh: %v", err)
		return
	}
	time.Sleep(50 * time.Millisecond)
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "color-scheme", current); err != nil {
		log.Warnf("Failed to restore color-scheme for GTK4 refresh: %v", err)
	}
}

func refreshQt6ct() {
	confPath := filepath.Join(utils.XDGConfigHome(), "qt6ct", "qt6ct.conf")
	now := time.Now()
	if err := os.Chtimes(confPath, now, now); err != nil {
		log.Warnf("Failed to touch qt6ct.conf: %v", err)
	}
}

func signalTerminals(opts *Options) {
	if !opts.ShouldSkipTemplate("kitty") && appExists(opts.AppChecker, []string{"kitty"}, nil) {
		signalByName("kitty", syscall.SIGUSR1)
		signalByName(".kitty-wrapped", syscall.SIGUSR1)
	}
	if !opts.ShouldSkipTemplate("ghostty") && appExists(opts.AppChecker, []string{"ghostty"}, nil) {
		signalByName("ghostty", syscall.SIGUSR2)
		signalByName(".ghostty-wrappe", syscall.SIGUSR2)
	}
}

func signalByName(name string, sig syscall.Signal) {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return
	}
	for _, entry := range entries {
		pid, err := strconv.Atoi(entry.Name())
		if err != nil {
			continue
		}
		comm, err := os.ReadFile(filepath.Join("/proc", entry.Name(), "comm"))
		if err != nil {
			continue
		}
		if strings.TrimSpace(string(comm)) == name {
			syscall.Kill(pid, sig)
		}
	}
}

func syncColorScheme(mode ColorMode) {
	scheme := "prefer-dark"
	if mode == ColorModeLight {
		scheme = "default"
	}

	if err := utils.GsettingsSet("org.gnome.desktop.interface", "color-scheme", scheme); err != nil {
		log.Warnf("Failed to sync color-scheme: %v", err)
	}
}

var adwaitaAccents = []struct {
	name   string
	colors []colorful.Color
}{
	{"blue", hexColors("#3f8ae5", "#438de6", "#a4caee")},
	{"green", hexColors("#26a269", "#39ac76", "#81d5ad")},
	{"orange", hexColors("#f17738", "#ff7800", "#ffc994")},
	{"pink", hexColors("#e4358a", "#e64392", "#f9b3d5")},
	{"purple", hexColors("#954ab5", "#9c46b9", "#d099d6")},
	{"red", hexColors("#e84053", "#e01b24", "#f2a1a5")},
	{"slate", hexColors("#557b9f", "#6a8daf", "#b4c6d6")},
	{"teal", hexColors("#129eb0", "#2190a4", "#7bdff4")},
	{"yellow", hexColors("#cbac10", "#d4b411", "#f5c211")},
}

func hexColors(hexes ...string) []colorful.Color {
	out := make([]colorful.Color, len(hexes))
	for i, h := range hexes {
		out[i], _ = colorful.Hex(h)
	}
	return out
}

func closestAdwaitaAccent(primaryHex string) string {
	c, err := colorful.Hex(primaryHex)
	if err != nil {
		return "blue"
	}

	best := "blue"
	bestDist := math.MaxFloat64
	for _, a := range adwaitaAccents {
		for _, ref := range a.colors {
			d := c.DistanceCIEDE2000(ref)
			if d < bestDist {
				bestDist = d
				best = a.name
			}
		}
	}
	return best
}

func syncAccentColor(primaryHex string) {
	accent := closestAdwaitaAccent(primaryHex)
	log.Infof("Setting GNOME accent color: %s", accent)
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "accent-color", accent); err != nil {
		log.Warnf("Failed to set accent-color: %v", err)
	}
}

type TemplateCheck struct {
	ID       string `json:"id"`
	Detected bool   `json:"detected"`
}

func CheckTemplates(checker utils.AppChecker) []TemplateCheck {
	if checker == nil {
		checker = utils.DefaultAppChecker{}
	}

	homeDir, _ := os.UserHomeDir()
	checks := make([]TemplateCheck, 0, len(templateRegistry))

	for _, tmpl := range templateRegistry {
		detected := false

		switch {
		case tmpl.RunUnconditionally:
			detected = true
		case tmpl.Kind == TemplateKindVSCode:
			detected = checkVSCodeExtension(homeDir)
		case tmpl.Kind == TemplateKindEmacs:
			detected = appExists(checker, tmpl.Commands, tmpl.Flatpaks) && utils.EmacsConfigDir() != ""
		default:
			detected = appExists(checker, tmpl.Commands, tmpl.Flatpaks)
		}

		checks = append(checks, TemplateCheck{ID: tmpl.ID, Detected: detected})
	}

	return checks
}

func checkVSCodeExtension(homeDir string) bool {
	extDirs := []string{
		filepath.Join(homeDir, ".vscode/extensions"),
		filepath.Join(homeDir, ".vscode-oss/extensions"),
		filepath.Join(homeDir, ".config/Code - OSS/extensions"),
		filepath.Join(homeDir, ".cursor/extensions"),
		filepath.Join(homeDir, ".windsurf/extensions"),
	}

	for _, extDir := range extDirs {
		pattern := filepath.Join(extDir, "danklinux.dms-theme-*")
		if matches, err := filepath.Glob(pattern); err == nil && len(matches) > 0 {
			return true
		}
	}
	return false
}
