package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/AvengeMedia/DankMaterialShell/core/internal/log"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/luaconfig"
	"github.com/AvengeMedia/DankMaterialShell/core/internal/utils"
	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Configuration utilities",
}

var resolveIncludeCmd = &cobra.Command{
	Use:   "resolve-include <compositor> <filename>",
	Short: "Check if a file is included in compositor config",
	Long:  "Recursively check if a file is included/sourced in compositor configuration. Returns JSON with exists and included status.",
	Args:  cobra.ExactArgs(2),
	ValidArgsFunction: func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
		switch len(args) {
		case 0:
			return []string{"hyprland", "niri", "mangowc"}, cobra.ShellCompDirectiveNoFileComp
		case 1:
			return []string{
				"binds.lua",
				"binds-user.lua",
				"colors.lua",
				"layout.lua",
				"outputs.lua",
				"cursor.lua",
				"windowrules.lua",
				"cursor.kdl",
				"layout.kdl",
				"outputs.kdl",
				"binds.kdl",
				"input.kdl",
				"cursor.conf",
				"layout.conf",
				"outputs.conf",
				"binds.conf",
			}, cobra.ShellCompDirectiveNoFileComp
		}
		return nil, cobra.ShellCompDirectiveNoFileComp
	},
	Run: runResolveInclude,
}

func init() {
	configCmd.AddCommand(resolveIncludeCmd)
}

type IncludeResult struct {
	Exists       bool   `json:"exists"`
	Included     bool   `json:"included"`
	ConfigFormat string `json:"configFormat,omitempty"`
	ReadOnly     bool   `json:"readOnly,omitempty"`
}

func runResolveInclude(cmd *cobra.Command, args []string) {
	compositor := strings.ToLower(args[0])
	filename := args[1]

	var result IncludeResult
	var err error

	switch compositor {
	case "hyprland":
		result, err = checkHyprlandInclude(filename)
	case "niri":
		result, err = checkNiriInclude(filename)
	case "mangowc", "mango":
		result, err = checkMangoWCInclude(filename)
	default:
		log.Fatalf("Unknown compositor: %s", compositor)
	}

	if err != nil {
		log.Fatalf("Error checking include: %v", err)
	}

	output, _ := json.Marshal(result)
	fmt.Fprintln(os.Stdout, string(output))
}

func checkHyprlandInclude(filename string) (IncludeResult, error) {
	configDir := filepath.Join(utils.XDGConfigHome(), "hypr")

	targetPath := filepath.Join(configDir, "dms", filename)
	result := IncludeResult{}

	if _, err := os.Stat(targetPath); err == nil {
		result.Exists = true
	}

	targetAbs, err := filepath.Abs(targetPath)
	if err != nil {
		return result, err
	}

	targetRel := filepath.ToSlash(filepath.Join("dms", filename))

	mainLua := filepath.Join(configDir, "hyprland.lua")
	if _, err := os.Stat(mainLua); err == nil {
		result.ConfigFormat = "lua"
		result.ReadOnly = false
		processedLua := make(map[string]bool)
		if luaconfig.RequiresTarget(mainLua, targetAbs, processedLua) {
			result.Included = true
			return result, nil
		}
	}

	mainConf := filepath.Join(configDir, "hyprland.conf")
	if _, err := os.Stat(mainConf); err == nil {
		if result.ConfigFormat == "" {
			result.ConfigFormat = "hyprlang"
			result.ReadOnly = true
		}
		processed := make(map[string]bool)
		if hyprlandFindIncludeHyprlang(mainConf, targetRel, processed) {
			result.Included = true
			return result, nil
		}
	}

	return result, nil
}

