package icc

import (
	"math"
	"testing"
)

func TestWhitePointCCT(t *testing.T) {
	cases := []struct {
		name     string
		wp       [3]float64
		wantCCT  int
		wantName string
	}{
		{"D65", [3]float64{0.9505, 1.0, 1.0890}, 6504, "D65"},
		{"D50", [3]float64{0.9642, 1.0, 0.8249}, 5003, "D50"},
		{"missing white point", [3]float64{}, 0, ""},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			p := &Profile{WhitePoint: tc.wp}

			cct := p.WhitePointCCT()
			if tc.wantCCT == 0 {
				if cct != 0 {
					t.Fatalf("WhitePointCCT() = %d, want 0", cct)
				}
			} else if math.Abs(float64(cct-tc.wantCCT)) > 150 {
				t.Fatalf("WhitePointCCT() = %d, want ~%d", cct, tc.wantCCT)
			}

			if got := p.WhitePointName(); got != tc.wantName {
				t.Fatalf("WhitePointName() = %q, want %q", got, tc.wantName)
			}
		})
	}
}

func TestTRCKind(t *testing.T) {
	identity := Curve{Type: CurveIdentity}
	gamma22 := Curve{Type: CurveParametric, Gamma: 2.2}
	gamma18 := Curve{Type: CurveParametric, Gamma: 1.8}
	table := Curve{Type: CurveTable, Entries: make([]uint16, 1024)}
	tableShort := Curve{Type: CurveTable, Entries: make([]uint16, 256)}

	cases := []struct {
		name        string
		profile     Profile
		wantKind    string
		wantGamma   float64
		wantEntries int
	}{
		{"identity", Profile{HasTRC: true, TRC: [3]Curve{identity, identity, identity}}, "identity", 0, 0},
		{"gamma", Profile{HasTRC: true, TRC: [3]Curve{gamma22, gamma22, gamma22}}, "gamma", 2.2, 0},
		{"table", Profile{HasTRC: true, TRC: [3]Curve{table, table, table}}, "table", 0, 1024},
		{"mixed types", Profile{HasTRC: true, TRC: [3]Curve{gamma22, table, gamma22}}, "mixed", 0, 0},
		{"per-channel gamma", Profile{HasTRC: true, TRC: [3]Curve{gamma22, gamma18, gamma22}}, "mixed", 0, 0},
		{"per-channel table size", Profile{HasTRC: true, TRC: [3]Curve{table, tableShort, table}}, "mixed", 0, 0},
		{"no TRC", Profile{}, "", 0, 0},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			kind, gamma, entries := tc.profile.TRCKind()
			if kind != tc.wantKind || gamma != tc.wantGamma || entries != tc.wantEntries {
				t.Fatalf("TRCKind() = (%q, %v, %d), want (%q, %v, %d)",
					kind, gamma, entries, tc.wantKind, tc.wantGamma, tc.wantEntries)
			}
		})
	}
}
