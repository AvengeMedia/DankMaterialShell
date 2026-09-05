package screenshot

import (
	"bytes"
	"image"
	"os"
	"testing"
)

func TestAqueousCropRoundsOutwardAndClips(t *testing.T) {
	for _, test := range []struct {
		geometry WindowGeometry
		pixels   image.Rectangle
		want     image.Rectangle
	}{
		{WindowGeometry{X: -1919, Y: 1, Width: 101, Height: 51, OutputX: -1920, Scale: 1.25}, image.Rect(0, 0, 2400, 1350), image.Rect(1, 1, 128, 65)},
		{WindowGeometry{X: -20, Y: -10, Width: 100, Height: 60, Scale: 1.5}, image.Rect(0, 0, 800, 600), image.Rect(0, 0, 120, 75)},
		{WindowGeometry{X: 90, Y: 80, Width: 100, Height: 100, Scale: 1}, image.Rect(0, 0, 100, 100), image.Rect(90, 80, 100, 100)},
		{WindowGeometry{X: 200, Y: 200, Width: 20, Height: 20, Scale: 1}, image.Rect(0, 0, 100, 100), image.Rectangle{}},
	} {
		if got := aqueousCropRect(&test.geometry, test.pixels); got != test.want {
			t.Fatalf("got %v want %v", got, test.want)
		}
	}
}

func TestAqueousGeometryUsesSeatAndOuterBounds(t *testing.T) {
	data, err := os.ReadFile("testdata/aqueous-snapshot.json")
	if err != nil {
		t.Fatal(err)
	}
	model, err := parseAqueousSnapshot(data)
	if err != nil {
		t.Fatal(err)
	}
	geometry, err := aqueousWindowGeometry(model, "")
	if err != nil {
		t.Fatal(err)
	}
	seat, _ := model.Seat("")
	window := model.Entities["window:"+seat.Window]
	if geometry.Width != int32(window.OuterGeometry.Width) || geometry.X != int32(window.OuterGeometry.X) {
		t.Fatal("wrong bounds")
	}
	seat.FocusKind = "layer_surface"
	if _, err := aqueousWindowGeometry(model, ""); err == nil {
		t.Fatal("layer focus captured")
	}
	seat.FocusKind = "window"
	model.Entities["seat:second"] = &aqueousCaptureEntity{Kind: "seat", ID: "second"}
	if _, err := aqueousWindowGeometry(model, ""); err == nil {
		t.Fatal("ambiguous seat captured")
	}
	if _, err := aqueousWindowGeometry(model, seat.ID); err != nil {
		t.Fatal(err)
	}
	delete(model.Entities, "window:"+seat.Window)
	if _, err := aqueousWindowGeometry(model, seat.ID); err == nil {
		t.Fatal("removed window captured")
	}
}

func TestAqueousSnapshotRejectsInvalidInput(t *testing.T) {
	data, err := os.ReadFile("testdata/aqueous-snapshot.json")
	if err != nil {
		t.Fatal(err)
	}
	for _, input := range [][]byte{
		[]byte(`{}`),
		bytes.Replace(data, []byte(`"schema": 1`), []byte(`"schema": 2`), 1),
		bytes.Replace(data, []byte(`"type": "snapshot"`), []byte(`"type": "delta"`), 1),
		append(data, []byte(`{}`)...),
		{0xff},
	} {
		if _, err := parseAqueousSnapshot(input); err == nil {
			t.Fatal("invalid snapshot accepted")
		}
	}
}
