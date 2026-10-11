package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/configfrag"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/luaconfig"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/windowrules"
)

type HyprlandWindowRule struct {
	Match   windowrules.MatchCriteria
	Actions windowrules.Actions
	Source  string
	RawLine string
}

type HyprlandRulesParser struct {
	configDir      string
	processedFiles map[string]bool
	rules          []HyprlandWindowRule
	currentSource  string
	dmsRulesExists bool
	dmsPrimaryPath string // dms/windowrules.lua preferred, else dms/windowrules.conf when present
	walker         *configfrag.Walker
	rulesAfterDMS  int
	dmsProcessed   bool
	configFormat   string
	readOnly       bool

	requireLineInMain int    // hyprland.lua line (1-based) where require("dms.windowrules") occurs; else -1
	primaryHyprLua    string // absolute path to ~/.config/hypr/hyprland.lua when that is the main config
}

func NewHyprlandRulesParser(configDir string) *HyprlandRulesParser {
	return &HyprlandRulesParser{
		configDir:         configDir,
		processedFiles:    make(map[string]bool),
		rules:             []HyprlandWindowRule{},
		walker:            configfrag.NewWalker(isDMSWindowRulesSourcePath),
		requireLineInMain: -1,
	}
}

func (p *HyprlandRulesParser) Parse() ([]HyprlandWindowRule, error) {
	expandedDir, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}

	dmsLua := filepath.Join(expandedDir, "dms", "windowrules.lua")
	dmsConf := filepath.Join(expandedDir, "dms", "windowrules.conf")
	if _, err := os.Stat(dmsLua); err == nil {
		p.dmsRulesExists = true
		p.dmsPrimaryPath = dmsLua
	} else if _, err := os.Stat(dmsConf); err == nil {
		p.dmsRulesExists = true
		p.dmsPrimaryPath = dmsConf
	}

	mainConfig, err := hyprlandMainConfigPath(expandedDir)
	if err != nil {
		return nil, err
	}

	if strings.EqualFold(filepath.Ext(mainConfig), ".lua") {
		p.configFormat = "lua"
		p.probeRequireWindowrulesLine(mainConfig)
		if ap, err := filepath.Abs(mainConfig); err == nil {
			p.primaryHyprLua = ap
		}
	} else {
		p.configFormat = "hyprlang"
		p.readOnly = true
	}

	if err := p.parseFile(mainConfig); err != nil {
		return nil, err
	}

	if p.dmsRulesExists && !p.dmsProcessed {
		p.parseDMSRulesDirectly(p.dmsPrimaryPath)
	}

	return p.rules, nil
}

func (p *HyprlandRulesParser) parseDMSRulesDirectly(dmsRulesPath string) {
	data, err := os.ReadFile(dmsRulesPath)
	if err != nil {
		return
	}

	abs, err := filepath.Abs(dmsRulesPath)
	if err != nil {
		abs = dmsRulesPath
	}

	if strings.EqualFold(filepath.Ext(abs), ".lua") {
		p.parseLuaWindowRules(string(data), filepath.Dir(abs), abs, false)
	} else {
		p.parseHyprlangContent(string(data), filepath.Dir(abs), abs, false)
	}
	p.dmsProcessed = true
}

func (p *HyprlandRulesParser) parseFile(filePath string) error {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return err
	}

	if p.processedFiles[absPath] {
		return nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil
	}

	if strings.EqualFold(filepath.Ext(absPath), ".lua") {
		p.parseLuaWindowRules(string(data), filepath.Dir(absPath), absPath, true)
		return nil
	}
	p.parseHyprlangContent(string(data), filepath.Dir(absPath), absPath, true)
	return nil
}

func (p *HyprlandRulesParser) parseHyprlangContent(content, baseDir, absPath string, allowSource bool) {
	prevSource := p.currentSource
	p.currentSource = absPath
	defer func() { p.currentSource = prevSource }()

	lines := strings.Split(content, "\n")
	for i := 0; i < len(lines); i++ {
		trimmed := strings.TrimSpace(lines[i])
		switch {
		case allowSource && strings.HasPrefix(trimmed, "source"):
			p.handleSource(trimmed, baseDir)
		case windowRuleBlockRegex.MatchString(strings.TrimSpace(stripHyprlangComment(trimmed))):
			i = p.parseWindowRuleBlock(lines, i)
		default:
			p.parseLine(trimmed)
		}
	}
}

func (p *HyprlandRulesParser) handleSource(line string, baseDir string) {
	matched := p.walker.IncludeAssignment(baseDir, line, func(absPath string) error {
		return p.parseFile(absPath)
	})
	if matched {
		p.dmsProcessed = true
	}
}

func (p *HyprlandRulesParser) parseLine(line string) {
	trimmed := strings.TrimSpace(line)
	if !strings.HasPrefix(trimmed, "windowrule") {
		return
	}
	rule := p.parseWindowRuleLine(trimmed)
	if rule == nil {
		return
	}
	rule.Source = p.currentSource
	p.rules = append(p.rules, *rule)
}

var windowRuleV2Regex = regexp.MustCompile(`^windowrulev?2?\s*=\s*(.+)$`)
var windowRuleBlockRegex = regexp.MustCompile(`^windowrule\s*\{$`)

// stripHyprlangComment cuts at the first `#` the way hyprlang does; `##` is a literal `#`.
func stripHyprlangComment(line string) string {
	if !strings.Contains(line, "#") {
		return line
	}
	var sb strings.Builder
	for i := 0; i < len(line); i++ {
		if line[i] != '#' {
			sb.WriteByte(line[i])
			continue
		}
		if i+1 < len(line) && line[i+1] == '#' {
			sb.WriteByte('#')
			i++
			continue
		}
		break
	}
	return sb.String()
}

