import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    
    property var weather: ({
        available: false,
        temp: 0,
        tempF: 0,
        city: "",
        wCode: "113", 
        humidity: 0,
        wind: "",
        sunrise: "06:00",
        sunset: "18:00",
        uv: 0,
        pressure: 0
    })
    
    // Weather icon mapping (based on wttr.in weather codes)
    property var weatherIcons: ({
        "113": "clear_day",
        "116": "partly_cloudy_day", 
        "119": "cloud",
        "122": "cloud",
        "143": "foggy",
        "176": "rainy",
        "179": "rainy",
        "182": "rainy",
        "185": "rainy",
        "200": "thunderstorm",
        "227": "cloudy_snowing",
        "230": "snowing_heavy",
        "248": "foggy",
        "260": "foggy",
        "263": "rainy",
        "266": "rainy",
        "281": "rainy",
        "284": "rainy",
        "293": "rainy",
        "296": "rainy",
        "299": "rainy",
        "302": "weather_hail",
        "305": "rainy",
        "308": "weather_hail",
        "311": "rainy",
        "314": "rainy",
        "317": "rainy",
        "320": "cloudy_snowing",
        "323": "cloudy_snowing",
        "326": "cloudy_snowing",
        "329": "snowing_heavy",
        "332": "snowing_heavy",
        "335": "snowing_heavy",
        "338": "snowing_heavy",
        "350": "rainy",
        "353": "rainy",
        "356": "weather_hail",
        "359": "weather_hail",
        "362": "rainy",
        "365": "weather_hail",
        "368": "cloudy_snowing",
        "371": "snowing_heavy",
        "374": "weather_hail",
        "377": "weather_hail",
        "386": "thunderstorm",
        "389": "thunderstorm",
        "392": "snowing_heavy",
        "395": "snowing_heavy"
    })
    
    function getWeatherIcon(code) {
        return weatherIcons[code] || "cloud"
    }
    
    Process {
        id: weatherFetcher
        command: ["bash", "-c", "curl -s 'wttr.in/?format=j1' | jq '{current: .current_condition[0], location: .nearest_area[0], astronomy: .weather[0].astronomy[0]}'"]
        running: false
        
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() && text.trim().startsWith("{")) {
                    try {
                        let parsedData = JSON.parse(text.trim())
                        if (parsedData.current && parsedData.location) {
                            root.weather = {
                                available: true,
                                temp: parseInt(parsedData.current.temp_C || 0),
                                tempF: parseInt(parsedData.current.temp_F || 0),
                                city: parsedData.location.areaName[0]?.value || "Unknown",
                                wCode: parsedData.current.weatherCode || "113", 
                                humidity: parseInt(parsedData.current.humidity || 0),
                                wind: (parsedData.current.windspeedKmph || 0) + " km/h",
                                sunrise: parsedData.astronomy?.sunrise || "06:00",
                                sunset: parsedData.astronomy?.sunset || "18:00",
                                uv: parseInt(parsedData.current.uvIndex || 0),
                                pressure: parseInt(parsedData.current.pressure || 0)
                            }
                            console.log("Weather updated:", root.weather.city, root.weather.temp + "°C")
                        }
                    } catch (e) {
                        console.warn("Failed to parse weather data:", e.message)
                        root.weather.available = false
                    }
                } else {
                    console.warn("No valid weather data received")
                    root.weather.available = false
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Weather fetch failed with exit code:", exitCode)
                root.weather.available = false
            }
        }
    }
    
    Timer {
        interval: 600000  // 10 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            weatherFetcher.running = true
        }
    }
}