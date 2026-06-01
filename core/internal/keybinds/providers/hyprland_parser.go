package providers

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/luaconfig"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

const (
	TitleRegex         = "#+!"
	HideComment        = "[hidden]"
	CommentBindPattern = "#/#"
)

var ModSeparators = []rune{'+', ' '}

type HyprlandKeyBinding struct {
	Mods       []string `json:"mods"`
	Key        string   `json:"key"`
	Dispatcher string   `json:"dispatcher"`
	Params     string   `json:"params"`
	Comment    string   `json:"comment"`
	Source     string   `json:"source"`
	Flags      string   `json:"flags"` // Bind flags: l=locked, r=release, e=repeat, n=non-consuming, m=mouse, t=transparent, i=ignore-mods, s=separate, d=description, o=long-press
}

type HyprlandSection struct {
	Children []HyprlandSection    `json:"children"`
	Keybinds []HyprlandKeyBinding `json:"keybinds"`
	Name     string               `json:"name"`
}

type HyprlandParser struct {
	contentLines       []string
	readingLine        int
	configDir          string
	currentSource      string
	dmsBindsExists     bool
	dmsBindsIncluded   bool
	includeCount       int
	dmsIncludePos      int
	bindsAfterDMS      int
	dmsBindKeys        map[string]bool
	configBindKeys     map[string]bool
	conflictingConfigs map[string]*HyprlandKeyBinding
	bindMap            map[string]*HyprlandKeyBinding
	bindOrder          []string
	processedFiles     map[string]bool
	dmsProcessed       bool
	removedKeys        map[string]bool // bare hl.unbind targets (negative overrides)
	defaultDMSKeys     map[string]bool // keys present in dms/binds.{lua,conf}
	configFormat       string
	readOnly           bool
}

func NewHyprlandParser(configDir string) *HyprlandParser {
	return &HyprlandParser{
		contentLines:       []string{},
		readingLine:        0,
		configDir:          configDir,
		dmsIncludePos:      -1,
		dmsBindKeys:        make(map[string]bool),
		configBindKeys:     make(map[string]bool),
		conflictingConfigs: make(map[string]*HyprlandKeyBinding),
		bindMap:            make(map[string]*HyprlandKeyBinding),
		bindOrder:          []string{},
		processedFiles:     make(map[string]bool),
		removedKeys:        make(map[string]bool),
		defaultDMSKeys:     make(map[string]bool),
	}
}

func (p *HyprlandParser) ReadContent(directory string) error {
	expandedDir, err := utils.ExpandPath(directory)
	if err != nil {
		return err
	}

	info, err := os.Stat(expandedDir)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return os.ErrNotExist
	}

	confFiles, err := filepath.Glob(filepath.Join(expandedDir, "*.conf"))
	if err != nil {
		return err
	}
	if len(confFiles) == 0 {
		return os.ErrNotExist
	}

	var combinedContent []string
	for _, confFile := range confFiles {
		if fileInfo, err := os.Stat(confFile); err == nil && fileInfo.Mode().IsRegular() {
			data, err := os.ReadFile(confFile)
			if err == nil {
				combinedContent = append(combinedContent, string(data))
			}
		}
	}

	if len(combinedContent) == 0 {
		return os.ErrNotExist
	}

	fullContent := strings.Join(combinedContent, "\n")
	p.contentLines = strings.Split(fullContent, "\n")
	return nil
}

func hyprlandAutogenerateComment(dispatcher, params string) string {
	switch dispatcher {
	case "resizewindow":
		return "Resize window"

	case "movewindow":
		if params == "" {
			return "Move window"
		}
		dirMap := map[string]string{
			"l": "left",
			"r": "right",
			"u": "up",
			"d": "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "move in " + dir + " direction"
		}
		return "move in null direction"

	case "pin":
		return "pin (show on all workspaces)"

	case "splitratio":
		return "Window split ratio " + params

	case "togglefloating":
		return "Float/unfloat window"

	case "resizeactive":
		return "Resize window by " + params

	case "killactive":
		return "Close window"

	case "fullscreen":
		fsMap := map[string]string{
			"0": "fullscreen",
			"1": "maximization",
			"2": "fullscreen on Hyprland's side",
		}
		if fs, ok := fsMap[params]; ok {
			return "Toggle " + fs
		}
		return "Toggle null"

	case "fakefullscreen":
		return "Toggle fake fullscreen"

	case "workspace":
		switch params {
		case "+1":
			return "focus right"
		case "-1":
			return "focus left"
		}
		return "focus workspace " + params
	case "movefocus":
		dirMap := map[string]string{
			"l": "left",
			"r": "right",
			"u": "up",
			"d": "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "move focus " + dir
		}
		return "move focus null"

	case "swapwindow":
		dirMap := map[string]string{
			"l": "left",
			"r": "right",
			"u": "up",
			"d": "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "swap in " + dir + " direction"
		}
		return "swap in null direction"

	case "movetoworkspace":
		switch params {
		case "+1":
			return "move to right workspace (non-silent)"
		case "-1":
			return "move to left workspace (non-silent)"
		}
		return "move to workspace " + params + " (non-silent)"
	case "movetoworkspacesilent":
		switch params {
		case "+1":
			return "move to right workspace"
		case "-1":
			return "move to right workspace"
		}
		return "move to workspace " + params

	case "togglespecialworkspace":
		return "toggle special"

	case "exec":
		return params

	default:
		return ""
	}
}

func (p *HyprlandParser) getKeybindAtLine(lineNumber int) *HyprlandKeyBinding {
	line := p.contentLines[lineNumber]
	return p.parseBindLine(line)
}