func (p *HyprlandRulesParser) parseWindowRuleLine(line string) *HyprlandWindowRule {
	rule := &HyprlandWindowRule{RawLine: line}
	line = strings.TrimSpace(stripHyprlangComment(line))
	matches := windowRuleV2Regex.FindStringSubmatch(line)
	if len(matches) < 2 {
		return nil
	}

	content := strings.TrimSpace(matches[1])

	switch {
	case strings.HasPrefix(line, "windowrulev2"):
		p.parseWindowRuleV2(content, rule)
	case strings.Contains(content, "match:"):
		parseWindowRuleMatchSyntax(content, rule)
	default:
		p.parseWindowRuleV1(content, rule)
	}

	return rule
}

func (p *HyprlandRulesParser) parseWindowRuleV1(content string, rule *HyprlandWindowRule) {
	parts := strings.SplitN(content, ",", 2)
	if len(parts) < 2 {
		return
	}

	rule.Match.AppID = strings.TrimSpace(parts[1])
	applyHyprlandRuleAction(&rule.Actions, strings.TrimSpace(parts[0]), "")
}

func (p *HyprlandRulesParser) parseWindowRuleV2(content string, rule *HyprlandWindowRule) {
	parts := strings.SplitN(content, ",", 2)
	if len(parts) < 2 {
		return
	}

	ruleName, value, _ := strings.Cut(strings.TrimSpace(parts[0]), " ")
	applyHyprlandRuleAction(&rule.Actions, ruleName, strings.TrimSpace(value))

	for pair := range strings.SplitSeq(parts[1], ",") {
		key, value, ok := strings.Cut(strings.TrimSpace(pair), ":")
		if !ok || key == "" {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)
		b := value == "1" || value == "true"

		switch key {
		case "class":
			rule.Match.AppID = value
		case "title":
			rule.Match.Title = value
		case "xwayland":
			rule.Match.XWayland = &b
		case "floating":
			rule.Match.IsFloating = &b
		case "fullscreen":
			rule.Match.Fullscreen = &b
		case "pinned":
			rule.Match.Pinned = &b
		case "initialised", "initialized":
			rule.Match.Initialised = &b
		}
	}
}

// 0.53+ hyprlang: `windowrule = match:class kitty, float on`; keys share the Lua names.
func parseWindowRuleMatchSyntax(content string, rule *HyprlandWindowRule) {
	for seg := range strings.SplitSeq(content, ",") {
		seg = strings.TrimSpace(seg)
		key, value, _ := strings.Cut(seg, " ")
		applyHyprlangRuleField(rule, key, value)
	}
}

func (p *HyprlandRulesParser) parseWindowRuleBlock(lines []string, start int) int {
	rule := HyprlandWindowRule{Source: p.currentSource}
	end := start + 1
	for ; end < len(lines); end++ {
		trimmed := strings.TrimSpace(stripHyprlangComment(lines[end]))
		if trimmed == "}" {
			break
		}
		if key, value, ok := strings.Cut(trimmed, "="); ok {
			applyHyprlangRuleField(&rule, key, value)
		}
	}
	rule.RawLine = strings.TrimSpace(strings.Join(lines[start:min(end+1, len(lines))], "\n"))
	p.rules = append(p.rules, rule)
	return end
}

func applyHyprlangRuleField(rule *HyprlandWindowRule, key, value string) {
	key = strings.ToLower(strings.TrimSpace(key))
	raw := hyprlangValueToLua(key, strings.TrimSpace(value))
	if matchKey, ok := strings.CutPrefix(key, "match:"); ok {
		applyLuaMatchKey(&rule.Match, matchKey, raw)
		return
	}
	applyLuaActionKey(&rule.Actions, key, raw)
}

func hyprlangValueToLua(key, value string) string {
	// Actions has one opacity, so `opacity active inactive` keeps only the active value.
	if f := strings.Fields(value); len(f) > 1 && key == "opacity" {
		value = f[0]
	}
	switch strings.ToLower(value) {
	case "", "on":
		return "true"
	case "off":
		return "false"
	}
	if _, ok := luaBoolLike(value); ok {
		return value
	}
	if _, err := strconv.ParseFloat(value, 64); err == nil {
		return value
	}
	if f := strings.Fields(value); len(f) == 2 && (key == "size" || key == "move") {
		return fmt.Sprintf("{ %s, %s }", strconv.Quote(f[0]), strconv.Quote(f[1]))
	}
	return strconv.Quote(value)
}

func (p *HyprlandRulesParser) HasDMSRulesIncluded() bool {
	return p.walker.Included()
}

var hyprlandRulesMessages = configfrag.Messages{
	Missing:     "dms window rules fragment (windowrules.lua / windowrules.conf) does not exist",
	NotIncluded: "dms window rules are not loaded (missing require/source for dms/windowrules)",
	Overridden:  "Some DMS rules may be overridden by config rules",
	Active:      "DMS window rules are active",
}

func (p *HyprlandRulesParser) buildDMSStatus() *windowrules.DMSRulesStatus {
	return windowrules.DMSRulesStatusFrom(configfrag.BuildStatus(p.walker.Scan(), p.dmsRulesExists, p.rulesAfterDMS, p.configFormat, p.readOnly, hyprlandRulesMessages))
}

type HyprlandRulesParseResult struct {
	Rules            []HyprlandWindowRule
	DMSRulesIncluded bool
	DMSStatus        *windowrules.DMSRulesStatus
}

