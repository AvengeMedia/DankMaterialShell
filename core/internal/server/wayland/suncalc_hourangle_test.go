package wayland

import (
	"math"
	"testing"
	"time"
)

// cos(z) = sin(lat)*sin(dec) + cos(lat)*cos(dec)*cos(H); the day's zenith span is
// [|lat-dec|, 180-|lat+dec|] (upper and lower culmination), which decides reachability
// independently of whatever expression sunHourAngle uses.
func TestSunHourAngleInvertsZenith(t *testing.T) {
	lats := []float64{0, 23.5, 40.7128, 45.6946, 51.5074, 59.91, 66.5}
	decls := []float64{-23.44, -10, 0, 10.69, 23.44}
	zeniths := []float64{90.833 - 3.0, 90.833 + 6.0, 90.833}

	for _, latDeg := range lats {
		for _, decDeg := range decls {
			for _, zDeg := range zeniths {
				lat := latDeg * degToRad
				dec := decDeg * degToRad
				z := zDeg * degToRad

				h, state := sunHourAngle(lat, dec, z)

				wantState := thresholdCrosses
				switch {
				case zDeg < math.Abs(latDeg-decDeg):
					wantState = thresholdAlwaysBelow
				case zDeg > 180-math.Abs(latDeg+decDeg):
					wantState = thresholdAlwaysAbove
				}
				if state != wantState {
					t.Errorf("lat=%.4f dec=%.2f zenith=%.3f: state=%d, want %d", latDeg, decDeg, zDeg, state, wantState)
					continue
				}
				if state != thresholdCrosses {
					continue
				}

				got := math.Sin(lat)*math.Sin(dec) + math.Cos(lat)*math.Cos(dec)*math.Cos(h)
				want := math.Cos(z)
				if math.Abs(got-want) > 1e-12 {
					t.Errorf("lat=%.4f dec=%.2f zenith=%.3f: H=%.6f rad gives cos(z)=%.12f, want %.12f", latDeg, decDeg, zDeg, h, got, want)
				}
			}
		}
	}
}

func TestUnreachableThresholdKeepsRealCrossings(t *testing.T) {
	summer := time.Date(2026, 6, 21, 12, 0, 0, 0, time.UTC)
	times, cond := CalculateSunTimesWithTwilight(59.91, 10.75, summer, -6.0, 3.0)
	if cond != SunNormal {
		t.Fatalf("oslo summer: cond=%d, want SunNormal", cond)
	}
	if !times.Dawn.Before(times.Sunrise) || !times.Sunrise.Before(times.Sunset) || !times.Sunset.Before(times.Night) {
		t.Errorf("oslo summer: want Dawn < Sunrise < Sunset < Night, got %v %v %v %v",
			times.Dawn, times.Sunrise, times.Sunset, times.Night)
	}

	winter := time.Date(2026, 12, 21, 12, 0, 0, 0, time.UTC)
	times, cond = CalculateSunTimesWithTwilight(69.65, 18.96, winter, -6.0, 3.0)
	if cond != SunNormal {
		t.Fatalf("tromso winter: cond=%d, want SunNormal", cond)
	}
	if !times.Sunrise.Equal(times.Sunset) {
		t.Errorf("tromso winter: want Sunrise == Sunset at solar noon, got %v %v", times.Sunrise, times.Sunset)
	}
	if !times.Dawn.Before(times.Sunrise) || !times.Sunset.Before(times.Night) {
		t.Errorf("tromso winter: want Dawn < Sunrise and Sunset < Night, got %v %v %v %v",
			times.Dawn, times.Sunrise, times.Sunset, times.Night)
	}
}

func TestPolarConditionsStillClassified(t *testing.T) {
	summer := time.Date(2026, 6, 21, 12, 0, 0, 0, time.UTC)
	if _, cond := CalculateSunTimesWithTwilight(78.22, 15.63, summer, -6.0, 3.0); cond != SunMidnightSun {
		t.Errorf("svalbard summer: cond=%d, want SunMidnightSun", cond)
	}

	winter := time.Date(2026, 12, 21, 12, 0, 0, 0, time.UTC)
	if _, cond := CalculateSunTimesWithTwilight(78.22, 15.63, winter, -6.0, 3.0); cond != SunPolarNight {
		t.Errorf("svalbard winter: cond=%d, want SunPolarNight", cond)
	}
}
