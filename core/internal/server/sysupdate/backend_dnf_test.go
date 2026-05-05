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
			name: "skips dnf5 banner / column header lines",
			input: `Updates available
Last metadata expiration check: 0:01:23 ago on Tue Apr 29 14:00:00 2026.
Package    Version    Repository    Size
bash.x86_64       5.2.40-1.fc41       updates`,
			backendID: "dnf",
			installed: nil,
			want: []Package{
				{Name: "bash.x86_64", Repo: RepoSystem, Backend: "dnf", FromVersion: "", ToVersion: "5.2.40-1.fc41"},
			},
		},
		{
			name: "skips dnf warning lines while keeping package rows",
			input: `Failed to expire repository cache in path "/home/user/.cache/libdnf5/updates": cannot open file
example-driver.x86_64                2:9.8.7-1.fc99                updates
example-tool.noarch                  1.2.3^45.gitabcdef-1.fc99     copr`,
			backendID: "dnf5",
			installed: map[string]string{
				"example-driver": "2:9.8.6-1.fc99",
				"example-tool":   "1.2.2^44.gitabcdef-1.fc99",
			},
			want: []Package{
				{Name: "example-driver.x86_64", Repo: RepoSystem, Backend: "dnf5", FromVersion: "2:9.8.6-1.fc99", ToVersion: "2:9.8.7-1.fc99"},
				{Name: "example-tool.noarch", Repo: RepoSystem, Backend: "dnf5", FromVersion: "1.2.2^44.gitabcdef-1.fc99", ToVersion: "1.2.3^45.gitabcdef-1.fc99"},
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

func TestDnfCheckUpdatesArgv(t *testing.T) {
	tests := []struct {
		bin  string
		want []string
	}{
		{bin: "dnf5", want: []string{"dnf5", "check-upgrade", "--refresh", "--quiet"}},
		{bin: "dnf", want: []string{"dnf", "check-update", "--refresh", "--quiet"}},
	}

	for _, tt := range tests {
		t.Run(tt.bin, func(t *testing.T) {
			got := dnfCheckUpdatesArgv(tt.bin)
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("dnfCheckUpdatesArgv(%q) = %#v, want %#v", tt.bin, got, tt.want)
			}
		})
	}
}
