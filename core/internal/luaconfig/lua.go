package luaconfig

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var luaRequireRE = regexp.MustCompile(`(?i)\brequire\s*\(\s*["']([^"']+)["']\s*\)`)

func ModuleToRelPath(module string) string {
	module = strings.TrimSpace(module)
	if module == "" {
		return ""
	}
	module = strings.NewReplacer(".", string(filepath.Separator), "/", string(filepath.Separator)).Replace(module)
	return filepath.Clean(module + ".lua")
}

func ModuleToPath(baseDir, module string) string {
	rel := ModuleToRelPath(module)
	if rel == "" {
		return ""
	}
	return filepath.Clean(filepath.Join(baseDir, rel))
}

func Requires(line string) []string {
	line = stripLineComment(line)
	if strings.TrimSpace(line) == "" {
		return nil
	}
	matches := luaRequireRE.FindAllStringSubmatch(line, -1)
	if len(matches) == 0 {
		return nil
	}
	modules := make([]string, 0, len(matches))
	for _, match := range matches {
		if len(match) > 1 && strings.TrimSpace(match[1]) != "" {
			modules = append(modules, strings.TrimSpace(match[1]))
		}
	}
	return modules
}

func Require(line string) (string, bool) {
	modules := Requires(line)
	if len(modules) != 1 {
		return "", false
	}
	return modules[0], true
}

func RequiresTarget(filePath, targetAbs string, processed map[string]bool) bool {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return false
	}
	return requiresTarget(absPath, filepath.Dir(absPath), targetAbs, processed)
}

func requiresTarget(filePath, rootDir, targetAbs string, processed map[string]bool) bool {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return false
	}
	targetAbsClean := filepath.Clean(targetAbs)

	if processed[absPath] {
		return false
	}
	processed[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return false
	}

	for _, raw := range strings.Split(string(data), "\n") {
		for _, module := range Requires(raw) {
			candidate := ModuleToPath(rootDir, module)
			if candidate == "" {
				continue
			}
			if filepath.Clean(candidate) == targetAbsClean {
				return true
			}
			if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
				if requiresTarget(candidate, rootDir, targetAbs, processed) {
					return true
				}
			}
		}
	}

	return false
}

func stripLineComment(line string) string {
	inStr := byte(0)
	esc := false
	for i := 0; i+1 < len(line); i++ {
		c := line[i]
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
		case '-':
			if line[i+1] == '-' {
				return line[:i]
			}
		}
	}
	return line
}
