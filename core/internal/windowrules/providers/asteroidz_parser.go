package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/windowrules"
)

// Mango window rules are flat `windowrule=key:value,...` lines. DMS-managed rules
// live in dms/windowrules.conf (sourced from config.kdl), each preceded by an
// `# @id=<id> @name=<name>` comment so they round-trip.

type AsteroidzWindowRule struct {
	Source string
	Fields map[string]string
}

// nested KDL: `window-rule { match app-id="..."; tags 4; open-fullscreen }`
// (emitted single-line so the line parser round-trips it). Meta comments use
// `//` (KDL has no #).
var asteroidzWindowRuleRegex = regexp.MustCompile(`^window-rule\s*\{(.*)\}\s*$`)
var asteroidzMetaCommentRegex = regexp.MustCompile(`^//\s*@id=(\S*)\s*@name=(.*)$`)

// tokenizeKDLProps splits a KDL node's argument text into whitespace-separated
// tokens, keeping quoted "..." spans (which may contain spaces) intact.
func tokenizeKDLProps(s string) []string {
	var toks []string
	var b strings.Builder
	inq := false
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case inq && c == '\\' && i+1 < len(s):
			b.WriteByte(c)
			b.WriteByte(s[i+1])
			i++
		case c == '"':
			inq = !inq
			b.WriteByte(c)
		case !inq && (c == ' ' || c == '\t'):
			if b.Len() > 0 {
				toks = append(toks, b.String())
				b.Reset()
			}
		default:
			b.WriteByte(c)
		}
	}
	if b.Len() > 0 {
		toks = append(toks, b.String())
	}
	return toks
}

