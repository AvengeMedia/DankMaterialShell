package wayland

import (
	"math"
	"time"
)

const (
	degToRad = math.Pi / 180.0
	radToDeg = 180.0 / math.Pi
)

type SunCondition int

const (
	SunNormal SunCondition = iota
	SunMidnightSun
	SunPolarNight
)

type SunTimes struct {
	Dawn    time.Time
	Sunrise time.Time
	Sunset  time.Time
	Night   time.Time
}

func daysInYear(year int) int {
	if (year%4 == 0 && year%100 != 0) || year%400 == 0 {
		return 366
	}
	return 365
}

func dateOrbitAngle(t time.Time) float64 {
	return 2 * math.Pi / float64(daysInYear(t.Year())) * float64(t.YearDay()-1)
}

func equationOfTime(orbitAngle float64) float64 {
	return 4 * (0.000075 +
		0.001868*math.Cos(orbitAngle) -
		0.032077*math.Sin(orbitAngle) -
		0.014615*math.Cos(2*orbitAngle) -
		0.040849*math.Sin(2*orbitAngle))
}

func sunDeclination(orbitAngle float64) float64 {
	return 0.006918 -
		0.399912*math.Cos(orbitAngle) +
		0.070257*math.Sin(orbitAngle) -
		0.006758*math.Cos(2*orbitAngle) +
		0.000907*math.Sin(2*orbitAngle) -
		0.002697*math.Cos(3*orbitAngle) +
		0.00148*math.Sin(3*orbitAngle)
}

type thresholdState int

const (
	thresholdCrosses thresholdState = iota
	thresholdAlwaysAbove
	thresholdAlwaysBelow
)

func sunHourAngle(latRad, declination, targetSunRad float64) (float64, thresholdState) {
	cosH := math.Cos(targetSunRad)/
		(math.Cos(latRad)*math.Cos(declination)) -
		math.Tan(latRad)*math.Tan(declination)
	switch {
	case cosH < -1:
		return math.Pi, thresholdAlwaysAbove
	case cosH > 1:
		return 0, thresholdAlwaysBelow
	default:
		return math.Acos(cosH), thresholdCrosses
	}
}

func hourAngleToSeconds(hourAngle, eqtime float64) float64 {
	return radToDeg * (4.0*math.Pi - 4*hourAngle - eqtime) * 60
}

func CalculateSunTimesWithTwilight(lat, lon float64, date time.Time, elevTwilight, elevDaylight float64) (SunTimes, SunCondition) {
	latRad := lat * degToRad
	elevTwilightRad := (90.833 - elevTwilight) * degToRad
	elevDaylightRad := (90.833 - elevDaylight) * degToRad

	utc := date.UTC()
	orbitAngle := dateOrbitAngle(utc)
	decl := sunDeclination(orbitAngle)
	eqtime := equationOfTime(orbitAngle)

	haTwilight, twilightState := sunHourAngle(latRad, decl, elevTwilightRad)
	haDaylight, daylightState := sunHourAngle(latRad, decl, elevDaylightRad)

	if daylightState == thresholdAlwaysAbove {
		return SunTimes{}, SunMidnightSun
	}
	if twilightState == thresholdAlwaysBelow {
		return SunTimes{}, SunPolarNight
	}

	dayStart := time.Date(utc.Year(), utc.Month(), utc.Day(), 0, 0, 0, 0, time.UTC)
	lonOffset := time.Duration(-lon*4) * time.Minute

	dawnSecs := hourAngleToSeconds(math.Abs(haTwilight), eqtime)
	sunriseSecs := hourAngleToSeconds(math.Abs(haDaylight), eqtime)
	sunsetSecs := hourAngleToSeconds(-math.Abs(haDaylight), eqtime)
	nightSecs := hourAngleToSeconds(-math.Abs(haTwilight), eqtime)

	return SunTimes{
		Dawn:    dayStart.Add(time.Duration(dawnSecs)*time.Second + lonOffset).In(date.Location()),
		Sunrise: dayStart.Add(time.Duration(sunriseSecs)*time.Second + lonOffset).In(date.Location()),
		Sunset:  dayStart.Add(time.Duration(sunsetSecs)*time.Second + lonOffset).In(date.Location()),
		Night:   dayStart.Add(time.Duration(nightSecs)*time.Second + lonOffset).In(date.Location()),
	}, SunNormal
}

func CalculateSunTimes(lat, lon float64, date time.Time) SunTimes {
	times, cond := CalculateSunTimesWithTwilight(lat, lon, date, -6.0, 3.0)
	switch cond {
	case SunMidnightSun:
		dayStart := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
		dayEnd := dayStart.Add(24*time.Hour - time.Second)
		return SunTimes{Dawn: dayStart, Sunrise: dayStart, Sunset: dayEnd, Night: dayEnd}
	case SunPolarNight:
		dayStart := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
		return SunTimes{Dawn: dayStart, Sunrise: dayStart, Sunset: dayStart, Night: dayStart}
	}
	return times
}