func ParseHyprlandWindowRules(configDir string) (*HyprlandRulesParseResult, error) {
	parser := NewHyprlandRulesParser(configDir)
	rules, err := parser.Parse()
	if err != nil {
		return nil, err
	}
	return &HyprlandRulesParseResult{
		Rules:            rules,
		DMSRulesIncluded: parser.HasDMSRulesIncluded(),
		DMSStatus:        parser.buildDMSStatus(),
	}, nil
}

func applyHyprlandRuleAction(actions *windowrules.Actions, rule, value string) {
	t := true
	switch rule {
	case "float":
		actions.OpenFloating = &t
	case "tile":
		actions.Tile = &t
	case "fullscreen":
		actions.OpenFullscreen = &t
	case "maximize":
		actions.OpenMaximized = &t
	case "nofocus":
		actions.NoFocus = &t
	case "noborder":
		actions.NoBorder = &t
	case "noshadow":
		actions.NoShadow = &t
	case "nodim":
		actions.NoDim = &t
	case "noblur":
		actions.NoBlur = &t
	case "noanim":
		actions.NoAnim = &t
	case "norounding":
		actions.NoRounding = &t
	case "pin":
		actions.Pin = &t
	case "opaque":
		actions.Opaque = &t
	case "forcergbx":
		actions.ForcergbX = &t
	case "opacity":
		if f, err := strconv.ParseFloat(value, 64); err == nil {
			actions.Opacity = &f
		}
	case "monitor":
		actions.Monitor = value
	case "workspace":
		actions.Workspace = value
	case "idleinhibit":
		actions.Idleinhibit = value
	case "rounding":
		if i, err := strconv.Atoi(value); err == nil {
			actions.CornerRadius = &i
		}
	}
}

func ConvertHyprlandRulesToWindowRules(hyprRules []HyprlandWindowRule) []windowrules.WindowRule {
	result := make([]windowrules.WindowRule, 0, len(hyprRules))
	for i, hr := range hyprRules {
		result = append(result, windowrules.WindowRule{
			ID:            strconv.Itoa(i),
			Enabled:       true,
			Source:        hr.Source,
			MatchCriteria: hr.Match,
			Actions:       hr.Actions,
		})
	}
	return result
}

type HyprlandWritableProvider struct {
	configDir string
}

func NewHyprlandWritableProvider(configDir string) *HyprlandWritableProvider {
	return &HyprlandWritableProvider{configDir: configDir}
}

func (p *HyprlandWritableProvider) Name() string {
	return "hyprland"
}

func (p *HyprlandWritableProvider) GetOverridePath() string {
	expanded, _ := utils.ExpandPath(p.configDir)
	return filepath.Join(expanded, "dms", "windowrules.lua")
}

func (p *HyprlandWritableProvider) GetRuleSet() (*windowrules.RuleSet, error) {
	result, err := ParseHyprlandWindowRules(p.configDir)
	if err != nil {
		return nil, err
	}
	return &windowrules.RuleSet{
		Title:            "Hyprland Window Rules",
		Provider:         "hyprland",
		Rules:            ConvertHyprlandRulesToWindowRules(result.Rules),
		DMSRulesIncluded: result.DMSRulesIncluded,
		DMSStatus:        result.DMSStatus,
	}, nil
}

func (p *HyprlandWritableProvider) EnsureWritable() error {
	if p.isLegacyConfigReadOnly() {
		return fmt.Errorf("hyprland legacy conf configs are read-only; run dms setup to migrate to Lua before editing window rules")
	}
	return nil
}

func (p *HyprlandWritableProvider) SetRule(rule windowrules.WindowRule) error {
	return windowrules.Set(p, rule)
}

func (p *HyprlandWritableProvider) RemoveRule(id string) error {
	return windowrules.Remove(p, id)
}

func (p *HyprlandWritableProvider) ReorderRules(ids []string) error {
	return windowrules.Reorder(p, ids)
}

func (p *HyprlandWritableProvider) isLegacyConfigReadOnly() bool {
	expanded, err := utils.ExpandPath(p.configDir)
	if err != nil {
		expanded = p.configDir
	}
	luaPath := filepath.Join(expanded, "hyprland.lua")
	if st, err := os.Stat(luaPath); err == nil && st.Mode().IsRegular() {
		return false
	}
	confPath := filepath.Join(expanded, "hyprland.conf")
	if st, err := os.Stat(confPath); err == nil && st.Mode().IsRegular() {
		return true
	}
	return false
}

var dmsRuleCommentRegex = regexp.MustCompile(`^#\s*DMS-RULE:\s*id=([^,]+),\s*name=(.*)$`)
var dmsRuleLuaHDRRegex = regexp.MustCompile(`^\s*--\s*DMS-RULE:\s*id=([^,]+),\s*name=(.*)$`)

// 0.55/0.56 reject rounding above 20 and drop the rule; main allows 100. Raise after 0.57 ships.
const hyprlandMaxRounding = 20

type luaField[S, V any] struct {
	key   string
	field func(*S) *V
}

var hyprBoolMatches = []luaField[windowrules.MatchCriteria, *bool]{
	{"focus", func(m *windowrules.MatchCriteria) **bool { return &m.IsFocused }},
	{"group", func(m *windowrules.MatchCriteria) **bool { return &m.Grouped }},
	{"modal", func(m *windowrules.MatchCriteria) **bool { return &m.Modal }},
}

