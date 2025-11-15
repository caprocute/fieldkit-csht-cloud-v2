#pragma once

#include <modules/bridge/modules.h>

#include "weather_types.h"
#include "rain_collector.h"

namespace fk {

class AggregatedWeather {
private:
    int8_t failures_{ -1 };
    RainCollector collector_;
    uint32_t last_rain_{ 0 };

public:
    ModuleReturn initialize(ModuleContext mc, Pool &pool);
    ModuleReturn service(ModuleContext mc, Pool &pool);
    ModuleReadings *take_readings(ModuleContext mc, Pool &pool);

private:
    bool try_initialize(ModuleContext mc, Pool &pool);
};

} // namespace fk
