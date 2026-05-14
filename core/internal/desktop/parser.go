package desktop

import (
	"bufio"
	"bytes"
	"strings"
)

type group struct {
	keys map[string]string
}

func parseGroups(data []byte) map[string]*group {
	groups := make(map[string]*group)
	var current *group

	scanner := bufio.NewScanner(bytes.NewReader(data))
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || line[0] == '#' {
			continue
		}

		if line[0] == '[' && strings.HasSuffix(line, "]") {
			name := line[1 : len(line)-1]
			g, ok := groups[name]
			if !ok {
				g = &group{keys: make(map[string]string)}
				groups[name] = g
			}
			current = g
			continue
		}

		if current == nil {
			continue
		}

		eq := strings.IndexByte(line, '=')
		if eq <= 0 {
			continue
		}

		key := strings.TrimSpace(line[:eq])
		if bracket := strings.IndexByte(key, '['); bracket > 0 {
			key = key[:bracket]
		}
		if _, ok := current.keys[key]; ok {
			continue
		}
		current.keys[key] = strings.TrimSpace(line[eq+1:])
	}

	return groups
}

func splitList(value string) []string {
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ";")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		out = append(out, p)
	}
	return out
}

func parseBool(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "true", "1", "yes":
		return true
	}
	return false
}
