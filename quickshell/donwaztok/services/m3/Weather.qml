pragma Singleton

import qs.config
import qs.services.m3
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    property string city
    property string loc
    property var cc
    property list<var> forecast
    property list<var> hourlyForecast

    readonly property string icon: cc ? Icons.getWeatherIcon(cc.weatherCode) : "cloud_alert"
    readonly property string description: cc?.weatherDesc ?? qsTr("No weather")
    readonly property string temp: Config.services.useFahrenheit ? `${cc?.tempF ?? 0}°F` : `${cc?.tempC ?? 0}°C`
    readonly property string feelsLike: Config.services.useFahrenheit ? `${cc?.feelsLikeF ?? 0}°F` : `${cc?.feelsLikeC ?? 0}°C`
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), Config.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), Config.services.useTwelveHourClock ? "h:mm A" : "h:mm") : "--:--"

    readonly property var cachedCities: new Map()

    function reload(): void {
        const configLocation = Config.services.weatherLocation;

        if (configLocation) {
            if (configLocation.indexOf(",") !== -1 && !isNaN(parseFloat(configLocation.split(",")[0]))) {
                loc = configLocation;
                fetchCityFromCoords(configLocation);
            } else {
                fetchCoordsFromCity(configLocation);
            }
        } else if (!loc || timer.elapsed() > 900) {
            Requests.get("https://ipinfo.io/json", text => {
                try {
                    const response = JSON.parse(text);
                    if (response.loc) {
                        loc = response.loc;
                        city = response.city ?? "";
                        timer.restart();
                    }
                } catch (e) {
                    console.warn("[Weather] ipinfo parse failed:", e);
                }
            });
        }
    }

    function coordFallbackLabel(lat: string, lon: string): string {
        const la = parseFloat(lat);
        const lo = parseFloat(lon);
        if (isNaN(la) || isNaN(lo))
            return "";
        return `${la.toFixed(3)}, ${lo.toFixed(3)}`;
    }

    function fetchCityFromCoords(coords: string): void {
        if (cachedCities.has(coords)) {
            city = cachedCities.get(coords);
            return;
        }

        const [lat, lon] = coords.split(",").map(s => s.trim());
        if (!lat || !lon || isNaN(parseFloat(lat)) || isNaN(parseFloat(lon))) {
            city = coordFallbackLabel(lat, lon) || qsTr("Invalid coordinates");
            return;
        }

        function setCityOrCoords(name: string): void {
            const label = (name && String(name).trim()) ? String(name).trim() : coordFallbackLabel(lat, lon);
            city = label;
            if (name && String(name).trim())
                cachedCities.set(coords, city);
        }

        const fallbackToBigDataCloud = () => {
            const fallbackUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${encodeURIComponent(lat)}&longitude=${encodeURIComponent(lon)}&localityLanguage=en`;
            Requests.get(fallbackUrl, text => {
                try {
                    const geo = JSON.parse(text);
                    const geoCity = geo.city || geo.locality || geo.principalSubdivision;
                    if (geoCity) {
                        city = geoCity;
                        cachedCities.set(coords, geoCity);
                    } else {
                        setCityOrCoords("");
                    }
                } catch (e) {
                    console.warn("[Weather] BigDataCloud reverse-geocode parse failed:", e);
                    setCityOrCoords("");
                }
            }, () => setCityOrCoords(""));
        };

        // jsonv2 is stable and matches common OSM address fields (geocodejson was often empty / wrong shape)
        const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&format=jsonv2`;
        Requests.get(nominatimUrl, text => {
            try {
                const j = JSON.parse(text);
                const a = j.address || {};
                const geoCity = a.city || a.town || a.village || a.municipality || a.hamlet || a.county || a.state_district || a.state;
                if (geoCity) {
                    city = geoCity;
                    cachedCities.set(coords, geoCity);
                    return;
                }
                if (j.display_name) {
                    const first = String(j.display_name).split(",").map(s => s.trim())[0];
                    if (first) {
                        city = first;
                        cachedCities.set(coords, city);
                        return;
                    }
                }
            } catch (e) {
                console.warn("[Weather] Nominatim parse failed:", e);
            }
            fallbackToBigDataCloud();
        }, fallbackToBigDataCloud);
    }

    function fetchCoordsFromCity(cityName: string): void {
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(cityName)}&count=1&language=en&format=json`;

        Requests.get(url, text => {
            try {
                const json = JSON.parse(text);
                if (json.results && json.results.length > 0) {
                    const result = json.results[0];
                    loc = result.latitude + "," + result.longitude;
                    city = result.name;
                } else {
                    loc = "";
                    reload();
                }
            } catch (e) {
                console.warn("[Weather] Geocoding search parse failed:", e);
                loc = "";
                reload();
            }
        });
    }

    function fetchWeatherData(): void {
        const url = getWeatherUrl();
        if (url === "")
            return;

        Requests.get(url, text => {
            let json;
            try {
                json = JSON.parse(text);
            } catch (e) {
                console.warn("[Weather] Forecast parse failed:", e);
                return;
            }
            if (!json.current || !json.daily)
                return;

            cc = {
                weatherCode: json.current.weather_code,
                weatherDesc: getWeatherCondition(json.current.weather_code),
                tempC: Math.round(json.current.temperature_2m),
                tempF: Math.round(toFahrenheit(json.current.temperature_2m)),
                feelsLikeC: Math.round(json.current.apparent_temperature),
                feelsLikeF: Math.round(toFahrenheit(json.current.apparent_temperature)),
                humidity: json.current.relative_humidity_2m,
                windSpeed: json.current.wind_speed_10m,
                isDay: json.current.is_day,
                sunrise: json.daily.sunrise[0],
                sunset: json.daily.sunset[0]
            };

            const forecastList = [];
            for (let i = 0; i < json.daily.time.length; i++)
                forecastList.push({
                    date: json.daily.time[i],
                    maxTempC: Math.round(json.daily.temperature_2m_max[i]),
                    maxTempF: Math.round(toFahrenheit(json.daily.temperature_2m_max[i])),
                    minTempC: Math.round(json.daily.temperature_2m_min[i]),
                    minTempF: Math.round(toFahrenheit(json.daily.temperature_2m_min[i])),
                    weatherCode: json.daily.weather_code[i],
                    icon: Icons.getWeatherIcon(json.daily.weather_code[i])
                });
            forecast = forecastList;

            const hourlyList = [];
            const now = new Date();
            for (let i = 0; i < json.hourly.time.length; i++) {
                const time = new Date(json.hourly.time[i]);
                if (time < now)
                    continue;

                hourlyList.push({
                    timestamp: json.hourly.time[i],
                    hour: time.getHours(),
                    tempC: Math.round(json.hourly.temperature_2m[i]),
                    tempF: Math.round(toFahrenheit(json.hourly.temperature_2m[i])),
                    weatherCode: json.hourly.weather_code[i],
                    icon: Icons.getWeatherIcon(json.hourly.weather_code[i])
                });
            }
            hourlyForecast = hourlyList;
        });
    }

    function toFahrenheit(celcius: real): real {
        return celcius * 9 / 5 + 32;
    }

    function getWeatherUrl(): string {
        if (!loc || loc.indexOf(",") === -1)
            return "";

        const [lat, lon] = loc.split(",").map(s => s.trim());
        const baseUrl = "https://api.open-meteo.com/v1/forecast";
        const params = ["latitude=" + lat, "longitude=" + lon, "hourly=weather_code,temperature_2m", "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset", "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m", "timezone=auto", "forecast_days=7"];

        return baseUrl + "?" + params.join("&");
    }

    function getWeatherCondition(code: string): string {
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
        return conditions[code] || "Unknown";
    }

    onLocChanged: fetchWeatherData()

    Connections {
        target: Config.services
        function onWeatherLocationChanged(): void {
            root.reload();
        }
    }

    // Refresh current location hourly
    Timer {
        interval: 3600000 // 1 hour
        running: true
        repeat: true
        onTriggered: fetchWeatherData()
    }

    ElapsedTimer {
        id: timer
    }
}
