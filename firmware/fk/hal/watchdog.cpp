#include <tiny_printf.h>
#include "hal/hal.h"

#if defined(__SAMD51__)
#include <Adafruit_SleepyDog.h>
#endif

namespace fk {

EnableWatchdog::EnableWatchdog() {
    fk_wdt_enable();
}

EnableWatchdog::~EnableWatchdog() {
    fk_wdt_disable();
}

} // namespace fk

extern "C" {

#if defined(__SAMD51__)

int32_t fk_wdt_initialize() {
    return 0;
}

int32_t fk_wdt_enable() {
    uint16_t to_period = 8192;
    Watchdog.enable(to_period, false);
    // alogf(LogLevels::DEBUG, "watchdog", "wdt:enabled");
    return 0;
}

int32_t fk_wdt_disable() {
    Watchdog.disable();
    // alogf(LogLevels::DEBUG, "watchdog", "wdt:disabled");
    return 0;
}

int32_t fk_wdt_feed() {
    // alogf(LogLevels::DEBUG, "watchdog", "wdt:feed");
    Watchdog.reset();
    return 0;
}

#endif

#if defined(linux)

int32_t fk_wdt_initialize() {
    return 0;
}

int32_t fk_wdt_enable() {
    return 0;
}

int32_t fk_wdt_disable() {
    return 0;
}

int32_t fk_wdt_feed() {
    return 0;
}

#endif
}
