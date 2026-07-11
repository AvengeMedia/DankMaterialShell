package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/windowrules"
)

// Mango window rules are flat `windowrule=key:value,...` lines. DMS-managed rules
// live in dms/windowrules.conf (sourced from config.conf), each preceded by an
// `# @id=<id> @name=<name>` comment so they round-trip.

type MangoWindowRule struct {
	Source string
	Fields map[string]string
}

var mangoWindowRuleRegex = regexp.MustCompile(`^windowrule\s*=\s*(.+)$`)
var mangoMetaCommentRegex = regexp.MustCompile(`^#\s*@id=(\S*)\s*@name=(.*)$`)

func parseMangoWindowRuleLine(value string) map[string]string {
	fields := map[string]string{}
	for _, pair := range strings.Split(value, ",") {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}
		colon := strings.Index(pair, ":")
		if colon < 0 {
			continue
		}
		key := strings.TrimSpace(pair[:colon])
		val := strings.TrimSpace(pair[colon+1:])
		if key != "" {
			fields[key] = val
		}
	}
	return fields
}

// mangoConfigPath returns the main mango config (config.conf or mango.conf).
func mangoConfigPath(configDir string) string {
	candidates := []string{
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

func mangoOverridePath(configDir string) string {
	return filepath.Join(configDir, "dms", "windowrules.conf")
}

// parseMangoRulesFile reads a config file and returns its windowrule= lines.
func parseMangoRulesFile(path, source string) []MangoWindowRule {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var rules []MangoWindowRule
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if m := mangoWindowRuleRegex.FindStringSubmatch(trimmed); m != nil {
			rules = append(rules, MangoWindowRule{Source: source, Fields: parseMangoWindowRuleLine(m[1])})
		}
	}
	return rules
}

type MangoRulesParseResult struct {
	Rules            []MangoWindowRule
	DMSRulesIncluded bool
	DMSStatus        *windowrules.DMSRulesStatus
}

func ParseMangoWindowRules(configDir string) (*MangoRulesParseResult, error) {
	mainPath := mangoConfigPath(configDir)
	overridePath := mangoOverridePath(configDir)

	var rules []MangoWindowRule
	rules = append(rules, parseMangoRulesFile(mainPath, "config.conf")...)
	rules = append(rules, parseMangoRulesFile(overridePath, "dms/windowrules.conf")...)

	included := mangoDMSRulesIncluded(mainPath)
	return &MangoRulesParseResult{
		Rules:            rules,
		DMSRulesIncluded: included,
		DMSStatus: &windowrules.DMSRulesStatus{
			Exists:        fileExists(overridePath),
			Included:      included,
			Effective:     included,
			ConfigFormat:  "conf",
			StatusMessage: mangoIncludeMessage(included),
		},
	}, nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func mangoDMSRulesIncluded(mainPath string) bool {
	data, err := os.ReadFile(mainPath)
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "source") && strings.Contains(trimmed, "dms/windowrules.conf") {
			return true
		}
	}
	return false
}

func mangoIncludeMessage(included bool) string {
	if included {
		return "DMS window rules are sourced from config.conf"
	}
	return "Add `source=./dms/windowrules.conf` to config.conf to apply DMS window rules"
}

func mangoBoolField(fields map[string]string, key string) *bool {
	v, ok := fields[key]
	if !ok {
		return nil
	}
	b := v == "1" || strings.EqualFold(v, "true")
	return &b
}

func mangoBoolStr(b *bool) string {
	if b != nil && *b {
		return "1"
	}
	return "0"
}