func (p *HyprlandParser) getBindsRecursive(currentContent *HyprlandSection, scope int) *HyprlandSection {
	titleRegex := regexp.MustCompile(TitleRegex)

	for p.readingLine < len(p.contentLines) {
		line := p.contentLines[p.readingLine]

		loc := titleRegex.FindStringIndex(line)
		if loc != nil && loc[0] == 0 {
			headingScope := strings.Index(line, "!")

			if headingScope <= scope {
				p.readingLine--
				return currentContent
			}

			sectionName := strings.TrimSpace(line[headingScope+1:])
			p.readingLine++

			childSection := &HyprlandSection{
				Children: []HyprlandSection{},
				Keybinds: []HyprlandKeyBinding{},
				Name:     sectionName,
			}
			result := p.getBindsRecursive(childSection, headingScope)
			currentContent.Children = append(currentContent.Children, *result)

		} else if strings.HasPrefix(line, CommentBindPattern) {
			keybind := p.getKeybindAtLine(p.readingLine)
			if keybind != nil {
				currentContent.Keybinds = append(currentContent.Keybinds, *keybind)
			}

		} else if line == "" || !strings.HasPrefix(strings.TrimSpace(line), "bind") {

		} else {
			keybind := p.getKeybindAtLine(p.readingLine)
			if keybind != nil {
				currentContent.Keybinds = append(currentContent.Keybinds, *keybind)
			}
		}

		p.readingLine++
	}

	return currentContent
}

func (p *HyprlandParser) ParseKeys() *HyprlandSection {
	p.readingLine = 0
	rootSection := &HyprlandSection{
		Children: []HyprlandSection{},
		Keybinds: []HyprlandKeyBinding{},
		Name:     "",
	}
	return p.getBindsRecursive(rootSection, 0)
}

func ParseHyprlandKeys(path string) (*HyprlandSection, error) {
	parser := NewHyprlandParser(path)
	if err := parser.ReadContent(path); err != nil {
		return nil, err
	}
	return parser.ParseKeys(), nil
}

type HyprlandParseResult struct {
	Section            *HyprlandSection
	DMSBindsIncluded   bool
	DMSStatus          *HyprlandDMSStatus
	ConflictingConfigs map[string]*HyprlandKeyBinding
	DefaultDMSKeys     map[string]bool // keys with a DMS default in binds.{lua,conf}
}

type HyprlandDMSStatus struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	BindsAfterDMS   int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
	ConfigFormat    string
	ReadOnly        bool
}

func (p *HyprlandParser) buildDMSStatus() *HyprlandDMSStatus {
	status := &HyprlandDMSStatus{
		Exists:          p.dmsBindsExists,
		Included:        p.dmsBindsIncluded,
		IncludePosition: p.dmsIncludePos,
		TotalIncludes:   p.includeCount,
		BindsAfterDMS:   p.bindsAfterDMS,
		ConfigFormat:    p.configFormat,
		ReadOnly:        p.readOnly,
	}

	switch {
	case !p.dmsBindsExists:
		status.Effective = false
		status.StatusMessage = "dms/binds.lua (or legacy binds.conf) does not exist"
	case !p.dmsBindsIncluded:
		status.Effective = false
		status.StatusMessage = "dms binds are not loaded from Hyprland config (require / source)"
	case p.bindsAfterDMS > 0:
		status.Effective = true
		status.OverriddenBy = p.bindsAfterDMS
		status.StatusMessage = "Some DMS binds may be overridden by config binds"
	default:
		status.Effective = true
		status.StatusMessage = "DMS binds are active"
	}

	return status
}

func (p *HyprlandParser) formatBindKey(kb *HyprlandKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (p *HyprlandParser) normalizeKey(key string) string {
	return strings.ToLower(key)
}

func (p *HyprlandParser) addBind(kb *HyprlandKeyBinding) bool {
	key := p.formatBindKey(kb)
	normalizedKey := p.normalizeKey(key)
	isDMSBind := isDMSBindsSourcePath(kb.Source)

	if isDMSBindsPrimarySourcePath(kb.Source) {
		p.defaultDMSKeys[normalizedKey] = true
	}
	if isDMSBind {
		p.dmsBindKeys[normalizedKey] = true
	} else if p.dmsBindKeys[normalizedKey] {
		p.bindsAfterDMS++
		p.conflictingConfigs[normalizedKey] = kb
		p.configBindKeys[normalizedKey] = true
		return false
	} else {
		p.configBindKeys[normalizedKey] = true
	}

	if _, exists := p.bindMap[normalizedKey]; !exists {
		p.bindOrder = append(p.bindOrder, key)
	}
	p.bindMap[normalizedKey] = kb
	return true
}

func (p *HyprlandParser) ParseWithDMS() (*HyprlandSection, error) {
	expandedDir, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}

	dmsBindsLua := filepath.Join(expandedDir, "dms", "binds.lua")
	dmsBindsConf := filepath.Join(expandedDir, "dms", "binds.conf")
	dmsBindsPath := ""
	if _, err := os.Stat(dmsBindsLua); err == nil {
		p.dmsBindsExists = true
		dmsBindsPath = dmsBindsLua
	} else if _, err := os.Stat(dmsBindsConf); err == nil {
		p.dmsBindsExists = true
		dmsBindsPath = dmsBindsConf
	}

	mainConfig, err := hyprlandMainConfigPath(p.configDir)
	if err != nil {
		return nil, err
	}
	if strings.EqualFold(filepath.Ext(mainConfig), ".lua") {
		p.configFormat = "lua"
		p.readOnly = false
	} else {
		p.configFormat = "hyprlang"
		p.readOnly = true
	}
	section, err := p.parseFileWithSource(mainConfig, "")
	if err != nil {
		return nil, err
	}

	if p.dmsBindsExists && !p.dmsProcessed {
		p.parseDMSBindsDirectly(dmsBindsPath, section)
	}
	p.removeShadowedDMSBinds(section)
	p.removeUnboundDMSBinds(section)

	return section, nil
}

func (p *HyprlandParser) removeUnboundDMSBinds(section *HyprlandSection) {
	if len(p.removedKeys) == 0 {
		return
	}
	filtered := section.Keybinds[:0]
	for i := range section.Keybinds {
		kb := section.Keybinds[i]
		if isDMSBindsSourcePath(kb.Source) && p.removedKeys[p.normalizeKey(p.formatBindKey(&kb))] {
			continue
		}
		filtered = append(filtered, kb)
	}
	section.Keybinds = filtered
	for i := range section.Children {
		p.removeUnboundDMSBinds(&section.Children[i])
	}
}

func (p *HyprlandParser) removeShadowedDMSBinds(section *HyprlandSection) {
	counts := make(map[string]int)
	p.countDMSBinds(section, counts)
	p.filterShadowedDMSBinds(section, counts)
}

