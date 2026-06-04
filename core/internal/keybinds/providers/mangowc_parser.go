package providers

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

const (
	MangoWCHideComment = "[hidden]"
)

var MangoWCModSeparators = []rune{'+', ' '}

type MangoWCKeyBinding struct {
	Mods    []string `json:"mods"`
	Key     string   `json:"key"`
	Command string   `json:"command"`
	Params  string   `json:"params"`
	Comment string   `json:"comment"`
	Source  string   `json:"source"`
}

type MangoWCParser struct {
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
	conflictingConfigs map[string]*MangoWCKeyBinding
	bindMap            map[string]*MangoWCKeyBinding
	bindOrder          []string
	processedFiles     map[string]bool
	dmsProcessed       bool
}

func NewMangoWCParser(configDir string) *MangoWCParser {
	return &MangoWCParser{
		contentLines:       []string{},
		readingLine:        0,
		configDir:          configDir,
		dmsIncludePos:      -1,
		dmsBindKeys:        make(map[string]bool),
		configBindKeys:     make(map[string]bool),
		conflictingConfigs: make(map[string]*MangoWCKeyBinding),
		bindMap:            make(map[string]*MangoWCKeyBinding),
		bindOrder:          []string{},
		processedFiles:     make(map[string]bool),
	}
}