func hyprlandFindIncludeHyprlang(filePath, target string, processed map[string]bool) bool {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return false
	}

	if processed[absPath] {
		return false
	}
	processed[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return false
	}

	baseDir := filepath.Dir(absPath)
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") || trimmed == "" {
			continue
		}

		if !strings.HasPrefix(trimmed, "source") {
			continue
		}

		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) < 2 {
			continue
		}

		sourcePath := strings.TrimSpace(parts[1])
		if matchesTarget(sourcePath, target) {
			return true
		}

		fullPath := sourcePath
		if !filepath.IsAbs(sourcePath) {
			fullPath = filepath.Join(baseDir, sourcePath)
		}

		expanded, err := utils.ExpandPath(fullPath)
		if err != nil {
			continue
		}

		if hyprlandFindIncludeHyprlang(expanded, target, processed) {
			return true
		}
	}

	return false
}

func checkNiriInclude(filename string) (IncludeResult, error) {
	configDir := filepath.Join(utils.XDGConfigHome(), "niri")

	targetPath := filepath.Join(configDir, "dms", filename)
	result := IncludeResult{}

	if _, err := os.Stat(targetPath); err == nil {
		result.Exists = true
	}

	mainConfig := filepath.Join(configDir, "config.kdl")
	if _, err := os.Stat(mainConfig); os.IsNotExist(err) {
		return result, nil
	}

	processed := make(map[string]bool)
	result.Included = niriFindInclude(mainConfig, "dms/"+filename, processed)
	return result, nil
}

func niriFindInclude(filePath, target string, processed map[string]bool) bool {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return false
	}

	if processed[absPath] {
		return false
	}
	processed[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return false
	}

	baseDir := filepath.Dir(absPath)
	content := string(data)

	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "//") || trimmed == "" {
			continue
		}

		if !strings.HasPrefix(trimmed, "include") {
			continue
		}

		startQuote := strings.Index(trimmed, "\"")
		if startQuote == -1 {
			continue
		}
		endQuote := strings.LastIndex(trimmed, "\"")
		if endQuote <= startQuote {
			continue
		}

		includePath := trimmed[startQuote+1 : endQuote]
		if matchesTarget(includePath, target) {
			return true
		}

		fullPath := includePath
		if !filepath.IsAbs(includePath) {
			fullPath = filepath.Join(baseDir, includePath)
		}

		if niriFindInclude(fullPath, target, processed) {
			return true
		}
	}

	return false
}

func checkMangoWCInclude(filename string) (IncludeResult, error) {
	configDir := filepath.Join(utils.XDGConfigHome(), "mango")

	targetPath := filepath.Join(configDir, "dms", filename)
	result := IncludeResult{}

	if _, err := os.Stat(targetPath); err == nil {
		result.Exists = true
	}

	mainConfig := filepath.Join(configDir, "config.conf")
	if _, err := os.Stat(mainConfig); os.IsNotExist(err) {
		mainConfig = filepath.Join(configDir, "mango.conf")
	}
	if _, err := os.Stat(mainConfig); os.IsNotExist(err) {
		return result, nil
	}

	processed := make(map[string]bool)
	result.Included = mangowcFindInclude(mainConfig, "dms/"+filename, processed)
	return result, nil
}

func mangowcFindInclude(filePath, target string, processed map[string]bool) bool {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return false
	}

	if processed[absPath] {
		return false
	}
	processed[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return false
	}

	baseDir := filepath.Dir(absPath)
	lines := strings.Split(string(data), "\n")

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") || trimmed == "" {
			continue
		}

		if !strings.HasPrefix(trimmed, "source") {
			continue
		}

		parts := strings.SplitN(trimmed, "=", 2)
		if len(parts) < 2 {
			continue
		}

		sourcePath := strings.TrimSpace(parts[1])
		if matchesTarget(sourcePath, target) {
			return true
		}

		fullPath := sourcePath
		if !filepath.IsAbs(sourcePath) {
			fullPath = filepath.Join(baseDir, sourcePath)
		}

		expanded, err := utils.ExpandPath(fullPath)
		if err != nil {
			continue
		}

		if mangowcFindInclude(expanded, target, processed) {
			return true
		}
	}

	return false
}

func matchesTarget(path, target string) bool {
	path = strings.TrimPrefix(path, "./")
	target = strings.TrimPrefix(target, "./")
	return path == target || strings.HasSuffix(path, "/"+target)
}
