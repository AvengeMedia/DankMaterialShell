package wayland

import (
	"testing"
	"time"
)

func TestCalculateSunTimes(t *testing.T) {
	tests := []struct {
		name      string
		lat       float64
		lon       float64
		date      time.Time
		checkFunc func(*testing.T, SunTimes)
	}{
		{
			name: "new_york_summer",
			lat:  40.7128,
			lon:  -74.0060,
			date: time.Date(2024, 6, 21, 12, 0, 0, 0, time.Local),
			checkFunc: func(t *testing.T, times SunTimes) {
				if times.Sunrise.Hour() < 4 || times.Sunrise.Hour() > 6 {
					t.Logf("sunrise: %v", times.Sunrise)
				}
				if times.Sunset.Hour() < 19 || times.Sunset.Hour() > 21 {
					t.Logf("sunset: %v", times.Sunset)
				}
				if !times.Sunset.After(times.Sunrise) {
					t.Error("sunset should be after sunrise")
				}
			},
		},
		{
			name: "london_winter",
			lat:  51.5074,
			lon:  -0.1278,
			date: time.Date(2024, 12, 21, 12, 0, 0, 0, time.UTC),
			checkFunc: func(t *testing.T, times SunTimes) {
				if times.Sunrise.Hour() < 7 || times.Sunrise.Hour() > 9 {
					t.Errorf("unexpected sunrise hour: %d", times.Sunrise.Hour())
				}
				if times.Sunset.Hour() < 15 || times.Sunset.Hour() > 17 {
					t.Errorf("unexpected sunset hour: %d", times.Sunset.Hour())
				}
			},
		},
		{
			name: "equator_equinox",
			lat:  0.0,
			lon:  0.0,
			date: time.Date(2024, 3, 20, 12, 0, 0, 0, time.UTC),
			checkFunc: func(t *testing.T, times SunTimes) {
				if times.Sunrise.Hour() < 5 || times.Sunrise.Hour() > 7 {
					t.Errorf("unexpected sunrise hour: %d", times.Sunrise.Hour())
				}
				if times.Sunset.Hour() < 17 || times.Sunset.Hour() > 19 {
					t.Errorf("unexpected sunset hour: %d", times.Sunset.Hour())
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			times := CalculateSunTimes(tt.lat, tt.lon, tt.date)
			tt.checkFunc(t, times)
		})
	}
}

func TestSunTimesWithTwilight(t *testing.T) {
	lat := 40.7128
	lon := -74.0060
	date := time.Date(2024, 6, 21, 12, 0, 0, 0, time.Local)

	times, cond := CalculateSunTimesWithTwilight(lat, lon, date, -6.0, 3.0)

	if cond != SunNormal {
		t.Errorf("expected SunNormal, got %v", cond)
	}
	if !times.Dawn.Before(times.Sunrise) {
		t.Error("dawn should be before sunrise")
	}
	if !times.Sunrise.Before(times.Sunset) {
		t.Error("sunrise should be before sunset")
	}
	if !times.Sunset.Before(times.Night) {
		t.Error("sunset should be before night")
	}
}

func TestSunConditions(t *testing.T) {
	tests := []struct {
		name     string
		lat      float64
		date     time.Time
		expected SunCondition
	}{
		{
			name:     "normal_conditions",
			lat:      40.0,
			date:     time.Date(2024, 6, 21, 12, 0, 0, 0, time.UTC),
			expected: SunNormal,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, cond := CalculateSunTimesWithTwilight(tt.lat, 0, tt.date, -6.0, 3.0)
			if cond != tt.expected {
				t.Errorf("expected condition %v, got %v", tt.expected, cond)
			}
		})
	}
}
