package clipolicy

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/afero"
)

const (
	PackagedPath = "/usr/share/dms/cli-policy.json"
	AdminPath    = "/etc/dms/cli-policy.json"
)

type File struct {
	PolicyVersion   int       `json:"policy_version"`
	ImmutableSystem *bool     `json:"immutable_system"`
	BlockedCommands *[]string `json:"blocked_commands"`
	Message         *string   `json:"message"`
}

// LoadFile returns nil without an error when the file does not exist.
func LoadFile(fs afero.Fs, path string) (*File, error) {
	data, err := afero.ReadFile(fs, path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to read %s: %w", path, err)
	}

	var policy File
	if err := json.Unmarshal(data, &policy); err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", path, err)
	}

	return &policy, nil
}
