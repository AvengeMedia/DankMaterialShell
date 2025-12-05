pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "../Common/suncalc.js" as SunCalc

Singleton {
    id: root

    property int refCount: 0

    property var selectedDate: new Date()
    property var weather: ({
            "available": false,
            "loading": true,
            "temp": 0,
            "tempF": 0,
            "feelsLike": 0,
            "feelsLikeF": 0,
            "city": "",
            "country": "",
            "wCode": 0,
            "humidity": 0,
            "wind": "",
            "sunrise": "06:00",
            "sunset": "18:00",
            "uv": 0,
            "pressure": 0,
            "precipitationProbability": 0,
            "isDay": true,
            "forecast": []
        })

    property var location: null
    property int updateInterval: 900000 // 15 minutes
    property int retryAttempts: 0
    property int maxRetryAttempts: 3
    property int retryDelay: 30000
    property int lastFetchTime: 0
    property int minFetchInterval: 30000
    property int persistentRetryCount: 0

    readonly property var lowPriorityCmd: ["nice", "-n", "19", "ionice", "-c3"]
    readonly property var curlBaseCmd: ["curl", "-sS", "--fail", "--connect-timeout", "3", "--max-time", "6", "--limit-rate", "100k", "--compressed"]

    property var weatherIcons: ({
            "0": "clear_day",
            "1": "clear_day",
            "2": "partly_cloudy_day",
            "3": "cloud",
            "45": "foggy",
            "48": "foggy",
            "51": "rainy",
            "53": "rainy",
            "55": "rainy",
            "56": "rainy",
            "57": "rainy",
            "61": "rainy",
            "63": "rainy",
            "65": "rainy",
            "66": "rainy",
            "67": "rainy",
            "71": "cloudy_snowing",
            "73": "cloudy_snowing",
            "75": "snowing_heavy",
            "77": "cloudy_snowing",
            "80": "rainy",
            "81": "rainy",
            "82": "rainy",
            "85": "cloudy_snowing",
            "86": "snowing_heavy",
            "95": "thunderstorm",
            "96": "thunderstorm",
            "99": "thunderstorm"
        })

    property var nightWeatherIcons: ({
            "0": "clear_night",
            "1": "clear_night",
            "2": "partly_cloudy_night",
            "3": "cloud",
            "45": "foggy",
            "48": "foggy",
            "51": "rainy",
            "53": "rainy",
            "55": "rainy",
            "56": "rainy",
            "57": "rainy",
            "61": "rainy",
            "63": "rainy",
            "65": "rainy",
            "66": "rainy",
            "67": "rainy",
            "71": "cloudy_snowing",
            "73": "cloudy_snowing",
            "75": "snowing_heavy",
            "77": "cloudy_snowing",
            "80": "rainy",
            "81": "rainy",
            "82": "rainy",
            "85": "cloudy_snowing",
            "86": "snowing_heavy",
            "95": "thunderstorm",
            "96": "thunderstorm",
            "99": "thunderstorm"
        })

    function getWeatherIcon(code, isDay) {
        if (typeof isDay === "undefined") {
            isDay = weather.isDay;
        }
        const iconMap = isDay ? weatherIcons : nightWeatherIcons;
        return iconMap[String(code)] || "cloud";
    }

    function getWeatherCondition(code) {
        const conditions = {
            "0": "Clear",
            "1": "Clear",
            "2": "Partly cloudy",
            "3": "Overcast",
            "45": "Fog",
            "48": "Fog",
            "51": "Drizzle",
            "53": "Drizzle",
            "55": "Drizzle",
            "56": "Freezing drizzle",
            "57": "Freezing drizzle",
            "61": "Light rain",
            "63": "Rain",
            "65": "Heavy rain",
            "66": "Light rain",
            "67": "Heavy rain",
            "71": "Light snow",
            "73": "Snow",
            "75": "Heavy snow",
            "77": "Snow",
            "80": "Light rain",
            "81": "Rain",
            "82": "Heavy rain",
            "85": "Light snow showers",
            "86": "Heavy snow showers",
            "95": "Thunderstorm",
            "96": "Thunderstorm with hail",
            "99": "Thunderstorm with hail"
        };
        return conditions[String(code)] || "Unknown";
    }

    property var moonWeatherIcons: ({
            "0": "",
            "1": "",
            "2": "",
            "3": "",
            "4": "",
            "5": "",
            "6": "",
            "7": "",
            "8": "",
            "9": "",
            "10": "",
            "11": "",
            "12": "",
            "13": "",
            "14": "",
            "15": "",
            "16": "",
            "17": "",
            "18": "",
            "19": "",
            "20": "",
            "21": "",
            "22": "",
            "23": "",
            "24": "",
            "25": "",
            "26": "",
            "27": ""
        })

    property var moonMaterialIcons: ({
            "0": "󰽤",
            "1": "󰽧",
            "2": "󰽡",
            "3": "󰽦",
            "4": "󰽢",
            "5": "󰽨",
            "6": "󰽣",
            "7": "󰽥"
        })

    function getMoonPhase(date) {
        const icons = moonWeatherIcons; // more icons in this set but thinner outline than material icons
        // const icons = moonMaterialIcons
        const iconCount = Object.keys(icons).length;
        const moon = SunCalc.getMoonIllumination(date);
        const index = ((Math.floor(moon.phase * iconCount + 0.5) % iconCount) + iconCount) % iconCount;

        return icons[index];
    }

    function getMoonAngle(date) {
        if (!location) {
            return;
        }
        const pos = SunCalc.getMoonPosition(date, location.latitude, location.longitude);
        return pos.parralacticAngle;
    }

    function getLocation() {
        return location;
    }

    function getSunDeclination(date) {
        return SunCalc.sunCoords(SunCalc.toDays(date)).dec * 180 / Math.PI;
    }

    function getSunTimes(date) {
        if (!location) {
            return null;
        }
        return SunCalc.getTimes(date, location.latitude, location.longitude, location.elevation);
    }

    function getEcliptic(date, points = 60) {
        if (!location) {
            return null;
        }
        const lat = location.latitude;
        const lon = location.longitude;
        const times = SunCalc.getTimes(date, lat, lon);
        const solarNoon = times.solarNoon;

        const eclipticPoints = [];

        const sunIsNorth = getSunDeclination(date) > lat;
        const transitAzimuth = sunIsNorth ? 0 : Math.PI;

        for (let i = 0; i <= points; i++) {
            const t = new Date(solarNoon.getTime() + (i / points) * 24 * 60 * 60 * 1000);
            const pos = SunCalc.getPosition(t, lat, lon);

            let h = (((pos.azimuth - transitAzimuth) / (2 * Math.PI)) + 1) % 1;
            h = Math.max(0, Math.min(1, h));
            let v = Math.sin(pos.altitude);
            v = Math.max(-1, Math.min(1, v));

            eclipticPoints.push({
                h,
                v
            });
        }

        const sortedEntries = eclipticPoints.sort((a, b) => a.h - b.h);
        return sortedEntries;
    }

    function getCurrentSunTime(date) {
        const times = getSunTimes(date);
        if (!times) {
            return;
        }
        const dateObj = new Date(date);

        const periods = [
            {
                name: I18n.tr("Dawn (Astronomical Twilight)"),
                start: new Date(times.nightEnd),
                end: new Date(times.nauticalDawn)
            },
            {
                name: I18n.tr("Dawn (Nautical Twilight)"),
                start: new Date(times.nauticalDawn),
                end: new Date(times.dawn)
            },
            {
                name: I18n.tr("Dawn (Civil Twilight)"),
                start: new Date(times.dawn),
                end: new Date(times.sunrise)
            },
            {
                name: I18n.tr("Sunrise"),
                start: new Date(times.sunrise),
                end: new Date(times.sunriseEnd)
            },
            {
                name: I18n.tr("Golden Hour"),
                start: new Date(times.sunriseEnd),
                end: new Date(times.goldenHourEnd)
            },
            {
                name: I18n.tr("Morning"),
                start: new Date(times.goldenHourEnd),
                end: new Date(times.solarNoon)
            },
            {
                name: I18n.tr("Afternoon"),
                start: new Date(times.solarNoon),
                end: new Date(times.goldenHour)
            },
            {
                name: I18n.tr("Golden Hour"),
                start: new Date(times.goldenHour),
                end: new Date(times.sunsetStart)
            },
            {
                name: I18n.tr("Sunset"),
                start: new Date(times.sunsetStart),
                end: new Date(times.sunset)
            },
            {
                name: I18n.tr("Dusk (Civil Twighlight)"),
                start: new Date(times.sunset),
                end: new Date(times.dusk)
            },
            {
                name: I18n.tr("Dusk (Nautical Twilight)"),
                start: new Date(times.dusk),
                end: new Date(times.nauticalDusk)
            },
            {
                name: I18n.tr("Dusk (Astronomical Twilight)"),
                start: new Date(times.nauticalDusk),
                end: new Date(times.night)
            },
        ];

        const sunrise = new Date(times.nightEnd);
        const sunset = new Date(times.night);
        const dayPercent = dateObj > sunrise && dateObj < sunset ? (dateObj - sunrise) / (sunset - sunrise) : 0;

        for (let i = 0; i < periods.length; i++) {
            const {
                name,
                start,
                end
            } = periods[i];
            if (dateObj >= start && dateObj < end) {
                const percent = (dateObj - start) / (end - start);
                return {
                    period: name,
                    periodIndex: i,
                    periodPercent: Math.min(Math.max(percent, 0), 1),
                    dayPercent: dayPercent
                };
            }
        }

        return {
            period: I18n.tr("Night"),
            periodIndex: 0,
            periodPercent: 0,
            dayPercent: dayPercent
        };
    }

    function getSkyArcPosition(date, isSun) {
        if (!location) {
            return null;
        }
        const lat = location.latitude;
        const lon = location.longitude;

        const pos = isSun ? SunCalc.getPosition(date, lat, lon) : SunCalc.getMoonPosition(date, lat, lon);

        const sunIsNorth = getSunDeclination(date) > lat;
        const transitAzimuth = sunIsNorth ? 0 : Math.PI;

        let h = (((pos.azimuth - transitAzimuth) / (2 * Math.PI)) + 1) % 1;
        h = Math.max(0, Math.min(1, h));
        // let v = pos.altitude / (Math.PI/2)
        let v = Math.sin(pos.altitude);
        v = Math.max(-1, Math.min(1, v));

        return {
            h,
            v
        };
    }

    function formatTemp(celcius, includeUnits = true, unitsShort = true) {
        if (celcius == null) {
            return null;
        }
        const value = SettingsData.useFahrenheit ? Math.round(celcius * (9 / 5) + 32) : celcius;
        const unit = unitsShort ? "°" : (SettingsData.useFahrenheit ? "°F" : "°C");
        return includeUnits ? value + unit : value;
    }

    function formatSpeed(kmh, includeUnits = true) {
        if (kmh == null) {
            return null;
        }
        const value = SettingsData.useFahrenheit ? Math.round(kmh * 0.621371) : kmh;
        const unit = SettingsData.useFahrenheit ? "mph" : "km/h";
        return includeUnits ? value + " " + unit : value;
    }

    function formatPressure(hpa, includeUnits = true) {
        if (hpa == null) {
            return null;
        }
        const value = SettingsData.useFahrenheit ? (hpa * 0.02953).toFixed(2) : hpa;
        const unit = SettingsData.useFahrenheit ? "inHg" : "hPa";
        return includeUnits ? value + " " + unit : value;
    }

    function formatPercent(percent, includeUnits = true) {
        if (percent == null) {
            return null;
        }
        const value = percent;
        const unit = "%";
        return includeUnits ? value + unit : value;
    }

    function formatVisibility(distance) {
        if (distance == null) {
            return null;
        }
        var value;
        var unit;
        if (SettingsData.useFahrenheit) {
            value = (distance / 1609.344).toFixed(1);
            unit = "mi";
            if (value < 1) {
                value = Math.round(value * 5280 / 50) * 50;
                unit = "ft";
            }
        } else {
            value = distance;
            unit = "m";
            if (value > 1000) {
                value = (value / 1000).toFixed(1);
                unit = "km";
            }
        }

        return value + " " + unit;
    }

    function formatTime(isoString) {
        if (!isoString)
            return "--";

        try {
            const date = new Date(isoString);
            const format = SettingsData.use24HourClock ? "HH:mm" : "h:mm AP";
            return date.toLocaleTimeString(Qt.locale(), format);
        } catch (e) {
            return "--";
        }
    }

    function calendarDayDifference(date1, date2) {
        const d1 = Date.UTC(date1.getFullYear(), date1.getMonth(), date1.getDate());
        const d2 = Date.UTC(date2.getFullYear(), date2.getMonth(), date2.getDate());
        return Math.floor((d2 - d1) / (1000 * 60 * 60 * 24));
    }

    function calendarHourDifference(date1, date2) {
        const d1 = Date.UTC(date1.getFullYear(), date1.getMonth(), date1.getDate(), date1.getHours());
        const d2 = Date.UTC(date2.getFullYear(), date2.getMonth(), date2.getDate(), date2.getHours());
        return Math.floor((d2 - d1) / (1000 * 60 * 60));
    }

    function formatForecastDay(isoString, index) {
        if (!isoString)
            return "--";

        if (index === 0)
            return I18n.tr("Today");
        if (index === 1)
            return I18n.tr("Tomorrow");

        const date = new Date();
        date.setDate(date.getDate() + index);
        const locale = Qt.locale();
        return locale.dayName(date.getDay(), Locale.ShortFormat);
    }

    function getWeatherApiUrl() {
        if (!location) {
            return null;
        }

        const params = ["latitude=" + location.latitude, "longitude=" + location.longitude, "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,surface_pressure,wind_speed_10m", "daily=sunrise,sunset,temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max", "hourly=temperature_2m,weather_code,precipitation_probability,wind_speed_10m,apparent_temperature,relative_humidity_2m,surface_pressure,visibility,cloud_cover", "timezone=auto", "forecast_days=7"];

        return "https://api.open-meteo.com/v1/forecast?" + params.join('&');
    }

    function getGeocodingUrl(query) {
        return "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=1&language=en&format=json";
    }

    function addRef() {
        refCount++;

        if (refCount === 1 && !weather.available && SettingsData.weatherEnabled) {
            fetchWeather();
        }
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
    }

    function updateLocation() {
        if (SettingsData.useAutoLocation) {
            getLocationFromIP();
        } else {
            const coords = SettingsData.weatherCoordinates;
            if (coords) {
                const parts = coords.split(",");
                if (parts.length === 2) {
                    const lat = parseFloat(parts[0]);
                    const lon = parseFloat(parts[1]);
                    if (!isNaN(lat) && !isNaN(lon)) {
                        getLocationFromCoords(lat, lon);
                        return;
                    }
                }
            }

            const cityName = SettingsData.weatherLocation;
            if (cityName) {
                getLocationFromCity(cityName);
            }
        }
    }

    function getLocationFromCoords(lat, lon) {
        const url = "https://nominatim.openstreetmap.org/reverse?lat=" + lat + "&lon=" + lon + "&format=json&addressdetails=1&accept-language=en";
        reverseGeocodeFetcher.command = lowPriorityCmd.concat(curlBaseCmd).concat(["-H", "User-Agent: DankMaterialShell Weather Widget", url]);
        reverseGeocodeFetcher.running = true;
    }

    function getLocationFromCity(city) {
        cityGeocodeFetcher.command = lowPriorityCmd.concat(curlBaseCmd).concat([getGeocodingUrl(city)]);
        cityGeocodeFetcher.running = true;
    }

    function getLocationFromIP() {
        ipLocationFetcher.running = true;
    }

    function fetchWeather() {
        if (root.refCount === 0 || !SettingsData.weatherEnabled) {
            return;
        }

        if (!location) {
            updateLocation();
            return;
        }

        if (weatherFetcher.running) {
            return;
        }

        const now = Date.now();
        if (now - root.lastFetchTime < root.minFetchInterval) {
            return;
        }

        const apiUrl = getWeatherApiUrl();
        if (!apiUrl) {
            return;
        }

        root.lastFetchTime = now;
        root.weather.loading = true;
        const weatherCmd = lowPriorityCmd.concat(["curl", "-sS", "--fail", "--connect-timeout", "3", "--max-time", "6", "--limit-rate", "150k", "--compressed"]);
        weatherFetcher.command = weatherCmd.concat([apiUrl]);
        weatherFetcher.running = true;
    }

    function forceRefresh() {
        root.lastFetchTime = 0; // Reset throttle
        fetchWeather();
    }

    function nextInterval() {
        const jitter = Math.floor(Math.random() * 15000) - 7500;
        return Math.max(60000, root.updateInterval + jitter);
    }

    function handleWeatherSuccess() {
        root.retryAttempts = 0;
        root.persistentRetryCount = 0;
        if (persistentRetryTimer.running) {
            persistentRetryTimer.stop();
        }
        if (updateTimer.interval !== root.updateInterval) {
            updateTimer.interval = root.updateInterval;
        }
    }

    function handleWeatherFailure() {
        root.retryAttempts++;
        if (root.retryAttempts < root.maxRetryAttempts) {
            retryTimer.start();
        } else {
            root.retryAttempts = 0;
            if (!root.weather.available) {
                root.weather.loading = false;
            }
            const backoffDelay = Math.min(60000 * Math.pow(2, persistentRetryCount), 300000);
            persistentRetryCount++;
            persistentRetryTimer.interval = backoffDelay;
            persistentRetryTimer.start();
        }
    }

    Process {
        id: ipLocationFetcher
        command: lowPriorityCmd.concat(curlBaseCmd).concat(["http://ip-api.com/json/"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw || raw[0] !== "{") {
                    root.handleWeatherFailure();
                    return;
                }

                try {
                    const data = JSON.parse(raw);

                    if (data.status === "fail") {
                        throw new Error("IP location lookup failed");
                    }

                    const lat = parseFloat(data.lat);
                    const lon = parseFloat(data.lon);
                    const city = data.city;

                    if (!city || isNaN(lat) || isNaN(lon)) {
                        throw new Error("Missing or invalid location data");
                    }

                    root.location = {
                        city: city,
                        latitude: lat,
                        longitude: lon
                    };
                    fetchWeather();
                } catch (e) {
                    root.handleWeatherFailure();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.handleWeatherFailure();
            }
        }
    }

    Process {
        id: reverseGeocodeFetcher
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw || raw[0] !== "{") {
                    root.handleWeatherFailure();
                    return;
                }

                try {
                    const data = JSON.parse(raw);
                    const address = data.address || {};

                    root.location = {
                        city: address.hamlet || address.city || address.town || address.village || "Unknown",
                        country: address.country || "Unknown",
                        latitude: parseFloat(data.lat),
                        longitude: parseFloat(data.lon)
                    };

                    fetchWeather();
                } catch (e) {
                    root.handleWeatherFailure();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.handleWeatherFailure();
            }
        }
    }

    Process {
        id: cityGeocodeFetcher
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw || raw[0] !== "{") {
                    root.handleWeatherFailure();
                    return;
                }

                try {
                    const data = JSON.parse(raw);
                    const results = data.results;

                    if (!results || results.length === 0) {
                        throw new Error("No results found");
                    }

                    const result = results[0];

                    root.location = {
                        city: result.name,
                        country: result.country,
                        latitude: result.latitude,
                        longitude: result.longitude,
                        elevation: data.elevation
                    };

                    fetchWeather();
                } catch (e) {
                    root.handleWeatherFailure();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.handleWeatherFailure();
            }
        }
    }

    Process {
        id: weatherFetcher
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (!raw || raw[0] !== "{") {
                    root.handleWeatherFailure();
                    return;
                }

                try {
                    const data = JSON.parse(raw);

                    if (!data.current || !data.daily || !data.hourly) {
                        throw new Error("Required weather data fields missing");
                    }

                    const hourly = data.hourly;
                    const hourly_forecast = [];
                    if (hourly.time && hourly.time.length > 0) {
                        for (let i = 0; i < hourly.time.length; i++) {
                            const tempMinC = hourly.temperature_2m_min?.[i] || 0;
                            const tempMaxC = hourly.temperature_2m_max?.[i] || 0;
                            const tempMinF = tempMinC * 9 / 5 + 32;
                            const tempMaxF = tempMaxC * 9 / 5 + 32;

                            const tempC = hourly.temperature_2m?.[i] || 0;
                            const tempF = tempC * 9 / 5 + 32;
                            const feelsLikeC = hourly.apparent_temperature?.[i] || tempC;
                            const feelsLikeF = feelsLikeC * 9 / 5 + 32;

                            const sunrise = new Date(data.daily.sunrise?.[Math.floor(i / 24)]);
                            const sunset = new Date(data.daily.sunset?.[Math.floor(i / 24)]);
                            const time = new Date(hourly.time[i]);
                            const isDay = sunrise < time && time < sunset;

                            hourly_forecast.push({
                                "time": formatTime(hourly.time[i]),
                                "temp": Math.round(tempC),
                                "tempF": Math.round(tempF),
                                "feelsLike": Math.round(feelsLikeC),
                                "feelsLikeF": Math.round(feelsLikeF),
                                "wCode": hourly.weather_code?.[i] || 0,
                                "humidity": Math.round(hourly.relative_humidity_2m?.[i] || 0),
                                "wind": Math.round(hourly.wind_speed_10m?.[i] || 0),
                                "pressure": Math.round(hourly.surface_pressure?.[i] || 0),
                                "precipitationProbability": Math.round(hourly.precipitation_probability_max?.[0] || 0),
                                "visibility": Math.round(hourly.visibility?.[i] || 0),
                                "isDay": isDay
                            });
                        }
                    }

                    const daily = data.daily;
                    const forecast = [];
                    if (daily.time && daily.time.length > 0) {
                        for (let i = 0; i < daily.time.length; i++) {
                            const tempMinC = daily.temperature_2m_min?.[i] || 0;
                            const tempMaxC = daily.temperature_2m_max?.[i] || 0;
                            const tempMinF = (tempMinC * 9 / 5 + 32);
                            const tempMaxF = (tempMaxC * 9 / 5 + 32);

                            forecast.push({
                                "day": formatForecastDay(daily.time[i], i),
                                "wCode": daily.weather_code?.[i] || 0,
                                "tempMin": Math.round(tempMinC),
                                "tempMax": Math.round(tempMaxC),
                                "tempMinF": Math.round(tempMinF),
                                "tempMaxF": Math.round(tempMaxF),
                                "precipitationProbability": Math.round(daily.precipitation_probability_max?.[i] || 0),
                                "sunrise": daily.sunrise?.[i] ? formatTime(daily.sunrise[i]) : "",
                                "sunset": daily.sunset?.[i] ? formatTime(daily.sunset[i]) : ""
                            });
                        }
                    }

                    const current = data.current;
                    const currentUnits = data.current_units || {};

                    const tempC = current.temperature_2m || 0;
                    const tempF = tempC * 9 / 5 + 32;
                    const feelsLikeC = current.apparent_temperature || tempC;
                    const feelsLikeF = feelsLikeC * 9 / 5 + 32;

                    root.weather = {
                        "available": true,
                        "loading": false,
                        "temp": Math.round(tempC),
                        "tempF": Math.round(tempF),
                        "feelsLike": Math.round(feelsLikeC),
                        "feelsLikeF": Math.round(feelsLikeF),
                        "city": root.location?.city || "Unknown",
                        "country": root.location?.country || "Unknown",
                        "wCode": current.weather_code || 0,
                        "humidity": Math.round(current.relative_humidity_2m || 0),
                        "wind": Math.round(current.wind_speed_10m || 0) + " " + (currentUnits.wind_speed_10m || 'm/s'),
                        "sunrise": formatTime(daily.sunrise?.[0]) || "06:00",
                        "sunset": formatTime(daily.sunset?.[0]) || "18:00",
                        "uv": 0,
                        "pressure": Math.round(current.surface_pressure || 0),
                        "precipitationProbability": Math.round(daily.precipitation_probability_max?.[0] || 0),
                        "isDay": Boolean(current.is_day),
                        "forecast": forecast,
                        "hourlyForecast": hourly_forecast
                    };
                    root.handleWeatherSuccess();
                } catch (e) {
                    root.handleWeatherFailure();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.handleWeatherFailure();
            }
        }
    }

    Timer {
        id: updateTimer
        interval: nextInterval()
        running: root.refCount > 0 && SettingsData.weatherEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.fetchWeather();
            interval = nextInterval();
        }
    }

    Timer {
        id: retryTimer
        interval: root.retryDelay
        running: false
        repeat: false
        onTriggered: {
            root.fetchWeather();
        }
    }

    Timer {
        id: persistentRetryTimer
        interval: 60000
        running: false
        repeat: false
        onTriggered: {
            if (!root.weather.available) {
                root.weather.loading = true;
            }
            root.fetchWeather();
        }
    }

    Component.onCompleted: {
        SettingsData.weatherCoordinatesChanged.connect(() => {
            root.location = null;
            root.weather = {
                "available": false,
                "loading": true,
                "temp": 0,
                "tempF": 0,
                "feelsLike": 0,
                "feelsLikeF": 0,
                "city": "",
                "country": "",
                "wCode": 0,
                "humidity": 0,
                "wind": "",
                "sunrise": "06:00",
                "sunset": "18:00",
                "uv": 0,
                "pressure": 0,
                "precipitationProbability": 0,
                "isDay": true,
                "forecast": []
            };
            root.lastFetchTime = 0;
            root.forceRefresh();
        });

        SettingsData.weatherLocationChanged.connect(() => {
            root.location = null;
            root.lastFetchTime = 0;
            root.forceRefresh();
        });

        SettingsData.useAutoLocationChanged.connect(() => {
            root.location = null;
            root.weather = {
                "available": false,
                "loading": true,
                "temp": 0,
                "tempF": 0,
                "feelsLike": 0,
                "feelsLikeF": 0,
                "city": "",
                "country": "",
                "wCode": 0,
                "humidity": 0,
                "wind": "",
                "sunrise": "06:00",
                "sunset": "18:00",
                "uv": 0,
                "pressure": 0,
                "precipitationProbability": 0,
                "isDay": true,
                "forecast": []
            };
            root.lastFetchTime = 0;
            root.forceRefresh();
        });

        SettingsData.weatherEnabledChanged.connect(() => {
            if (SettingsData.weatherEnabled && root.refCount > 0 && !root.weather.available) {
                root.forceRefresh();
            } else if (!SettingsData.weatherEnabled) {
                updateTimer.stop();
                retryTimer.stop();
                persistentRetryTimer.stop();
                if (weatherFetcher.running) {
                    weatherFetcher.running = false;
                }
            }
        });
    }
}