func (p *HyprlandParser) countDMSBinds(section *HyprlandSection, counts map[string]int) {
	for i := range section.Keybinds {
		kb := &section.Keybinds[i]
		if isDMSBindsSourcePath(kb.Source) {
			counts[p.normalizeKey(p.formatBindKey(kb))]++
		}
	}
	for i := range section.Children {
		p.countDMSBinds(&section.Children[i], counts)
	}
}

func (p *HyprlandParser) filterShadowedDMSBinds(section *HyprlandSection, counts map[string]int) {
	filtered := section.Keybinds[:0]
	for i := range section.Keybinds {
		kb := section.Keybinds[i]
		key := p.normalizeKey(p.formatBindKey(&kb))
		if isDMSBindsSourcePath(kb.Source) && counts[key] > 1 {
			counts[key]--
			continue
		}
		filtered = append(filtered, kb)
	}
	section.Keybinds = filtered
	for i := range section.Children {
		p.filterShadowedDMSBinds(&section.Children[i], counts)
	}
}

func (p *HyprlandParser) parseFileWithSource(filePath, sectionName string) (*HyprlandSection, error) {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, err
	}

	if p.processedFiles[absPath] {
		return &HyprlandSection{Name: sectionName}, nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, err
	}

	if strings.EqualFold(filepath.Ext(absPath), ".lua") {
		return p.parseLuaLines(string(data), filepath.Dir(absPath), absPath, sectionName)
	}

	prevSource := p.currentSource
	p.currentSource = absPath

	section := &HyprlandSection{Name: sectionName}
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "source") {
			p.handleSource(trimmed, section, filepath.Dir(absPath))
			continue
		}

		if !strings.HasPrefix(trimmed, "bind") {
			continue
		}

		kb := p.parseBindLine(line)
		if kb == nil {
			continue
		}
		kb.Source = p.currentSource
		if p.addBind(kb) {
			section.Keybinds = append(section.Keybinds, *kb)
		}
	}

	p.currentSource = prevSource
	return section, nil
}

func (p *HyprlandParser) handleSource(line string, section *HyprlandSection, baseDir string) {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return
	}

	sourcePath := strings.TrimSpace(parts[1])
	isDMSSource := isDMSBindsPrimarySourcePath(sourcePath)

	p.includeCount++
	if isDMSSource {
		p.dmsBindsIncluded = true
		p.dmsIncludePos = p.includeCount
		p.dmsProcessed = true
	}

	fullPath := sourcePath
	if !filepath.IsAbs(sourcePath) {
		fullPath = filepath.Join(baseDir, sourcePath)
	}

	expanded, err := utils.ExpandPath(fullPath)
	if err != nil {
		return
	}

	includedSection, err := p.parseFileWithSource(expanded, "")
	if err != nil {
		return
	}

	section.Children = append(section.Children, *includedSection)
}

func (p *HyprlandParser) parseDMSBindsDirectly(dmsBindsPath string, section *HyprlandSection) {
	if strings.EqualFold(filepath.Ext(dmsBindsPath), ".lua") {
		sub, err := p.parseLuaLinesFromPath(dmsBindsPath)
		if err != nil {
			return
		}
		section.Keybinds = append(section.Keybinds, sub.Keybinds...)
		section.Children = append(section.Children, sub.Children...)
		p.dmsProcessed = true
		return
	}

	data, err := os.ReadFile(dmsBindsPath)
	if err != nil {
		return
	}

	prevSource := p.currentSource
	p.currentSource = dmsBindsPath

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "bind") {
			continue
		}

		kb := p.parseBindLine(line)
		if kb == nil {
			continue
		}
		kb.Source = dmsBindsPath
		if p.addBind(kb) {
			section.Keybinds = append(section.Keybinds, *kb)
		}
	}

	p.currentSource = prevSource
	p.dmsProcessed = true
}

func (p *HyprlandParser) parseLuaLinesFromPath(absPath string) (*HyprlandSection, error) {
	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, err
	}
	return p.parseLuaLines(string(data), filepath.Dir(absPath), absPath, "")
}

// parseLuaLines reads a Hyprland Lua config fragment: require() includes and hl.bind keybinds.
func (p *HyprlandParser) parseLuaLines(content string, baseDir, absPath, sectionName string) (*HyprlandSection, error) {
	section := &HyprlandSection{Name: sectionName}
	prevSource := p.currentSource
	p.currentSource = absPath

	lines := strings.Split(content, "\n")
	boundInFile := make(map[string]bool)
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "--") || !strings.Contains(trimmed, "hl.bind") {
			continue
		}
		if kbc, _, _, ok := parseLuaBindInvocation(trimmed); ok {
			boundInFile[strings.ToLower(luaKeyComboToInternalKey(kbc))] = true
		}
	}
	rootDir := baseDir
	if expanded, err := utils.ExpandPath(p.configDir); err == nil && expanded != "" {
		rootDir = expanded
	}
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "--") {
			continue
		}

		if modules := luaconfig.Requires(trimmed); len(modules) > 0 {
			for _, mod := range modules {
				rel := luaconfig.ModuleToRelPath(mod)
				if rel == "" {
					continue
				}
				isDMS := isDMSBindsPrimarySourcePath(rel)
				p.includeCount++
				if isDMS {
					p.dmsBindsIncluded = true
					p.dmsIncludePos = p.includeCount
					p.dmsProcessed = true
				}
				fullPath := luaconfig.ModuleToPath(rootDir, mod)
				expanded, err := utils.ExpandPath(fullPath)
				if err != nil {
					continue
				}
				includedSection, err := p.parseFileWithSource(expanded, "")
				if err != nil {
					continue
				}
				section.Children = append(section.Children, *includedSection)
			}
			continue
		}

		if strings.HasPrefix(trimmed, "hl.unbind") {
			if key, ok := parseLuaUnbindLine(trimmed); ok {
				normalized := strings.ToLower(key)
				if !boundInFile[normalized] {
					p.removedKeys[normalized] = true
				}
			}
			continue
		}

		if !strings.Contains(trimmed, "hl.bind") {
			continue
		}

		kbc, action, optSuffix, ok := parseLuaBindInvocation(trimmed)
		if !ok {
			continue
		}
		flags := luaBindOptFlags(optSuffix)
		desc := luaBindOptDescription(optSuffix)
		if desc == "" {
			desc = luaLineTrailingComment(line)
		}
		kb := luaKeyComboToBinding(kbc, action, p.currentSource, desc)
		kb.Flags = flags
		if p.addBind(kb) {
			section.Keybinds = append(section.Keybinds, *kb)
		}
	}

	p.currentSource = prevSource
	return section, nil
}

