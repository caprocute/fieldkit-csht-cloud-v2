#include <algorithm>

#include "deep_sleep.h"
#include "hal/clock.h"
#include "hal/network.h"
#include "hal/random.h"
#include "hal/watchdog.h"
#include "tasks/tasks.h"
#include "platform.h"

namespace fk {

FK_DECLARE_LOGGER("sleep");

constexpr uint32_t MinimumDeepSleepMs = 8192;

constexpr uint32_t MinimumAcceptableDeepSleepMs = (MinimumDeepSleepMs / 1000) * 1000;

uint32_t DeepSleep::once() {
    auto now_before = get_clock_now();

    logverbose("sleeping");

#if defined(FK_WDT_ENABLE)
    fk_wdt_disable();
#endif

    fk_deep_sleep(MinimumDeepSleepMs);

#if defined(FK_WDT_ENABLE)
    fk_wdt_enable();
#endif

    auto now_after = get_clock_now();
    if (now_after < now_before) {
        logwarn("before=%" PRIu32 " now=%" PRIu32, now_before, now_after);
        return 0;
    }

    // Cap this at the maximum sleep time.
    auto elapsed = std::min(MinimumDeepSleepMs, (now_after - now_before) * 1000);
    logdebug("before=%" PRIu32 " now=%" PRIu32 " elapsed=%" PRIu32, now_before, now_after, elapsed);

    fk_uptime_adjust_after_sleep(elapsed);

    return elapsed;
}

void DeepSleep::try_deep_sleep(lwcron::Scheduler &scheduler) {
#if defined(FK_WDT_ENABLE)
    fk_wdt_feed();
#endif

    auto now = get_clock_now();
    auto nextTask = scheduler.nextTask(lwcron::DateTime{ now }, 0);
    if (!nextTask) {
        logerror("no next task, that's very strange");
        return;
    }

    // If we have enough time for a nap, otherwise we bail.
    auto remaining_seconds = nextTask.time - now;
    if (remaining_seconds * 1000 < MinimumDeepSleepMs) {
        loginfo("no-sleep: task-eta=%" PRIu32 "s", remaining_seconds);
        return;
    }

    // Sleep!
    // This can return early for a few reasons:
    // 1) We're unable to sleep, in which case this will
    // return 0.
    // 2) We were woken up via IRQ of some kind, which can
    // also return 0. So we basically gotta just bail out of
    // here in either case.
    if (once() < MinimumAcceptableDeepSleepMs) {
        return;
    }
}

} // namespace fk
