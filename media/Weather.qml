import QtQuick
import Quickshell
import Quickshell.Io

// Weather.qml: uses Open-Meteo (free, no API key). The place comes from a city
// name (geocoding) or, when empty, from an IP geolocation lookup. The result is
// cached in ~/.config/quickshell/media/weather.json and refreshed every 30 minutes.
Scope {
    id: wx

    property bool active: false
    property bool enabled: true
    property string city: ""
    property string units: "c"          // "c" | "f"

    property bool ready: false
    property string status: ""
    property string place: ""
    property real temp: 0
    property real feels: 0
    property int code: 0
    property string kind: "clear"       // clear, clouds, fog, rain, snow, storm
    property string desc: ""
    property bool isDay: true
    property real sunrise: 6
    property real sunset: 18
    property real hi: 0
    property real lo: 0
    property real wind: 0
    property int humidity: 0
    property var days: []               // next three days: { label, hi, lo, kind, desc }
    property double fetched: 0

    property real lat: 0
    property real lon: 0
    property bool haveCoords: false
    property string coordKey: ""

    readonly property string unitSym: units === "f" ? "\u00B0F" : "\u00B0C"
    readonly property bool busy: geoProc.running || fcProc.running
    readonly property string cachePath: Quickshell.env("HOME") + "/.config/quickshell/media/weather.json"

    function describe(c) {
        if (c === 0) return { kind: "clear", desc: "Clear" };
        if (c === 1) return { kind: "clear", desc: "Mostly clear" };
        if (c === 2) return { kind: "clouds", desc: "Partly cloudy" };
        if (c === 3) return { kind: "clouds", desc: "Overcast" };
        if (c === 45 || c === 48) return { kind: "fog", desc: "Fog" };
        if (c >= 51 && c <= 55) return { kind: "rain", desc: "Drizzle" };
        if (c === 56 || c === 57) return { kind: "rain", desc: "Freezing drizzle" };
        if (c === 61) return { kind: "rain", desc: "Light rain" };
        if (c === 63) return { kind: "rain", desc: "Rain" };
        if (c === 65) return { kind: "rain", desc: "Heavy rain" };
        if (c === 66 || c === 67) return { kind: "rain", desc: "Freezing rain" };
        if (c === 71) return { kind: "snow", desc: "Light snow" };
        if (c === 73) return { kind: "snow", desc: "Snow" };
        if (c === 75) return { kind: "snow", desc: "Heavy snow" };
        if (c === 77) return { kind: "snow", desc: "Snow grains" };
        if (c >= 80 && c <= 82) return { kind: "rain", desc: "Showers" };
        if (c === 85 || c === 86) return { kind: "snow", desc: "Snow showers" };
        if (c === 95) return { kind: "storm", desc: "Thunderstorm" };
        if (c === 96 || c === 99) return { kind: "storm", desc: "Thunderstorm, hail" };
        return { kind: "clouds", desc: "Unknown" };
    }

    function hourOf(iso) {
        var t = String(iso).split("T")[1];
        if (!t)
            return 0;
        var p = t.split(":");
        return Number(p[0]) + Number(p[1]) / 60;
    }

    function enc(s) { return encodeURIComponent(s); }
    function key() { return city.trim().toLowerCase() + "|" + units; }

    // ───────── flow: coordinates, then forecast ─────────
    function refresh(force) {
        if (!enabled || busy)
            return;
        var k = city.trim().toLowerCase();
        if (!force && ready && coordKey === k && units === _appliedUnits && Date.now() - fetched < 30 * 60000)
            return;
        if (haveCoords && coordKey === k)
            forecast();
        else
            locate();
    }

    property string _appliedUnits: "c"

    function locate() {
        status = "Locating...";
        var c = city.trim();
        if (c !== "")
            geoProc.command = ["curl", "-s", "-m", "15", "https://geocoding-api.open-meteo.com/v1/search?name=" + enc(c) + "&count=1&language=en&format=json"];
        else
            geoProc.command = ["curl", "-s", "-m", "15", "https://ipwho.is/"];
        geoProc.running = true;
    }

    function geoDone(txt) {
        try {
            var r = JSON.parse(txt);
            if (city.trim() !== "") {
                if (!r.results || r.results.length === 0) {
                    status = "City not found";
                    return;
                }
                lat = r.results[0].latitude;
                lon = r.results[0].longitude;
                place = r.results[0].name;
            } else {
                if (r.success === false || r.latitude === undefined) {
                    status = "Could not guess the location";
                    return;
                }
                lat = r.latitude;
                lon = r.longitude;
                place = r.city || "";
            }
            haveCoords = true;
            coordKey = city.trim().toLowerCase();
            forecast();
        } catch (e) {
            status = "Location lookup failed";
        }
    }

    function forecast() {
        status = "Loading weather...";
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=auto&forecast_days=4"
            + (units === "f" ? "&temperature_unit=fahrenheit" : "");
        fcProc.command = ["curl", "-s", "-m", "20", url];
        fcProc.running = true;
    }

    function apply(d) {
        var cur = d.current;
        var dly = d.daily;
        code = cur.weather_code;
        var info = describe(code);
        kind = info.kind;
        desc = info.desc;
        temp = cur.temperature_2m;
        feels = cur.apparent_temperature;
        humidity = Math.round(cur.relative_humidity_2m);
        wind = cur.wind_speed_10m;
        isDay = cur.is_day === 1;
        sunrise = hourOf(dly.sunrise[0]);
        sunset = hourOf(dly.sunset[0]);
        hi = dly.temperature_2m_max[0];
        lo = dly.temperature_2m_min[0];
        var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var out = [];
        for (var i = 1; i < dly.time.length && i <= 3; i++) {
            var inf = describe(dly.weather_code[i]);
            out.push({ label: names[new Date(dly.time[i] + "T12:00:00").getDay()], hi: dly.temperature_2m_max[i],
                       lo: dly.temperature_2m_min[i], kind: inf.kind, desc: inf.desc });
        }
        days = out;
        ready = true;
        status = "";
    }

    function fcDone(txt) {
        try {
            var d = JSON.parse(txt);
            if (!d.current)
                throw new Error("no data");
            apply(d);
            fetched = Date.now();
            _appliedUnits = units;
            cacheFile.setText(JSON.stringify({ time: fetched, key: coordKey, units: units, lat: lat, lon: lon, place: place, data: d }));
        } catch (e) {
            status = ready ? "" : "Weather unavailable";
        }
    }

    Process {
        id: geoProc
        stdout: StdioCollector {
            onStreamFinished: wx.geoDone(text)
        }
    }
    Process {
        id: fcProc
        stdout: StdioCollector {
            onStreamFinished: wx.fcDone(text)
        }
    }

    FileView {
        id: cacheFile
        path: wx.cachePath
        onLoaded: {
            try {
                var s = JSON.parse(cacheFile.text());
                if (s.key === wx.city.trim().toLowerCase() && s.units === wx.units && s.data) {
                    wx.lat = s.lat;
                    wx.lon = s.lon;
                    wx.place = s.place || "";
                    wx.haveCoords = true;
                    wx.coordKey = s.key;
                    wx.apply(s.data);
                    wx.fetched = Number(s.time) || 0;
                    wx._appliedUnits = s.units;
                }
            } catch (e) {
                console.log("media: could not read weather.json:", e);
            }
        }
    }

    // a changed city or unit refetches at once
    onCityChanged: {
        ready = false;
        refreshSoon.restart();
    }
    onUnitsChanged: refreshSoon.restart()
    Timer {
        id: refreshSoon
        interval: 800
        onTriggered: wx.refresh(true)
    }

    // checks every minute whether the 30 minute cache is stale
    Timer {
        interval: 60000
        repeat: true
        running: wx.active && wx.enabled
        triggeredOnStart: true
        onTriggered: wx.refresh(false)
    }
}
