package utils

import (
	"os"
	"strings"
)

func HasGroup(groupName string) bool {
	return HasGroupIn(groupName, "/etc/group")
}

func HasGroupIn(groupName, path string) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return HasGroupData(groupName, string(data))
}

func HasGroupData(groupName, data string) bool {
	prefix := groupName + ":"
	for line := range strings.SplitSeq(data, "\n") {
		if strings.HasPrefix(line, prefix) {
			return true
		}
	}
	return false
}

func FindGroupData(data string, candidates ...string) (string, bool) {
	for _, candidate := range candidates {
		if HasGroupData(candidate, data) {
			return candidate, true
		}
	}
	return "", false
}