func ConvertMangoRulesToWindowRules(mangoRules []MangoWindowRule) []windowrules.WindowRule {
	result := make([]windowrules.WindowRule, 0, len(mangoRules))
	for i, mr := range mangoRules {
		f := mr.Fields
		actions := windowrules.Actions{
			OpenFloating:   mangoBoolField(f, "isfloating"),
			OpenFullscreen: mangoBoolField(f, "isfullscreen"),
			NoBlur:         mangoBoolField(f, "noblur"),
			NoBorder:       mangoBoolField(f, "isnoborder"),
			NoShadow:       mangoBoolField(f, "isnoshadow"),
			NoRounding:     mangoBoolField(f, "isnoradius"),
			NoAnim:         mangoBoolField(f, "isnoanimation"),
		}
		if tags, ok := f["tags"]; ok {
			actions.Workspace = tags
		}
		if mon, ok := f["monitor"]; ok {
			actions.Monitor = mon
		}
		if w, ok := f["width"]; ok {
			if h, ok2 := f["height"]; ok2 {
				actions.SizeWidth = w
				actions.SizeHeight = h
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

// formatMangoRule serializes a shared WindowRule into a mango windowrule= line.
func formatMangoRule(rule windowrules.WindowRule) string {
	var parts []string
	add := func(k, v string) {
		if v != "" {
			parts = append(parts, k+":"+v)
		}
	}

	add("appid", rule.MatchCriteria.AppID)
	add("title", rule.MatchCriteria.Title)
	add("tags", rule.Actions.Workspace)
	add("monitor", rule.Actions.Monitor)

	if rule.Actions.SizeWidth != "" && rule.Actions.SizeHeight != "" {
		add("width", rule.Actions.SizeWidth)
		add("height", rule.Actions.SizeHeight)
	}

	addBool := func(k string, b *bool) {
		if b != nil {
			parts = append(parts, k+":"+mangoBoolStr(b))
		}
	}
	addBool("isfloating", rule.Actions.OpenFloating)
	addBool("isfullscreen", rule.Actions.OpenFullscreen)
	addBool("noblur", rule.Actions.NoBlur)
	addBool("isnoborder", rule.Actions.NoBorder)
	addBool("isnoshadow", rule.Actions.NoShadow)
	addBool("isnoradius", rule.Actions.NoRounding)
	addBool("isnoanimation", rule.Actions.NoAnim)

	return "windowrule=" + strings.Join(parts, ",")
}

type MangoWritableProvider struct {
	configDir string
}

func NewMangoWritableProvider(configDir string) *MangoWritableProvider {
	return &MangoWritableProvider{configDir: configDir}
}

func (p *MangoWritableProvider) Name() string { return "mango" }

func (p *MangoWritableProvider) GetOverridePath() string {
	return mangoOverridePath(p.configDir)
}

func (p *MangoWritableProvider) GetRuleSet() (*windowrules.RuleSet, error) {
	result, err := ParseMangoWindowRules(p.configDir)
	if err != nil {
		return nil, err
	}
	return &windowrules.RuleSet{
		Title:            "Mango Window Rules",
		Provider:         "mango",
		Rules:            ConvertMangoRulesToWindowRules(result.Rules),
		DMSRulesIncluded: result.DMSRulesIncluded,
		DMSStatus:        result.DMSStatus,
	}, nil
}

func (p *MangoWritableProvider) SetRule(rule windowrules.WindowRule) error {
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

func (p *MangoWritableProvider) RemoveRule(id string) error {
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

func (p *MangoWritableProvider) ReorderRules(ids []string) error {
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
func (p *MangoWritableProvider) LoadDMSRules() ([]windowrules.WindowRule, error) {
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
		if m := mangoMetaCommentRegex.FindStringSubmatch(trimmed); m != nil {
			curID = m[1]
			curName = strings.TrimSpace(m[2])
			continue
		}
		if m := mangoWindowRuleRegex.FindStringSubmatch(trimmed); m != nil {
			converted := ConvertMangoRulesToWindowRules([]MangoWindowRule{{Source: "dms/windowrules.conf", Fields: parseMangoWindowRuleLine(m[1])}})
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

func (p *MangoWritableProvider) writeDMSRules(rules []windowrules.WindowRule) error {
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
		fmt.Fprintf(&sb, "# @id=%s @name=%s\n", id, r.Name)
		sb.WriteString(formatMangoRule(r))
		sb.WriteString("\n\n")
	}

	return os.WriteFile(overridePath, []byte(sb.String()), 0o644)
}
