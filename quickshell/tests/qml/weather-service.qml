import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DankCommon.Common as DC

ShellRoot {
    id: root

    property bool failed: false

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: {
            const icons = {};
            for (let code = 0; code < 100; code++)
                icons[code] = [WeatherService.getWeatherIcon(code, true), WeatherService.getWeatherIcon(code, false), WeatherService.getWeatherIcon(code)];
            console.log("PARITY " + JSON.stringify({
                label: "icons",
                icons: icons,
                dayKeys: Object.keys(WeatherService.weatherIcons),
                nightKeys: Object.keys(WeatherService.nightWeatherIcons)
            }));
            check(Object.values(icons).every(triple => triple.every(icon => typeof icon === "string" && icon.length > 0)), "every code yields an icon name");
            check(icons[4][0] === "cloud" && icons[99][0] === "thunderstorm" && icons[0][0] === "clear_day", "unmapped codes fall back to cloud, mapped codes resolve");
            check([0, 1, 2].every(code => icons[code][0] !== icons[code][1]) && icons[3][0] === icons[3][1], "only the clear and partly cloudy codes differ at night");
            check(Object.keys(WeatherService.nightWeatherIcons).length === Object.keys(WeatherService.weatherIcons).length, "night map covers the same codes as the day map");
            check(icons[2][2] === (WeatherService.weather.isDay ? icons[2][0] : icons[2][1]), "default argument follows weather.isDay");
            console.log("PARITY " + JSON.stringify({
                label: "initial",
                weather: WeatherService.weather
            }));
            WeatherService.weather = {
                available: true,
                loading: false,
                temp: 21,
                city: "Somewhere",
                forecast: [1, 2]
            };
            SettingsData.weatherCoordinatesChanged();
            console.log("PARITY " + JSON.stringify({
                label: "afterCoordinates",
                weather: WeatherService.weather,
                location: WeatherService.location
            }));
            check(WeatherService.weather.available === false && WeatherService.weather.loading === true && WeatherService.weather.city === "" && WeatherService.location === null, "coordinates change resets weather and location");
            WeatherService.weather = {
                available: true,
                loading: false,
                temp: 22,
                city: "Elsewhere",
                forecast: []
            };
            SettingsData.useAutoLocationChanged();
            console.log("PARITY " + JSON.stringify({
                label: "afterAutoLocation",
                weather: WeatherService.weather,
                location: WeatherService.location
            }));
            check(WeatherService.weather.available === false && WeatherService.weather.forecast.length === 0 && WeatherService.location === null, "auto location change resets weather and location");
            root.finish();
            Qt.quit();
        }
    }
}
