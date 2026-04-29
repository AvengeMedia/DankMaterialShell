package sysupdate

import (
	"reflect"
	"testing"
)

func TestParseDnfList(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		backendID string
		installed map[string]string
		want      []Package
	}{
		{
			name:  "empty",
			input: "",
			want:  nil,
		},
		{
			name:      "single package with installed cross-ref",
			input:     "bash.x86_64                              5.2.40-1.fc41                       updates",
			backendID: "dnf",
			installed: map[string]string{"bash": "5.2.39-1.fc41"},
			want: []Package{
				{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf", FromVersion: "5.2.39-1.fc41", ToVersion: "5.2.40-1.fc41"},
			},
		},
		{
			name: "noarch package and missing installed entry",
			input: `bash.x86_64        5.2.40-1.fc41        updates
fonts-misc.noarch  1.0.5-2.fc41         updates`,
			backendID: "dnf",
			installed: map[string]string{"bash": "5.2.39-1.fc41"},
			want: []Package{
				{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf", FromVersion: "5.2.39-1.fc41", ToVersion: "5.2.40-1.fc41"},
				{Name: "fonts-misc.noarch", Repo: RepoSystem, Backend: "dnf", FromVersion: "", ToVersion: "1.0.5-2.fc41"},
			},
		},
		{
			name: "skips header rows",
			input: `Available
Upgrades
bash.x86_64       5.2.40-1.fc41       updates`,
			backendID: "dnf",
			installed: nil,
			want: []Package{
				{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf", FromVersion: "", ToVersion: "5.2.40-1.fc41"},
			},
		},
		{
			name:      "skips lines with too few fields",
			input:     "incomplete",
			backendID: "dnf",
			want:      nil,
		},
		{
			name:      "package without arch suffix",
			input:     "noarchpkg 1.2.3 updates",
			backendID: "dnf",
			installed: map[string]string{"noarchpkg": "1.2.0"},
			want: []Package{
				{Name: "noarchpkg", Repo: RepoSystem, Backend: "dnf", FromVersion: "1.2.0", ToVersion: "1.2.3"},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseDnfList(tt.input, tt.backendID, tt.installed)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseDnfList() = %#v\nwant %#v", got, tt.want)
			}
		})
	}
}