var hyprStringMatches = []luaField[windowrules.MatchCriteria, string]{
	{"initial_class", func(m *windowrules.MatchCriteria) *string { return &m.InitialClass }},
	{"initial_title", func(m *windowrules.MatchCriteria) *string { return &m.InitialTitle }},
	{"tag", func(m *windowrules.MatchCriteria) *string { return &m.Tag }},
	{"workspace", func(m *windowrules.MatchCriteria) *string { return &m.Workspace }},
	{"content", func(m *windowrules.MatchCriteria) *string { return &m.Content }},
	{"xdg_tag", func(m *windowrules.MatchCriteria) *string { return &m.XdgTag }},
}

var hyprIntMatches = []luaField[windowrules.MatchCriteria, *int]{
	{"fullscreen_state_internal", func(m *windowrules.MatchCriteria) **int { return &m.FullscreenStateInternal }},
	{"fullscreen_state_client", func(m *windowrules.MatchCriteria) **int { return &m.FullscreenStateClient }},
}

var hyprBoolEffects = []luaField[windowrules.Actions, *bool]{
	{"no_initial_focus", func(a *windowrules.Actions) **bool { return &a.NoInitialFocus }},
	{"focus_on_activate", func(a *windowrules.Actions) **bool { return &a.FocusOnActivate }},
	{"stay_focused", func(a *windowrules.Actions) **bool { return &a.StayFocused }},
	{"confine_pointer", func(a *windowrules.Actions) **bool { return &a.ConfinePointer }},
	{"no_xdg_drags", func(a *windowrules.Actions) **bool { return &a.NoXdgDrags }},
	{"no_auto_hdr", func(a *windowrules.Actions) **bool { return &a.NoAutoHDR }},
	{"no_glow", func(a *windowrules.Actions) **bool { return &a.NoGlow }},
	{"no_wobble", func(a *windowrules.Actions) **bool { return &a.NoWobble }},
}

var hyprStringEffects = []luaField[windowrules.Actions, string]{
	{"border_color", func(a *windowrules.Actions) *string { return &a.BorderColor }},
	{"tonemap", func(a *windowrules.Actions) *string { return &a.Tonemap }},
	{"suppress_event", func(a *windowrules.Actions) *string { return &a.SuppressEvent }},
}

