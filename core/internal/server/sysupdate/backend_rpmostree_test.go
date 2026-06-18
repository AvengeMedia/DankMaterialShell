package sysupdate

import (
	"reflect"
	"testing"
)

func TestParseRpmOstreeStatus(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []Package
		wantErr bool
	}{
		{
			name:  "no cached update",
			input: `{"deployments":[{"version":"39.20240101.0","booted":true}],"cached-update":null}`,
			want:  nil,
		},
		{
			name: "cached update available, booted version differs",
			input: `{
				"deployments": [
					{"origin": "fedora:fedora/x86_64/silverblue", "version": "39.20240101.0", "booted": true},
					{"origin": "fedora:fedora/x86_64/silverblue", "version": "39.20231215.0", "booted": false}
				],
				"cached-update": {
					"origin": "fedora:fedora/x86_64/silverblue",
					"version": "39.20240115.0",
					"checksum": "abc123"
				}
			}`,
			want: []Package{
				{
					Name:        "fedora:fedora/x86_64/silverblue",
					Repo:        RepoOSTree,
					Backend:     "rpm-ostree",
					FromVersion: "39.20240101.0",
					ToVersion:   "39.20240115.0",
				},
			},
		},
		{
			name: "cached update equals booted version (no real update)",
			input: `{
				"deployments": [{"version": "39.20240101.0", "booted": true}],
				"cached-update": {"origin": "x", "version": "39.20240101.0"}
			}`,
			want: nil,
		},
		{
			name: "no booted deployment falls back to empty from",
			input: `{
				"deployments": [{"version": "39.20240101.0", "booted": false}],
				"cached-update": {"origin": "fedora:silverblue", "version": "39.20240115.0"}
			}`,
			want: []Package{
				{
					Name:        "fedora:silverblue",
					Repo:        RepoOSTree,
					Backend:     "rpm-ostree",
					FromVersion: "",
					ToVersion:   "39.20240115.0",
				},
			},
		},
		{
			name: "missing origin defaults to system",
			input: `{
				"deployments": [{"version": "1.0", "booted": true}],
				"cached-update": {"version": "1.1"}
			}`,
			want: []Package{
				{
					Name:        "system",
					Repo:        RepoOSTree,
					Backend:     "rpm-ostree",
					FromVersion: "1.0",
					ToVersion:   "1.1",
				},
			},
		},
		{
			name:    "malformed JSON",
			input:   `{not json`,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseRpmOstreeStatus([]byte(tt.input))
			if (err != nil) != tt.wantErr {
				t.Fatalf("parseRpmOstreeStatus() err = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr {
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseRpmOstreeStatus() = %#v\nwant %#v", got, tt.want)
			}
		})
	}
}
