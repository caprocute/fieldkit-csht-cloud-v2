#!/usr/bin/python3

import re
import sys
import datetime

# This is used to filter readings keys as well as set the sort order
# for known columns. In the end it was easier to just predefine these
# keys and their order rather than scan all the rows and find unknown
# keys to generate a consistent column order.
selected_key_order = [
    "time",
    "uptime",
    "gps",
    "wifi",
    "255_diagnostics.battery_vbus",
    "255_diagnostics.solar_vbus",
    "255_diagnostics.temperature",
]

water_sensors = [
    "water.temp.temp",
    "water.ec.ec_uncal",
    "water.ec.ec",
    "water.ph.ph_uncal",
    "water.ph.ph",
    "water.do.do_uncal",
    "water.do.do",
]

weather_sensors = [
    "weather.humidity",
    "weather.pressure",
    "weather.rain",
    "weather.rain_prev_hour",
    "weather.rain_this_hour",
    "weather.temperature_1",
    "weather.temperature_2",
    "weather.wind_10m_max_dir",
    "weather.wind_10m_max_speed",
    "weather.wind_2m_avg_dir",
    "weather.wind_2m_avg_speed",
    "weather.wind_dir",
    "weather.wind_dir_mv",
    "weather.wind_hr_max_dir",
    "weather.wind_hr_max_speed",
    "weather.wind_speed"
]

def flatten(l): 
    return [i for sl in l for i in sl]

def get_selected_key_order():
    keys = [[
        "time",
        "uptime",
        "gps",
        "wifi",
        "255_diagnostics.battery_vbus",
        "255_diagnostics.solar_vbus",
        "255_diagnostics.temperature",
    ]]

    keys += [["%d_%s" % (b, s) for s in weather_sensors] for b in range(5)]
    keys += [["%d_%s" % (b, s) for s in water_sensors] for b in range(5)]

    keys = flatten(keys)

    return keys

def main():
    strip_ansi = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

    selected_key_order = get_selected_key_order()

    time_marker = None
    gps = False
    wifi = False
    rows = []
    d = {}
    for line in sys.stdin:
        sanitized = strip_ansi.sub("", line.strip())

#       263259769 idle       info    status: 2024/3/5 20:04:49
        match = re.search(
            "(\d+) \S+\s+\S+\s+status:\s+(\d\d\d\d/\d+/\d+ \d+:\d+:\d+)",
            sanitized,
        )
        if match:
            stamp = datetime.datetime.strptime(match.group(2), "%Y/%m/%d %H:%M:%S")
            uptime = int(match.group(1))
            time_marker = (uptime, stamp)

        match = re.search("gps\((.+)\)", sanitized)
        if match:
            gps = "off" not in match[1]

        match = re.search("wifi\((.+)\)", sanitized)
        if match:
            wifi = "off" not in match[1]

        match = re.search("(\d+).+take-readings begin", sanitized)
        if match:
            rows.append(d)
            uptime = int(match[1])
            time = ""
            if time_marker:
                millis = uptime - time_marker[0]
                time = time_marker[1] + datetime.timedelta(milliseconds=millis)
                time = time.strftime("%Y/%m/%d %H:%M:%S.%f")
            d = {
                "uptime": uptime,
                "time": time,
                "gps": 1 if gps else 0,
                "wifi": 1 if wifi else 0,
            }

        match = re.search(
            "state: \[(\d+)\]\s+sensor\[\s*(\d+)\]\s+name='(\S+)'\s+reading=(\S+)\s+\((\S+)\)",
            sanitized,
        )
        if match:
            bay = int(match[1])
            sensor = int(match[2])
            key = match[3]
            calibrated = float(match[4])
            uncalibrated = float(match[5])
            bay_key = "{0}_{1}".format(bay, key)
            if bay_key in selected_key_order:
                d[bay_key] = calibrated
                d[bay_key + "_uncal"] = uncalibrated

    print(",".join(selected_key_order))

    for row in rows:
        with_missing_columns = [
            str(row[key]) if key in row else "" for key in selected_key_order
        ]

        print(",".join(with_missing_columns))


if __name__ == "__main__":
    main()
