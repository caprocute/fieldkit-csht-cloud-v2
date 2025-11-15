#pragma once

#include <cstdint>

#include "weather.h"

namespace fk {

class RainCollector {
private:
    int16_t minute_{ -1 };
    int32_t value_{ -1 };
    uint32_t ticks_{ 0 };

public:
    uint32_t ticks() {
        return ticks_;
    }

    void include(fk_weather_aggregated_t *aw) {
        if (minute_ == -1) {
            auto t = aw->rain_60m[aw->minute].ticks;
            if (t != FK_WEATHER_TICKS_NULL) {
                ticks_ = t;
            }
        } else {
            int32_t m = minute_;
            while (true) {
                auto t = aw->rain_60m[m].ticks;
                if (t != FK_WEATHER_TICKS_NULL) {
                    if (m == minute_) {
                        ticks_ += t - value_;
                    } else {
                        ticks_ += t;
                    }
                }

                if (m == aw->minute) {
                    break;
                }

                m++;
                if (m == 60) {
                    m = 0;
                }
            }
        }

        minute_ = aw->minute;
        value_ = aw->rain_60m[minute_].ticks;
    }
};

} // namespace fk