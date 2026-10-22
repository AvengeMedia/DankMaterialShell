package clipolicy

import (
	"strings"
	"testing"

	"github.com/spf13/afero"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRegistriesDisabled(t *testing.T) {
	tests := []struct {
		name     string
		packaged string
		admin    string
		want     bool
		wantErr  string
	}{
		{name: "no policy files"},
		{name: "packaged policy", packaged: `{"disable_registries": true}`, want: true},
		{name: "admin policy overrides packaged", packaged: `{"disable_registries": true}`, admin: `{"disable_registries": false}`},
		{name: "admin policy", admin: `{"disable_registries": true}`, want: true},
		{name: "admin policy without the key keeps packaged", packaged: `{"disable_registries": true}`, admin: `{"immutable_system": true}`, want: true},
		{name: "malformed packaged policy", packaged: "{not json", admin: `{"disable_registries": false}`, wantErr: "failed to parse " + PackagedPath},
		{name: "malformed admin policy", packaged: `{"disable_registries": false}`, admin: "{not json", wantErr: "failed to parse " + AdminPath},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs := afero.NewMemMapFs()
			if tt.packaged != "" {
				require.NoError(t, afero.WriteFile(fs, PackagedPath, []byte(tt.packaged), 0o644))
			}
			if tt.admin != "" {
				require.NoError(t, afero.WriteFile(fs, AdminPath, []byte(tt.admin), 0o644))
			}

			disabled, err := RegistriesDisabled(fs)
			if tt.wantErr != "" {
				require.ErrorContains(t, err, tt.wantErr)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, tt.want, disabled)
		})
	}
}

var shellSwitchEnv = map[string]string{
	"disable_lock_ipc_unlock":  "DMS_POLICY_DISABLE_LOCK_IPC_UNLOCK",
	"disable_logind_unlock":    "DMS_POLICY_DISABLE_LOGIND_UNLOCK",
	"disable_custom_lock_pam":  "DMS_POLICY_DISABLE_CUSTOM_LOCK_PAM",
	"disable_user_plugins":     "DMS_POLICY_DISABLE_USER_PLUGINS",
	"disable_settings_ipc_set": "DMS_POLICY_DISABLE_SETTINGS_IPC_SET",
}

func TestShellEnv(t *testing.T) {
	tests := []struct {
		name     string
		packaged string
		admin    string
		on       bool
	}{
		{name: "no policy files"},
		{name: "packaged policy", packaged: `{"KEY": true}`, on: true},
		{name: "admin policy", admin: `{"KEY": true}`, on: true},
		{name: "admin policy overrides packaged", packaged: `{"KEY": true}`, admin: `{"KEY": false}`},
		{name: "admin policy without the key keeps packaged", packaged: `{"KEY": true}`, admin: `{"immutable_system": true}`, on: true},
	}

	for key, name := range shellSwitchEnv {
		for _, tt := range tests {
			t.Run(key+"/"+tt.name, func(t *testing.T) {
				fs := afero.NewMemMapFs()
				if tt.packaged != "" {
					require.NoError(t, afero.WriteFile(fs, PackagedPath, []byte(strings.ReplaceAll(tt.packaged, "KEY", key)), 0o644))
				}
				if tt.admin != "" {
					require.NoError(t, afero.WriteFile(fs, AdminPath, []byte(strings.ReplaceAll(tt.admin, "KEY", key)), 0o644))
				}

				var want []string
				for _, other := range shellSwitchEnv {
					if other == name && tt.on {
						want = append(want, other+"=1")
					} else {
						want = append(want, other+"=0")
					}
				}

				env, err := ShellEnv(fs)
				require.NoError(t, err)
				assert.ElementsMatch(t, want, env)
			})
		}
	}
}

func TestShellEnvMalformedPolicyTurnsEverySwitchOn(t *testing.T) {
	fs := afero.NewMemMapFs()
	require.NoError(t, afero.WriteFile(fs, AdminPath, []byte("{not json"), 0o644))

	var want []string
	for _, name := range shellSwitchEnv {
		want = append(want, name+"=1")
	}

	env, err := ShellEnv(fs)
	require.ErrorContains(t, err, "failed to parse "+AdminPath)
	assert.ElementsMatch(t, want, env)
}
