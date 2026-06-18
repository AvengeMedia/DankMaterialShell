package sysupdate

import (
	"reflect"
	"testing"
)

func TestParseFlatpakUpdateOutput(t *testing.T) {
	realOutput := "Looking for updates…\n\n\n 1.\t   \torg.gtk.Gtk3theme.adw-gtk3-dark\t3.22\ti\tflathub\t< 131.4 kB\n\nProceed with these changes to the system installation? [Y/n]: n\n"

	tests := []struct {
		name      string
		input     string
		installed map[string]flatpakInstalledEntry
		want      []Package
	}{
		{
			name:  "empty output",
			input: "",
			want:  nil,
		},
		{
			name:  "nothing to do",
			input: "Looking for updates…\n\nNothing to do.\n",
			want:  nil,
		},
		{
			name:  "real flatpak update output — new install",
			input: realOutput,
			want: []Package{
				{
					Name:        "org.gtk.Gtk3theme.adw-gtk3-dark",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "",
					Ref:         "org.gtk.Gtk3theme.adw-gtk3-dark//3.22",
				},
			},
		},
		{
			name:  "update with installed version",
			input: "Looking for updates…\n\n 1.\tSlack\tcom.slack.Slack\tstable\tu\tflathub\t< 5.2 MB\n\nProceed? [Y/n]: n\n",
			installed: map[string]flatpakInstalledEntry{
				"com.slack.Slack//stable": {version: "4.40.0"},
			},
			want: []Package{
				{
					Name:        "Slack",
					Repo:        RepoFlatpak,
					Backend:     "flatpak",
					FromVersion: "4.40.0",
					Ref:         "com.slack.Slack//stable",
				},
			},
		},
		{
			name:  "reinstall op included",
			input: " 1.\t\torg.freedesktop.Platform\t25.08\tr\tflathub\t< 100 MB\n",
			want: []Package{
				{
					Name:    "org.freedesktop.Platform",
					Repo:    RepoFlatpak,
					Backend: "flatpak",
					Ref:     "org.freedesktop.Platform//25.08",
				},
			},
		},
		{
			name:  "unknown op excluded",
			input: " 1.\t\torg.freedesktop.Platform\t25.08\te\tflathub\t0\n",
			want:  nil,
		},
		{
			name:  "deduplicates same ref",
			input: " 1.\t\tcom.example.App\tstable\ti\tflathub\t< 1 MB\n 2.\t\tcom.example.App\tstable\ti\tflathub\t< 1 MB\n",
			want: []Package{
				{
					Name:    "com.example.App",
					Repo:    RepoFlatpak,
					Backend: "flatpak",
					Ref:     "com.example.App//stable",
				},
			},
		},
		{
			name:  "non-table lines ignored",
			input: "Looking for updates…\nSome warning line\nID\tBranch\tOp\n 1.\t\tcom.example.App\tstable\ti\tflathub\t< 1 MB\nProceed? [Y/n]: n\n",
			want: []Package{
				{
					Name:    "com.example.App",
					Repo:    RepoFlatpak,
					Backend: "flatpak",
					Ref:     "com.example.App//stable",
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseFlatpakUpdateOutput(tt.input, tt.installed)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseFlatpakUpdateOutput() = %#v\nwant %#v", got, tt.want)
			}
		})
	}
}
