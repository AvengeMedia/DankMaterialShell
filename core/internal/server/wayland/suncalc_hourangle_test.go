package wayland

import (
	"math"
	"testing"
)

// The hour angle returned by sunHourAngle must invert the zenith-angle definition:
//
//	cos(z) = sin(lat)*sin(dec) + cos(lat)*cos(dec)*cos(H)
//
// This is a property of the quantity itself, not a restatement of any particular formula:
// whatever expression sunHourAngle uses, feeding its result back through the definition has to
// reproduce the zenith angle that was asked for.
func TestSunHourAngleInvertsZenith(t *testing.T) {
	// Latitudes from the tropics to the polar circle, declinations spanning a full year, and both
	// zenith targets the caller actually uses (elevTwilight -6, elevDaylight 3 => 96.833 and
	// 87.833 degrees).
	lats := []float64{0, 23.5, 40.7128, 45.6946, 51.5074, 60, 66.5}
	decls := []float64{-23.44, -10, 0, 10.69, 23.44}
	zeniths := []float64{90.833 - 3.0, 90.833 + 6.0, 90.833}

	for _, latDeg := range lats {
		for _, decDeg := range decls {
			for _, zDeg := range zeniths {
				lat := latDeg * degToRad
				dec := decDeg * degToRad
				z := zDeg * degToRad

				h := sunHourAngle(lat, dec, z)
				if math.IsNaN(h) {
					// The sun never reaches that elevation there on that day: midnight sun or
					// polar night. Not a failure, and the caller already handles it.
					continue
				}

				got := math.Sin(lat)*math.Sin(dec) + math.Cos(lat)*math.Cos(dec)*math.Cos(h)
				want := math.Cos(z)
				if math.Abs(got-want) > 1e-12 {
					t.Errorf("lat=%.4f dec=%.2f zenith=%.3f: H=%.6f rad reproduces cos(z)=%.12f, want %.12f (off by %.3e, %.1f s of clock time)",
						latDeg, decDeg, zDeg, h, got, want, got-want,
						math.Abs(math.Acos(clamp(got))-math.Acos(clamp(want)))*radToDeg*240)
				}
			}
		}
	}
}

func clamp(v float64) float64 {
	if v > 1 {
		return 1
	}
	if v < -1 {
		return -1
	}
	return v
}
