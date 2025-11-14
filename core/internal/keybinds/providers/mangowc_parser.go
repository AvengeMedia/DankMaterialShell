package providers

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
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
}

type MangoWCParser struct {
	contentLines []string
	readingLine  int
}

func NewMangoWCParser() *MangoWCParser {
	return &MangoWCParser{
		contentLines: []string{},
		readingLine:  0,
	}
}

func (p *MangoWCParser) ReadContent(path string) error {
	expandedPath := os.ExpandEnv(path)
	expandedPath = filepath.Clean(expandedPath)
	if strings.HasPrefix(expandedPath, "~") {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		expandedPath = filepath.Join(home, expandedPath[1:])
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

func (p *MangoWCParser) getKeybindAtLine(lineNumber int) *MangoWCKeyBinding {
	if lineNumber >= len(p.contentLines) {
		return nil
	}

	line := p.contentLines[lineNumber]

	bindMatch := regexp.MustCompile(`^(bind[lsr]*)\s*=\s*(.+)$`)
	matches := bindMatch.FindStringSubmatch(line)
	if len(matches) < 3 {
		return nil
	}

	bindType := matches[1]
	content := matches[2]

	parts := strings.SplitN(content, "#", 2)
	keys := parts[0]

	var comment string
	if len(parts) > 1 {
		comment = strings.TrimSpace(parts[1])
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
		p := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range MangoWCModSeparators {
				if char == sep {
					isModSep = true
					break
				}
			}
			if isModSep {
				if index-p > 1 {
					modList = append(modList, modstring[p:index])
				}
				p = index + 1
			}
		}
	}

	_ = bindType

	return &MangoWCKeyBinding{
		Mods:    modList,
		Key:     key,
		Command: command,
		Params:  params,
		Comment: comment,
	}
}

func (p *MangoWCParser) ParseKeys() []MangoWCKeyBinding {
	var keybinds []MangoWCKeyBinding

	for lineNumber := 0; lineNumber < len(p.contentLines); lineNumber++ {
		line := p.contentLines[lineNumber]
		if line == "" || strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}

		if !strings.HasPrefix(strings.TrimSpace(line), "bind") {
			continue
		}

		keybind := p.getKeybindAtLine(lineNumber)
		if keybind != nil {
			keybinds = append(keybinds, *keybind)
		}
	}

	return keybinds
}

func ParseMangoWCKeys(path string) ([]MangoWCKeyBinding, error) {
	parser := NewMangoWCParser()
	if err := parser.ReadContent(path); err != nil {
		return nil, err
	}
	return parser.ParseKeys(), nil
}
