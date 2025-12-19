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
	Mode                string
	IconTheme           string
	MatugenType         string
	RunUserTemplates    bool
	StockColors         string
	SyncModeWithPortal  bool
	TerminalsAlwaysDark bool
	SkipTemplates       string
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
		opts.Mode = "dark"
	}
	if opts.MatugenType == "" {
		opts.MatugenType = "scheme-tonal-spot"
	}
	if opts.IconTheme == "" {
		opts.IconTheme = "System Default"
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
		args := []string{"color", "hex", primaryDark, "-m", opts.Mode, "-t", opts.MatugenType, "-c", cfgFile.Name()}
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
		args = append(args, "-m", opts.Mode, "-t", opts.MatugenType, "-c", cfgFile.Name())
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
			cfgFile.WriteString(substituteShellDir(line, opts.ShellDir) + "\n")
		}
		cfgFile.WriteString("\n")
	}

	fmt.Fprintf(cfgFile, `[templates.dank]
input_path = '%s/matugen/templates/dank.json'
output_path = '%s'

`, opts.ShellDir, opts.ColorsOutput())

	if !opts.ShouldSkipTemplate("gtk") {
		switch opts.Mode {
		case "light":
			appendConfig(opts, cfgFile, "skip", "gtk3-light.toml")
		default:
			appendConfig(opts, cfgFile, "skip", "gtk3-dark.toml")
		}
	}

	if !opts.ShouldSkipTemplate("niri") {
		appendConfig(opts, cfgFile, "niri", "niri.toml")
	}
	if !opts.ShouldSkipTemplate("qt5ct") {
		appendConfig(opts, cfgFile, "qt5ct", "qt5ct.toml")
	}
	if !opts.ShouldSkipTemplate("qt6ct") {
		appendConfig(opts, cfgFile, "qt6ct", "qt6ct.toml")
	}
	if !opts.ShouldSkipTemplate("firefox") {
		appendConfig(opts, cfgFile, "firefox", "firefox.toml")
	}
	if !opts.ShouldSkipTemplate("pywalfox") {
		appendConfig(opts, cfgFile, "pywalfox", "pywalfox.toml")
	}
	if !opts.ShouldSkipTemplate("vesktop") {
		appendConfig(opts, cfgFile, "vesktop", "vesktop.toml")
	}

	if !opts.ShouldSkipTemplate("ghostty") {
		appendTerminalConfig(opts, cfgFile, tmpDir, "ghostty", "ghostty.toml")
	}
	if !opts.ShouldSkipTemplate("kitty") {
		appendTerminalConfig(opts, cfgFile, tmpDir, "kitty", "kitty.toml")
	}
	if !opts.ShouldSkipTemplate("foot") {
		appendTerminalConfig(opts, cfgFile, tmpDir, "foot", "foot.toml")
	}
	if !opts.ShouldSkipTemplate("alacritty") {
		appendTerminalConfig(opts, cfgFile, tmpDir, "alacritty", "alacritty.toml")
	}
	if !opts.ShouldSkipTemplate("wezterm") {
		appendTerminalConfig(opts, cfgFile, tmpDir, "wezterm", "wezterm.toml")
	}
	if !opts.ShouldSkipTemplate("nvim") {
		appendTerminalConfig(opts, cfgFile, tmpDir, "nvim", "neovim.toml")
	}

	if !opts.ShouldSkipTemplate("dgop") {
		appendConfig(opts, cfgFile, "dgop", "dgop.toml")
	}

	if !opts.ShouldSkipTemplate("kcolorscheme") {
		appendConfig(opts, cfgFile, "skip", "kcolorscheme.toml")
	}

	if !opts.ShouldSkipTemplate("vscode") {
		homeDir, _ := os.UserHomeDir()
		appendVSCodeConfig(cfgFile, "vscode", filepath.Join(homeDir, ".vscode/extensions/local.dynamic-base16-dankshell-0.0.1"), opts.ShellDir)
		appendVSCodeConfig(cfgFile, "codium", filepath.Join(homeDir, ".vscode-oss/extensions/local.dynamic-base16-dankshell-0.0.1"), opts.ShellDir)
		appendVSCodeConfig(cfgFile, "codeoss", filepath.Join(homeDir, ".config/Code - OSS/extensions/local.dynamic-base16-dankshell-0.0.1"), opts.ShellDir)
		appendVSCodeConfig(cfgFile, "cursor", filepath.Join(homeDir, ".cursor/extensions/local.dynamic-base16-dankshell-0.0.1"), opts.ShellDir)
		appendVSCodeConfig(cfgFile, "windsurf", filepath.Join(homeDir, ".windsurf/extensions/local.dynamic-base16-dankshell-0.0.1"), opts.ShellDir)
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

func appendConfig(opts *Options, cfgFile *os.File, checkCmd, fileName string) {
	configPath := filepath.Join(opts.ShellDir, "matugen", "configs", fileName)
	if _, err := os.Stat(configPath); err != nil {
		return
	}
	if checkCmd != "skip" && !utils.CommandExists(checkCmd) {
		return
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return
	}
	cfgFile.WriteString(substituteShellDir(string(data), opts.ShellDir))
	cfgFile.WriteString("\n")
}

func appendTerminalConfig(opts *Options, cfgFile *os.File, tmpDir, checkCmd, fileName string) {
	configPath := filepath.Join(opts.ShellDir, "matugen", "configs", fileName)
	if _, err := os.Stat(configPath); err != nil {
		return
	}
	if checkCmd != "skip" && !utils.CommandExists(checkCmd) {
		return
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return
	}

	content := string(data)

	if !opts.TerminalsAlwaysDark {
		cfgFile.WriteString(substituteShellDir(content, opts.ShellDir))
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

	cfgFile.WriteString(substituteShellDir(content, opts.ShellDir))
	cfgFile.WriteString("\n")
}

func appendVSCodeConfig(cfgFile *os.File, name, extDir, shellDir string) {
	if _, err := os.Stat(extDir); err != nil {
		return
	}
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

func substituteShellDir(content, shellDir string) string {
	return strings.ReplaceAll(content, "'SHELL_DIR/", "'"+shellDir+"/")
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

func generateDank16Variants(primaryDark, primaryLight, surface, mode string) string {
	variantOpts := dank16.VariantOptions{
		PrimaryDark:  primaryDark,
		PrimaryLight: primaryLight,
		Background:   surface,
		UseDPS:       true,
		IsLightMode:  mode == "light",
	}
	variantColors := dank16.GenerateVariantPalette(variantOpts)
	return dank16.GenerateVariantJSON(variantColors)
}

func refreshGTK(configDir, mode string) {
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
	exec.Command("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "adw-gtk3-"+mode).Run()
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

func syncColorScheme(mode string) {
	scheme := "prefer-dark"
	if mode == "light" {
		scheme = "default"
	}

	if err := exec.Command("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme).Run(); err != nil {
		exec.Command("dconf", "write", "/org/gnome/desktop/interface/color-scheme", "'"+scheme+"'").Run()
	}
}
