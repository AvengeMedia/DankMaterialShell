package providers

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
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
}

type HyprlandSection struct {
	Children []HyprlandSection    `json:"children"`
	Keybinds []HyprlandKeyBinding `json:"keybinds"`
	Name     string               `json:"name"`
}

type HyprlandParser struct {
	contentLines []string
	readingLine  int
}

func NewHyprlandParser() *HyprlandParser {
	return &HyprlandParser{
		contentLines: []string{},
		readingLine:  0,
	}
}

func (p *HyprlandParser) ReadContent(directory string) error {
	expandedDir := os.ExpandEnv(directory)
	expandedDir = filepath.Clean(expandedDir)
	if strings.HasPrefix(expandedDir, "~") {
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		expandedDir = filepath.Join(home, expandedDir[1:])
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
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return nil
	}

	keys := parts[1]
	keyParts := strings.SplitN(keys, "#", 2)
	keys = keyParts[0]

	var comment string
	if len(keyParts) > 1 {
		comment = strings.TrimSpace(keyParts[1])
	}

	keyFields := strings.SplitN(keys, ",", 5)
	if len(keyFields) < 3 {
		return nil
	}

	mods := strings.TrimSpace(keyFields[0])
	key := strings.TrimSpace(keyFields[1])
	dispatcher := strings.TrimSpace(keyFields[2])

	var params string
	if len(keyFields) > 3 {
		paramParts := keyFields[3:]
		params = strings.TrimSpace(strings.Join(paramParts, ","))
	}

	if comment != "" {
		if strings.HasPrefix(comment, HideComment) {
			return nil
		}
	} else {
		comment = hyprlandAutogenerateComment(dispatcher, params)
	}

	var modList []string
	if mods != "" {
		modstring := mods + string(ModSeparators[0])
		p := 0
		for index, char := range modstring {
			isModSep := false
			for _, sep := range ModSeparators {
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

	return &HyprlandKeyBinding{
		Mods:       modList,
		Key:        key,
		Dispatcher: dispatcher,
		Params:     params,
		Comment:    comment,
	}
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
	parser := NewHyprlandParser()
	if err := parser.ReadContent(path); err != nil {
		return nil, err
	}
	return parser.ParseKeys(), nil
}