func hyprLuaBoolStr(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func hyprLuaExprWrap(v string) string {
	if _, err := strconv.ParseFloat(v, 64); err == nil {
		return v
	}
	return strconv.Quote(v)
}

func luaAppendMatch(mc windowrules.MatchCriteria, dst *[]string) {
	if mc.AppID != "" {
		*dst = append(*dst, fmt.Sprintf(`class = %s`, strconv.Quote(mc.AppID)))
	}
	if mc.Title != "" {
		*dst = append(*dst, fmt.Sprintf(`title = %s`, strconv.Quote(mc.Title)))
	}
	if mc.XWayland != nil {
		*dst = append(*dst, fmt.Sprintf(`xwayland = %s`, hyprLuaBoolStr(*mc.XWayland)))
	}
	if mc.IsFloating != nil {
		*dst = append(*dst, fmt.Sprintf(`float = %s`, hyprLuaBoolStr(*mc.IsFloating)))
	}
	if mc.Fullscreen != nil {
		*dst = append(*dst, fmt.Sprintf(`fullscreen = %s`, hyprLuaBoolStr(*mc.Fullscreen)))
	}
	if mc.Pinned != nil {
		*dst = append(*dst, fmt.Sprintf(`pin = %s`, hyprLuaBoolStr(*mc.Pinned)))
	}
	for _, f := range hyprBoolMatches {
		if v := *f.field(&mc); v != nil {
			*dst = append(*dst, fmt.Sprintf(`%s = %s`, f.key, hyprLuaBoolStr(*v)))
		}
	}
	for _, f := range hyprStringMatches {
		if v := *f.field(&mc); v != "" {
			*dst = append(*dst, fmt.Sprintf(`%s = %s`, f.key, strconv.Quote(v)))
		}
	}
	for _, f := range hyprIntMatches {
		if v := *f.field(&mc); v != nil {
			*dst = append(*dst, fmt.Sprintf(`%s = %d`, f.key, *v))
		}
	}
}

func luaAppendActions(a windowrules.Actions, dst *[]string) {
	if a.OpenFloating != nil && *a.OpenFloating {
		*dst = append(*dst, `float = true`)
	}
	if a.Tile != nil && *a.Tile {
		*dst = append(*dst, `tile = true`)
	}
	if a.OpenFullscreen != nil && *a.OpenFullscreen {
		*dst = append(*dst, `fullscreen = true`)
	}
	if a.OpenMaximized != nil && *a.OpenMaximized {
		*dst = append(*dst, `maximize = true`)
	}
	if a.NoFocus != nil && *a.NoFocus {
		*dst = append(*dst, `no_focus = true`)
	}
	if a.NoBorder != nil && *a.NoBorder {
		*dst = append(*dst, `border_size = 0`)
	}
	if a.NoShadow != nil && *a.NoShadow {
		*dst = append(*dst, `no_shadow = true`)
	}
	if a.NoDim != nil && *a.NoDim {
		*dst = append(*dst, `no_dim = true`)
	}
	if a.NoBlur != nil && *a.NoBlur {
		*dst = append(*dst, `no_blur = true`)
	}
	if a.NoAnim != nil && *a.NoAnim {
		*dst = append(*dst, `no_anim = true`)
	}
	if a.NoRounding != nil && *a.NoRounding {
		*dst = append(*dst, `rounding = 0`)
	}
	if a.Pin != nil && *a.Pin {
		*dst = append(*dst, `pin = true`)
	}
	if a.Opaque != nil && *a.Opaque {
		*dst = append(*dst, `opaque = true`)
	}
	if a.ForcergbX != nil && *a.ForcergbX {
		*dst = append(*dst, `force_rgbx = true`)
	}
	if a.Opacity != nil {
		*dst = append(*dst, fmt.Sprintf(`opacity = %s`, strconv.FormatFloat(*a.Opacity, 'g', -1, 64)))
	}
	if a.SizeWidth != "" && a.SizeHeight != "" {
		*dst = append(*dst, fmt.Sprintf(`size = { %s, %s }`, hyprLuaExprWrap(a.SizeWidth), hyprLuaExprWrap(a.SizeHeight)))
	}
	if a.MoveX != "" && a.MoveY != "" {
		*dst = append(*dst, fmt.Sprintf(`move = { %s, %s }`, hyprLuaExprWrap(a.MoveX), hyprLuaExprWrap(a.MoveY)))
	}
	if a.Monitor != "" {
		*dst = append(*dst, fmt.Sprintf(`monitor = %s`, strconv.Quote(a.Monitor)))
	}
	if a.Workspace != "" {
		*dst = append(*dst, fmt.Sprintf(`workspace = %s`, strconv.Quote(a.Workspace)))
	}
	if a.CornerRadius != nil && (a.NoRounding == nil || !*a.NoRounding) {
		*dst = append(*dst, fmt.Sprintf(`rounding = %d`, min(*a.CornerRadius, hyprlandMaxRounding)))
	}
	if a.Idleinhibit != "" {
		*dst = append(*dst, fmt.Sprintf(`idle_inhibit = %s`, strconv.Quote(a.Idleinhibit)))
	}
	for _, f := range hyprBoolEffects {
		if v := *f.field(&a); v != nil {
			*dst = append(*dst, fmt.Sprintf(`%s = %s`, f.key, hyprLuaBoolStr(*v)))
		}
	}
	if a.ScrollingWidth != nil {
		*dst = append(*dst, fmt.Sprintf(`scrolling_width = %s`, strconv.FormatFloat(*a.ScrollingWidth, 'g', -1, 64)))
	}
	for _, f := range hyprStringEffects {
		if v := *f.field(&a); v != "" {
			*dst = append(*dst, fmt.Sprintf(`%s = %s`, f.key, strconv.Quote(v)))
		}
	}
}

func formatLuaManagedHyprRule(rule windowrules.WindowRule) []string {
	var matchParts []string
	luaAppendMatch(rule.MatchCriteria, &matchParts)
	var body []string
	if len(matchParts) > 0 {
		body = append(body, fmt.Sprintf(`match = { %s }`, strings.Join(matchParts, ", ")))
	}
	luaAppendActions(rule.Actions, &body)

	out := []string{fmt.Sprintf("-- DMS-RULE: id=%s, name=%s", rule.ID, rule.Name)}
	if len(body) == 0 {
		out = append(out, fmt.Sprintf("-- (no matchers/actions for rule %s)", rule.ID))
	} else {
		out = append(out, fmt.Sprintf("hl.window_rule({ %s })", strings.Join(body, ", ")))
	}
	out = append(out, "")
	return out
}

func (p *HyprlandWritableProvider) LoadDMSRules() ([]windowrules.WindowRule, error) {
	luaPath := p.GetOverridePath()
	data, err := os.ReadFile(luaPath)
	if err == nil {
		return p.loadDMSRulesFromLua(data, luaPath)
	}
	if !os.IsNotExist(err) {
		return nil, err
	}

	confPath := filepath.Join(filepath.Dir(luaPath), "windowrules.conf")
	data, err = os.ReadFile(confPath)
	if os.IsNotExist(err) {
		return []windowrules.WindowRule{}, nil
	}
	if err != nil {
		return nil, err
	}
	return p.loadDMSRulesFromConf(data, confPath)
}

func (p *HyprlandWritableProvider) loadDMSRulesFromConf(data []byte, rulesPath string) ([]windowrules.WindowRule, error) {
	var rules []windowrules.WindowRule
	var currentID, currentName string
	parser := NewHyprlandRulesParser(p.configDir)

	for line := range strings.SplitSeq(string(data), "\n") {
		trimmed := strings.TrimSpace(line)

		if matches := dmsRuleCommentRegex.FindStringSubmatch(trimmed); matches != nil {
			currentID = matches[1]
			currentName = matches[2]
			continue
		}

		if !strings.HasPrefix(trimmed, "windowrule") {
			continue
		}
		hrule := parser.parseWindowRuleLine(trimmed)
		if hrule == nil {
			continue
		}

		wr := windowrules.WindowRule{
			ID:            currentID,
			Name:          currentName,
			Enabled:       true,
			Source:        rulesPath,
			MatchCriteria: hrule.Match,
			Actions:       hrule.Actions,
		}
		if wr.ID == "" {
			wr.ID = hrule.Match.AppID
			if wr.ID == "" {
				wr.ID = hrule.Match.Title
			}
		}

		rules = append(rules, wr)
		currentID = ""
		currentName = ""
	}

	return rules, nil
}

func (p *HyprlandWritableProvider) loadDMSRulesFromLua(data []byte, rulesPath string) ([]windowrules.WindowRule, error) {
	var rules []windowrules.WindowRule
	lines := strings.Split(string(data), "\n")

	var curID, curName string

	for li := 0; li < len(lines); {
		trimmed := strings.TrimSpace(lines[li])
		if strings.HasPrefix(trimmed, "--") {
			if m := dmsRuleLuaHDRRegex.FindStringSubmatch(trimmed); m != nil {
				curID, curName = m[1], m[2]
				li++
				continue
			}
		}

		if strings.Contains(strings.ToLower(trimmed), hlWinRuleLower) {
			tail := strings.Join(lines[li:], "\n")
			idx := strings.Index(strings.ToLower(tail), hlWinRuleLower)
			if idx < 0 {
				li++
				continue
			}
			frag := tail[idx:]
			tableArg, consumedFrag, ok := extractHlWindowRuleTableArg(frag)
			if !ok {
				li++
				continue
			}

			idSnap := curID
			nameSnap := curName

			if acts, mf, ok2 := parseHlWindowRuleLuaTable(tableArg); ok2 && acts != nil {
				wr := windowrules.WindowRule{
					ID:            idSnap,
					Name:          nameSnap,
					Enabled:       true,
					Source:        rulesPath,
					MatchCriteria: mf,
					Actions:       *acts,
				}
				if wr.ID == "" {
					wr.ID = fmt.Sprintf("dms_rule_%d", len(rules))
				}
				rules = append(rules, wr)
			}
			curID = ""
			curName = ""

			advance := strings.Count(tail[:idx+consumedFrag], "\n")
			if advance == 0 {
				li++
			} else {
				li += advance
			}
			continue
		}
		if trimmed != "" && !strings.HasPrefix(trimmed, "--") {
			curID = ""
			curName = ""
		}
		li++
	}

	return rules, nil
}

func (p *HyprlandWritableProvider) WriteDMSRules(rules []windowrules.WindowRule) error {
	rulesPath := p.GetOverridePath()

	if err := os.MkdirAll(filepath.Dir(rulesPath), 0755); err != nil {
		return err
	}

	var lines []string
	lines = append(lines, "-- DMS Window Rules — managed by DankMaterialShell")
	lines = append(lines, "-- Do not edit manually; changes may be overwritten")
	lines = append(lines, "")

	for _, rule := range rules {
		lines = append(lines, formatLuaManagedHyprRule(rule)...)
	}

	return os.WriteFile(rulesPath, []byte(strings.Join(lines, "\n")), 0644)
}

const hlWinRuleLower = "hl.window_rule"

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

func isDMSWindowRulesSourcePath(sourcePath string) bool {
	p := filepath.ToSlash(strings.TrimSpace(sourcePath))
	return p == "dms/windowrules.lua" || strings.HasSuffix(p, "/dms/windowrules.lua") ||
		p == "dms/windowrules.conf" || strings.HasSuffix(p, "/dms/windowrules.conf") ||
		p == "./dms/windowrules.lua" || p == "./dms/windowrules.conf"
}

func isDMSWindowRulesRequireModule(mod string) bool {
	return isDMSWindowRulesSourcePath(luaconfig.ModuleToRelPath(mod))
}

func (p *HyprlandRulesParser) probeRequireWindowrulesLine(mainLua string) {
	data, err := os.ReadFile(mainLua)
	if err != nil {
		return
	}
	lines := strings.Split(string(data), "\n")
	for i, line := range lines {
		if mod, ok := luaconfig.Require(line); ok && isDMSWindowRulesRequireModule(mod) {
			p.requireLineInMain = i + 1
			return
		}
	}
}

func (p *HyprlandRulesParser) parseLuaWindowRules(content, baseDir, absPath string, allowRequires bool) {
	prev := p.currentSource
	p.currentSource = absPath
	defer func() { p.currentSource = prev }()

	lines := strings.Split(content, "\n")
	rootDir := baseDir
	if expanded, err := utils.ExpandPath(p.configDir); err == nil && expanded != "" {
		rootDir = expanded
	}
	curAbs := absPath
	if a, err := filepath.Abs(absPath); err == nil {
		curAbs = a
	}
	mainAbs := ""
	if p.primaryHyprLua != "" {
		if a, err := filepath.Abs(p.primaryHyprLua); err == nil {
			mainAbs = a
		}
	}

	for i := 0; i < len(lines); {
		trimmed := strings.TrimSpace(lines[i])
		if trimmed == "" || strings.HasPrefix(trimmed, "--") {
			i++
			continue
		}

		if modules := luaconfig.Requires(trimmed); len(modules) > 0 && allowRequires {
			for _, mod := range modules {
				rel := luaconfig.ModuleToRelPath(mod)
				if rel == "" {
					continue
				}
				fullPath := luaconfig.ModuleToPath(rootDir, mod)
				expanded, err := utils.ExpandPath(fullPath)
				if err != nil {
					continue
				}
				if p.walker.RecordMatch(isDMSWindowRulesRequireModule(mod)) {
					p.dmsProcessed = true
				}
				_ = p.parseFile(expanded)
			}
			i++
			continue
		}

		lowTrim := strings.ToLower(trimmed)
		if strings.Contains(lowTrim, hlWinRuleLower) {
			tail := strings.Join(lines[i:], "\n")
			idx := strings.Index(strings.ToLower(tail), hlWinRuleLower)
			if idx < 0 {
				i++
				continue
			}
			frag := tail[idx:]
			tableArg, consumedFrag, ok := extractHlWindowRuleTableArg(frag)
			if !ok {
				i++
				continue
			}

			startLine := i + strings.Count(tail[:idx], "\n") + 1
			if acts, mf, ok2 := parseHlWindowRuleLuaTable(tableArg); ok2 && acts != nil {
				raw := strings.Join(strings.Fields(strings.ReplaceAll(strings.TrimSpace(frag[:consumedFrag]), "\n", " ")), " ")
				if len(raw) > 240 {
					raw = raw[:240] + "…"
				}
				p.rules = append(p.rules, HyprlandWindowRule{
					Match:   mf,
					Actions: *acts,
					Source:  curAbs,
					RawLine: raw,
				})

				if p.requireLineInMain > 0 && mainAbs != "" && curAbs == mainAbs && startLine > p.requireLineInMain {
					p.rulesAfterDMS++
				}
			}
			advance := strings.Count(tail[:idx+consumedFrag], "\n")
			if advance == 0 {
				i++
			} else {
				i += advance
			}
			continue
		}

		i++
	}
}

// extractHlWindowRuleTableArg parses a fragment beginning with (optional prefix then) hl.window_rule( ... ).
// consumed is counted from frag[0] (caller adds idx offset when iterating).
func extractHlWindowRuleTableArg(frag string) (inner string, consumed int, ok bool) {
	tagIdx := strings.Index(strings.ToLower(frag), hlWinRuleLower)
	if tagIdx < 0 {
		return "", 0, false
	}
	afterTag := frag[tagIdx+len(hlWinRuleLower):]
	openIdx := strings.IndexByte(afterTag, '(')
	if openIdx < 0 || (openIdx > 0 && strings.TrimSpace(afterTag[:openIdx]) != "") {
		return "", 0, false
	}
	parenTail := afterTag[openIdx:]
	body, endAfter, ok := extractBalancedParensFromOpen(parenTail, 0)
	if !ok {
		return "", 0, false
	}
	consumedFromFrag := tagIdx + openIdx + endAfter
	return strings.TrimSpace(body), consumedFromFrag, true
}

// extractBalancedParensFromOpen extracts inner string between '(' at openIdx and its matching ')'.
func extractBalancedParensFromOpen(s string, openIdx int) (inner string, endExclusive int, ok bool) {
	if openIdx >= len(s) || s[openIdx] != '(' {
		return "", 0, false
	}
	depth := 0
	inStr := byte(0)
	esc := false
	for i := openIdx; i < len(s); i++ {
		c := s[i]
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
		switch c {
		case '"', '\'':
			inStr = c
		case '(':
			depth++
			if depth == 1 {
				continue
			}
		case ')':
			if depth > 0 {
				depth--
				if depth == 0 {
					return strings.TrimSpace(s[openIdx+1 : i]), i + 1, true
				}
			}
		}
	}
	return "", 0, false
}

func trimOuterBraces(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 && s[0] == '{' && s[len(s)-1] == '}' {
		return strings.TrimSpace(s[1 : len(s)-1])
	}
	return s
}

func splitTopLevelCommaLua(s string) []string {
	var out []string
	depth := 0
	inStr := byte(0)
	esc := false
	start := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
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
		switch c {
		case '"', '\'':
			inStr = c
		case '{', '(':
			depth++
		case '}', ')':
			if depth > 0 {
				depth--
			}
		case ',':
			if depth == 0 {
				out = append(out, strings.TrimSpace(s[start:i]))
				start = i + 1
			}
		}
	}
	out = append(out, strings.TrimSpace(s[start:]))
	return out
}