func luaBindOptFlags(optSuffix string) string {
	optSuffix = strings.TrimSpace(optSuffix)
	if optSuffix == "" {
		return ""
	}
	var flags string
	if strings.Contains(optSuffix, "repeating") {
		flags += "e"
	}
	if strings.Contains(optSuffix, "locked") {
		flags += "l"
	}
	if strings.Contains(optSuffix, "description") {
		flags += "d"
	}
	return flags
}

func luaBindOptDescription(optSuffix string) string {
	return luaTableStringField(optSuffix, "description")
}

func (p *HyprlandParser) parseBindLine(line string) *HyprlandKeyBinding {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return nil
	}

	// Extract bind type and flags from the left side of "="
	bindType := strings.TrimSpace(parts[0])
	flags := extractBindFlags(bindType)
	hasDescFlag := strings.Contains(flags, "d")

	keys := parts[1]
	keyParts := strings.SplitN(keys, "#", 2)
	keys = keyParts[0]

	var comment string
	if len(keyParts) > 1 {
		comment = strings.TrimSpace(keyParts[1])
	}

	// For bindd, the format is: bindd = MODS, key, description, dispatcher, params
	// For regular binds: bind = MODS, key, dispatcher, params
	var minFields, descIndex, dispatcherIndex int
	if hasDescFlag {
		minFields = 4 // mods, key, description, dispatcher
		descIndex = 2
		dispatcherIndex = 3
	} else {
		minFields = 3 // mods, key, dispatcher
		dispatcherIndex = 2
	}

	keyFields := strings.SplitN(keys, ",", minFields+2) // Allow for params
	if len(keyFields) < minFields {
		return nil
	}

	mods := strings.TrimSpace(keyFields[0])
	key := strings.TrimSpace(keyFields[1])

	var dispatcher, params string
	if hasDescFlag {
		// bindd format: description is in the bind itself
		if comment == "" {
			comment = strings.TrimSpace(keyFields[descIndex])
		}
		dispatcher = strings.TrimSpace(keyFields[dispatcherIndex])
		if len(keyFields) > dispatcherIndex+1 {
			paramParts := keyFields[dispatcherIndex+1:]
			params = strings.TrimSpace(strings.Join(paramParts, ","))
		}
	} else {
		dispatcher = strings.TrimSpace(keyFields[dispatcherIndex])
		if len(keyFields) > dispatcherIndex+1 {
			paramParts := keyFields[dispatcherIndex+1:]
			params = strings.TrimSpace(strings.Join(paramParts, ","))
		}
	}

	if comment != "" && strings.HasPrefix(comment, HideComment) {
		return nil
	}

	if comment == "" {
		comment = hyprlandAutogenerateComment(dispatcher, params)
	}

	var modList []string
	if mods != "" {
		modstring := mods + string(ModSeparators[0])
		idx := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range ModSeparators {
				if char == sep {
					isModSep = true
					break
				}
			}
			if isModSep {
				if index-idx > 1 {
					modList = append(modList, modstring[idx:index])
				}
				idx = index + 1
			}
		}
	}

	return &HyprlandKeyBinding{
		Mods:       modList,
		Key:        key,
		Dispatcher: dispatcher,
		Params:     params,
		Comment:    comment,
		Flags:      flags,
	}
}

// extractBindFlags extracts the flags from a bind type string
// e.g., "binde" -> "e", "bindel" -> "el", "bindd" -> "d"
func extractBindFlags(bindType string) string {
	bindType = strings.TrimSpace(bindType)
	if !strings.HasPrefix(bindType, "bind") {
		return ""
	}
	return bindType[4:] // Everything after "bind"
}

func ParseHyprlandKeysWithDMS(path string) (*HyprlandParseResult, error) {
	parser := NewHyprlandParser(path)
	section, err := parser.ParseWithDMS()
	if err != nil {
		return nil, err
	}

	return &HyprlandParseResult{
		Section:            section,
		DMSBindsIncluded:   parser.dmsBindsIncluded,
		DMSStatus:          parser.buildDMSStatus(),
		ConflictingConfigs: parser.conflictingConfigs,
		DefaultDMSKeys:     parser.defaultDMSKeys,
	}, nil
}

func skipLuaWS(s string, i int) int {
	for i < len(s) && (s[i] == ' ' || s[i] == '\t' || s[i] == '\r') {
		i++
	}
	return i
}

// parseLuaStringLiteral reads a Lua "..." or '...' starting at i (first quote).
func parseLuaStringLiteral(line string, i int) (value string, next int, ok bool) {
	if i >= len(line) {
		return "", i, false
	}
	q := line[i]
	if q != '"' && q != '\'' {
		return "", i, false
	}
	i++
	var sb strings.Builder
	for i < len(line) {
		c := line[i]
		if c == '\\' && i+1 < len(line) {
			i++
			sb.WriteByte(line[i])
			i++
			continue
		}
		if c == q {
			return sb.String(), i + 1, true
		}
		sb.WriteByte(c)
		i++
	}
	return "", i, false
}