func kdlUnquote(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		inner := s[1 : len(s)-1]
		inner = strings.ReplaceAll(inner, `\"`, `"`)
		inner = strings.ReplaceAll(inner, `\\`, `\`)
		return inner
	}
	return s
}

// parse the inner of a `window-rule { ... }` block into legacy fields
func parseAsteroidzWindowRuleLine(inner string) map[string]string {
	fields := map[string]string{}
	legacy := func(nice string) string {
		if lk, ok := azNiceToLegacy[nice]; ok {
			return lk
		}
		return nice
	}
	for _, seg := range strings.Split(inner, ";") {
		seg = strings.TrimSpace(seg)
		if seg == "" {
			continue
		}
		if seg == "match" || strings.HasPrefix(seg, "match ") {
			rest := strings.TrimSpace(strings.TrimPrefix(seg, "match"))
			for _, tok := range tokenizeKDLProps(rest) {
				eq := strings.Index(tok, "=")
				if eq < 0 {
					continue
				}
				fields[legacy(strings.TrimSpace(tok[:eq]))] =
					kdlUnquote(strings.TrimSpace(tok[eq+1:]))
			}
			continue
		}
		toks := tokenizeKDLProps(seg)
		if len(toks) == 0 {
			continue
		}
		key := legacy(toks[0])
		if len(toks) >= 2 {
			v := kdlUnquote(toks[1])
			if v == "false" {
				v = "0"
			} else if v == "true" {
				v = "1"
			}
			fields[key] = v
		} else {
			fields[key] = "1" // bare flag
		}
	}
	return fields
}

// asteroidzConfigPath returns the main mango config (config.conf or mango.conf).
func asteroidzConfigPath(configDir string) string {
	candidates := []string{
		filepath.Join(configDir, "config.kdl"),
		filepath.Join(configDir, "config.conf"),
		filepath.Join(configDir, "mango.conf"),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return candidates[0]
}

func asteroidzOverridePath(configDir string) string {
	return filepath.Join(configDir, "dms", "windowrules.kdl")
}

// parseAsteroidzRulesFile reads a config file and returns its windowrule= lines.
func parseAsteroidzRulesFile(path, source string) []AsteroidzWindowRule {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var rules []AsteroidzWindowRule
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if m := asteroidzWindowRuleRegex.FindStringSubmatch(trimmed); m != nil {
			rules = append(rules, AsteroidzWindowRule{Source: source, Fields: parseAsteroidzWindowRuleLine(m[1])})
		}
	}
	return rules
}

type AsteroidzRulesParseResult struct {
	Rules            []AsteroidzWindowRule
	DMSRulesIncluded bool
	DMSStatus        *windowrules.DMSRulesStatus
}

func ParseAsteroidzWindowRules(configDir string) (*AsteroidzRulesParseResult, error) {
	mainPath := asteroidzConfigPath(configDir)
	overridePath := asteroidzOverridePath(configDir)

	var rules []AsteroidzWindowRule
	rules = append(rules, parseAsteroidzRulesFile(mainPath, "config.kdl")...)
	rules = append(rules, parseAsteroidzRulesFile(overridePath, "dms/windowrules.kdl")...)

	included := asteroidzDMSRulesIncluded(mainPath)
	return &AsteroidzRulesParseResult{
		Rules:            rules,
		DMSRulesIncluded: included,
		DMSStatus: &windowrules.DMSRulesStatus{
			Exists:        fileExists(overridePath),
			Included:      included,
			Effective:     included,
			ConfigFormat:  "kdl",
			StatusMessage: asteroidzIncludeMessage(included),
		},
	}, nil
}

func asteroidzDMSRulesIncluded(mainPath string) bool {
	data, err := os.ReadFile(mainPath)
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "source") && strings.Contains(trimmed, "dms/windowrules.kdl") {
			return true
		}
	}
	return false
}

func asteroidzIncludeMessage(included bool) string {
	if included {
		return "DMS window rules are sourced from config.kdl"
	}
	return "Add source ./dms/windowrules.kdl to config.kdl to apply DMS window rules"
}

func asteroidzBoolField(fields map[string]string, key string) *bool {
	v, ok := fields[key]
	if !ok {
		return nil
	}
	b := v == "1" || strings.EqualFold(v, "true")
	return &b
}

func asteroidzBoolStr(b *bool) string {
	if b != nil && *b {
		return "1"
	}
	return "0"
}

func ConvertAsteroidzRulesToWindowRules(mangoRules []AsteroidzWindowRule) []windowrules.WindowRule {
	result := make([]windowrules.WindowRule, 0, len(mangoRules))
	for i, mr := range mangoRules {
		f := mr.Fields
		actions := windowrules.Actions{
			OpenFloating:      asteroidzBoolField(f, "isfloating"),
			OpenFullscreen:    asteroidzBoolField(f, "isfullscreen"),
			NoBlur:            asteroidzBoolField(f, "noblur"),
			NoBorder:          asteroidzBoolField(f, "isnoborder"),
			NoShadow:          asteroidzBoolField(f, "isnoshadow"),
			NoRounding:        asteroidzBoolField(f, "isnoradius"),
			NoAnim:            asteroidzBoolField(f, "isnoanimation"),
			ForceTearing:      asteroidzBoolField(f, "force_tearing"),
			VrrOnlyFullscreen: asteroidzBoolField(f, "vrr_only_fullscreen"),
			ShieldWhenCapture: asteroidzBoolField(f, "shield_when_capture"),
			DenyGroup:         asteroidzBoolField(f, "deny_group"),
			Pinned:            asteroidzBoolField(f, "ispinned"),
		}
		// Preserve every option this DMS build doesn't model (fork
		// extensions and future keys) so edits never strip them.
		for k, v := range f {
			switch k {
			case "appid", "title", "toplevel_tag", "tags", "monitor",
				"width", "height", "isfloating", "isfullscreen", "noblur",
				"isnoborder", "isnoshadow", "isnoradius", "isnoanimation",
				"force_tearing", "vrr_only_fullscreen", "shield_when_capture",
				"deny_group", "ispinned", "special_workspace":
			default:
				if actions.AsteroidzExtra == nil {
					actions.AsteroidzExtra = map[string]string{}
				}
				actions.AsteroidzExtra[k] = v
			}
		}
		if tags, ok := f["tags"]; ok {
			actions.Workspace = tags
		}
		if sw, ok := f["special_workspace"]; ok {
			actions.SpecialWorkspace = sw
		}
		if mon, ok := f["monitor"]; ok {
			actions.Monitor = mon
		}
		if w, ok := f["width"]; ok {
			if h, ok2 := f["height"]; ok2 {
				actions.Size = w + "x" + h
			}
		}

		result = append(result, windowrules.WindowRule{
			ID:      fmt.Sprintf("rule_%d", i),
			Enabled: true,
			Source:  mr.Source,
			MatchCriteria: windowrules.MatchCriteria{
				AppID: f["appid"],
				Title: f["title"],
			},
			Actions: actions,
		})
	}
	return result
}

// azKdlQuote quotes a KDL property value unless it's a clean number or a
// bare-safe token (matches the compositor's kdl_is_bare set).
var azKdlNumRe = regexp.MustCompile(`^-?\d+(\.\d+)?$`)
var azKdlBareRe = regexp.MustCompile(`^[^\s{}()="\\;/]+$`)

func azKdlQuote(s string) string {
	if s == "" {
		return `""`
	}
	if azKdlNumRe.MatchString(s) {
		return s
	}
	if s == "true" || s == "false" || s == "null" {
		return `"` + s + `"`
	}
	if azKdlBareRe.MatchString(s) {
		return s
	}
	e := strings.ReplaceAll(s, `\`, `\\`)
	e = strings.ReplaceAll(e, `"`, `\"`)
	return `"` + e + `"`
}

var azNiceToLegacy = map[string]string{
	"app-id": "appid", "title": "title", "open-floating": "isfloating",
	"open-fullscreen": "isfullscreen", "no-blur": "noblur", "no-border": "isnoborder",
	"no-shadow": "isnoshadow", "no-rounding": "isnoradius", "no-animation": "isnoanimation",
}

// formatAsteroidzRule serializes a shared WindowRule into a nested KDL
// window-rule node (single line so it round-trips through the line parser):
//   window-rule { match app-id="mpv"; tags 4; open-fullscreen; no-blur }
func formatAsteroidzRule(rule windowrules.WindowRule) string {
	var match, act []string
	if v := rule.MatchCriteria.AppID; v != "" {
		match = append(match, "app-id="+azKdlQuote(v))
	}
	if v := rule.MatchCriteria.Title; v != "" {
		match = append(match, "title="+azKdlQuote(v))
	}
	addAct := func(nice, v string) {
		if v != "" {
			act = append(act, nice+" "+azKdlQuote(v))
		}
	}
	addAct("tags", rule.Actions.Workspace)
	addAct("special_workspace", rule.Actions.SpecialWorkspace)
	addAct("monitor", rule.Actions.Monitor)
	if rule.Actions.Size != "" {
		if w, h, ok := splitSize(rule.Actions.Size); ok {
			addAct("width", w)
			addAct("height", h)
		}
	}
	flag := func(nice string, b *bool) {
		if b == nil {
			return
		}
		if *b {
			act = append(act, nice)
		} else {
			act = append(act, nice+" false")
		}
	}
	flag("force_tearing", rule.Actions.ForceTearing)
	flag("vrr_only_fullscreen", rule.Actions.VrrOnlyFullscreen)
	flag("shield_when_capture", rule.Actions.ShieldWhenCapture)
	flag("deny_group", rule.Actions.DenyGroup)
	flag("ispinned", rule.Actions.Pinned)
	flag("open-floating", rule.Actions.OpenFloating)
	flag("open-fullscreen", rule.Actions.OpenFullscreen)
	flag("no-blur", rule.Actions.NoBlur)
	flag("no-border", rule.Actions.NoBorder)
	flag("no-shadow", rule.Actions.NoShadow)
	flag("no-rounding", rule.Actions.NoRounding)
	flag("no-animation", rule.Actions.NoAnim)

	if len(rule.Actions.AsteroidzExtra) > 0 {
		keys := make([]string, 0, len(rule.Actions.AsteroidzExtra))
		for k := range rule.Actions.AsteroidzExtra {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			addAct(k, rule.Actions.AsteroidzExtra[k])
		}
	}

	parts := []string{}
	if len(match) > 0 {
		parts = append(parts, "match "+strings.Join(match, " "))
	}
	parts = append(parts, act...)
	return "window-rule { " + strings.Join(parts, "; ") + " }"
}

type AsteroidzWritableProvider struct {
	configDir string
}

func NewAsteroidzWritableProvider(configDir string) *AsteroidzWritableProvider {
	return &AsteroidzWritableProvider{configDir: configDir}
}

func (p *AsteroidzWritableProvider) Name() string { return "asteroidz" }

func (p *AsteroidzWritableProvider) GetOverridePath() string {
	return asteroidzOverridePath(p.configDir)
}

func (p *AsteroidzWritableProvider) GetRuleSet() (*windowrules.RuleSet, error) {
	result, err := ParseAsteroidzWindowRules(p.configDir)
	if err != nil {
		return nil, err
	}
	return &windowrules.RuleSet{
		Title:            "Asteroidz Window Rules",
		Provider:         "asteroidz",
		Rules:            ConvertAsteroidzRulesToWindowRules(result.Rules),
		DMSRulesIncluded: result.DMSRulesIncluded,
		DMSStatus:        result.DMSStatus,
	}, nil
}

func (p *AsteroidzWritableProvider) SetRule(rule windowrules.WindowRule) error {
	rules, err := p.LoadDMSRules()
	if err != nil {
		rules = []windowrules.WindowRule{}
	}
	found := false
	for i, r := range rules {
		if r.ID == rule.ID {
			rules[i] = rule
			found = true
			break
		}
	}
	if !found {
		rules = append(rules, rule)
	}
	return p.writeDMSRules(rules)
}

func (p *AsteroidzWritableProvider) RemoveRule(id string) error {
	rules, err := p.LoadDMSRules()
	if err != nil {
		return err
	}
	newRules := make([]windowrules.WindowRule, 0, len(rules))
	for _, r := range rules {
		if r.ID != id {
			newRules = append(newRules, r)
		}
	}
	return p.writeDMSRules(newRules)
}

func (p *AsteroidzWritableProvider) ReorderRules(ids []string) error {
	rules, err := p.LoadDMSRules()
	if err != nil {
		return err
	}
	ruleMap := make(map[string]windowrules.WindowRule, len(rules))
	for _, r := range rules {
		ruleMap[r.ID] = r
	}
	newRules := make([]windowrules.WindowRule, 0, len(ids))
	for _, id := range ids {
		if r, ok := ruleMap[id]; ok {
			newRules = append(newRules, r)
			delete(ruleMap, id)
		}
	}
	for _, r := range ruleMap {
		newRules = append(newRules, r)
	}
	return p.writeDMSRules(newRules)
}

// LoadDMSRules parses only the DMS override file, preserving @id/@name metadata.
func (p *AsteroidzWritableProvider) LoadDMSRules() ([]windowrules.WindowRule, error) {
	data, err := os.ReadFile(p.GetOverridePath())
	if err != nil {
		if os.IsNotExist(err) {
			return []windowrules.WindowRule{}, nil
		}
		return nil, err
	}

	var rules []windowrules.WindowRule
	var curID, curName string
	idx := 0
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if m := asteroidzMetaCommentRegex.FindStringSubmatch(trimmed); m != nil {
			curID = m[1]
			curName = strings.TrimSpace(m[2])
			continue
		}
		if m := asteroidzWindowRuleRegex.FindStringSubmatch(trimmed); m != nil {
			converted := ConvertAsteroidzRulesToWindowRules([]AsteroidzWindowRule{{Source: "dms/windowrules.kdl", Fields: parseAsteroidzWindowRuleLine(m[1])}})
			wr := converted[0]
			if curID != "" {
				wr.ID = curID
			} else {
				wr.ID = fmt.Sprintf("rule_%d", idx)
			}
			wr.Name = curName
			rules = append(rules, wr)
			curID, curName = "", ""
			idx++
		}
	}
	return rules, nil
}

func (p *AsteroidzWritableProvider) writeDMSRules(rules []windowrules.WindowRule) error {
	overridePath := p.GetOverridePath()
	if err := os.MkdirAll(filepath.Dir(overridePath), 0o755); err != nil {
		return err
	}

	var sb strings.Builder
	sb.WriteString("# Auto-generated by DMS - DMS-managed mango window rules\n\n")
	for i, r := range rules {
		id := r.ID
		if id == "" {
			id = fmt.Sprintf("rule_%d", i)
		}
		fmt.Fprintf(&sb, "// @id=%s @name=%s\n", id, r.Name)
		sb.WriteString(formatAsteroidzRule(r))
		sb.WriteString("\n\n")
	}

	return os.WriteFile(overridePath, []byte(sb.String()), 0o644)
}
