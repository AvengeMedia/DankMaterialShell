package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/sblinch/kdl-go"
	"github.com/sblinch/kdl-go/document"
)

type NiriKeyBinding struct {
	Mods          []string
	Key           string
	Action        string
	Args          []string
	Description   string
	HideOnOverlay bool
	CooldownMs    int
	Source        string
}

type NiriSection struct {
	Name     string
	Keybinds []NiriKeyBinding
	Children []NiriSection
}

type NiriParser struct {
	configDir          string
	processedFiles     map[string]bool
	bindMap            map[string]*NiriKeyBinding
	bindOrder          []string
	currentSource      string
	dmsBindsIncluded   bool
	dmsBindsExists     bool
	includeCount       int
	dmsIncludePos      int
	bindsBeforeDMS     int
	bindsAfterDMS      int
	dmsBindKeys        map[string]bool
	configBindKeys     map[string]bool
	dmsProcessed       bool
	dmsBindMap         map[string]*NiriKeyBinding
	conflictingConfigs map[string]*NiriKeyBinding
}

func NewNiriParser(configDir string) *NiriParser {
	return &NiriParser{
		configDir:          configDir,
		processedFiles:     make(map[string]bool),
		bindMap:            make(map[string]*NiriKeyBinding),
		bindOrder:          []string{},
		currentSource:      "",
		dmsIncludePos:      -1,
		dmsBindKeys:        make(map[string]bool),
		configBindKeys:     make(map[string]bool),
		dmsBindMap:         make(map[string]*NiriKeyBinding),
		conflictingConfigs: make(map[string]*NiriKeyBinding),
	}
}

func (p *NiriParser) Parse() (*NiriSection, error) {
	dmsBindsPath := filepath.Join(p.configDir, "dms", "binds.kdl")
	if _, err := os.Stat(dmsBindsPath); err == nil {
		p.dmsBindsExists = true
	}

	configPath := filepath.Join(p.configDir, "config.kdl")
	section, err := p.parseFile(configPath, "")
	if err != nil {
		return nil, err
	}

	if p.dmsBindsExists && !p.dmsProcessed {
		p.parseDMSBindsDirectly(dmsBindsPath, section)
	}

	section.Keybinds = p.finalizeBinds()
	return section, nil
}

func (p *NiriParser) parseDMSBindsDirectly(dmsBindsPath string, section *NiriSection) {
	data, err := os.ReadFile(dmsBindsPath)
	if err != nil {
		return
	}

	doc, err := kdl.Parse(strings.NewReader(string(data)))
	if err != nil {
		return
	}

	prevSource := p.currentSource
	p.currentSource = dmsBindsPath
	baseDir := filepath.Dir(dmsBindsPath)
	p.processNodes(doc.Nodes, section, baseDir)
	p.currentSource = prevSource
	p.dmsProcessed = true
}

func (p *NiriParser) finalizeBinds() []NiriKeyBinding {
	binds := make([]NiriKeyBinding, 0, len(p.bindOrder))
	for _, key := range p.bindOrder {
		if kb, ok := p.bindMap[key]; ok {
			binds = append(binds, *kb)
		}
	}
	return binds
}

func (p *NiriParser) addBind(kb *NiriKeyBinding) {
	key := p.formatBindKey(kb)
	isDMSBind := strings.Contains(kb.Source, "dms/binds.kdl")

	if isDMSBind {
		p.dmsBindKeys[key] = true
		p.dmsBindMap[key] = kb
	} else if p.dmsBindKeys[key] {
		p.bindsAfterDMS++
		p.conflictingConfigs[key] = kb
		p.configBindKeys[key] = true
		return
	} else {
		p.configBindKeys[key] = true
	}

	if _, exists := p.bindMap[key]; !exists {
		p.bindOrder = append(p.bindOrder, key)
	}
	p.bindMap[key] = kb
}

func (p *NiriParser) formatBindKey(kb *NiriKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (p *NiriParser) parseFile(filePath, sectionName string) (*NiriSection, error) {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve path %s: %w", filePath, err)
	}

	if p.processedFiles[absPath] {
		return &NiriSection{Name: sectionName}, nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", absPath, err)
	}

	doc, err := kdl.Parse(strings.NewReader(string(data)))
	if err != nil {
		return nil, fmt.Errorf("failed to parse KDL in %s: %w", absPath, err)
	}

	section := &NiriSection{
		Name: sectionName,
	}

	prevSource := p.currentSource
	p.currentSource = absPath
	baseDir := filepath.Dir(absPath)
	p.processNodes(doc.Nodes, section, baseDir)
	p.currentSource = prevSource

	return section, nil
}

func (p *NiriParser) processNodes(nodes []*document.Node, section *NiriSection, baseDir string) {
	for _, node := range nodes {
		name := node.Name.String()

		switch name {
		case "include":
			p.handleInclude(node, section, baseDir)
		case "binds":
			p.extractBinds(node, section, "")
		case "recent-windows":
			p.handleRecentWindows(node, section)
		}
	}
}