// parseLuaFirstArgExpr parses a single Lua expression starting at i, stopping at
// the next top-level comma. It handles nested calls/tables and inline functions.
func parseLuaFirstArgExpr(line string, start int) (expr string, next int, ok bool) {
	start = skipLuaWS(line, start)
	if start >= len(line) {
		return "", start, false
	}
	i := start
	parenDepth := 0
	braceDepth := 0
	bracketDepth := 0
	functionDepth := 0
	inStr := byte(0)
	esc := false
	for ; i < len(line); i++ {
		c := line[i]
		if inStr != 0 {
			if esc {
				esc = false
				continue
			}
			if c == '\\' && inStr == '"' {
				esc = true
				continue
			}
			if c == inStr {
				inStr = 0
			}
			continue
		}
		if c == '[' && i+1 < len(line) && line[i+1] == '[' {
			if end := strings.Index(line[i+2:], "]]"); end >= 0 {
				i += end + 3
				continue
			}
			return "", start, false
		}
		if luaWordAt(line, i, "function") {
			functionDepth++
			i += len("function") - 1
			continue
		}
		if luaWordAt(line, i, "end") && functionDepth > 0 {
			functionDepth--
			i += len("end") - 1
			continue
		}
		switch c {
		case '"', '\'':
			inStr = c
		case '(':
			parenDepth++
		case ')':
			if parenDepth > 0 {
				parenDepth--
			}
		case '{':
			braceDepth++
		case '}':
			if braceDepth > 0 {
				braceDepth--
			}
		case '[':
			bracketDepth++
		case ']':
			if bracketDepth > 0 {
				bracketDepth--
			}
		case ',':
			if parenDepth == 0 && braceDepth == 0 && bracketDepth == 0 && functionDepth == 0 {
				return strings.TrimSpace(line[start:i]), i, true
			}
		}
	}
	expr = strings.TrimSpace(line[start:i])
	return expr, i, expr != ""
}

func luaWordAt(line string, idx int, word string) bool {
	if idx < 0 || idx+len(word) > len(line) || line[idx:idx+len(word)] != word {
		return false
	}
	before := idx == 0 || !isLuaIdentByte(line[idx-1])
	afterIdx := idx + len(word)
	after := afterIdx >= len(line) || !isLuaIdentByte(line[afterIdx])
	return before && after
}

