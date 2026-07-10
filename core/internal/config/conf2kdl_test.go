package config

import (
	"strings"
	"testing"
)

func TestConfToKDL(t *testing.T) {
	in := strings.Join([]string{
		"titlebar_height=36",
		"blur_params_num_passes=2",
		"blur_params_noise=0.02",
		"shadows_contact_position_y=1",
		"env=MESA_GLTHREAD,true",
		"exec-once=dms run --session",
		"source=./dms/colors.conf",
		"bind=SUPER+CTRL,r,restart",
		"mousebind=SUPER,btn_left,moveresize,curmove",
		"windowrule=appid:mpv,tags:4,isfullscreen:1,noblur:1",
		"tagrule=id:1,name:web,layout_name:monocle",
		"monitorrule=name:^DP-1$,hdr:1,bitdepth:10",
	}, "\n")
	out := ConfToKDL(in)

	wantContains := []string{
		"layout {",
		"titlebar {",
		"height 36",
		"effects {",
		"passes 2",
		"params {",
		"noise 0.02",
		"contact {",
		"position {",
		"y 1",
		`environment {`,
		`MESA_GLTHREAD "true"`,
		`spawn-at-startup dms run --session`,
		`source "./dms/colors.kdl"`,
		"binds {",
		"Super+Ctrl+r { restart; }",
		"mouse-binds {",
		"Super+btn_left { moveresize curmove; }",
		"window-rule { match app-id=mpv; tags 4; open-fullscreen; no-blur }",
		`tag 1 { name web; layout monocle }`,
		`output DP-1 { hdr; bit-depth 10 }`,
	}
	for _, w := range wantContains {
		if !strings.Contains(out, w) {
			t.Errorf("ConfToKDL output missing %q\n--- got ---\n%s", w, out)
		}
	}
}
