package providers

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
	"github.com/sblinch/kdl-go"
	"github.com/sblinch/kdl-go/document"
)

type NiriProvider struct {
	configDir        string
	dmsBindsIncluded bool
	parsed           bool
}

func NewNiriProvider(configDir string) *NiriProvider {
	if configDir == "" {
		configDir = defaultNiriConfigDir()
	}
	return &NiriProvider{
		configDir: configDir,
	}
}

func defaultNiriConfigDir() string {
	if configHome := os.Getenv("XDG_CONFIG_HOME"); configHome != "" {
		return filepath.Join(configHome, "niri")
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".config", "niri")
}

func (n *NiriProvider) Name() string {
	return "niri"
}

func (n *NiriProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	result, err := ParseNiriKeys(n.configDir)
	if err != nil {
		return nil, fmt.Errorf("failed to parse niri config: %w", err)
	}

	n.dmsBindsIncluded = result.DMSBindsIncluded
	n.parsed = true

	categorizedBinds := make(map[string][]keybinds.Keybind)
	n.convertSection(result.Section, "", categorizedBinds, result.ConflictingConfigs)

	sheet := &keybinds.CheatSheet{
		Title:            "Niri Keybinds",
		Provider:         n.Name(),
		Binds:            categorizedBinds,
		DMSBindsIncluded: result.DMSBindsIncluded,
	}

	if result.DMSStatus != nil {
		sheet.DMSStatus = &keybinds.DMSBindsStatus{
			Exists:          result.DMSStatus.Exists,
			Included:        result.DMSStatus.Included,
			IncludePosition: result.DMSStatus.IncludePosition,
			TotalIncludes:   result.DMSStatus.TotalIncludes,
			BindsAfterDMS:   result.DMSStatus.BindsAfterDMS,
			Effective:       result.DMSStatus.Effective,
			OverriddenBy:    result.DMSStatus.OverriddenBy,
			StatusMessage:   result.DMSStatus.StatusMessage,
		}
	}

	return sheet, nil
}

func (n *NiriProvider) HasDMSBindsIncluded() bool {
	if n.parsed {
		return n.dmsBindsIncluded
	}

	result, err := ParseNiriKeys(n.configDir)
	if err != nil {
		return false
	}

	n.dmsBindsIncluded = result.DMSBindsIncluded
	n.parsed = true
	return n.dmsBindsIncluded
}