func isLuaIdentByte(c byte) bool {
	return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

// parseLuaBindInvocation parses one hl.bind("KEY", expr [, opts]) on a single line.
func parseLuaBindInvocation(line string) (keyCombo, actionExpr, optSuffix string, ok bool) {
	idx := strings.Index(line, "hl.bind")
	if idx < 0 {
		return "", "", "", false
	}
	i := idx + len("hl.bind")
	i = skipLuaWS(line, i)
	if i >= len(line) || line[i] != '(' {
		return "", "", "", false
	}
	i++
	i = skipLuaWS(line, i)
	keyCombo, i, ok = parseLuaStringLiteral(line, i)
	if !ok {
		return "", "", "", false
	}
	i = skipLuaWS(line, i)
	if i >= len(line) || line[i] != ',' {
		return "", "", "", false
	}
	i++
	i = skipLuaWS(line, i)
	actionExpr, i, ok = parseLuaFirstArgExpr(line, i)
	if !ok {
		return "", "", "", false
	}
	i = skipLuaWS(line, i)
	if i < len(line) && line[i] == ',' {
		optSuffix = strings.TrimSpace(line[i:])
	}
	return keyCombo, strings.TrimSpace(actionExpr), optSuffix, true
}

func luaKeyComboToBinding(keyCombo, actionExpr, source, lineComment string) *HyprlandKeyBinding {
	keyCombo = strings.TrimSpace(keyCombo)
	mods, leaf := luaKeyComboToModsKey(keyCombo)
	dispatcher, params := luaExprToDispatcherParams(actionExpr)
	comment := lineComment
	if comment == "" {
		comment = hyprlandAutogenerateComment(dispatcher, params)
	}
	return &HyprlandKeyBinding{
		Mods:       mods,
		Key:        leaf,
		Dispatcher: dispatcher,
		Params:     params,
		Comment:    comment,
		Source:     source,
		Flags:      "",
	}
}

func luaKeyComboToModsKey(combo string) (mods []string, leaf string) {
	parts := strings.Split(combo, "+")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	switch len(parts) {
	case 0:
		return nil, ""
	case 1:
		return nil, parts[0]
	default:
		return parts[:len(parts)-1], parts[len(parts)-1]
	}
}

func luaExprToDispatcherParams(expr string) (dispatcher, params string) {
	expr = strings.TrimSpace(expr)
	switch {
	case strings.HasPrefix(expr, "hl.dsp.exec_cmd("):
		arg := extractLuaCallStringArg(expr, "hl.dsp.exec_cmd")
		if arg != "" {
			if u, err := strconv.Unquote(arg); err == nil {
				if strings.HasPrefix(u, "hyprctl dispatch ") {
					return splitDispatchCommand(strings.TrimSpace(strings.TrimPrefix(u, "hyprctl dispatch ")))
				}
				return "exec", u
			}
		}
		return "exec", strings.TrimSpace(strings.TrimPrefix(expr, "hl.dsp.exec_cmd"))
	case strings.HasPrefix(expr, "hl.dsp.exec_raw("):
		return "execr", luaCallStringArgValue(expr, "hl.dsp.exec_raw")
	case strings.HasPrefix(expr, "hl.dispatch("):
		if arg := luaCallStringArgValue(expr, "hl.dispatch"); arg != "" {
			return splitDispatchCommand(arg)
		}
		return "", ""
	case strings.Contains(expr, "hl.exec_cmd("):
		if arg := luaEmbeddedCallStringArgValue(expr, "hl.exec_cmd"); strings.HasPrefix(arg, "hyprctl dispatch ") {
			return splitDispatchCommand(strings.TrimSpace(strings.TrimPrefix(arg, "hyprctl dispatch ")))
		}
	case strings.HasPrefix(expr, "hl.dsp.window.close("):
		if window := luaTableStringField(expr, "window"); window != "" {
			return "closewindow", window
		}
		if arg := luaCallStringArgValue(expr, "hl.dsp.window.close"); arg != "" {
			return "closewindow", arg
		}
		return "closewindow", ""
	case strings.HasPrefix(expr, "hl.dsp.window.kill("):
		if window := luaTableStringField(expr, "window"); window != "" {
			return "killwindow", window
		}
		if arg := luaCallStringArgValue(expr, "hl.dsp.window.kill"); arg != "" {
			return "killwindow", arg
		}
		return "killactive", ""
	case strings.HasPrefix(expr, "hl.dsp.window.fullscreen("):
		switch luaTableStringField(expr, "mode") {
		case "maximized", "maximize":
			return "fullscreen", "1"
		case "fullscreen":
			return "fullscreen", "0"
		}
		return "fullscreen", luaTableStringField(expr, "mode")
	case strings.HasPrefix(expr, "hl.dsp.window.fullscreen_state("):
		internal := luaStringValue(luaTableScalarField(expr, "internal"))
		client := luaStringValue(luaTableScalarField(expr, "client"))
		return joinDispatcherParams("fullscreenstate", internal, client)
	case strings.HasPrefix(expr, "hl.dsp.window.float("):
		switch luaToggleActionToLegacy(luaTableStringField(expr, "action")) {
		case "on":
			return "setfloating", ""
		case "off":
			return "settiled", ""
		default:
			return "togglefloating", ""
		}
	case strings.HasPrefix(expr, "hl.dsp.window.pseudo("):
		action := luaToggleActionToLegacy(luaTableStringField(expr, "action"))
		if action == "" || action == "toggle" {
			return "pseudo", ""
		}
		return "pseudo", action
	case strings.HasPrefix(expr, "hl.dsp.window.pin("):
		if action := luaToggleActionToLegacy(luaTableStringField(expr, "action")); action != "" && action != "toggle" {
			return "pin", action
		}
		return "pin", ""
	case strings.Contains(expr, "hl.dsp.window.center()"):
		return "centerwindow", ""
	case strings.Contains(expr, "hl.dsp.window.bring_to_top()"):
		return "bringactivetotop", ""
	case strings.Contains(expr, "hl.dsp.window.toggle_swallow()"):
		return "toggleswallow", ""
	case strings.Contains(expr, "hl.dsp.group.toggle()"):
		return "togglegroup", ""
	case strings.Contains(expr, "hl.dsp.group.next()"):
		return "changegroupactive", "f"
	case strings.Contains(expr, "hl.dsp.group.prev()"):
		return "changegroupactive", "b"
	case strings.HasPrefix(expr, "hl.dsp.group.active("):
		return "changegroupactive", luaStringValue(luaTableScalarField(expr, "index"))
	case strings.HasPrefix(expr, "hl.dsp.group.move_window("):
		if forward, ok := luaTableBoolField(expr, "forward"); ok && !forward {
			return "movegroupwindow", "b"
		}
		return "movegroupwindow", "f"
	case strings.HasPrefix(expr, "hl.dsp.group.lock_active("):
		return "lockactivegroup", luaToggleActionToLockArg(luaTableStringField(expr, "action"))
	case strings.HasPrefix(expr, "hl.dsp.group.lock("):
		return "lockgroups", luaToggleActionToLockArg(luaTableStringField(expr, "action"))
	case strings.HasPrefix(expr, "hl.dsp.window.deny_from_group("):
		return "denywindowfromgroup", luaToggleActionToLegacy(luaTableStringField(expr, "action"))
	case strings.HasPrefix(expr, "hl.dsp.focus("):
		switch {
		case luaTableStringField(expr, "direction") != "":
			return "movefocus", luaTableStringField(expr, "direction")
		case luaTableStringField(expr, "monitor") != "":
			return "focusmonitor", luaTableStringField(expr, "monitor")
		case luaTableStringField(expr, "workspace") != "":
			if luaTableBoolFieldValue(expr, "on_current_monitor") {
				return "focusworkspaceoncurrentmonitor", luaTableStringField(expr, "workspace")
			}
			return "workspace", luaTableStringField(expr, "workspace")
		case luaTableStringField(expr, "window") != "":
			return "focuswindow", luaTableStringField(expr, "window")
		case luaTableBoolFieldValue(expr, "urgent_or_last"):
			return "focusurgentorlast", ""
		case luaTableBoolFieldValue(expr, "last"):
			return "focuscurrentorlast", ""
		}
	case strings.HasPrefix(expr, "hl.dsp.window.move("):
		switch {
		case luaTableScalarField(expr, "x") != "" || luaTableScalarField(expr, "y") != "":
			x := luaStringValue(luaTableScalarField(expr, "x"))
			y := luaStringValue(luaTableScalarField(expr, "y"))
			if x == "" {
				x = "0"
			}
			if y == "" {
				y = "0"
			}
			prefix := ""
			if raw, ok := luaTableBoolField(expr, "relative"); ok && !raw {
				prefix = "exact "
			}
			params := prefix + x + " " + y
			if window := luaTableStringField(expr, "window"); window != "" {
				return "movewindowpixel", params + "," + window
			}
			return "moveactive", params
		case luaTableStringField(expr, "into_group") != "":
			return "moveintogroup", luaTableStringField(expr, "into_group")
		case luaTableStringField(expr, "into_or_create_group") != "":
			return "moveintoorcreategroup", luaTableStringField(expr, "into_or_create_group")
		case luaTableBoolFieldValue(expr, "out_of_group"):
			return "moveoutofgroup", ""
		case luaTableStringField(expr, "out_of_group") != "":
			return "moveoutofgroup", luaTableStringField(expr, "out_of_group")
		case luaTableStringField(expr, "direction") != "":
			if luaTableBoolFieldValue(expr, "group_aware") {
				return "movewindoworgroup", luaTableStringField(expr, "direction")
			}
			return "movewindow", luaTableStringField(expr, "direction")
		case luaTableStringField(expr, "monitor") != "":
			return "movewindow", "mon:" + luaTableStringField(expr, "monitor")
		case luaTableStringField(expr, "workspace") != "":
			action := "movetoworkspace"
			if follow, ok := luaTableBoolField(expr, "follow"); ok && !follow {
				action = "movetoworkspacesilent"
			}
			return joinDispatcherParams(action, luaTableStringField(expr, "workspace"), luaTableStringField(expr, "window"))
		}
	case expr == "hl.dsp.window.drag()":
		return "movewindow", ""
	case expr == "hl.dsp.window.resize()":
		return "resizewindow", ""
	case strings.HasPrefix(expr, "hl.dsp.window.resize("):
		x := luaStringValue(luaTableScalarField(expr, "x"))
		y := luaStringValue(luaTableScalarField(expr, "y"))
		if x != "" || y != "" {
			if x == "" {
				x = "0"
			}
			if y == "" {
				y = "0"
			}
			prefix := ""
			if relative, ok := luaTableBoolField(expr, "relative"); ok && !relative {
				prefix = "exact "
			}
			params := prefix + x + " " + y
			if window := luaTableStringField(expr, "window"); window != "" {
				return "resizewindowpixel", params + "," + window
			}
			return "resizeactive", params
		}
	case strings.HasPrefix(expr, "hl.dsp.window.swap("):
		switch {
		case luaTableBoolFieldValue(expr, "next"):
			return "swapnext", ""
		case luaTableBoolFieldValue(expr, "prev"):
			return "swapnext", "prev"
		}
		return "swapwindow", luaTableStringField(expr, "direction")
	case strings.HasPrefix(expr, "hl.dsp.window.cycle_next("):
		parts := []string{}
		if next, ok := luaTableBoolField(expr, "next"); ok && !next {
			parts = append(parts, "prev")
		}
		if luaTableBoolFieldValue(expr, "tiled") {
			parts = append(parts, "tiled")
		}
		if luaTableBoolFieldValue(expr, "floating") {
			parts = append(parts, "floating")
		}
		return "cyclenext", strings.Join(parts, " ")
	case strings.HasPrefix(expr, "hl.dsp.window.signal("):
		signal := luaStringValue(luaTableScalarField(expr, "signal"))
		window := luaTableStringField(expr, "window")
		if window != "" {
			return joinDispatcherParams("signalwindow", window, signal)
		}
		return "signal", signal
	case strings.HasPrefix(expr, "hl.dsp.window.tag("):
		return joinDispatcherParams("tagwindow", luaTableStringField(expr, "tag"), luaTableStringField(expr, "window"))
	case strings.HasPrefix(expr, "hl.dsp.window.alter_zorder("):
		mode := luaTableStringField(expr, "mode")
		if mode == "" {
			mode = luaTableStringField(expr, "zheight")
		}
		return joinDispatcherParams("alterzorder", mode, luaTableStringField(expr, "window"))
	case strings.HasPrefix(expr, "hl.dsp.window.set_prop("):
		prop := luaTableStringField(expr, "prop")
		if prop == "" {
			prop = luaTableStringField(expr, "property")
		}
		return joinDispatcherParams("setprop", luaTableStringField(expr, "window"), prop, luaTableStringField(expr, "value"))
	case strings.HasPrefix(expr, "hl.dsp.workspace.rename("):
		return joinDispatcherParams("renameworkspace", luaTableStringField(expr, "workspace"), luaTableStringField(expr, "name"))
	case strings.HasPrefix(expr, "hl.dsp.workspace.move("):
		workspace := luaTableStringField(expr, "workspace")
		monitor := luaTableStringField(expr, "monitor")
		if workspace != "" {
			return joinDispatcherParams("moveworkspacetomonitor", workspace, monitor)
		}
		return "movecurrentworkspacetomonitor", monitor
	case strings.HasPrefix(expr, "hl.dsp.workspace.swap_monitors("):
		return joinDispatcherParams("swapactiveworkspaces", luaTableStringField(expr, "monitor1"), luaTableStringField(expr, "monitor2"))
	case strings.HasPrefix(expr, "hl.dsp.workspace.toggle_special("):
		return "togglespecialworkspace", luaCallStringArgValue(expr, "hl.dsp.workspace.toggle_special")
	case strings.HasPrefix(expr, "hl.dsp.layout("):
		if arg := luaCallStringArgValue(expr, "hl.dsp.layout"); arg != "" {
			return "layoutmsg", arg
		}
	case strings.HasPrefix(expr, "hl.dsp.dpms("):
		if action := luaTableStringField(expr, "action"); action != "" {
			switch action {
			case "enable":
				return "dpms", "on"
			case "disable":
				return "dpms", "off"
			}
			return "dpms", action
		}
		return "dpms", ""
	case strings.HasPrefix(expr, "hl.dsp.submap("):
		return "submap", luaCallStringArgValue(expr, "hl.dsp.submap")
	case strings.HasPrefix(expr, "hl.dsp.global("):
		return "global", luaCallStringArgValue(expr, "hl.dsp.global")
	case strings.HasPrefix(expr, "hl.dsp.event("):
		return "event", luaCallStringArgValue(expr, "hl.dsp.event")
	case strings.HasPrefix(expr, "hl.dsp.pass("):
		if window := luaTableStringField(expr, "window"); window != "" {
			return "pass", window
		}
		return "pass", luaCallStringArgValue(expr, "hl.dsp.pass")
	case strings.HasPrefix(expr, "hl.dsp.send_shortcut("):
		return joinDispatcherParams("sendshortcut", luaTableModsField(expr), luaTableStringField(expr, "key"), luaTableStringField(expr, "window"))
	case strings.HasPrefix(expr, "hl.dsp.send_key_state("):
		return joinDispatcherParams("sendkeystate", luaTableModsField(expr), luaTableStringField(expr, "key"), luaTableStringField(expr, "state"), luaTableStringField(expr, "window"))
	case strings.HasPrefix(expr, "hl.dsp.cursor.move_to_corner("):
		return "movecursortocorner", luaStringValue(luaTableScalarField(expr, "corner"))
	case strings.HasPrefix(expr, "hl.dsp.cursor.move("):
		return joinDispatcherParams("movecursor", luaStringValue(luaTableScalarField(expr, "x")), luaStringValue(luaTableScalarField(expr, "y")))
	case strings.Contains(expr, "hl.dsp.force_renderer_reload()"):
		return "forcerendererreload", ""
	case strings.HasPrefix(expr, "hl.dsp.force_idle("):
		return "forceidle", luaCallScalarArgValue(expr, "hl.dsp.force_idle")
	case strings.Contains(expr, "hl.dsp.exit()"):
		return "exit", ""
	default:
		return expr, ""
	}
	return expr, ""
}

func splitDispatchCommand(command string) (dispatcher, params string) {
	command = strings.TrimSpace(command)
	if command == "" {
		return "", ""
	}
	parts := strings.SplitN(command, " ", 2)
	if len(parts) == 1 {
		return parts[0], ""
	}
	return parts[0], strings.TrimSpace(parts[1])
}

func joinDispatcherParams(dispatcher string, values ...string) (string, string) {
	parts := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			parts = append(parts, value)
		}
	}
	return dispatcher, strings.Join(parts, " ")
}

