package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

type MangoWCProvider struct {
	configPath       string
	dmsBindsIncluded bool
	parsed           bool
}

func NewMangoWCProvider(configPath string) *MangoWCProvider {
	if configPath == "" {
		configPath = defaultMangoWCConfigDir()
	}
	return &MangoWCProvider{
		configPath: configPath,
	}
}

func defaultMangoWCConfigDir() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return ""
	}
	return filepath.Join(configDir, "mango")
}

func (m *MangoWCProvider) Name() string {
	return "mangowc"
}

func (m *MangoWCProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	result, err := ParseMangoWCKeysWithDMS(m.configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse mangowc config: %w", err)
	}

	m.dmsBindsIncluded = result.DMSBindsIncluded
	m.parsed = true

	categorizedBinds := make(map[string][]keybinds.Keybind)
	for _, kb := range result.Keybinds {
		category := m.categorizeByCommand(kb.Command)
		bind := m.convertKeybind(&kb, result.ConflictingConfigs)
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	sheet := &keybinds.CheatSheet{
		Title:            "MangoWC Keybinds",
		Provider:         m.Name(),
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

func (m *MangoWCProvider) HasDMSBindsIncluded() bool {
	if m.parsed {
		return m.dmsBindsIncluded
	}

	result, err := ParseMangoWCKeysWithDMS(m.configPath)
	if err != nil {
		return false
	}

	m.dmsBindsIncluded = result.DMSBindsIncluded
	m.parsed = true
	return m.dmsBindsIncluded
}

func (m *MangoWCProvider) categorizeByCommand(command string) string {
	switch {
	case strings.Contains(command, "mon"):
		return "Monitor"
	case command == "toggleoverview":
		return "Overview"
	case command == "toggle_scratchpad":
		return "Scratchpad"
	case strings.Contains(command, "layout") || strings.Contains(command, "proportion"):
		return "Layout"
	case strings.Contains(command, "gaps"):
		return "Gaps"
	case strings.Contains(command, "view") || strings.Contains(command, "tag"):
		return "Tags"
	case command == "focusstack" ||
		command == "focusdir" ||
		command == "exchange_client" ||
		command == "killclient" ||
		command == "togglefloating" ||
		command == "togglefullscreen" ||
		command == "togglefakefullscreen" ||
		command == "togglemaximizescreen" ||
		command == "toggleglobal" ||
		command == "toggleoverlay" ||
		command == "minimized" ||
		command == "restore_minimized" ||
		command == "movewin" ||
		command == "resizewin":
		return "Window"
	case command == "spawn" || command == "spawn_shell":
		return "Execute"
	case command == "quit" || command == "reload_config":
		return "System"
	default:
		return "Other"
	}
}

func (m *MangoWCProvider) convertKeybind(kb *MangoWCKeyBinding, conflicts map[string]*MangoWCKeyBinding) keybinds.Keybind {
	keyStr := m.formatKey(kb)
	rawAction := m.formatRawAction(kb.Command, kb.Params)
	desc := kb.Comment

	if desc == "" {
		desc = rawAction
	}

	source := "config"
	if strings.Contains(kb.Source, "dms/binds.conf") || strings.Contains(kb.Source, "dms"+string(filepath.Separator)+"binds.conf") {
		source = "dms-default"
	}

	bind := keybinds.Keybind{
		Key:         keyStr,
		Description: desc,
		Action:      rawAction,
		Source:      source,
	}

	if source == "dms-default" && conflicts != nil {
		normalizedKey := strings.ToLower(keyStr)
		if conflictKb, ok := conflicts[normalizedKey]; ok {
			bind.Conflict = &keybinds.Keybind{
				Key:         keyStr,
				Description: conflictKb.Comment,
				Action:      m.formatRawAction(conflictKb.Command, conflictKb.Params),
				Source:      "config",
			}
		}
	}

	return bind
}

func (m *MangoWCProvider) formatRawAction(command, params string) string {
	if params != "" {
		return command + " " + params
	}
	return command
}

func (m *MangoWCProvider) formatKey(kb *MangoWCKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (m *MangoWCProvider) GetOverridePath() string {
	expanded, err := utils.ExpandPath(m.configPath)
	if err != nil {
		return filepath.Join(m.configPath, "dms", "binds.conf")
	}
	return filepath.Join(expanded, "dms", "binds.conf")
}

func (m *MangoWCProvider) validateAction(action string) error {
	action = strings.TrimSpace(action)
	switch {
	case action == "":
		return fmt.Errorf("action cannot be empty")
	case action == "spawn" || action == "spawn ":
		return fmt.Errorf("spawn command requires arguments")
	case action == "spawn_shell" || action == "spawn_shell ":
		return fmt.Errorf("spawn_shell command requires arguments")
	case strings.HasPrefix(action, "spawn "):
		rest := strings.TrimSpace(strings.TrimPrefix(action, "spawn "))
		if rest == "" {
			return fmt.Errorf("spawn command requires arguments")
		}
	case strings.HasPrefix(action, "spawn_shell "):
		rest := strings.TrimSpace(strings.TrimPrefix(action, "spawn_shell "))
		if rest == "" {
			return fmt.Errorf("spawn_shell command requires arguments")
		}
	}
	return nil
}

func (m *MangoWCProvider) SetBind(key, action, description string, options map[string]any) error {
	if err := m.validateAction(action); err != nil {
		return err
	}

	overridePath := m.GetOverridePath()

	if err := os.MkdirAll(filepath.Dir(overridePath), 0o755); err != nil {
		return fmt.Errorf("failed to create dms directory: %w", err)
	}

	existingBinds, err := m.loadOverrideBinds()
	if err != nil {
		existingBinds = make(map[string]*mangowcOverrideBind)
	}

	normalizedKey := strings.ToLower(key)
	existingBinds[normalizedKey] = &mangowcOverrideBind{
		Key:         key,
		Action:      action,
		Description: description,
		Options:     options,
	}

	return m.writeOverrideBinds(existingBinds)
}

func (m *MangoWCProvider) RemoveBind(key string) error {
	existingBinds, err := m.loadOverrideBinds()
	if err != nil {
		return nil
	}

	normalizedKey := strings.ToLower(key)
	delete(existingBinds, normalizedKey)
	return m.writeOverrideBinds(existingBinds)
}

func (m *MangoWCProvider) ResetBind(key string) error {
	return m.RemoveBind(key)
}

type mangowcOverrideBind struct {
	Key         string
	Action      string
	Description string
	Options     map[string]any
}

func (m *MangoWCProvider) loadOverrideBinds() (map[string]*mangowcOverrideBind, error) {
	overridePath := m.GetOverridePath()
	binds := make(map[string]*mangowcOverrideBind)

	data, err := os.ReadFile(overridePath)
	if os.IsNotExist(err) {
		return binds, nil
	}
	if err != nil {
		return nil, err
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		if !strings.HasPrefix(line, "bind") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) < 2 {
			continue
		}

		content := strings.TrimSpace(parts[1])
		commentParts := strings.SplitN(content, "#", 2)
		bindContent := strings.TrimSpace(commentParts[0])

		var comment string
		if len(commentParts) > 1 {
			comment = strings.TrimSpace(commentParts[1])
		}

		fields := strings.SplitN(bindContent, ",", 4)
		if len(fields) < 3 {
			continue
		}

		mods := strings.TrimSpace(fields[0])
		keyName := strings.TrimSpace(fields[1])
		command := strings.TrimSpace(fields[2])

		var params string
		if len(fields) > 3 {
			params = strings.TrimSpace(fields[3])
		}

		keyStr := m.buildKeyString(mods, keyName)
		normalizedKey := strings.ToLower(keyStr)
		action := command
		if params != "" {
			action = command + " " + params
		}

		binds[normalizedKey] = &mangowcOverrideBind{
			Key:         keyStr,
			Action:      action,
			Description: comment,
		}
	}

	return binds, nil
}

func (m *MangoWCProvider) buildKeyString(mods, key string) string {
	if mods == "" || strings.EqualFold(mods, "none") {
		return key
	}

	modList := strings.FieldsFunc(mods, func(r rune) bool {
		return r == '+' || r == ' '
	})

	parts := append(modList, key)
	return strings.Join(parts, "+")
}

func (m *MangoWCProvider) getBindSortPriority(action string) int {
	switch {
	case strings.HasPrefix(action, "spawn") && strings.Contains(action, "dms"):
		return 0
	case strings.Contains(action, "view") || strings.Contains(action, "tag"):
		return 1
	case strings.Contains(action, "focus") || strings.Contains(action, "exchange") ||
		strings.Contains(action, "resize") || strings.Contains(action, "move"):
		return 2
	case strings.Contains(action, "mon"):
		return 3
	case strings.HasPrefix(action, "spawn"):
		return 4
	case action == "quit" || action == "reload_config":
		return 5
	default:
		return 6
	}
}

func (m *MangoWCProvider) writeOverrideBinds(binds map[string]*mangowcOverrideBind) error {
	overridePath := m.GetOverridePath()
	content := m.generateBindsContent(binds)
	return os.WriteFile(overridePath, []byte(content), 0o644)
}

func (m *MangoWCProvider) generateBindsContent(binds map[string]*mangowcOverrideBind) string {
	if len(binds) == 0 {
		return ""
	}

	bindList := make([]*mangowcOverrideBind, 0, len(binds))
	for _, bind := range binds {
		bindList = append(bindList, bind)
	}

	sort.Slice(bindList, func(i, j int) bool {
		pi, pj := m.getBindSortPriority(bindList[i].Action), m.getBindSortPriority(bindList[j].Action)
		if pi != pj {
			return pi < pj
		}
		return bindList[i].Key < bindList[j].Key
	})

	var sb strings.Builder
	for _, bind := range bindList {
		m.writeBindLine(&sb, bind)
	}

	return sb.String()
}

func (m *MangoWCProvider) writeBindLine(sb *strings.Builder, bind *mangowcOverrideBind) {
	mods, key := m.parseKeyString(bind.Key)
	command, params := m.parseAction(bind.Action)

	sb.WriteString("bind=")
	if mods == "" {
		sb.WriteString("none")
	} else {
		sb.WriteString(mods)
	}
	sb.WriteString(",")
	sb.WriteString(key)
	sb.WriteString(",")
	sb.WriteString(command)

	if params != "" {
		sb.WriteString(",")
		sb.WriteString(params)
	}

	if bind.Description != "" {
		sb.WriteString(" # ")
		sb.WriteString(bind.Description)
	}

	sb.WriteString("\n")
}

func (m *MangoWCProvider) parseKeyString(keyStr string) (mods, key string) {
	parts := strings.Split(keyStr, "+")
	switch len(parts) {
	case 0:
		return "", keyStr
	case 1:
		return "", parts[0]
	default:
		return strings.Join(parts[:len(parts)-1], "+"), parts[len(parts)-1]
	}
}

func (m *MangoWCProvider) parseAction(action string) (command, params string) {
	parts := strings.SplitN(action, " ", 2)
	switch len(parts) {
	case 0:
		return action, ""
	case 1:
		return parts[0], ""
	default:
		return parts[0], parts[1]
	}
}
