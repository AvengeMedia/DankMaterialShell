package matugen

import (
	"bytes"
	"encoding/json"
	"errors"
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
	"github.com/godbus/dbus/v5"
	"github.com/lucasb-eyer/go-colorful"
)

var ErrNoChanges = errors.New("no color changes")

type ColorMode string

const (
	ColorModeDark  ColorMode = "dark"
	ColorModeLight ColorMode = "light"
	ColorModeSmart ColorMode = "smart"
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
	ConfigDirs         []string
	ConfigFile         string
	FlatpakConfigPath  string
	Kind               TemplateKind
	RunUnconditionally bool
	RequiredEnv        string
}

var templateRegistry = []TemplateDef{
	{ID: "gtk", Kind: TemplateKindGTK, RunUnconditionally: true},
	{ID: "niri", Commands: []string{"niri"}, ConfigFile: "niri.toml"},
	{ID: "hyprland", Commands: []string{"Hyprland"}, ConfigFile: "hyprland.toml"},
	{ID: "mangowc", Commands: []string{"mango"}, ConfigFile: "mangowc.toml", RequiredEnv: "MANGO_INSTANCE_SIGNATURE"},
	{ID: "qt5ct", Commands: []string{"qt5ct"}, ConfigFile: "qt5ct.toml"},
	{ID: "qt6ct", Commands: []string{"qt6ct"}, ConfigFile: "qt6ct.toml"},
	{ID: "fcitx5", Commands: []string{"fcitx5"}, ConfigDirs: []string{"fcitx5"}, ConfigFile: "fcitx5.toml"},
	{ID: "firefox", Commands: []string{"firefox"}, ConfigFile: "firefox.toml"},
	{ID: "pywalfox", Commands: []string{"pywalfox"}, ConfigFile: "pywalfox.toml"},
	{ID: "zenbrowser", Commands: []string{"zen", "zen-browser", "zen-beta", "zen-twilight"}, Flatpaks: []string{"app.zen_browser.zen"}, ConfigFile: "zenbrowser.toml"},
	{ID: "vesktop", Commands: []string{"vesktop"}, Flatpaks: []string{"dev.vencord.Vesktop"}, ConfigDirs: []string{"vesktop"}, ConfigFile: "vesktop.toml", FlatpakConfigPath: "dev.vencord.Vesktop/config"},
	{ID: "vencord", Commands: []string{"discord", "Discord", "discord-canary", "DiscordCanary"}, Flatpaks: []string{"com.discordapp.Discord", "com.discordapp.DiscordCanary"}, ConfigDirs: []string{"Vencord"}, ConfigFile: "vencord.toml"},
	{ID: "equibop", Commands: []string{"equibop"}, ConfigDirs: []string{"equibop"}, ConfigFile: "equibop.toml"},
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
	{ID: "zed", Commands: []string{"zed", "zeditor", "zedit"}, ConfigFile: "zed.toml"},
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
	matugenVersionMu      sync.Mutex
	matugenVersionOK      bool
	matugenSupportsCOE    bool
	matugenIsV4           bool
	matugenIsV42          bool
	matugenSupportsPrefer bool
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
	Contrast            float64
	SourceMode          string
	RunUserTemplates    bool
	ColorsOnly          bool
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

type SchemePreview struct {
	Dark  string `json:"dark"`
	Light string `json:"light"`
}

var previewSchemeTypes = []string{
	"scheme-tonal-spot",
	"scheme-vibrant",
	"scheme-content",
	"scheme-expressive",
	"scheme-fidelity",
	"scheme-fruit-salad",
	"scheme-monochrome",
	"scheme-neutral",
	"scheme-rainbow",
}

func PreviewSchemes(sourceColor string, contrast float64, imagePath string) (map[string]SchemePreview, error) {
	if sourceColor == "" {
		return nil, fmt.Errorf("source color is required")
	}

	previews := make(map[string]SchemePreview, len(previewSchemeTypes)+1)
	for _, schemeType := range previewSchemeTypes {
		output, err := runMatugenDryRun(&Options{
			Kind:        "hex",
			Value:       sourceColor,
			Mode:        ColorModeDark,
			MatugenType: schemeType,
			Contrast:    contrast,
		})
		if err != nil {
			return nil, fmt.Errorf("preview %s: %w", schemeType, err)
		}

		dark := extractMatugenColor(output, "primary", "dark")
		light := extractMatugenColor(output, "primary", "light")
		if dark == "" || light == "" {
			return nil, fmt.Errorf("preview %s: primary colors missing from matugen output", schemeType)
		}
		previews[schemeType] = SchemePreview{Dark: dark, Light: light}
	}

	previews["scheme-smart"] = smartSchemePreview(previews["scheme-tonal-spot"], contrast, imagePath)
	return previews, nil
}

func smartSchemePreview(fallback SchemePreview, contrast float64, imagePath string) SchemePreview {
	if imagePath == "" {
		return fallback
	}
	flags, err := detectMatugenVersion()
	if err != nil || !flags.isV42 {
		return fallback
	}
	output, err := runMatugenDryRun(&Options{
		Kind:        "image",
		Value:       imagePath,
		Mode:        ColorModeDark,
		MatugenType: "scheme-smart",
		Contrast:    contrast,
	})
	if err != nil {
		log.Warnf("Smart scheme preview failed falling back to tonal-spot: %v", err)
		return fallback
	}
	dark := extractMatugenColor(output, "primary", "dark")
	light := extractMatugenColor(output, "primary", "light")
	if dark == "" || light == "" {
		log.Warn("Smart scheme preview failed falling back to tonal-spot: primary colors missing from matugen output")
		return fallback
	}
	return SchemePreview{Dark: dark, Light: light}
}

func (o *Options) ColorsOutput() string {
	return filepath.Join(o.StateDir, "dms-colors.json")
}

func (o *Options) colorsStaging() string {
	return o.ColorsOutput() + ".tmp"
}

func (o *Options) ShouldSkipTemplate(name string) bool {
	if o.SkipTemplates == "" {
		return false
	}
	for skip := range strings.SplitSeq(o.SkipTemplates, ",") {
		if strings.TrimSpace(skip) == name {
			return true
		}
	}
	return false
}

func acquireMatugenLock(stateDir string) (*os.File, error) {
	f, err := os.OpenFile(filepath.Join(stateDir, "matugen.lock"), os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return nil, fmt.Errorf("failed to open matugen lock: %w", err)
	}

	deadline := time.Now().Add(45 * time.Second)
	for {
		switch err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err {
		case nil:
			return f, nil
		case syscall.EWOULDBLOCK:
			if time.Now().After(deadline) {
				f.Close()
				return nil, fmt.Errorf("timed out waiting for matugen lock")
			}
			time.Sleep(100 * time.Millisecond)
		default:
			f.Close()
			return nil, fmt.Errorf("failed to lock matugen: %w", err)
		}
	}
}

func releaseMatugenLock(f *os.File) {
	if f == nil {
		return
	}
	_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	f.Close()
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

	lock, err := acquireMatugenLock(opts.StateDir)
	if err != nil {
		return err
	}
	defer releaseMatugenLock(lock)

	log.Infof("Building theme: %s %s (%s)", opts.Kind, opts.Value, opts.Mode)

	changed, buildErr := buildOnce(&opts)
	if buildErr != nil {
		return buildErr
	}

	if opts.SyncModeWithPortal {
		syncColorScheme(opts.Mode)
	}

	if !changed {
		log.Info("No color changes detected, skipping refresh")
		return ErrNoChanges
	}

	log.Info("Done")
	return nil
}

func buildOnce(opts *Options) (bool, error) {
	defer os.Remove(opts.colorsStaging())

	flags, err := detectMatugenVersion()
	if err != nil {
		return false, err
	}
	if err := resolveSmartMode(opts, flags); err != nil {
		return false, err
	}

	cfgFile, err := os.CreateTemp("", "matugen-config-*.toml")
	if err != nil {
		return false, fmt.Errorf("failed to create temp config: %w", err)
	}
	defer os.Remove(cfgFile.Name())
	defer cfgFile.Close()

	tmpDir, err := os.MkdirTemp("", "matugen-templates-*")
	if err != nil {
		return false, fmt.Errorf("failed to create temp dir: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	if err := buildMergedConfig(opts, cfgFile, tmpDir); err != nil {
		return false, fmt.Errorf("failed to build config: %w", err)
	}
	cfgFile.Close()

	oldColors, _ := os.ReadFile(opts.ColorsOutput())

	var primaryDark, primaryLight, surface string
	var dank16JSON string
	var importArgs []string
	var sourceImage string

	// Colorful mode resolves the seed here, before matugen is invoked at all,
	// by rewriting the source to the extracted hex. Both the dry-run and the
	// real run below read opts.Kind/opts.Value, so one rewrite covers both and
	// they cannot disagree about the seed. Extraction failure (a format
	// image.Decode cannot read, an unreadable file) falls through to matugen's
	// own extraction: this must never fail a theme build.
	if opts.StockColors == "" && opts.Kind == "image" && opts.SourceMode == SourceModeColorful {
		if seed, err := ExtractSourceColor(opts.Value); err != nil {
			log.Warnf("Colorful source extraction failed for %s, using matugen's own: %v", opts.Value, err)
		} else {
			log.Infof("Colorful source color: %s -> %s", opts.Value, seed)
			// matugen resolves {{image}} to an absolute path, so match it.
			sourceImage = opts.Value
			if abs, err := filepath.Abs(sourceImage); err == nil {
				sourceImage = abs
			}
			opts.Kind = "hex"
			opts.Value = seed
		}
	}

	if opts.StockColors != "" {
		log.Info("Using stock/custom theme colors with matugen base")
		primaryDark = extractNestedColor(opts.StockColors, "primary", "dark")
		primaryLight = extractNestedColor(opts.StockColors, "primary", "light")
		surface = extractNestedColor(opts.StockColors, "surface", "dark")

		if primaryDark == "" {
			return false, fmt.Errorf("failed to extract primary dark from stock colors")
		}
		if primaryLight == "" {
			primaryLight = primaryDark
		}

		dank16JSON = generateDank16Variants(primaryDark, primaryLight, surface, opts.Mode)
		importData := fmt.Sprintf(`{"colors": %s, "dank16": %s}`, opts.StockColors, dank16JSON)
		importArgs = []string{"--import-json-string", importData}

		log.Info("Running matugen color hex with stock color overrides")
		args := []string{"color", "hex", primaryDark, "-m", string(opts.Mode), "-t", opts.MatugenType, "-c", cfgFile.Name()}
		args = appendContrastArg(args, opts.Contrast)
		args = append(args, importArgs...)
		if err := runMatugen(args, opts.SourceMode); err != nil {
			return false, err
		}
	} else {
		log.Infof("Using dynamic theme from %s: %s", opts.Kind, opts.Value)

		matJSON, err := runMatugenDryRun(opts)
		if err != nil {
			return false, fmt.Errorf("matugen dry-run failed: %w", err)
		}

		primaryDark = extractMatugenColor(matJSON, "primary", "dark")
		primaryLight = extractMatugenColor(matJSON, "primary", "light")
		surface = extractMatugenColor(matJSON, "surface", "dark")

		if primaryDark == "" {
			return false, fmt.Errorf("failed to extract primary color")
		}
		if primaryLight == "" {
			primaryLight = primaryDark
		}

		dank16JSON = generateDank16Variants(primaryDark, primaryLight, surface, opts.Mode)
		importArgs = []string{"--import-json-string", buildImportData(dank16JSON, sourceImage)}

		log.Infof("Running matugen %s with dank16 injection", opts.Kind)
		var args []string
		switch opts.Kind {
		case "hex":
			args = []string{"color", "hex", opts.Value}
		default:
			args = []string{opts.Kind, opts.Value}
		}
		args = append(args, "-m", string(opts.Mode), "-t", opts.MatugenType, "-c", cfgFile.Name())
		args = appendContrastArg(args, opts.Contrast)
		args = append(args, importArgs...)
		if err := runMatugen(args, opts.SourceMode); err != nil {
			return false, err
		}
	}

	newColors, err := os.ReadFile(opts.colorsStaging())
	if err != nil {
		return false, fmt.Errorf("matugen did not produce colors output: %w", err)
	}
	if bytes.Equal(oldColors, newColors) && len(oldColors) > 0 {
		return false, nil
	}
	if err := os.Rename(opts.colorsStaging(), opts.ColorsOutput()); err != nil {
		return false, fmt.Errorf("failed to commit colors output: %w", err)
	}

	if opts.ColorsOnly {
		return true, nil
	}

	if isDMSGTKActive(opts.ConfigDir) {
		switch opts.Mode {
		case ColorModeLight:
			syncAccentColor(primaryLight)
		default:
			syncAccentColor(primaryDark)
		}
		refreshGTKTheme(opts.Mode)
		refreshGTKColorScheme()
	}

	if isDMSKDEColorSchemeActive(opts.ConfigDir) {
		applyKDEColorScheme(opts.Mode)
	}

	if !opts.ShouldSkipTemplate("qt6ct") && appExists(opts.AppChecker, []string{"qt6ct"}, nil) {
		refreshQt6ct()
	}

	// kcolorscheme writes the .colors file qtengine is pointed at, so with that
	// template off there is nothing to point to and the config would name a
	// scheme DMS no longer generates.
	if !opts.ShouldSkipTemplate("qtengine") && !opts.ShouldSkipTemplate("kcolorscheme") && QtengineActive() {
		if err := SyncQtengineConfigAt(opts.ConfigDir, opts.IconTheme); err != nil {
			log.Warnf("Failed to sync qtengine config: %v", err)
		}
	}

	signalTerminals(opts)
	if !opts.ShouldSkipTemplate("fcitx5") && appExists(opts.AppChecker, []string{"fcitx5"}, nil) {
		refreshFcitx5()
	}

	return true, nil
}

func appendContrastArg(args []string, contrast float64) []string {
	if contrast == 0 {
		return args
	}
	return append(args, "--contrast", strconv.FormatFloat(contrast, 'f', -1, 64))
}

// buildImportData is the JSON passed to matugen's --import-json-string. image is
// set only when the source was rewritten from a wallpaper to a hex color, where
// matugen leaves {{image}} unset and templates using it would render "Null".
func buildImportData(dank16JSON, image string) string {
	if image == "" {
		return fmt.Sprintf(`{"dank16": %s}`, dank16JSON)
	}
	path, _ := json.Marshal(image)
	return fmt.Sprintf(`{"dank16": %s, "image": %s}`, dank16JSON, path)
}

func userConfigSection(opts *Options) string {
	if !opts.RunUserTemplates || opts.ConfigDir == "" {
		return "[config]\n\n"
	}
	data, err := os.ReadFile(filepath.Join(opts.ConfigDir, "matugen", "config.toml"))
	if err != nil {
		return "[config]\n\n"
	}
	section := extractTOMLSection(string(data), "[config]", "[templates]")
	if section == "" {
		return "[config]\n\n"
	}
	return section + "\n"
}

func buildMergedConfig(opts *Options, cfgFile *os.File, tmpDir string) error {
	userConfigPath := filepath.Join(opts.ConfigDir, "matugen", "config.toml")

	cfgFile.WriteString(userConfigSection(opts))

	baseConfigPath := filepath.Join(opts.ShellDir, "matugen", "configs", "base.toml")
	if data, err := os.ReadFile(baseConfigPath); err == nil {
		content := string(data)
		lines := strings.SplitSeq(content, "\n")
		for line := range lines {
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

`, opts.ShellDir, opts.colorsStaging())

	if opts.ColorsOnly {
		return nil
	}

	homeDir, _ := os.UserHomeDir()
	for _, tmpl := range templateRegistry {
		if opts.ShouldSkipTemplate(tmpl.ID) {
			continue
		}
		if !templateSessionActive(tmpl) {
			continue
		}

		switch tmpl.Kind {
		case TemplateKindGTK:
			switch opts.Mode {
			case ColorModeLight:
				appendConfig(opts, cfgFile, nil, nil, nil, "gtk3-light.toml")
			default:
				appendConfig(opts, cfgFile, nil, nil, nil, "gtk3-dark.toml")
			}
		case TemplateKindTerminal:
			appendTerminalConfig(opts, cfgFile, tmpDir, tmpl.Commands, tmpl.Flatpaks, tmpl.ConfigFile)
		case TemplateKindVSCode:
			for _, editor := range vscodeEditors {
				appendVSCodeConfig(cfgFile, editor.name, editor.extensionsDir(homeDir), opts.ShellDir)
			}
		case TemplateKindEmacs:
			if utils.EmacsConfigDir() != "" {
				appendConfig(opts, cfgFile, tmpl.Commands, tmpl.Flatpaks, tmpl.ConfigDirs, tmpl.ConfigFile)
			}
		default:
			flatpaks := tmpl.Flatpaks
			if tmpl.FlatpakConfigPath != "" {
				flatpaks = nil
			}
			appendConfig(opts, cfgFile, tmpl.Commands, flatpaks, tmpl.ConfigDirs, tmpl.ConfigFile)
			if tmpl.FlatpakConfigPath != "" {
				appendFlatpakConfig(opts, cfgFile, tmpl.Flatpaks, tmpl.ConfigFile, tmpl.FlatpakConfigPath)
			}
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
	checkConfigDirs []string,
	fileName string,
) {
	appendConfigContent(opts, cfgFile, checkCmd, checkFlatpaks, checkConfigDirs, fileName, "")
}

func appendFlatpakConfig(opts *Options, cfgFile *os.File, checkFlatpaks []string, fileName, configPath string) {
	appendConfigContent(opts, cfgFile, nil, checkFlatpaks, nil, fileName, configPath)
}

func appendConfigContent(
	opts *Options,
	cfgFile *os.File,
	checkCmd []string,
	checkFlatpaks []string,
	checkConfigDirs []string,
	fileName string,
	flatpakConfigPath string,
) {
	configPath := filepath.Join(opts.ShellDir, "matugen", "configs", fileName)
	if _, err := os.Stat(configPath); err != nil {
		return
	}
	if !appExists(opts.AppChecker, checkCmd, checkFlatpaks) && !configDirExists(checkConfigDirs) {
		log.Debugf("Skipping template %s: app not detected", strings.TrimSuffix(fileName, ".toml"))
		return
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return
	}
	content := string(data)
	if flatpakConfigPath != "" {
		content = strings.ReplaceAll(content, "'CONFIG_DIR/", "'FLATPAK_CONFIG_DIR/"+flatpakConfigPath+"/")
		lines := strings.Split(content, "\n")
		for i, line := range lines {
			if strings.HasPrefix(line, "[templates.") && strings.HasSuffix(line, "]") {
				lines[i] = strings.TrimSuffix(line, "]") + "-flatpak]"
			}
		}
		content = strings.Join(lines, "\n")
	}
	cfgFile.WriteString(substituteVars(content, opts.ShellDir))
	cfgFile.WriteString("\n")
}

func appendTerminalConfig(opts *Options, cfgFile *os.File, tmpDir string, checkCmd []string, checkFlatpaks []string, fileName string) {
	configPath := filepath.Join(opts.ShellDir, "matugen", "configs", fileName)
	if _, err := os.Stat(configPath); err != nil {
		return
	}
	if !appExists(opts.AppChecker, checkCmd, checkFlatpaks) {
		log.Debugf("Skipping template %s: app not detected", strings.TrimSuffix(fileName, ".toml"))
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

	lines := strings.SplitSeq(content, "\n")
	for line := range lines {
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

func templateSessionActive(tmpl TemplateDef) bool {
	if tmpl.RequiredEnv == "" {
		return true
	}
	socket := os.Getenv(tmpl.RequiredEnv)
	if socket == "" {
		return false
	}
	_, err := os.Stat(socket)
	return err == nil
}

func configDirExists(names []string) bool {
	configHome := utils.XDGConfigHome()
	if configHome == "" {
		return false
	}
	for _, name := range names {
		info, err := os.Stat(filepath.Join(configHome, name))
		if err == nil && info.IsDir() {
			return true
		}
	}
	return false
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

type vscodeEditor struct {
	name    string
	dataDir string
}

var vscodeEditors = []vscodeEditor{
	{"vscode", ".vscode"},
	{"codium", ".vscode-oss"},
	{"cursor", ".cursor"},
	{"windsurf", ".windsurf"},
	{"vscode-insiders", ".vscode-insiders"},
}

func (e vscodeEditor) extensionsDir(homeDir string) string {
	return filepath.Join(homeDir, e.dataDir, "extensions")
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
	if homeDir, err := os.UserHomeDir(); err == nil {
		result = strings.ReplaceAll(result, "'FLATPAK_CONFIG_DIR/", "'"+filepath.Join(homeDir, ".var", "app")+"/")
	}
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
	supportsCOE    bool
	isV4           bool
	isV42          bool
	supportsPrefer bool
}

func detectMatugenVersion() (matugenFlags, error) {
	matugenVersionMu.Lock()
	defer matugenVersionMu.Unlock()

	if matugenVersionOK {
		return matugenFlags{matugenSupportsCOE, matugenIsV4, matugenIsV42, matugenSupportsPrefer}, nil
	}

	return detectMatugenVersionLocked()
}

func SupportsSmart() bool {
	flags, err := detectMatugenVersion()
	return err == nil && flags.isV42
}

func redetectMatugenVersion(old matugenFlags) (matugenFlags, bool) {
	matugenVersionMu.Lock()
	defer matugenVersionMu.Unlock()

	matugenVersionOK = false
	flags, err := detectMatugenVersionLocked()
	if err != nil {
		return old, false
	}
	changed := flags.supportsCOE != old.supportsCOE || flags.isV4 != old.isV4 || flags.isV42 != old.isV42 ||
		flags.supportsPrefer != old.supportsPrefer
	return flags, changed
}

func detectMatugenVersionLocked() (matugenFlags, error) {
	cmd := exec.Command("matugen", "--version")
	cmd.Env = utils.EnvWithUserBinPath(nil)
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
	matugenIsV42 = major > 4 || (major == 4 && minor >= 2)
	// --prefer landed in 4.1; 4.0.x has --source-color-index but not --prefer,
	// and clap aborts on an unknown argument rather than ignoring it.
	matugenSupportsPrefer = major > 4 || (major == 4 && minor >= 1)
	matugenVersionOK = true

	if matugenSupportsCOE {
		log.Debugf("Matugen %s detected: continue-on-error support enabled", versionStr)
	}
	if matugenIsV4 {
		log.Debugf("Matugen %s detected: using v4 compatibility flags", versionStr)
	}
	if matugenIsV4 && !matugenSupportsPrefer {
		log.Debugf("Matugen %s detected: --prefer unavailable, source modes fall back to the dominant color", versionStr)
	}
	return matugenFlags{matugenSupportsCOE, matugenIsV4, matugenIsV42, matugenSupportsPrefer}, nil
}

func buildMatugenArgs(baseArgs []string, flags matugenFlags, sourceMode string) []string {
	args := make([]string, 0, len(baseArgs)+4)
	if flags.supportsCOE {
		args = append(args, "--continue-on-error")
	}
	args = append(args, baseArgs...)
	// matugen 3 has neither flag. matugen 4's --source-color-index help notes
	// "In earlier versions the default was 0", so omitting both on v3 gives the
	// same seed the flag would have asked for.
	if flags.isV4 {
		args = append(args, sourceSelectionArgs(sourceMode, flags.supportsPrefer)...)
	}
	return args
}

func runMatugen(baseArgs []string, sourceMode string) error {
	flags, err := detectMatugenVersion()
	if err != nil {
		return err
	}

	args := buildMatugenArgs(baseArgs, flags, sourceMode)
	cmd := exec.Command("matugen", args...)
	cmd.Env = utils.EnvWithUserBinPath(nil)
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
	args = buildMatugenArgs(baseArgs, newFlags, sourceMode)
	retryCmd := exec.Command("matugen", args...)
	retryCmd.Env = utils.EnvWithUserBinPath(nil)
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

// matugen aborts on a config file it cannot deserialize, and without -c it
// reads the user's own ~/.config/matugen/config.toml, so a dry run gets a
// config of its own instead of inheriting whatever is there.
func writeDryRunConfig(opts *Options) (string, error) {
	cfgFile, err := os.CreateTemp("", "matugen-dryrun-*.toml")
	if err != nil {
		return "", fmt.Errorf("failed to create dry-run config: %w", err)
	}
	defer cfgFile.Close()

	section := userConfigSection(opts)
	if idx := strings.Index(section, "\n[templates"); idx != -1 {
		section = section[:idx+1]
	}
	cfgFile.WriteString(section)
	cfgFile.WriteString("[templates]\n")
	return cfgFile.Name(), nil
}

func execDryRun(opts *Options, flags matugenFlags) (string, error) {
	cfgPath, err := writeDryRunConfig(opts)
	if err != nil {
		return "", err
	}
	defer os.Remove(cfgPath)

	var baseArgs []string
	switch opts.Kind {
	case "hex":
		baseArgs = []string{"color", "hex", opts.Value}
	default:
		baseArgs = []string{opts.Kind, opts.Value}
	}
	baseArgs = append(baseArgs, "-m", string(opts.Mode), "-t", opts.MatugenType, "-c", cfgPath, "--json", "hex", "--dry-run")
	baseArgs = appendContrastArg(baseArgs, opts.Contrast)
	if flags.isV4 {
		baseArgs = append(baseArgs, sourceSelectionArgs(opts.SourceMode, flags.supportsPrefer)...)
		baseArgs = append(baseArgs, "--old-json-output")
	}

	cmd := exec.Command("matugen", baseArgs...)
	cmd.Env = utils.EnvWithUserBinPath(nil)
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

func extractTopLevelString(jsonStr, key string) string {
	var data map[string]any
	if err := json.Unmarshal([]byte(jsonStr), &data); err != nil {
		return ""
	}
	if val, ok := data[key].(string); ok {
		return val
	}
	return ""
}

func resolveSmartMode(opts *Options, flags matugenFlags) error {
	if opts.MatugenType == "scheme-smart" && !flags.isV42 {
		return fmt.Errorf("scheme-smart requires matugen 4.2+")
	}
	if opts.Mode != ColorModeSmart {
		return nil
	}
	if !flags.isV42 {
		return fmt.Errorf("smart mode requires matugen 4.2+")
	}
	if opts.Kind != "image" || opts.StockColors != "" {
		opts.Mode = ColorModeDark
		return nil
	}
	output, err := runMatugenDryRun(opts)
	if err != nil {
		return fmt.Errorf("smart mode resolution failed: %w", err)
	}
	resolved := extractTopLevelString(output, "mode")
	if resolved != string(ColorModeLight) && resolved != string(ColorModeDark) {
		return fmt.Errorf("smart mode resolution returned unexpected mode %q", resolved)
	}
	log.Infof("Smart mode resolved to %s", resolved)
	opts.Mode = ColorMode(resolved)
	return nil
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
	gtkCSS := filepath.Join(configDir, "gtk-4.0", "gtk.css")

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

// isDMSKDEColorSchemeActive only flips the scheme when the user is already on a
// DankMatugen one, leaving Breeze (or anything else) untouched.
func isDMSKDEColorSchemeActive(configDir string) bool {
	data, err := os.ReadFile(filepath.Join(configDir, "kdeglobals"))
	if err != nil {
		return false
	}

	inGeneral := false
	for line := range strings.SplitSeq(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") {
			inGeneral = line == "[General]"
			continue
		}
		if !inGeneral {
			continue
		}
		if name, ok := strings.CutPrefix(line, "ColorScheme="); ok {
			return strings.HasPrefix(strings.TrimSpace(name), "DankMatugen")
		}
	}
	return false
}

func applyKDEColorScheme(mode ColorMode) {
	if !utils.CommandExists("plasma-apply-colorscheme") {
		return
	}

	scheme := "DankMatugenDark"
	if mode == ColorModeLight {
		scheme = "DankMatugenLight"
	}

	log.Infof("Applying KDE color scheme: %s", scheme)
	if err := exec.Command("plasma-apply-colorscheme", scheme).Run(); err != nil {
		log.Warnf("Failed to apply KDE color scheme: %v", err)
	}
}

func gtkThemeInstalled(theme string) bool {
	home, _ := os.UserHomeDir()
	candidates := []string{
		filepath.Join(home, ".local/share/themes", theme),
		filepath.Join(home, ".themes", theme),
		filepath.Join("/usr/share/themes", theme),
		filepath.Join("/usr/local/share/themes", theme),
	}
	for _, dir := range candidates {
		if info, err := os.Stat(dir); err == nil && info.IsDir() {
			return true
		}
	}
	return false
}

func refreshGTKTheme(mode ColorMode) {
	theme := mode.GTKTheme()
	if !gtkThemeInstalled(theme) {
		log.Infof("Skipping gtk-theme refresh: %s is not installed", theme)
		return
	}
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "gtk-theme", ""); err != nil {
		log.Warnf("Failed to reset gtk-theme: %v", err)
	}
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "gtk-theme", theme); err != nil {
		log.Warnf("Failed to set gtk-theme: %v", err)
	}
}

var colorSchemeEchoHook func(scheme string)

func SetColorSchemeEchoHook(hook func(scheme string)) {
	colorSchemeEchoHook = hook
}

func expectColorSchemeEcho(scheme string) {
	if colorSchemeEchoHook != nil {
		colorSchemeEchoHook(scheme)
	}
}

// The color-scheme round trip is the only mechanism that makes running GTK4
// apps reload ~/.config/gtk-4.0 CSS (a gtk-theme flip does not). But apps
// following the portal color-scheme (Chromium) can drop the restore signal
// mid-repaint and latch the wrong mode, so this is opt-in.
func refreshGTKColorScheme() {
	if os.Getenv("DMS_ENABLE_GTK_REFRESH") != "1" {
		return
	}
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

	expectColorSchemeEcho(toggle)
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "color-scheme", toggle); err != nil {
		log.Warnf("Failed to toggle color-scheme for GTK refresh: %v", err)
		return
	}
	time.Sleep(50 * time.Millisecond)
	expectColorSchemeEcho(current)
	if err := utils.GsettingsSet("org.gnome.desktop.interface", "color-scheme", current); err != nil {
		log.Warnf("Failed to restore color-scheme for GTK refresh: %v", err)
	}
}

func refreshQt6ct() {
	confPath := filepath.Join(utils.XDGConfigHome(), "qt6ct", "qt6ct.conf")
	now := time.Now()
	if err := os.Chtimes(confPath, now, now); err != nil {
		log.Warnf("Failed to touch qt6ct.conf: %v", err)
	}
}

func refreshFcitx5() {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		log.Debugf("Failed to connect to session bus for Fcitx5 refresh: %v", err)
		return
	}
	defer conn.Close()

	obj := conn.Object("org.fcitx.Fcitx5", dbus.ObjectPath("/controller"))
	if err := obj.Call("org.fcitx.Fcitx.Controller1.ReloadAddonConfig", 0, "classicui").Err; err != nil {
		log.Debugf("Failed to refresh Fcitx5 theme: %v", err)
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

func syncColorScheme(mode ColorMode) {
	scheme := "prefer-dark"
	if mode == ColorModeLight {
		scheme = "default"
	}

	if cur, err := utils.GsettingsGet("org.gnome.desktop.interface", "color-scheme"); err == nil {
		cur = strings.Trim(cur, "'")
		if cur == scheme || (mode == ColorModeLight && cur == "prefer-light") {
			return
		}
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
	if cur, err := utils.GsettingsGet("org.gnome.desktop.interface", "accent-color"); err == nil && strings.Trim(cur, "'") == accent {
		return
	}
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
	checks := make([]TemplateCheck, 0, len(templateRegistry)+1)

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
			detected = (appExists(checker, tmpl.Commands, tmpl.Flatpaks) || configDirExists(tmpl.ConfigDirs)) && templateSessionActive(tmpl)
		}

		checks = append(checks, TemplateCheck{ID: tmpl.ID, Detected: detected})
	}

	// qtengine is not a matugen template and ships no binary, so it has no
	// templateRegistry entry to detect; the settings row still needs an honest
	// indicator, which is the platform theme env var.
	checks = append(checks, TemplateCheck{ID: "qtengine", Detected: QtengineActive()})

	return checks
}

func checkVSCodeExtension(homeDir string) bool {
	for _, editor := range vscodeEditors {
		pattern := filepath.Join(editor.extensionsDir(homeDir), "danklinux.dms-theme-*")
		if matches, err := filepath.Glob(pattern); err == nil && len(matches) > 0 {
			return true
		}
	}
	return false
}