func luaEmbeddedCallStringArgValue(expr, funcName string) string {
	idx := strings.Index(expr, funcName+"(")
	if idx < 0 {
		return ""
	}
	return luaCallStringArgValue(expr[idx:], funcName)
}

func luaCallScalarArgValue(callExpr, funcName string) string {
	callExpr = strings.TrimSpace(callExpr)
	prefix := funcName + "("
	if !strings.HasPrefix(callExpr, prefix) {
		return ""
	}
	inner := strings.TrimSpace(callExpr[len(prefix):])
	if inner == "" {
		return ""
	}
	if s := luaCallStringArgValue(callExpr, funcName); s != "" {
		return s
	}
	re := regexp.MustCompile(`^-?\d+(?:\.\d+)?`)
	return re.FindString(inner)
}

func luaToggleActionToLegacy(action string) string {
	switch strings.ToLower(strings.TrimSpace(action)) {
	case "on", "enable", "enabled", "set", "lock":
		return "on"
	case "off", "disable", "disabled", "unset", "unlock":
		return "off"
	default:
		return "toggle"
	}
}

func luaToggleActionToLockArg(action string) string {
	switch luaToggleActionToLegacy(action) {
	case "on":
		return "lock"
	case "off":
		return "unlock"
	default:
		return "toggle"
	}
}

