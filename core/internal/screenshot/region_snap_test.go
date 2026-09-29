package screenshot

import (
	"testing"
)

func TestSnapTargetDisplayName(t *testing.T) {
	tests := []struct {
		target   SnapTarget
		expected string
	}{
		{
			target:   SnapTarget{Name: "dms:control-center", Type: "popout"},
			expected: "control center",
		},
		{
			target:   SnapTarget{Name: "dms:clipboard-popout", Type: "popout"},
			expected: "clipboard",
		},
		{
			target:   SnapTarget{Name: "dms:wifi-password", Type: "modal"},
			expected: "wifi password",
		},
		{
			target:   SnapTarget{Name: "dms:polkit-auth-surface", Type: "modal"},
			expected: "polkit auth",
		},
		{
			target:   SnapTarget{Name: "", Type: "popout"},
			expected: "popout",
		},
	}

	for _, tt := range tests {
		got := tt.target.DisplayName()
		if got != tt.expected {
			t.Errorf("DisplayName() for %+v = %q, want %q", tt.target, got, tt.expected)
		}
	}
}

func TestUpdateHoverTarget(t *testing.T) {
	mockSurface := &OutputSurface{
		logicalW: 1920,
		logicalH: 1080,
		output: &WaylandOutput{
			name:            "eDP-1",
			x:               0,
			y:               0,
			fractionalScale: 1.0,
		},
		screenBuf: &ShmBuffer{
			Width:  1920,
			Height: 1080,
			Stride: 1920 * 4,
		},
	}

	targets := []SnapTarget{
		{
			Name:   "dms:control-center",
			Type:   "popout",
			X:      1400,
			Y:      48,
			Width:  420,
			Height: 580,
		},
		{
			Name:   "dms:clipboard-popout",
			Type:   "popout",
			X:      500,
			Y:      100,
			Width:  350,
			Height: 400,
		},
	}

	r := &RegionSelector{
		activeSurface: mockSurface,
		surfaces:      []*OutputSurface{mockSurface},
		snapTargets:   targets,
	}

	// 1. Outside any target
	r.updateHoverTarget(100, 100)
	if r.hoveredTarget != nil {
		t.Fatalf("expected nil hoveredTarget, got %+v", r.hoveredTarget)
	}

	// 2. Inside control center
	r.updateHoverTarget(1500, 100)
	if r.hoveredTarget == nil || r.hoveredTarget.Name != "dms:control-center" {
		t.Fatalf("expected control-center target, got %+v", r.hoveredTarget)
	}

	// 3. Move inside clipboard
	r.updateHoverTarget(600, 200)
	if r.hoveredTarget == nil || r.hoveredTarget.Name != "dms:clipboard-popout" {
		t.Fatalf("expected clipboard target, got %+v", r.hoveredTarget)
	}

	// 4. Move outside
	r.updateHoverTarget(0, 0)
	if r.hoveredTarget != nil {
		t.Fatalf("expected nil hoveredTarget when outside, got %+v", r.hoveredTarget)
	}

	// 5. When user has actively drawn a selection, hoverTarget must not change
	r.selection.hasSelection = true
	r.selection.fromPreSelect = false
	r.updateHoverTarget(1500, 100)
	if r.hoveredTarget != nil {
		t.Fatalf("expected nil hoveredTarget when user selection is active, got %+v", r.hoveredTarget)
	}

	// 6. When selection is a preselection (fromPreSelect=true), hover snap must still work
	r.selection.hasSelection = true
	r.selection.fromPreSelect = true
	r.updateHoverTarget(1500, 100)
	if r.hoveredTarget == nil || r.hoveredTarget.Name != "dms:control-center" {
		t.Fatalf("expected control-center hover over preselection, got %+v", r.hoveredTarget)
	}
}

func TestSelectionRenderBoundsHoveredTarget(t *testing.T) {
	mockSurface := &OutputSurface{
		logicalW: 1920,
		logicalH: 1080,
		output: &WaylandOutput{
			name:            "eDP-1",
			x:               0,
			y:               0,
			fractionalScale: 1.0,
		},
		screenBuf: &ShmBuffer{
			Width:  1920,
			Height: 1080,
			Stride: 1920 * 4,
		},
	}

	target := &SnapTarget{
		Name:   "dms:control-center",
		Type:   "popout",
		X:      1400,
		Y:      48,
		Width:  420,
		Height: 580,
	}

	r := &RegionSelector{
		activeSurface: mockSurface,
		surfaces:      []*OutputSurface{mockSurface},
		hoveredTarget: target,
	}

	bounds, ok := r.selectionRenderBounds(mockSurface)
	if !ok {
		t.Fatalf("expected selectionRenderBounds to return ok for hovered target")
	}

	if bounds.x != 1400 || bounds.y != 48 || bounds.w != 421 || bounds.h != 581 {
		t.Errorf("unexpected bounds: %+v", bounds)
	}

	// At scale 1x: w=x2-x1+1=421, h=581 — matches ext.width()/ext.height() from regular path.
	if bounds.labelText != "[control center] 421x581" {
		t.Errorf("unexpected label text: %q", bounds.labelText)
	}

	// With a preselection active, hoveredTarget must still be rendered.
	r.selection.hasSelection = true
	r.selection.fromPreSelect = true
	bounds, ok = r.selectionRenderBounds(mockSurface)
	if !ok {
		t.Fatalf("expected selectionRenderBounds to return ok over preselection")
	}
	if bounds.x != 1400 || bounds.y != 48 {
		t.Errorf("unexpected bounds over preselection: %+v", bounds)
	}

	// With a user-drawn selection, hoveredTarget must NOT be rendered.
	r.selection.fromPreSelect = false
	_, ok = r.selectionRenderBounds(mockSurface)
	if ok {
		t.Fatalf("expected selectionRenderBounds to return !ok when user selection is active")
	}
}
