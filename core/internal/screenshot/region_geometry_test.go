package screenshot

import (
	"testing"
)

func TestSelectedLogicalGeometry(t *testing.T) {
	tests := []struct {
		name          string
		anchorX       float64
		anchorY       float64
		currentX      float64
		currentY      float64
		shiftHeld     bool
		hasSelection  bool
		wantX         int
		wantY         int
		wantW         int
		wantH         int
		wantOK        bool
		wantFormatted string
	}{
		{
			name:          "standard drag top-left to bottom-right",
			anchorX:       2263,
			anchorY:       118,
			currentX:      2263 + 513,
			currentY:      118 + 313,
			hasSelection:  true,
			wantX:         2263,
			wantY:         118,
			wantW:         513,
			wantH:         313,
			wantOK:        true,
			wantFormatted: "2263,118 513x313",
		},
		{
			name:          "inverted drag bottom-right to top-left",
			anchorX:       1000,
			anchorY:       800,
			currentX:      400,
			currentY:      300,
			hasSelection:  true,
			wantX:         400,
			wantY:         300,
			wantW:         600,
			wantH:         500,
			wantOK:        true,
			wantFormatted: "400,300 600x500",
		},
		{
			name:          "shift held square constraint",
			anchorX:       100,
			anchorY:       100,
			currentX:      500,
			currentY:      300,
			shiftHeld:     true,
			hasSelection:  true,
			wantX:         100,
			wantY:         100,
			wantW:         200,
			wantH:         200,
			wantOK:        true,
			wantFormatted: "100,100 200x200",
		},
		{
			name:         "no selection",
			hasSelection: false,
			wantOK:       false,
		},
		{
			name:         "zero width",
			anchorX:      100,
			anchorY:      100,
			currentX:     100,
			currentY:     200,
			hasSelection: true,
			wantOK:       false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			r := &RegionSelector{
				shiftHeld: tc.shiftHeld,
				selection: SelectionState{
					hasSelection: tc.hasSelection,
					anchorX:      tc.anchorX,
					anchorY:      tc.anchorY,
					currentX:     tc.currentX,
					currentY:     tc.currentY,
				},
			}

			reg, ok := r.selectedLogicalGeometry()
			if ok != tc.wantOK {
				t.Fatalf("selectedLogicalGeometry() ok = %v, want %v", ok, tc.wantOK)
			}
			if !tc.wantOK {
				return
			}

			if int(reg.X) != tc.wantX || int(reg.Y) != tc.wantY || int(reg.Width) != tc.wantW || int(reg.Height) != tc.wantH {
				t.Errorf("got (%d, %d, %d, %d), want (%d, %d, %d, %d)",
					reg.X, reg.Y, reg.Width, reg.Height, tc.wantX, tc.wantY, tc.wantW, tc.wantH)
			}

			formatted := reg.GeometryString()
			if formatted != tc.wantFormatted {
				t.Errorf("formatted = %q, want %q", formatted, tc.wantFormatted)
			}
		})
	}
}

func TestRegionGeometryString(t *testing.T) {
	r := Region{X: 1920, Y: 1080, Width: 800, Height: 600}
	if got := r.GeometryString(); got != "1920,1080 800x600" {
		t.Fatalf("GeometryString() = %q, want %q", got, "1920,1080 800x600")
	}
}