func (p *MangoWCParser) ReadContent(path string) error {
	expandedPath, err := utils.ExpandPath(path)
	if err != nil {
		return err
	}

	info, err := os.Stat(expandedPath)
	if err != nil {
		return err
	}

	var files []string
	if info.IsDir() {
		confFiles, err := filepath.Glob(filepath.Join(expandedPath, "*.conf"))
		if err != nil {
			return err
		}
		if len(confFiles) == 0 {
			return os.ErrNotExist
		}
		files = confFiles
	} else {
		files = []string{expandedPath}
	}

	var combinedContent []string
	for _, file := range files {
		if fileInfo, err := os.Stat(file); err == nil && fileInfo.Mode().IsRegular() {
			data, err := os.ReadFile(file)
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

func mangowcAutogenerateComment(command, params string) string {
	switch command {
	case "spawn", "spawn_shell":
		return params
	case "killclient":
		return "Close window"
	case "quit":
		return "Exit MangoWC"
	case "reload_config":
		return "Reload configuration"
	case "focusstack":
		if params == "next" {
			return "Focus next window"
		}
		if params == "prev" {
			return "Focus previous window"
		}
		return "Focus stack " + params
	case "focusdir":
		dirMap := map[string]string{
			"left":  "left",
			"right": "right",
			"up":    "up",
			"down":  "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "Focus " + dir
		}
		return "Focus " + params
	case "exchange_client":
		dirMap := map[string]string{
			"left":  "left",
			"right": "right",
			"up":    "up",
			"down":  "down",
		}
		if dir, ok := dirMap[params]; ok {
			return "Swap window " + dir
		}
		return "Swap window " + params
	case "togglefloating":
		return "Float/unfloat window"
	case "togglefullscreen":
		return "Toggle fullscreen"
	case "togglefakefullscreen":
		return "Toggle fake fullscreen"
	case "togglemaximizescreen":
		return "Toggle maximize"
	case "toggleglobal":
		return "Toggle global"
	case "toggleoverview":
		return "Toggle overview"
	case "toggleoverlay":
		return "Toggle overlay"
	case "minimized":
		return "Minimize window"
	case "restore_minimized":
		return "Restore minimized"
	case "toggle_scratchpad":
		return "Toggle scratchpad"
	case "setlayout":
		return "Set layout " + params
	case "switch_layout":
		return "Switch layout"
	case "view":
		parts := strings.Split(params, ",")
		if len(parts) > 0 {
			return "View tag " + parts[0]
		}
		return "View tag"
	case "tag":
		parts := strings.Split(params, ",")
		if len(parts) > 0 {
			return "Move to tag " + parts[0]
		}
		return "Move to tag"
	case "toggleview":
		parts := strings.Split(params, ",")
		if len(parts) > 0 {
			return "Toggle tag " + parts[0]
		}
		return "Toggle tag"
	case "viewtoleft", "viewtoleft_have_client":
		return "View left tag"
	case "viewtoright", "viewtoright_have_client":
		return "View right tag"
	case "tagtoleft":
		return "Move to left tag"
	case "tagtoright":
		return "Move to right tag"
	case "focusmon":
		return "Focus monitor " + params
	case "tagmon":
		return "Move to monitor " + params
	case "incgaps":
		if strings.HasPrefix(params, "-") {
			return "Decrease gaps"
		}
		return "Increase gaps"
	case "togglegaps":
		return "Toggle gaps"
	case "movewin":
		return "Move window by " + params
	case "resizewin":
		return "Resize window by " + params
	case "set_proportion":
		return "Set proportion " + params
	case "switch_proportion_preset":
		return "Switch proportion preset"
	default:
		return ""
	}
}

func (p *MangoWCParser) getKeybindAtLine(lineNumber int, precedingComment string) *MangoWCKeyBinding {
	if lineNumber >= len(p.contentLines) {
		return nil
	}
	return p.getKeybindAtLineContent(p.contentLines[lineNumber], precedingComment)
}

func (p *MangoWCParser) ParseKeys() []MangoWCKeyBinding {
	var keybinds []MangoWCKeyBinding
	var pendingComment string

	for lineNumber := 0; lineNumber < len(p.contentLines); lineNumber++ {
		trimmed := strings.TrimSpace(p.contentLines[lineNumber])
		if trimmed == "" {
			pendingComment = ""
			continue
		}
		if strings.HasPrefix(trimmed, "#") {
			pendingComment = strings.TrimSpace(strings.TrimPrefix(trimmed, "#"))
			continue
		}
		if !strings.HasPrefix(trimmed, "bind") {
			pendingComment = ""
			continue
		}

		keybind := p.getKeybindAtLine(lineNumber, pendingComment)
		if keybind != nil {
			keybinds = append(keybinds, *keybind)
		}
		pendingComment = ""
	}

	return keybinds
}

func ParseMangoWCKeys(path string) ([]MangoWCKeyBinding, error) {
	parser := NewMangoWCParser(path)
	if err := parser.ReadContent(path); err != nil {
		return nil, err
	}
	return parser.ParseKeys(), nil
}

type MangoWCParseResult struct {
	Keybinds           []MangoWCKeyBinding
	DMSBindsIncluded   bool
	DMSStatus          *MangoWCDMSStatus
	ConflictingConfigs map[string]*MangoWCKeyBinding
}

type MangoWCDMSStatus struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	BindsAfterDMS   int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
}

func (p *MangoWCParser) buildDMSStatus() *MangoWCDMSStatus {
	status := &MangoWCDMSStatus{
		Exists:          p.dmsBindsExists,
		Included:        p.dmsBindsIncluded,
		IncludePosition: p.dmsIncludePos,
		TotalIncludes:   p.includeCount,
		BindsAfterDMS:   p.bindsAfterDMS,
	}

	switch {
	case !p.dmsBindsExists:
		status.Effective = false
		status.StatusMessage = "dms/binds.conf does not exist"
	case !p.dmsBindsIncluded:
		status.Effective = false
		status.StatusMessage = "dms/binds.conf is not sourced in config"
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

func (p *MangoWCParser) formatBindKey(kb *MangoWCKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (p *MangoWCParser) normalizeKey(key string) string {
	return strings.ToLower(key)
}

func (p *MangoWCParser) addBind(kb *MangoWCKeyBinding) {
	key := p.formatBindKey(kb)
	normalizedKey := p.normalizeKey(key)
	isDMSBind := strings.Contains(kb.Source, "dms/binds.conf") || strings.Contains(kb.Source, "dms"+string(os.PathSeparator)+"binds.conf")

	if isDMSBind {
		p.dmsBindKeys[normalizedKey] = true
	} else if p.dmsBindKeys[normalizedKey] {
		p.bindsAfterDMS++
		p.conflictingConfigs[normalizedKey] = kb
		p.configBindKeys[normalizedKey] = true
		return
	} else {
		p.configBindKeys[normalizedKey] = true
	}

	if _, exists := p.bindMap[normalizedKey]; !exists {
		p.bindOrder = append(p.bindOrder, key)
	}
	p.bindMap[normalizedKey] = kb
}

func (p *MangoWCParser) ParseWithDMS() ([]MangoWCKeyBinding, error) {
	expandedDir, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}

	dmsBindsPath := filepath.Join(expandedDir, "dms", "binds.conf")
	if _, err := os.Stat(dmsBindsPath); err == nil {
		p.dmsBindsExists = true
	}

	mainConfig := filepath.Join(expandedDir, "config.conf")
	if _, err := os.Stat(mainConfig); os.IsNotExist(err) {
		mainConfig = filepath.Join(expandedDir, "mango.conf")
	}

	_, err = p.parseFileWithSource(mainConfig)
	if err != nil {
		return nil, err
	}

	if p.dmsBindsExists && !p.dmsProcessed {
		p.parseDMSBindsDirectly(dmsBindsPath)
	}

	var keybinds []MangoWCKeyBinding
	for _, key := range p.bindOrder {
		normalizedKey := p.normalizeKey(key)
		if kb, exists := p.bindMap[normalizedKey]; exists {
			keybinds = append(keybinds, *kb)
		}
	}

	return keybinds, nil
}

func (p *MangoWCParser) parseFileWithSource(filePath string) ([]MangoWCKeyBinding, error) {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, err
	}

	if p.processedFiles[absPath] {
		return nil, nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, err
	}

	prevSource := p.currentSource
	p.currentSource = absPath

	var keybinds []MangoWCKeyBinding
	var pendingComment string
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if trimmed == "" {
			pendingComment = ""
			continue
		}

		if strings.HasPrefix(trimmed, "source") {
			p.handleSource(trimmed, filepath.Dir(absPath), &keybinds)
			pendingComment = ""
			continue
		}

		if strings.HasPrefix(trimmed, "#") {
			pendingComment = strings.TrimSpace(strings.TrimPrefix(trimmed, "#"))
			continue
		}

		if !strings.HasPrefix(trimmed, "bind") {
			pendingComment = ""
			continue
		}

		kb := p.getKeybindAtLineContent(line, pendingComment)
		pendingComment = ""
		if kb == nil {
			continue
		}
		kb.Source = p.currentSource
		p.addBind(kb)
		keybinds = append(keybinds, *kb)
	}

	p.currentSource = prevSource
	return keybinds, nil
}

func (p *MangoWCParser) handleSource(line, baseDir string, keybinds *[]MangoWCKeyBinding) {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return
	}

	sourcePath := strings.TrimSpace(parts[1])
	isDMSSource := sourcePath == "dms/binds.conf" || sourcePath == "./dms/binds.conf" || strings.HasSuffix(sourcePath, "/dms/binds.conf")

	p.includeCount++
	if isDMSSource {
		p.dmsBindsIncluded = true
		p.dmsIncludePos = p.includeCount
		p.dmsProcessed = true
	}

	expanded, err := utils.ExpandPath(sourcePath)
	if err != nil {
		return
	}

	fullPath := expanded
	if !filepath.IsAbs(expanded) {
		fullPath = filepath.Join(baseDir, expanded)
	}

	includedBinds, err := p.parseFileWithSource(fullPath)
	if err != nil {
		return
	}

	*keybinds = append(*keybinds, includedBinds...)
}

func (p *MangoWCParser) parseDMSBindsDirectly(dmsBindsPath string) []MangoWCKeyBinding {
	keybinds, err := p.parseFileWithSource(dmsBindsPath)
	if err != nil {
		return nil
	}
	p.dmsProcessed = true
	return keybinds
}

// getKeybindAtLineContent parses one `bind=` line. precedingComment (a `# ...`
// line directly above) is the description: mango feeds inline comments to spawn
// as argv, so DMS keeps descriptions on the line above; inline `#` is a fallback.
func (p *MangoWCParser) getKeybindAtLineContent(line string, precedingComment string) *MangoWCKeyBinding {
	bindMatch := regexp.MustCompile(`^(bind[lsr]*)\s*=\s*(.+)$`)
	matches := bindMatch.FindStringSubmatch(line)
	if len(matches) < 3 {
		return nil
	}

	content := matches[2]
	parts := strings.SplitN(content, "#", 2)
	keys := parts[0]

	var comment string
	if len(parts) > 1 {
		comment = strings.TrimSpace(parts[1])
	}
	if comment == "" {
		comment = strings.TrimSpace(precedingComment)
	}

	if strings.HasPrefix(comment, MangoWCHideComment) {
		return nil
	}

	keyFields := strings.SplitN(keys, ",", 4)
	if len(keyFields) < 3 {
		return nil
	}

	mods := strings.TrimSpace(keyFields[0])
	key := strings.TrimSpace(keyFields[1])
	command := strings.TrimSpace(keyFields[2])

	var params string
	if len(keyFields) > 3 {
		params = strings.TrimSpace(keyFields[3])
	}

	if comment == "" {
		comment = mangowcAutogenerateComment(command, params)
	}

	var modList []string
	if mods != "" && !strings.EqualFold(mods, "none") {
		modstring := mods + string(MangoWCModSeparators[0])
		idx := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range MangoWCModSeparators {
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

	return &MangoWCKeyBinding{
		Mods:    modList,
		Key:     key,
		Command: command,
		Params:  params,
		Comment: comment,
	}
}

func ParseMangoWCKeysWithDMS(path string) (*MangoWCParseResult, error) {
	parser := NewMangoWCParser(path)
	keybinds, err := parser.ParseWithDMS()
	if err != nil {
		return nil, err
	}

	return &MangoWCParseResult{
		Keybinds:           keybinds,
		DMSBindsIncluded:   parser.dmsBindsIncluded,
		DMSStatus:          parser.buildDMSStatus(),
		ConflictingConfigs: parser.conflictingConfigs,
	}, nil
}