func extractLuaCallStringArg(callExpr, funcName string) string {
	callExpr = strings.TrimSpace(callExpr)
	prefix := funcName + "("
	if !strings.HasPrefix(callExpr, prefix) {
		return ""
	}
	inner := callExpr[len(prefix):]
	inner = strings.TrimSpace(inner)
	if len(inner) == 0 {
		return ""
	}
	switch inner[0] {
	case '"', '\'':
		s, _, ok := parseLuaStringLiteral(inner, 0)
		if ok {
			return strconv.Quote(s)
		}
	case '[':
		if strings.HasPrefix(inner, "[[") {
			if end := strings.Index(inner[2:], "]]"); end >= 0 {
				return strconv.Quote(inner[2 : 2+end])
			}
		}
	}
	return ""
}

func luaCallStringArgValue(callExpr, funcName string) string {
	arg := extractLuaCallStringArg(callExpr, funcName)
	if arg == "" {
		return ""
	}
	u, err := strconv.Unquote(arg)
	if err != nil {
		return ""
	}
	return u
}

func luaTableStringField(expr, field string) string {
	return luaStringValue(luaTableScalarField(expr, field))
}

func luaTableModsField(expr string) string {
	if mods := luaTableStringField(expr, "mods"); mods != "" {
		return mods
	}
	return luaTableStringField(expr, "mod")
}

func luaTableBoolFieldValue(expr, field string) bool {
	value, ok := luaTableBoolField(expr, field)
	return ok && value
}

func luaTableBoolField(expr, field string) (bool, bool) {
	raw := strings.ToLower(luaTableScalarField(expr, field))
	switch raw {
	case "true":
		return true, true
	case "false":
		return false, true
	default:
		return false, false
	}
}

func luaTableScalarField(expr, field string) string {
	re := regexp.MustCompile(`(?s)\b` + regexp.QuoteMeta(field) + `\s*=\s*("(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\[\[.*?\]\]|-?\d+(?:\.\d+)?|true|false)`)
	m := re.FindStringSubmatch(expr)
	if len(m) < 2 {
		return ""
	}
	return strings.TrimSpace(m[1])
}

func luaStringValue(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if strings.HasPrefix(raw, "[[") && strings.HasSuffix(raw, "]]") {
		return raw[2 : len(raw)-2]
	}
	if len(raw) >= 2 {
		q := raw[0]
		if (q == '"' || q == '\'') && raw[len(raw)-1] == q {
			if q == '"' {
				if u, err := strconv.Unquote(raw); err == nil {
					return u
				}
			}
			return strings.ReplaceAll(raw[1:len(raw)-1], `\'`, `'`)
		}
	}
	return raw
}

func luaLineTrailingComment(line string) string {
	inString := byte(0)
	escaped := false
	for i := 0; i < len(line)-1; i++ {
		c := line[i]
		if inString != 0 {
			if escaped {
				escaped = false
				continue
			}
			if c == '\\' && inString == '"' {
				escaped = true
				continue
			}
			if c == inString {
				inString = 0
			}
			continue
		}
		if c == '"' || c == '\'' {
			inString = c
			continue
		}
		if c == '[' && line[i+1] == '[' {
			if end := strings.Index(line[i+2:], "]]"); end >= 0 {
				i += end + 3
				continue
			}
			return ""
		}
		if c == '-' && line[i+1] == '-' {
			return strings.TrimSpace(line[i+2:])
		}
	}
	return ""
}

func isDMSBindsSourcePath(p string) bool {
	p = filepath.ToSlash(strings.TrimSpace(p))
	if isDMSBindsPrimarySourcePath(p) {
		return true
	}
	return isDMSBindsUserOverridePath(p)
}

func isDMSBindsUserOverridePath(p string) bool {
	p = filepath.ToSlash(strings.TrimSpace(p))
	return p == "dms/binds-user.lua" || p == "./dms/binds-user.lua" ||
		strings.HasSuffix(p, "/dms/binds-user.lua")
}

func isDMSBindsPrimarySourcePath(p string) bool {
	p = filepath.ToSlash(strings.TrimSpace(p))
	if strings.Contains(p, "/dms/binds.lua") || strings.HasSuffix(p, "dms/binds.lua") || p == "dms/binds.lua" || p == "./dms/binds.lua" {
		return true
	}
	if strings.Contains(p, "/dms/binds.conf") || strings.HasSuffix(p, "dms/binds.conf") {
		return true
	}
	return p == "dms/binds.conf" || p == "./dms/binds.conf"
}

// hyprlandMainConfigPath returns hyprland.lua if present, else hyprland.conf if present.
func hyprlandMainConfigPath(dir string) (string, error) {
	expandedDir, err := utils.ExpandPath(dir)
	if err != nil {
		return "", err
	}
	luaPath := filepath.Join(expandedDir, "hyprland.lua")
	if st, err := os.Stat(luaPath); err == nil && st.Mode().IsRegular() {
		return luaPath, nil
	}
	confPath := filepath.Join(expandedDir, "hyprland.conf")
	if st, err := os.Stat(confPath); err == nil && st.Mode().IsRegular() {
		return confPath, nil
	}
	return "", os.ErrNotExist
}