func splitLuaKeyVal(seg string) (key, val string, ok bool) {
	seg = strings.TrimSpace(seg)
	if seg == "" {
		return "", "", false
	}
	depth := 0
	inStr := byte(0)
	esc := false
	for i := 0; i < len(seg); i++ {
		c := seg[i]
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
		switch c {
		case '"', '\'':
			inStr = c
		case '{', '(':
			depth++
		case '}', ')':
			if depth > 0 {
				depth--
			}
		case '=':
			if depth == 0 {
				return strings.TrimSpace(seg[:i]), strings.TrimSpace(seg[i+1:]), true
			}
		}
	}
	return "", "", false
}

func luaStringValue(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 {
		q0 := s[0]
		q1 := s[len(s)-1]
		if q0 == q1 && (q0 == '"' || q0 == '\'') {
			if q0 == '"' {
				if u, err := strconv.Unquote(s); err == nil {
					return u
				}
			} else if len(s) >= 2 && q0 == '\'' {
				v := strings.TrimSuffix(strings.TrimPrefix(s, "'"), "'")
				v = strings.ReplaceAll(v, `\'`, `'`)
				return v
			}
		}
	}
	v := strings.Trim(strings.TrimSpace(s), `"'`)
	if len(v) >= 2 && v[0] == '(' && v[len(v)-1] == ')' {
		v = strings.TrimSpace(v[1 : len(v)-1])
	}
	return v
}

