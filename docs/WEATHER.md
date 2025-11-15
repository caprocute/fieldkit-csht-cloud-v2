# Sensors

## Temperature

Gathered once every second.

## Humidity

Gathered once every second.

## Pressure

Gathered once every second.

## Wind

Direction is read every second.

Hardware counter monitors revolutions. `2.4km/hr` per tick.

Counter is read every second.

Hourly gust is reset every 60m. Not guaranteed to be on a whole minute.

If the current second's data is stronger than the last hourly gust, it becomes
the new gust.

If the current second's data is stronger than the last gust, it becomes the new
gust.

10m aggregates reset every 10m. 

2m (120 samples) data gets currently read wind reading set for the current second.

Averages of wind direction are done via X. **Need to dig up the wiki for this algorithm.**

## Rain

Hardware counter monitors tips. `0.336mm` per tick.

Counter is read every second and accumulated in a counter for the current
minute. 60 of these counters are available, and wrapped around, always keeping
the last 60m worth of rain data.

2024-11: The core firmware will now monitor those 60 samples to provide a delta
between readings. This is done by remember the minute of the last reading,
comparing to the reading that was just taken and then adding up the new ticks.
This gives an ever increasing number of ticks, that can be subtracted from the
previous value to get the delta.

TBD: It would be nice to also gather the time of the last rain tick, and using
this to generate a rate. This will require changes to the weather firmware.
Ideally we can do this when we improve on the gathering of simple rain deltas.

