package matugen

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/dank16"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
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
	{ID: "emacs", Commands: []string{"emacs"}, ConfigFile: "emacs.toml"},
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
	matugenVersionOnce sync.Once
	matugenSupportsCOE bool
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

	if err := os.MkdirAll(opts.StateDir, 0755); err != nil {
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

	refreshGTK(opts.ConfigDir, opts.Mode)
	signalTerminals()

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
		if err := os.WriteFile(tmpPath, []byte(modified), 0644); err != nil {
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

func checkMatugenVersion() {
	matugenVersionOnce.Do(func() {
		cmd := exec.Command("matugen", "--version")
		output, err := cmd.Output()
		if err != nil {
			return
		}

		versionStr := strings.TrimSpace(string(output))
		versionStr = strings.TrimPrefix(versionStr, "matugen ")

		parts := strings.Split(versionStr, ".")
		if len(parts) < 2 {
			return
		}

		major, err := strconv.Atoi(parts[0])
		if err != nil {
			return
		}

		minor, err := strconv.Atoi(parts[1])
		if err != nil {
			return
		}

		matugenSupportsCOE = major > 3 || (major == 3 && minor >= 1)
		if matugenSupportsCOE {
			log.Infof("Matugen %s supports --continue-on-error", versionStr)
		}
	})
}

func runMatugen(args []string) error {
	checkMatugenVersion()

	if matugenSupportsCOE {
		args = append([]string{"--continue-on-error"}, args...)
	}

	cmd := exec.Command("matugen", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func runMatugenDryRun(opts *Options) (string, error) {
	var args []string
	switch opts.Kind {
	case "hex":
		args = []string{"color", "hex", opts.Value}
	default:
		args = []string{opts.Kind, opts.Value}
	}
	args = append(args, "-m", "dark", "-t", opts.MatugenType, "--json", "hex", "--dry-run")

	cmd := exec.Command("matugen", args...)
	output, err := cmd.Output()
	if err != nil {
		return "", err
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

func refreshGTK(configDir string, mode ColorMode) {
	gtkCSS := filepath.Join(configDir, "gtk-3.0", "gtk.css")

	info, err := os.Lstat(gtkCSS)
	if err != nil {
		return
	}

	shouldRun := false
	if info.Mode()&os.ModeSymlink != 0 {
		target, err := os.Readlink(gtkCSS)
		if err == nil && strings.Contains(target, "dank-colors.css") {
			shouldRun = true
		}
	} else {
		data, err := os.ReadFile(gtkCSS)
		if err == nil && strings.Contains(string(data), "dank-colors.css") {
			shouldRun = true
		}
	}

	if !shouldRun {
		return
	}

	exec.Command("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "").Run()
	exec.Command("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", mode.GTKTheme()).Run()
}

func signalTerminals() {
	signalByName("kitty", syscall.SIGUSR1)
	signalByName("ghostty", syscall.SIGUSR2)
	signalByName(".kitty-wrapped", syscall.SIGUSR1)
	signalByName(".ghostty-wrappe", syscall.SIGUSR2)
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

	if err := exec.Command("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme).Run(); err != nil {
		exec.Command("dconf", "write", "/org/gnome/desktop/interface/color-scheme", "'"+scheme+"'").Run()
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
