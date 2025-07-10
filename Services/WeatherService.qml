pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: weatherService
    
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
                            weatherService.weather = {
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
                            console.log("Weather updated:", weatherService.weather.city, weatherService.weather.temp + "°C")
                        }
                    } catch (e) {
                        console.warn("Failed to parse weather data:", e.message)
                        weatherService.weather.available = false
                    }
                } else {
                    console.warn("No valid weather data received")
                    weatherService.weather.available = false
                }
            }
        }
        
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                console.warn("Weather fetch failed with exit code:", exitCode)
                weatherService.weather.available = false
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