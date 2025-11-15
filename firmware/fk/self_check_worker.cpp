#include <os.h>

#include "self_check_worker.h"
#include "tasks/tasks.h"
#include "hal/hal.h"
#include "state_manager.h"

namespace fk {

FK_DECLARE_LOGGER("self-check");

SelfCheckWorker::SelfCheckWorker(SelfCheckCallbacks &callbacks) : callbacks_(&callbacks) {
}

void SelfCheckWorker::run(Pool &pool) {
    if (stop_network()) {
        check();
    } else {
        GlobalStateManager gsm;
        gsm.notify("network error");
    }
}

bool SelfCheckWorker::stop_network() {
    auto started = fk_uptime();
    auto signaled = false;
    while (os_task_is_running(&network_task)) {
        if (!signaled) {
            os_task_stop(&network_task);
            signaled = true;
        }

        fk_delay(250);

        if (fk_uptime() - started > FiveSecondsMs) {
            logwarn("networking never stopped");
            return false;
        }
    }

    return true;
}

void SelfCheckWorker::check() {
    auto lock = storage_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);
    StandardPool pool{ "self-check" };
    NullDisplay noop_display;
    SelfCheck self_check(&noop_display, get_network(), get_modmux(), get_module_leds());
    self_check.check(SelfCheckSettings::detailed(), *callbacks_, &pool);
    self_check.save();
}

} // namespace fk
