package clipolicy

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/afero"
)

const (
	PackagedPath = "/usr/share/dms/cli-policy.json"
	AdminPath    = "/etc/dms/cli-policy.json"
)

type File struct {
	PolicyVersion        int       `json:"policy_version"`
	ImmutableSystem      *bool     `json:"immutable_system"`
	BlockedCommands      *[]string `json:"blocked_commands"`
	Message              *string   `json:"message"`
	DisableRegistries    *bool     `json:"disable_registries"`
	DisableLockIPCUnlock *bool     `json:"disable_lock_ipc_unlock"`
	DisableLogindUnlock  *bool     `json:"disable_logind_unlock"`
	DisableCustomLockPAM *bool     `json:"disable_custom_lock_pam"`
}

// shellSwitches reach the shell as DMS_POLICY_<KEY> in its launch environment.
var shellSwitches = []struct {
	key   string
	value func(*File) *bool
}{
	{"disable_lock_ipc_unlock", func(p *File) *bool { return p.DisableLockIPCUnlock }},
	{"disable_logind_unlock", func(p *File) *bool { return p.DisableLogindUnlock }},
	{"disable_custom_lock_pam", func(p *File) *bool { return p.DisableCustomLockPAM }},
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

// load returns the policy files that exist, PackagedPath first.
func load(fs afero.Fs) ([]*File, error) {
	var policies []*File
	for _, path := range []string{PackagedPath, AdminPath} {
		policy, err := LoadFile(fs, path)
		if err != nil {
			return nil, err
		}
		if policy != nil {
			policies = append(policies, policy)
		}
	}
	return policies, nil
}

// flag reports a boolean key, false unless set. An explicit value in AdminPath
// overrides PackagedPath.
func flag(policies []*File, value func(*File) *bool) bool {
	set := false
	for _, policy := range policies {
		if v := value(policy); v != nil {
			set = *v
		}
	}
	return set
}

// RegistriesDisabled reports whether the policy turns off the plugin and theme
// registries. An explicit value in AdminPath overrides PackagedPath.
func RegistriesDisabled(fs afero.Fs) (bool, error) {
	policies, err := load(fs)
	if err != nil {
		return false, err
	}
	return flag(policies, func(p *File) *bool { return p.DisableRegistries }), nil
}

// ShellEnv returns every shell switch as DMS_POLICY_<KEY>=1 or 0, so a value
// inherited by the shell never counts. A policy file that fails to load turns
// every switch on, and its error is returned with them.
func ShellEnv(fs afero.Fs) ([]string, error) {
	policies, err := load(fs)
	env := make([]string, 0, len(shellSwitches))
	for _, s := range shellSwitches {
		value := "0"
		if err != nil || flag(policies, s.value) {
			value = "1"
		}
		env = append(env, "DMS_POLICY_"+strings.ToUpper(s.key)+"="+value)
	}
	return env, err
}