func (p *NiriParser) handleInclude(node *document.Node, section *NiriSection, baseDir string) {
	if len(node.Arguments) == 0 {
		return
	}

	includePath := strings.Trim(node.Arguments[0].String(), "\"")
	isDMSInclude := includePath == "dms/binds.kdl" || strings.HasSuffix(includePath, "/dms/binds.kdl")

	p.includeCount++
	if isDMSInclude {
		p.dmsBindsIncluded = true
		p.dmsIncludePos = p.includeCount
		p.bindsBeforeDMS = len(p.bindMap)
	}

	fullPath := filepath.Join(baseDir, includePath)
	if filepath.IsAbs(includePath) {
		fullPath = includePath
	}

	if isDMSInclude {
		p.dmsProcessed = true
	}

	includedSection, err := p.parseFile(fullPath, "")
	if err != nil {
		return
	}

	section.Children = append(section.Children, includedSection.Children...)
}

func (p *NiriParser) HasDMSBindsIncluded() bool {
	return p.dmsBindsIncluded
}

func (p *NiriParser) handleRecentWindows(node *document.Node, section *NiriSection) {
	if node.Children == nil {
		return
	}

	for _, child := range node.Children {
		if child.Name.String() != "binds" {
			continue
		}
		p.extractBinds(child, section, "Alt-Tab")
	}
}

func (p *NiriParser) extractBinds(node *document.Node, section *NiriSection, subcategory string) {
	if node.Children == nil {
		return
	}

	for _, child := range node.Children {
		kb := p.parseKeybindNode(child, subcategory)
		if kb == nil {
			continue
		}
		p.addBind(kb)
	}
}

func (p *NiriParser) parseKeybindNode(node *document.Node, _ string) *NiriKeyBinding {
	keyCombo := node.Name.String()
	if keyCombo == "" {
		return nil
	}

	mods, key := p.parseKeyCombo(keyCombo)

	var action string
	var args []string
	if len(node.Children) > 0 {
		actionNode := node.Children[0]
		action = actionNode.Name.String()
		for _, arg := range actionNode.Arguments {
			args = append(args, arg.ValueString())
		}
		if actionNode.Properties != nil {
			if val, ok := actionNode.Properties.Get("focus"); ok {
				args = append(args, "focus="+val.String())
			}
		}
	}

	var description string
	var hideOnOverlay bool
	var cooldownMs int
	if node.Properties != nil {
		if val, ok := node.Properties.Get("hotkey-overlay-title"); ok {
			switch val.ValueString() {
			case "null", "":
				hideOnOverlay = true
			default:
				description = val.ValueString()
			}
		}
		if val, ok := node.Properties.Get("cooldown-ms"); ok {
			cooldownMs, _ = strconv.Atoi(val.String())
		}
	}

	return &NiriKeyBinding{
		Mods:          mods,
		Key:           key,
		Action:        action,
		Args:          args,
		Description:   description,
		HideOnOverlay: hideOnOverlay,
		CooldownMs:    cooldownMs,
		Source:        p.currentSource,
	}
}

func (p *NiriParser) parseKeyCombo(combo string) ([]string, string) {
	parts := strings.Split(combo, "+")

	switch len(parts) {
	case 0:
		return nil, combo
	case 1:
		return nil, parts[0]
	default:
		return parts[:len(parts)-1], parts[len(parts)-1]
	}
}

type NiriParseResult struct {
	Section            *NiriSection
	DMSBindsIncluded   bool
	DMSStatus          *DMSBindsStatusInfo
	ConflictingConfigs map[string]*NiriKeyBinding
}

type DMSBindsStatusInfo struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	BindsAfterDMS   int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
}

func (p *NiriParser) buildDMSStatus() *DMSBindsStatusInfo {
	status := &DMSBindsStatusInfo{
		Exists:          p.dmsBindsExists,
		Included:        p.dmsBindsIncluded,
		IncludePosition: p.dmsIncludePos,
		TotalIncludes:   p.includeCount,
		BindsAfterDMS:   p.bindsAfterDMS,
	}

	switch {
	case !p.dmsBindsExists:
		status.Effective = false
		status.StatusMessage = "dms/binds.kdl does not exist"
	case !p.dmsBindsIncluded:
		status.Effective = false
		status.StatusMessage = "dms/binds.kdl is not included in config.kdl"
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

func ParseNiriKeys(configDir string) (*NiriParseResult, error) {
	parser := NewNiriParser(configDir)
	section, err := parser.Parse()
	if err != nil {
		return nil, err
	}
	return &NiriParseResult{
		Section:            section,
		DMSBindsIncluded:   parser.HasDMSBindsIncluded(),
		DMSStatus:          parser.buildDMSStatus(),
		ConflictingConfigs: parser.conflictingConfigs,
	}, nil
}
