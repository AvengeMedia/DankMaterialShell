package thememode

import (
	"testing"
	"time"
)

func coord(v float64) *float64 { return &v }

func locationConfig(lat, lon float64) Config {
	return Config{
		Enabled:           true,
		Mode:              "location",
		Latitude:          coord(lat),
		Longitude:         coord(lon),
		ElevationTwilight: -6,
		ElevationDaylight: 3,
	}
}

// computeLocationSchedule works in the location's own calendar day, so the sun
// times it reads must too. When they came from the UTC day instead, a zone far
// enough from UTC±0 got a neighbouring day's sunrise and reported the wrong mode
// for the hours where the two calendars disagree (#3179).
func TestComputeLocationScheduleAcrossUTCOffsets(t *testing.T) {
	east := time.FixedZone("UTC+8", 8*60*60)
	west := time.FixedZone("UTC-7", -7*60*60)

	tests := []struct {
		name      string
		lat, lon  float64
		now       time.Time
		wantLight bool
	}{
		{
			// After local sunrise (~07:01) but before 08:00, where the UTC date
			// is still the previous day.
			name: "east_after_sunrise_before_utc_midnight",
			lat:  25.0399353, lon: 102.7169061,
			now:       time.Date(2026, 8, 26, 7, 30, 0, 0, east),
			wantLight: true,
		},
		{
			name: "east_before_sunrise",
			lat:  25.0399353, lon: 102.7169061,
			now:       time.Date(2026, 8, 26, 5, 0, 0, 0, east),
			wantLight: false,
		},
		{
			// Before local sunset (~19:12) but after 17:00, where the UTC date
			// has already rolled over to the next day.
			name: "west_before_sunset_after_utc_midnight",
			lat:  34.05, lon: -118.24,
			now:       time.Date(2026, 8, 26, 18, 0, 0, 0, west),
			wantLight: true,
		},
		{
			name: "west_after_sunset",
			lat:  34.05, lon: -118.24,
			now:       time.Date(2026, 8, 26, 21, 0, 0, 0, west),
			wantLight: false,
		},
		{
			// Apia: west longitude on a UTC+13 offset. With the reference day
			// taken from the civil date the schedule reported dark around the
			// clock, because every event landed on the following local day.
			name: "antimeridian_local_midday_is_light",
			lat:  -13.83, lon: -171.76,
			now:       time.Date(2026, 8, 26, 12, 0, 0, 0, time.FixedZone("UTC+13", 13*60*60)),
			wantLight: true,
		},
		{
			name: "antimeridian_local_night_is_dark",
			lat:  -13.83, lon: -171.76,
			now:       time.Date(2026, 8, 26, 2, 0, 0, 0, time.FixedZone("UTC+13", 13*60*60)),
			wantLight: false,
		},
		{
			name: "utc_midday",
			lat:  51.5074, lon: -0.1278,
			now:       time.Date(2026, 8, 26, 12, 0, 0, 0, time.UTC),
			wantLight: true,
		},
	}

	m := &Manager{}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isLight, next := m.computeLocationSchedule(tt.now, locationConfig(tt.lat, tt.lon))

			if isLight != tt.wantLight {
				t.Errorf("isLight = %v, want %v (now %s)", isLight, tt.wantLight, tt.now.Format(time.RFC3339))
			}
			// schedulerLoop clamps a non-positive wait to one second, so a
			// transition in the past busy-loops until the clock catches up.
			if !next.After(tt.now) {
				t.Errorf("nextTransition %s is not after now %s",
					next.Format(time.RFC3339), tt.now.Format(time.RFC3339))
			}
		})
	}
}

// The mode must not change on its own at UTC midnight, which is an arbitrary
// moment in the middle of a local day for most of the world.
func TestComputeLocationScheduleStableAcrossUTCMidnight(t *testing.T) {
	east := time.FixedZone("UTC+8", 8*60*60)
	config := locationConfig(25.0399353, 102.7169061)
	m := &Manager{}

	before := time.Date(2026, 8, 26, 7, 30, 0, 0, east)
	after := time.Date(2026, 8, 26, 8, 5, 0, 0, east)

	lightBefore, nextBefore := m.computeLocationSchedule(before, config)
	lightAfter, nextAfter := m.computeLocationSchedule(after, config)

	if lightBefore != lightAfter {
		t.Errorf("mode flipped at UTC midnight: isLight %v at %s, %v at %s",
			lightBefore, before.Format(time.RFC3339), lightAfter, after.Format(time.RFC3339))
	}
	if !nextBefore.Equal(nextAfter) {
		t.Errorf("nextTransition moved at UTC midnight: %s then %s",
			nextBefore.Format(time.RFC3339), nextAfter.Format(time.RFC3339))
	}
}
