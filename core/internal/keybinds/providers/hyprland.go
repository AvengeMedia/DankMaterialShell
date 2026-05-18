package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/keybinds"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
)

type HyprlandProvider struct {
	configPath       string
	dmsBindsIncluded bool
	parsed           bool
}

func NewHyprlandProvider(configPath string) *HyprlandProvider {
	if configPath == "" {
		configPath = defaultHyprlandConfigDir()
	}
	return &HyprlandProvider{
		configPath: configPath,
	}
}

func defaultHyprlandConfigDir() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return ""
	}
	return filepath.Join(configDir, "hypr")
}

func (h *HyprlandProvider) Name() string {
	return "hyprland"
}

func (h *HyprlandProvider) GetCheatSheet() (*keybinds.CheatSheet, error) {
	result, err := ParseHyprlandKeysWithDMS(h.configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to parse hyprland config: %w", err)
	}

	h.dmsBindsIncluded = result.DMSBindsIncluded
	h.parsed = true

	categorizedBinds := make(map[string][]keybinds.Keybind)
	h.convertSection(result.Section, "", categorizedBinds, result.ConflictingConfigs, result.DefaultDMSKeys)

	sheet := &keybinds.CheatSheet{
		Title:            "Hyprland Keybinds",
		Provider:         h.Name(),
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

func (h *HyprlandProvider) HasDMSBindsIncluded() bool {
	if h.parsed {
		return h.dmsBindsIncluded
	}

	result, err := ParseHyprlandKeysWithDMS(h.configPath)
	if err != nil {
		return false
	}

	h.dmsBindsIncluded = result.DMSBindsIncluded
	h.parsed = true
	return h.dmsBindsIncluded
}

func (h *HyprlandProvider) convertSection(section *HyprlandSection, subcategory string, categorizedBinds map[string][]keybinds.Keybind, conflicts map[string]*HyprlandKeyBinding, defaultKeys map[string]bool) {
	currentSubcat := subcategory
	if section.Name != "" {
		currentSubcat = section.Name
	}

	for _, kb := range section.Keybinds {
		category := h.categorizeByDispatcher(kb.Dispatcher)
		bind := h.convertKeybind(&kb, currentSubcat, conflicts, defaultKeys)
		categorizedBinds[category] = append(categorizedBinds[category], bind)
	}

	for _, child := range section.Children {
		h.convertSection(&child, currentSubcat, categorizedBinds, conflicts, defaultKeys)
	}
}

func (h *HyprlandProvider) categorizeByDispatcher(dispatcher string) string {
	switch {
	case strings.Contains(dispatcher, "workspace"):
		return "Workspace"
	case strings.Contains(dispatcher, "monitor"):
		return "Monitor"
	case strings.Contains(dispatcher, "window") ||
		strings.Contains(dispatcher, "focus") ||
		strings.Contains(dispatcher, "move") ||
		strings.Contains(dispatcher, "swap") ||
		strings.Contains(dispatcher, "resize") ||
		dispatcher == "killactive" ||
		dispatcher == "fullscreen" ||
		dispatcher == "togglefloating" ||
		dispatcher == "pin" ||
		dispatcher == "fakefullscreen" ||
		dispatcher == "splitratio" ||
		dispatcher == "resizeactive":
		return "Window"
	case dispatcher == "exec":
		return "Execute"
	case dispatcher == "exit" || strings.Contains(dispatcher, "dpms"):
		return "System"
	default:
		return "Other"
	}
}

func (h *HyprlandProvider) convertKeybind(kb *HyprlandKeyBinding, subcategory string, conflicts map[string]*HyprlandKeyBinding, defaultKeys map[string]bool) keybinds.Keybind {
	keyStr := h.formatKey(kb)
	rawAction := h.formatRawAction(kb.Dispatcher, kb.Params)
	desc := kb.Comment

	if desc == "" {
		desc = rawAction
	}

	source := "config"
	if isDMSBindsUserOverridePath(kb.Source) {
		source = "dms"
	} else if isDMSBindsPrimarySourcePath(kb.Source) {
		source = "dms-default"
	}

	hasDefault := false
	if source == "dms" && defaultKeys != nil {
		hasDefault = defaultKeys[strings.ToLower(keyStr)]
	}

	bind := keybinds.Keybind{
		Key:         keyStr,
		Description: desc,
		Action:      rawAction,
		Subcategory: subcategory,
		Source:      source,
		Flags:       kb.Flags,
		HasDefault:  hasDefault,
	}

	if (source == "dms" || source == "dms-default") && conflicts != nil {
		normalizedKey := strings.ToLower(keyStr)
		if conflictKb, ok := conflicts[normalizedKey]; ok {
			bind.Conflict = &keybinds.Keybind{
				Key:         keyStr,
				Description: conflictKb.Comment,
				Action:      h.formatRawAction(conflictKb.Dispatcher, conflictKb.Params),
				Source:      "config",
			}
		}
	}

	return bind
}

func (h *HyprlandProvider) formatRawAction(dispatcher, params string) string {
	if params != "" {
		return dispatcher + " " + params
	}
	return dispatcher
}

func (h *HyprlandProvider) formatKey(kb *HyprlandKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (h *HyprlandProvider) GetOverridePath() string {
	expanded, err := utils.ExpandPath(h.configPath)
	if err != nil {
		return filepath.Join(h.configPath, "dms", "binds-user.lua")
	}
	return filepath.Join(expanded, "dms", "binds-user.lua")
}

func (h *HyprlandProvider) validateAction(action string) error {
	action = strings.TrimSpace(action)
	switch {
	case action == "":
		return fmt.Errorf("action cannot be empty")
	case action == "exec" || action == "exec ":
		return fmt.Errorf("exec dispatcher requires arguments")
	case strings.HasPrefix(action, "exec "):
		rest := strings.TrimSpace(strings.TrimPrefix(action, "exec "))
		if rest == "" {
			return fmt.Errorf("exec dispatcher requires arguments")
		}
	}
	return nil
}

func (h *HyprlandProvider) SetBind(key, action, description string, options map[string]any) error {
	if err := h.validateAction(action); err != nil {
		return err
	}

	overridePath := h.GetOverridePath()

	if err := os.MkdirAll(filepath.Dir(overridePath), 0o755); err != nil {
		return fmt.Errorf("failed to create dms directory: %w", err)
	}

	existingBinds, err := h.loadOverrideBinds()
	if err != nil {
		existingBinds = make(map[string]*hyprlandOverrideBind)
	}

	// Extract flags from options
	var flags string
	if options != nil {
		if f, ok := options["flags"].(string); ok {
			flags = f
		}
	}

	normalizedKey := strings.ToLower(key)
	existingBinds[normalizedKey] = &hyprlandOverrideBind{
		Key:         key,
		Action:      action,
		Description: description,
		Flags:       flags,
		Options:     options,
	}

	return h.writeOverrideBinds(existingBinds)
}

func (h *HyprlandProvider) RemoveBind(key string) error {
	existingBinds, err := h.loadOverrideBinds()
	if err != nil {
		return nil
	}
	normalizedKey := strings.ToLower(key)
	existingBinds[normalizedKey] = &hyprlandOverrideBind{Key: key, Unbind: true}
	return h.writeOverrideBinds(existingBinds)
}

func (h *HyprlandProvider) ResetBind(key string) error {
	existingBinds, err := h.loadOverrideBinds()
	if err != nil {
		return nil
	}
	normalizedKey := strings.ToLower(key)
	delete(existingBinds, normalizedKey)
	return h.writeOverrideBinds(existingBinds)
}

type hyprlandOverrideBind struct {
	Key         string
	Action      string
	Description string
	Flags       string // Bind flags: l=locked, r=release, e=repeat, n=non-consuming, m=mouse, t=transparent, i=ignore-mods, s=separate, d=description, o=long-press
	Options     map[string]any
	// Unbind: negative override (hl.unbind only, no rebind).
	Unbind bool
}

func (h *HyprlandProvider) loadOverrideBinds() (map[string]*hyprlandOverrideBind, error) {
	return readLuaOrHyprlangOverride(h.GetOverridePath())
}

func (h *HyprlandProvider) getBindSortPriority(action string) int {
	switch {
	case strings.HasPrefix(action, "exec") && strings.Contains(action, "dms"):
		return 0
	case strings.Contains(action, "workspace"):
		return 1
	case strings.Contains(action, "window") || strings.Contains(action, "focus") ||
		strings.Contains(action, "move") || strings.Contains(action, "swap") ||
		strings.Contains(action, "resize"):
		return 2
	case strings.Contains(action, "monitor"):
		return 3
	case strings.HasPrefix(action, "exec"):
		return 4
	case action == "exit" || strings.Contains(action, "dpms"):
		return 5
	default:
		return 6
	}
}

func (h *HyprlandProvider) writeOverrideBinds(binds map[string]*hyprlandOverrideBind) error {
	overridePath := h.GetOverridePath()
	content := h.generateBindsContent(binds)
	return os.WriteFile(overridePath, []byte(content), 0o644)
}

func (h *HyprlandProvider) generateBindsContent(binds map[string]*hyprlandOverrideBind) string {
	if len(binds) == 0 {
		return ""
	}

	bindList := make([]*hyprlandOverrideBind, 0, len(binds))
	for _, bind := range binds {
		bindList = append(bindList, bind)
	}

	sort.Slice(bindList, func(i, j int) bool {
		pi, pj := h.getBindSortPriority(bindList[i].Action), h.getBindSortPriority(bindList[j].Action)
		if pi != pj {
			return pi < pj
		}
		return bindList[i].Key < bindList[j].Key
	})

	var sb strings.Builder
	sb.WriteString("-- DMS user keybind overrides (edit via Control Center or dms; do not remove this header)\n\n")
	for _, bind := range bindList {
		writeLuaBindLine(&sb, bind)
	}

	return sb.String()
}

func formatLuaBindKey(internalKey string) string {
	internalKey = strings.TrimSpace(internalKey)
	parts := strings.Split(internalKey, "+")
	for i := range parts {
		parts[i] = normalizeLuaBindKeyPart(strings.TrimSpace(parts[i]))
	}
	return strings.Join(parts, " + ")
}

func normalizeLuaBindKeyPart(part string) string {
	switch strings.ToLower(part) {
	case "super", "mod4", "mainmod":
		return "SUPER"
	case "ctrl", "control":
		return "CTRL"
	case "shift":
		return "SHIFT"
	case "alt", "mod1":
		return "ALT"
	}
	if len(part) == 1 {
		return strings.ToUpper(part)
	}
	return part
}

func luaActionStringFromHyprlangAction(action string) string {
	action = strings.TrimSpace(action)
	if strings.HasPrefix(action, "spawn ") {
		return fmt.Sprintf(`hl.dsp.exec_cmd(%s)`, strconv.Quote(strings.TrimSpace(strings.TrimPrefix(action, "spawn "))))
	}
	if strings.HasPrefix(action, "exec ") {
		return fmt.Sprintf(`hl.dsp.exec_cmd(%s)`, strconv.Quote(strings.TrimPrefix(action, "exec ")))
	}
	switch action {
	case "killactive":
		return `hl.dsp.window.kill()`
	case "togglefloating":
		return `hl.dsp.window.float({ action = "toggle" })`
	case "exit":
		return `hl.dsp.exit()`
	default:
		return fmt.Sprintf(`hl.dsp.exec_cmd(%s)`, strconv.Quote("hyprctl dispatch "+action))
	}
}

func luaExprToInternalAction(expr string) string {
	d, p := luaExprToDispatcherParams(expr)
	if d == "exec" && p != "" && !strings.HasPrefix(p, "hyprctl dispatch lua:") {
		return "exec " + p
	}
	if p != "" {
		return d + " " + p
	}
	return d
}

func luaBindOptions(bind *hyprlandOverrideBind) []string {
	var opts []string
	if strings.Contains(bind.Flags, "l") {
		opts = append(opts, "locked = true")
	}
	if strings.Contains(bind.Flags, "e") {
		opts = append(opts, "repeating = true")
	}
	if bind.Description != "" && strings.Contains(bind.Flags, "d") {
		opts = append(opts, fmt.Sprintf("description = %s", strconv.Quote(bind.Description)))
	}
	return opts
}

func writeLuaBindLine(sb *strings.Builder, bind *hyprlandOverrideBind) {
	key := formatLuaBindKey(bind.Key)
	if bind.Unbind {
		fmt.Fprintf(sb, `hl.unbind("%s")`, key)
		sb.WriteByte('\n')
		return
	}
	expr := luaActionStringFromHyprlangAction(bind.Action)
	opts := luaBindOptions(bind)
	fmt.Fprintf(sb, `hl.unbind("%s")`, key)
	sb.WriteByte('\n')
	if len(opts) > 0 {
		fmt.Fprintf(sb, `hl.bind("%s", %s, { %s })`, key, expr, strings.Join(opts, ", "))
	} else {
		if bind.Description != "" {
			fmt.Fprintf(sb, `hl.bind("%s", %s) -- %s`, key, expr, bind.Description)
		} else {
			fmt.Fprintf(sb, `hl.bind("%s", %s)`, key, expr)
		}
	}
	sb.WriteByte('\n')
}

func parseLuaBindOverrideLine(line string) (*hyprlandOverrideBind, bool) {
	line = strings.TrimSpace(line)
	if line == "" || strings.HasPrefix(line, "--") {
		return nil, false
	}
	kbc, actionExpr, optSuffix, ok := parseLuaBindInvocation(line)
	if !ok {
		return nil, false
	}
	internalKey := luaKeyComboToInternalKey(kbc)

	action := luaExprToInternalAction(actionExpr)
	flags := luaBindOptFlags(optSuffix)
	description := luaBindOptDescription(optSuffix)
	return &hyprlandOverrideBind{
		Key:         internalKey,
		Action:      action,
		Description: description,
		Flags:       flags,
	}, true
}

func parseLuaUnbindLine(line string) (string, bool) {
	line = strings.TrimSpace(line)
	if !strings.HasPrefix(line, "hl.unbind") {
		return "", false
	}
	rest := strings.TrimSpace(line[len("hl.unbind"):])
	if !strings.HasPrefix(rest, "(") {
		return "", false
	}
	rest = rest[1:]
	combo, _, ok := parseLuaStringLiteral(rest, 0)
	if !ok {
		return "", false
	}
	return luaKeyComboToInternalKey(combo), true
}

func luaKeyComboToInternalKey(combo string) string {
	parts := strings.Fields(strings.ReplaceAll(strings.ReplaceAll(combo, "+", " "), "  ", " "))
	return strings.Join(parts, "+")
}

func readLuaOrHyprlangOverride(path string) (map[string]*hyprlandOverrideBind, error) {
	binds := make(map[string]*hyprlandOverrideBind)
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return binds, nil
	}
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(data), "\n")
	parser := NewHyprlandParser("")
	pendingUnbinds := make(map[string]string)
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "--") {
			continue
		}
		if key, ok := parseLuaUnbindLine(line); ok {
			pendingUnbinds[strings.ToLower(key)] = key
			continue
		}
		if kb, ok := parseLuaBindOverrideLine(line); ok {
			normalizedKey := strings.ToLower(kb.Key)
			binds[normalizedKey] = kb
			delete(pendingUnbinds, normalizedKey)
			continue
		}
		if !strings.HasPrefix(line, "bind") {
			continue
		}
		kb := parser.parseBindLine(line)
		if kb == nil {
			continue
		}
		keyStr := parser.formatBindKey(kb)
		action := kb.Dispatcher
		if kb.Params != "" {
			action = kb.Dispatcher + " " + kb.Params
		}
		flags := kb.Flags
		normalizedKey := strings.ToLower(keyStr)
		binds[normalizedKey] = &hyprlandOverrideBind{
			Key:         keyStr,
			Action:      action,
			Description: kb.Comment,
			Flags:       flags,
		}
		delete(pendingUnbinds, normalizedKey)
	}
	for normKey, origKey := range pendingUnbinds {
		binds[normKey] = &hyprlandOverrideBind{Key: origKey, Unbind: true}
	}
	return binds, nil
}
