package sysupdate

import (
	"reflect"
	"testing"
)

func TestParseFlatpakUpdates(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		installed map[string]flatpakInstalledEntry
		want      []Package
	}{
		{
			name:  "empty",
			input: "",
			want:  nil,
		},
		{
			name: "real flathub-style row with empty version, falls back to commit",
			// columns: application,version,branch,commit,name
			input: "com.discordapp.Discord\t\tstable\t43a1e5d2d3a446919356fd86d9f984ad7c6a0e20f109250d9d868223f26ca586\tDiscord",
			installed: map[string]flatpakInstalledEntry{
				"com.discordapp.Discord//stable": {commit: "8b16fa1a9b2aa189302c2428c8a7bb33dd050faf7e535dd1d975044cb0986855"},
			},
			want: []Package{
				{
					Name:        "Discord",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "8b16fa1a",
					ToVersion:   "43a1e5d2",
					Ref:         "com.discordapp.Discord//stable",
				},
			},
		},
		{
			name:  "remote provides version, installed version known",
			input: "com.example.App\t1.5.0\tstable\tdeadbeefcafe\tExample App",
			installed: map[string]flatpakInstalledEntry{
				"com.example.App//stable": {version: "1.4.2"},
			},
			want: []Package{
				{
					Name:        "Example App",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "1.4.2",
					ToVersion:   "1.5.0",
					Ref:         "com.example.App//stable",
				},
			},
		},
		{
			name:      "no installed entry, remote has no version, falls back to commit on both sides",
			input:     "org.gnome.Platform\t\t49\tbadcd4afb1fe\tgnome platform",
			installed: nil,
			want: []Package{
				{
					Name:        "gnome platform",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "",
					ToVersion:   "badcd4af",
					Ref:         "org.gnome.Platform//49",
				},
			},
		},
		{
			name:  "missing display name falls back to application id",
			input: "com.example.NoName\t2.0\tstable\tabcdef123456\t",
			want: []Package{
				{
					Name:        "com.example.NoName",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "",
					ToVersion:   "2.0",
					Ref:         "com.example.NoName//stable",
				},
			},
		},
		{
			name:  "skips blank lines and rows with empty application id",
			input: "\n\t\t\t\t\norg.real.App\t1.0\tstable\tdeadbeef\tReal App",
			want: []Package{
				{
					Name:        "Real App",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "",
					ToVersion:   "1.0",
					Ref:         "org.real.App//stable",
				},
			},
		},
		{
			name:  "skips phantom updates where remote commit matches installed",
			input: "com.phantom.App\t\tstable\tabc12345deadbeef\tPhantom",
			installed: map[string]flatpakInstalledEntry{
				"com.phantom.App//stable": {commit: "abc12345"},
			},
			want: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseFlatpakUpdates(tt.input, tt.installed)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseFlatpakUpdates() = %#v\nwant %#v", got, tt.want)
			}
		})
	}
}

func TestFlatpakVersionPair(t *testing.T) {
	tests := []struct {
		name                                                   string
		installedVer, installedCommit, remoteVer, remoteCommit string
		wantFrom, wantTo                                       string
	}{
		{
			name:         "remote has version - prefer versions",
			installedVer: "1.0.0", remoteVer: "1.1.0",
			wantFrom: "1.0.0", wantTo: "1.1.0",
		},
		{
			name:            "remote has no version - both sides fall to short commit",
			installedCommit: "8b16fa1a9b2aa189302c2428c8a7bb33dd050faf7e535dd1d975044cb0986855",
			remoteCommit:    "43a1e5d2d3a446919356fd86d9f984ad7c6a0e20f109250d9d868223f26ca586",
			wantFrom:        "8b16fa1a", wantTo: "43a1e5d2",
		},
		{
			name:            "short commits left as-is",
			installedCommit: "abc123", remoteCommit: "def456",
			wantFrom: "abc123", wantTo: "def456",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			from, to := flatpakVersionPair(tt.installedVer, tt.installedCommit, tt.remoteVer, tt.remoteCommit)
			if from != tt.wantFrom || to != tt.wantTo {
				t.Errorf("flatpakVersionPair() = (%q, %q), want (%q, %q)", from, to, tt.wantFrom, tt.wantTo)
			}
		})
	}
}
