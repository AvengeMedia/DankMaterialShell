package wayland

import (
	"testing"
	"time"
)

// The event seconds are local mean solar time and the longitude offset converts
// them to UTC, so the reference day has to be the caller's calendar day. Reading
// it off date.UTC() returned the neighbouring day's times for every hour where
// the local and UTC dates disagree (#3179).
func TestSunTimesUseLocalCalendarDay(t *testing.T) {
	tests := []struct {
		name string
		lat  float64
		lon  float64
		date time.Time
	}{
		{
			// Kunming: local morning is still the previous day in UTC.
			name: "east_of_utc_local_morning",
			lat:  25.0399353,
			lon:  102.7169061,
			date: time.Date(2026, 8, 26, 7, 30, 0, 0, time.FixedZone("UTC+8", 8*60*60)),
		},
		{
			// Los Angeles: local evening is already the next day in UTC.
			name: "west_of_utc_local_evening",
			lat:  34.05,
			lon:  -118.24,
			date: time.Date(2026, 8, 26, 18, 0, 0, 0, time.FixedZone("UTC-7", -7*60*60)),
		},
		{
			// Apia: west longitude, but UTC+13. The zone sits a whole day away
			// from its own mean solar time, so the local calendar day and the
			// local solar day are different days.
			name: "antimeridian_west_longitude_east_offset",
			lat:  -13.83,
			lon:  -171.76,
			date: time.Date(2026, 8, 26, 12, 0, 0, 0, time.FixedZone("UTC+13", 13*60*60)),
		},
		{
			// Kiritimati, the largest offset in use.
			name: "antimeridian_utc_plus_14",
			lat:  1.87,
			lon:  -157.43,
			date: time.Date(2026, 8, 26, 12, 0, 0, 0, time.FixedZone("UTC+14", 14*60*60)),
		},
		{
			// Chatham Islands, a three-quarter-hour offset on the same side.
			name: "antimeridian_quarter_hour_offset",
			lat:  -43.95,
			lon:  -176.55,
			date: time.Date(2026, 8, 26, 12, 0, 0, 0, time.FixedZone("UTC+12:45", 12*60*60+45*60)),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.date.UTC().Day() == tt.date.Day() {
				t.Fatalf("case proves nothing: local and UTC dates agree at %s", tt.date)
			}

			times, cond := CalculateSunTimesWithTwilight(tt.lat, tt.lon, tt.date, -6.0, 3.0)
			if cond != SunNormal {
				t.Fatalf("expected SunNormal, got %v", cond)
			}

			wantYear, wantMonth, wantDay := tt.date.Date()
			events := []struct {
				name string
				at   time.Time
			}{
				{"dawn", times.Dawn},
				{"sunrise", times.Sunrise},
				{"sunset", times.Sunset},
				{"night", times.Night},
			}
			for _, e := range events {
				year, month, day := e.at.Date()
				if year != wantYear || month != wantMonth || day != wantDay {
					t.Errorf("%s is %s, want it on the local day %04d-%02d-%02d",
						e.name, e.at.Format(time.RFC3339), wantYear, wantMonth, wantDay)
				}
			}
		})
	}
}

// Crossing UTC midnight is not an astronomical event, so the times for one local
// day must not change when it happens. Before the fix an eastern zone got
// yesterday's times until 08:00 local and jumped to today's on the hour.
func TestSunTimesStableAcrossUTCMidnight(t *testing.T) {
	const lat, lon = 25.0399353, 102.7169061
	east := time.FixedZone("UTC+8", 8*60*60)

	beforeUTCMidnight := time.Date(2026, 8, 26, 7, 30, 0, 0, east)
	afterUTCMidnight := time.Date(2026, 8, 26, 8, 5, 0, 0, east)

	before, cond := CalculateSunTimesWithTwilight(lat, lon, beforeUTCMidnight, -6.0, 3.0)
	if cond != SunNormal {
		t.Fatalf("expected SunNormal before UTC midnight, got %v", cond)
	}
	after, cond := CalculateSunTimesWithTwilight(lat, lon, afterUTCMidnight, -6.0, 3.0)
	if cond != SunNormal {
		t.Fatalf("expected SunNormal after UTC midnight, got %v", cond)
	}

	if !before.Sunrise.Equal(after.Sunrise) {
		t.Errorf("sunrise moved across UTC midnight: %s then %s",
			before.Sunrise.Format(time.RFC3339), after.Sunrise.Format(time.RFC3339))
	}
	if !before.Sunset.Equal(after.Sunset) {
		t.Errorf("sunset moved across UTC midnight: %s then %s",
			before.Sunset.Format(time.RFC3339), after.Sunset.Format(time.RFC3339))
	}
}

// A caller whose date is already in UTC must be unaffected by the change.
func TestSunTimesUnchangedForUTCCallers(t *testing.T) {
	const lat, lon = 51.5074, -0.1278
	date := time.Date(2024, 12, 21, 12, 0, 0, 0, time.UTC)

	times, cond := CalculateSunTimesWithTwilight(lat, lon, date, -6.0, 3.0)
	if cond != SunNormal {
		t.Fatalf("expected SunNormal, got %v", cond)
	}
	if got := times.Sunrise.UTC().Format("2006-01-02"); got != "2024-12-21" {
		t.Errorf("sunrise on %s, want 2024-12-21", got)
	}
	if got := times.Sunset.UTC().Format("2006-01-02"); got != "2024-12-21" {
		t.Errorf("sunset on %s, want 2024-12-21", got)
	}
}