func (n *NiriProvider) convertSection(section *NiriSection, subcategory string, categorizedBinds map[string][]keybinds.Keybind, conflicts map[string]*NiriKeyBinding) {
	currentSubcat := subcategory
	if section.Name != "" {
		currentSubcat = section.Name
	}

	for _, kb := range section.Keybinds {
		category := n.categorizeByAction(kb.Action)
		bind := n.convertKeybind(&kb, currentSubcat, conflicts)
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	for _, child := range section.Children {
		n.convertSection(&child, currentSubcat, categorizedBinds, conflicts)
	}
}

func (n *NiriProvider) categorizeByAction(action string) string {
	switch {
	case action == "next-window" || action == "previous-window":
		return "Alt-Tab"
	case strings.Contains(action, "screenshot"):
		return "Screenshot"
	case action == "show-hotkey-overlay" || action == "toggle-overview":
		return "Overview"
	case action == "quit" ||
		action == "power-off-monitors" ||
		action == "toggle-keyboard-shortcuts-inhibit" ||
		strings.Contains(action, "dpms"):
		return "System"
	case action == "spawn":
		return "Execute"
	case strings.Contains(action, "workspace"):
		return "Workspace"
	case strings.HasPrefix(action, "focus-monitor") ||
		strings.HasPrefix(action, "move-column-to-monitor") ||
		strings.HasPrefix(action, "move-window-to-monitor"):
		return "Monitor"
	case strings.Contains(action, "window") ||
		strings.Contains(action, "focus") ||
		strings.Contains(action, "move") ||
		strings.Contains(action, "swap") ||
		strings.Contains(action, "resize") ||
		strings.Contains(action, "column"):
		return "Window"
	default:
		return "Other"
	}
}

func (n *NiriProvider) convertKeybind(kb *NiriKeyBinding, subcategory string, conflicts map[string]*NiriKeyBinding) keybinds.Keybind {
	rawAction := n.formatRawAction(kb.Action, kb.Args)
	keyStr := n.formatKey(kb)

	source := "config"
	if strings.Contains(kb.Source, "dms/binds.kdl") {
		source = "dms"
	}

	bind := keybinds.Keybind{
		Key:         keyStr,
		Description: kb.Description,
		Action:      rawAction,
		Subcategory: subcategory,
		Source:      source,
	}

	if source == "dms" && conflicts != nil {
		if conflictKb, ok := conflicts[keyStr]; ok {
			bind.Conflict = &keybinds.Keybind{
				Key:         keyStr,
				Description: conflictKb.Description,
				Action:      n.formatRawAction(conflictKb.Action, conflictKb.Args),
				Source:      "config",
			}
		}
	}

	return bind
}

func (n *NiriProvider) formatRawAction(action string, args []string) string {
	if len(args) == 0 {
		return action
	}

	if action == "spawn" && len(args) >= 3 && args[1] == "-c" {
		switch args[0] {
		case "sh", "bash":
			cmd := strings.Join(args[2:], " ")
			return fmt.Sprintf("spawn %s -c \"%s\"", args[0], strings.ReplaceAll(cmd, "\"", "\\\""))
		}
	}

	return action + " " + strings.Join(args, " ")
}

func (n *NiriProvider) formatKey(kb *NiriKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (n *NiriProvider) GetOverridePath() string {
	return filepath.Join(n.configDir, "dms", "binds.kdl")
}

func (n *NiriProvider) validateAction(action string) error {
	action = strings.TrimSpace(action)
	switch {
	case action == "":
		return fmt.Errorf("action cannot be empty")
	case action == "spawn" || action == "spawn ":
		return fmt.Errorf("spawn command requires arguments")
	case strings.HasPrefix(action, "spawn "):
		rest := strings.TrimSpace(strings.TrimPrefix(action, "spawn "))
		switch rest {
		case "":
			return fmt.Errorf("spawn command requires arguments")
		case "sh -c \"\"", "sh -c ''", "bash -c \"\"", "bash -c ''":
			return fmt.Errorf("shell command cannot be empty")
		}
	}
	return nil
}

func (n *NiriProvider) SetBind(key, action, description string, options map[string]any) error {
	if err := n.validateAction(action); err != nil {
		return err
	}

	overridePath := n.GetOverridePath()

	if err := os.MkdirAll(filepath.Dir(overridePath), 0755); err != nil {
		return fmt.Errorf("failed to create dms directory: %w", err)
	}

	existingBinds, err := n.loadOverrideBinds()
	if err != nil {
		existingBinds = make(map[string]*overrideBind)
	}

	existingBinds[key] = &overrideBind{
		Key:         key,
		Action:      action,
		Description: description,
		Options:     options,
	}

	return n.writeOverrideBinds(existingBinds)
}

func (n *NiriProvider) RemoveBind(key string) error {
	existingBinds, err := n.loadOverrideBinds()
	if err != nil {
		return nil
	}

	delete(existingBinds, key)
	return n.writeOverrideBinds(existingBinds)
}

type overrideBind struct {
	Key         string
	Action      string
	Description string
	Options     map[string]any
}

func (n *NiriProvider) loadOverrideBinds() (map[string]*overrideBind, error) {
	overridePath := n.GetOverridePath()
	binds := make(map[string]*overrideBind)

	data, err := os.ReadFile(overridePath)
	if os.IsNotExist(err) {
		return binds, nil
	}
	if err != nil {
		return nil, err
	}

	parser := NewNiriParser(filepath.Dir(overridePath))
	parser.currentSource = overridePath

	doc, err := kdl.Parse(strings.NewReader(string(data)))
	if err != nil {
		return nil, err
	}

	for _, node := range doc.Nodes {
		if node.Name.String() != "binds" || node.Children == nil {
			continue
		}
		for _, child := range node.Children {
			kb := parser.parseKeybindNode(child, "")
			if kb == nil {
				continue
			}
			keyStr := parser.formatBindKey(kb)
			binds[keyStr] = &overrideBind{
				Key:         keyStr,
				Action:      n.formatRawAction(kb.Action, kb.Args),
				Description: kb.Description,
				Options:     n.extractOptions(child),
			}
		}
	}

	return binds, nil
}

func (n *NiriProvider) extractOptions(node *document.Node) map[string]any {
	if node.Properties == nil {
		return make(map[string]any)
	}

	opts := make(map[string]any)
	if val, ok := node.Properties.Get("repeat"); ok {
		opts["repeat"] = val.String() == "true"
	}
	if val, ok := node.Properties.Get("cooldown-ms"); ok {
		opts["cooldown-ms"] = val.String()
	}
	if val, ok := node.Properties.Get("allow-when-locked"); ok {
		opts["allow-when-locked"] = val.String() == "true"
	}
	return opts
}

func (n *NiriProvider) isRecentWindowsAction(action string) bool {
	switch action {
	case "next-window", "previous-window":
		return true
	default:
		return false
	}
}

func (n *NiriProvider) parseSpawnArgs(s string) []string {
	var args []string
	var current strings.Builder
	var inQuote, escaped bool

	for _, r := range s {
		switch {
		case escaped:
			current.WriteRune(r)
			escaped = false
		case r == '\\':
			escaped = true
		case r == '"':
			inQuote = !inQuote
		case r == ' ' && !inQuote:
			if current.Len() > 0 {
				args = append(args, current.String())
				current.Reset()
			}
		default:
			current.WriteRune(r)
		}
	}
	if current.Len() > 0 {
		args = append(args, current.String())
	}
	return args
}

func (n *NiriProvider) buildBindNode(bind *overrideBind) *document.Node {
	node := document.NewNode()
	node.SetName(bind.Key)

	if bind.Options != nil {
		if v, ok := bind.Options["repeat"]; ok && v == false {
			node.AddProperty("repeat", false, "")
		}
		if v, ok := bind.Options["cooldown-ms"]; ok {
			node.AddProperty("cooldown-ms", v, "")
		}
		if v, ok := bind.Options["allow-when-locked"]; ok && v == true {
			node.AddProperty("allow-when-locked", true, "")
		}
	}

	if bind.Description != "" {
		node.AddProperty("hotkey-overlay-title", bind.Description, "")
	}

	actionNode := n.buildActionNode(bind.Action)
	node.AddNode(actionNode)

	return node
}

func (n *NiriProvider) buildActionNode(action string) *document.Node {
	action = strings.TrimSpace(action)
	node := document.NewNode()

	if !strings.HasPrefix(action, "spawn ") {
		node.SetName(action)
		return node
	}

	node.SetName("spawn")
	args := n.parseSpawnArgs(strings.TrimPrefix(action, "spawn "))
	for _, arg := range args {
		node.AddArgument(arg, "")
	}
	return node
}

func (n *NiriProvider) writeOverrideBinds(binds map[string]*overrideBind) error {
	overridePath := n.GetOverridePath()
	content := n.generateBindsContent(binds)

	if err := n.validateBindsContent(content); err != nil {
		return err
	}

	return os.WriteFile(overridePath, []byte(content), 0644)
}

func (n *NiriProvider) getBindSortPriority(action string) int {
	switch {
	case strings.HasPrefix(action, "spawn") && strings.Contains(action, "dms"):
		return 0
	case strings.Contains(action, "workspace"):
		return 1
	case strings.Contains(action, "window") || strings.Contains(action, "column") ||
		strings.Contains(action, "focus") || strings.Contains(action, "move") ||
		strings.Contains(action, "swap") || strings.Contains(action, "resize"):
		return 2
	case strings.HasPrefix(action, "focus-monitor") || strings.Contains(action, "monitor"):
		return 3
	case strings.Contains(action, "screenshot"):
		return 4
	case action == "quit" || action == "power-off-monitors" || strings.Contains(action, "dpms"):
		return 5
	case strings.HasPrefix(action, "spawn"):
		return 6
	default:
		return 7
	}
}

func (n *NiriProvider) generateBindsContent(binds map[string]*overrideBind) string {
	if len(binds) == 0 {
		return "binds {}\n"
	}

	var regularBinds, recentWindowsBinds []*overrideBind
	for _, bind := range binds {
		switch {
		case n.isRecentWindowsAction(bind.Action):
			recentWindowsBinds = append(recentWindowsBinds, bind)
		default:
			regularBinds = append(regularBinds, bind)
		}
	}

	sort.Slice(regularBinds, func(i, j int) bool {
		pi, pj := n.getBindSortPriority(regularBinds[i].Action), n.getBindSortPriority(regularBinds[j].Action)
		if pi != pj {
			return pi < pj
		}
		return regularBinds[i].Key < regularBinds[j].Key
	})

	sort.Slice(recentWindowsBinds, func(i, j int) bool {
		return recentWindowsBinds[i].Key < recentWindowsBinds[j].Key
	})

	var sb strings.Builder

	sb.WriteString("binds {\n")
	for _, bind := range regularBinds {
		n.writeBindNode(&sb, bind, "    ")
	}
	sb.WriteString("}\n")

	if len(recentWindowsBinds) > 0 {
		sb.WriteString("\nrecent-windows {\n")
		sb.WriteString("    binds {\n")
		for _, bind := range recentWindowsBinds {
			n.writeBindNode(&sb, bind, "        ")
		}
		sb.WriteString("    }\n")
		sb.WriteString("}\n")
	}

	return sb.String()
}

func (n *NiriProvider) writeBindNode(sb *strings.Builder, bind *overrideBind, indent string) {
	node := n.buildBindNode(bind)

	sb.WriteString(indent)
	sb.WriteString(node.Name.String())

	if node.Properties.Exist() {
		sb.WriteString(" ")
		sb.WriteString(strings.TrimLeft(node.Properties.String(), " "))
	}

	sb.WriteString(" { ")
	if len(node.Children) > 0 {
		child := node.Children[0]
		sb.WriteString(child.Name.String())
		for _, arg := range child.Arguments {
			sb.WriteString(" ")
			n.writeQuotedArg(sb, arg.ValueString())
		}
	}
	sb.WriteString("; }\n")
}

func (n *NiriProvider) writeQuotedArg(sb *strings.Builder, val string) {
	sb.WriteString("\"")
	sb.WriteString(strings.ReplaceAll(val, "\"", "\\\""))
	sb.WriteString("\"")
}

func (n *NiriProvider) validateBindsContent(content string) error {
	tmpFile, err := os.CreateTemp("", "dms-binds-*.kdl")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}
	defer os.Remove(tmpFile.Name())

	if _, err := tmpFile.WriteString(content); err != nil {
		tmpFile.Close()
		return fmt.Errorf("failed to write temp file: %w", err)
	}
	tmpFile.Close()

	cmd := exec.Command("niri", "validate", "-c", tmpFile.Name())
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("invalid config: %s", strings.TrimSpace(string(output)))
	}

	return nil
}
