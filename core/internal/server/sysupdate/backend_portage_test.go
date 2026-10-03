package sysupdate

import (
	"reflect"
	"testing"
)

func TestParsePortageUpdates(t *testing.T) {
	input := `These are the packages that would be merged, in order:

Calculating dependencies ... done!
[ebuild     U  ] app-text/ansifilter-2.23::gentoo [2.22::gentoo] USE="gui -verify-sig" 0 KiB
[ebuild     U ~] sys-apps/kmscon-10.0.4::gentoo [10.0.3::gentoo] USE="drm fbdev gles2 pango -debug" 0 KiB
[ebuild     UD~] gui-wm/umbriel-0.0.0_pre20260924::guru [0.0.0_pre20261003::guru] USE="X%* screencast -jemalloc" 0 KiB
[binary    gU  ] mail-client/thunderbird-153.4.0-1:0/esr::gentoo [153.3.0:0/esr::gentoo] USE="X clang pulseaudio" 0 KiB
[binary  rRg   ] media-video/mpv-0.41.0-r2-21:0/2::gentoo  USE="X alsa cdda cli" 0 KiB
[ebuild     U  ] www-client/librewolf-bin-157.0_p1::librewolf [156.0.1_p1::librewolf] USE="wayland (-selinux)" 0 KiB

Total: 6 packages (6 upgrades), Size of downloads: 0 KiB
`

	want := []Package{
		{Name: "app-text/ansifilter", Repo: "gentoo (ebuild)", Backend: "portage", FromVersion: "2.22", ToVersion: "2.23"},
		{Name: "sys-apps/kmscon", Repo: "gentoo (ebuild)", Backend: "portage", FromVersion: "10.0.3", ToVersion: "10.0.4"},
		{Name: "gui-wm/umbriel", Repo: "guru (ebuild)", Backend: "portage", FromVersion: "0.0.0_pre20261003", ToVersion: "0.0.0_pre20260924"},
		{Name: "mail-client/thunderbird", Repo: "gentoo (binary)", Backend: "portage", FromVersion: "153.3.0:0/esr", ToVersion: "153.4.0-1:0/esr"},
		{Name: "media-video/mpv", Repo: "gentoo (binary)", Backend: "portage", ToVersion: "0.41.0-r2-21:0/2"},
		{Name: "www-client/librewolf-bin", Repo: "librewolf (ebuild)", Backend: "portage", FromVersion: "156.0.1_p1", ToVersion: "157.0_p1"},
	}

	got := parsePortageUpdates(input, "portage")
	if !reflect.DeepEqual(got, want) {
		t.Errorf("parsePortageUpdates() =\n%#v\nwant\n%#v", got, want)
	}
}

func TestPortageRepoLabelDefaultsToGentoo(t *testing.T) {
	if got := portageRepoLabel("ebuild", ""); got != RepoKind("gentoo (ebuild)") {
		t.Errorf("portageRepoLabel(no repo) = %q, want %q", got, "gentoo (ebuild)")
	}
}
