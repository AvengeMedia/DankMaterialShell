package clipolicy

import (
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