func luaBoolLike(s string) (val bool, ok bool) {
	s = strings.TrimSpace(strings.ToLower(s))
	switch s {
	case "true", "yes", "1":
		return true, true
	case "false", "no", "0":
		return false, true
	default:
		return false, false
	}
}

func parseMatchLua(val string, m *windowrules.MatchCriteria) {
	body := trimOuterBraces(val)
	for _, seg := range splitTopLevelCommaLua(body) {
		if k, v, ok := splitLuaKeyVal(seg); ok {
			applyLuaMatchKey(m, strings.TrimSpace(strings.ToLower(k)), v)
		}
	}
}

func applyLuaMatchKey(m *windowrules.MatchCriteria, key, v string) {
	if applyLuaMatchTableKey(m, key, v) {
		return
	}
	switch key {
	case "class":
		m.AppID = luaStringValue(v)
	case "title":
		m.Title = luaStringValue(v)
	case "xwayland":
		if b, okb := luaBoolLike(v); okb {
			m.XWayland = new(b)
		}
	case "float", "floating":
		if b, okb := luaBoolLike(v); okb {
			m.IsFloating = new(b)
		}
	case "fullscreen":
		if b, okb := luaBoolLike(v); okb {
			m.Fullscreen = new(b)
		}
	case "pin", "pinned":
		if b, okb := luaBoolLike(v); okb {
			m.Pinned = new(b)
		}
	case "initialised", "initialized":
		if b, okb := luaBoolLike(v); okb {
			m.Initialised = new(b)
		}
	}
}

