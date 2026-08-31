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

	lonOffset := time.Duration(-lon*4) * time.Minute

	// The event seconds below are local mean solar time and lonOffset converts
	// them to UTC, so the reference day has to be the *solar* day the caller's
	// civil day falls in. Reading it off date.UTC() returned the neighbouring
	// day's times whenever the local and UTC dates disagree, which is most of
	// the day for large offsets (#3179).
	//
	// For nearly every zone the solar day and the civil day are the same date,
	// but a zone can be shifted a full day away from its own meridian: Apia,
	// Kiritimati, Tongatapu and the Chathams all sit on west longitudes while
	// keeping a UTC+12:45..+14 offset. Taking the civil date directly puts
	// every event there a day late, and the caller then sees no daylight at
	// all. Anchoring on the caller's local noon and converting that to mean
	// solar time picks the right day in both cases.
	//
	// dayStart stays at UTC midnight so the lonOffset arithmetic is unchanged.
	year, month, day := date.Date()
	localNoon := time.Date(year, month, day, 12, 0, 0, 0, date.Location())
	refYear, refMonth, refDay := localNoon.UTC().Add(-lonOffset).Date()
	dayStart := time.Date(refYear, refMonth, refDay, 0, 0, 0, 0, time.UTC)

	// Declination and the equation of time belong to the same reference day.
	orbitAngle := dateOrbitAngle(dayStart)
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