func applyLuaMatchTableKey(m *windowrules.MatchCriteria, key, raw string) bool {
	for _, f := range hyprBoolMatches {
		if f.key != key {
			continue
		}
		if b, ok := luaBoolLike(raw); ok {
			*f.field(m) = new(b)
		}
		return true
	}
	for _, f := range hyprStringMatches {
		if f.key == key {
			*f.field(m) = luaStringValue(raw)
			return true
		}
	}
	for _, f := range hyprIntMatches {
		if f.key != key {
			continue
		}
		if n, err := strconv.Atoi(luaStringValue(raw)); err == nil {
			*f.field(m) = new(n)
		}
		return true
	}
	return false
}

func applyLuaActionTableKey(a *windowrules.Actions, key, raw string) (handled bool, known bool) {
	for _, f := range hyprBoolEffects {
		if f.key != key {
			continue
		}
		b, ok := luaBoolLike(raw)
		if ok {
			*f.field(a) = new(b)
		}
		return ok, true
	}
	for _, f := range hyprStringEffects {
		if f.key != key {
			continue
		}
		v := strings.TrimSpace(raw)
		if !strings.HasPrefix(v, `"`) && !strings.HasPrefix(v, `'`) {
			return false, true
		}
		*f.field(a) = luaStringValue(v)
		return true, true
	}
	return false, false
}

func applyLuaActionKey(a *windowrules.Actions, key, raw string) bool {
	k := strings.TrimSpace(strings.ToLower(key))
	raw = strings.TrimSpace(raw)
	if handled, known := applyLuaActionTableKey(a, k, raw); known {
		return handled
	}
	switch k {
	case "float":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.OpenFloating = &t
			return true
		}
	case "tile":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.Tile = &t
			return true
		}
	case "fullscreen":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.OpenFullscreen = &t
			return true
		}
	case "maximize":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.OpenMaximized = &t
			return true
		}
	case "nofocus", "no_focus":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoFocus = &t
			return true
		}
	case "noborder":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoBorder = &t
			return true
		}
	case "noshadow", "no_shadow":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoShadow = &t
			return true
		}
	case "nodim", "no_dim":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoDim = &t
			return true
		}
	case "noblur", "no_blur":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoBlur = &t
			return true
		}
	case "noanim", "no_anim":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoAnim = &t
			return true
		}
	case "norounding":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoRounding = &t
			return true
		}
	case "border_size":
		if n, err := strconv.Atoi(luaStringValue(raw)); err == nil && n == 0 {
			t := true
			a.NoBorder = &t
			return true
		}
	case "pin":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.Pin = &t
			return true
		}
	case "opaque":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.Opaque = &t
			return true
		}
	case "forcergbx", "force_rgbx":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.ForcergbX = &t
			return true
		}
	case "opacity":
		if f, err := strconv.ParseFloat(luaStringValue(raw), 64); err == nil {
			a.Opacity = &f
			return true
		}
	case "rounding":
		if v := luaStringValue(raw); v != "" {
			if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
				if n == 0 {
					t := true
					a.NoRounding = &t
					return true
				}
				a.CornerRadius = &n
				return true
			}
		}
	case "size":
		v := strings.TrimSpace(luaStringValue(raw))
		if strings.HasPrefix(v, "{") && strings.HasSuffix(v, "}") {
			inner := trimOuterBraces(v)
			parts := splitTopLevelCommaLua(inner)
			if len(parts) == 2 {
				a.SizeWidth = strings.TrimSpace(luaStringValue(parts[0]))
				a.SizeHeight = strings.TrimSpace(luaStringValue(parts[1]))
				return true
			}
		}
		return false
	case "move":
		v := strings.TrimSpace(luaStringValue(raw))
		if strings.HasPrefix(v, "{") && strings.HasSuffix(v, "}") {
			inner := trimOuterBraces(v)
			parts := splitTopLevelCommaLua(inner)
			if len(parts) == 2 {
				a.MoveX = strings.TrimSpace(luaStringValue(parts[0]))
				a.MoveY = strings.TrimSpace(luaStringValue(parts[1]))
				return true
			}
		}
		return false
	case "monitor":
		a.Monitor = strings.TrimSpace(luaStringValue(raw))
		return true
	case "workspace":
		a.Workspace = strings.TrimSpace(luaStringValue(raw))
		return true
	case "scrolling_width":
		if f, err := strconv.ParseFloat(luaStringValue(raw), 64); err == nil {
			a.ScrollingWidth = &f
			return true
		}
	case "idleinhibit", "idle_inhibit":
		a.Idleinhibit = strings.TrimSpace(luaStringValue(raw))
		return true
	default:
		// Unsupported keys are left to Hyprland; DMS only round-trips managed fields.
	}
	return false
}

func parseHlWindowRuleLuaTable(inner string) (*windowrules.Actions, windowrules.MatchCriteria, bool) {
	body := trimOuterBraces(strings.TrimSpace(inner))
	if body == "" {
		return nil, windowrules.MatchCriteria{}, false
	}
	var match windowrules.MatchCriteria
	var a windowrules.Actions
	haveActions := false

	for _, seg := range splitTopLevelCommaLua(body) {
		k, v, ok := splitLuaKeyVal(seg)
		if !ok {
			continue
		}
		if strings.TrimSpace(strings.ToLower(k)) == "match" {
			parseMatchLua(v, &match)
			continue
		}
		if applyLuaActionKey(&a, k, v) {
			haveActions = true
		}
	}
	if !haveActions {
		return nil, windowrules.MatchCriteria{}, false
	}
	return &a, match, true
}
