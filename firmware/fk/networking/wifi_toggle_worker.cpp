#include <os.h>

#include "networking/wifi_toggle_worker.h"

#include "config.h"
#include "hal/hal.h"
#include "tasks/tasks.h"
#include "timer.h"

namespace fk {

FK_DECLARE_LOGGER("wifi-toggle");

WifiToggleWorker::WifiToggleWorker(WifiToggleWorker::DesiredState desired) : desired_(desired) {
}

void WifiToggleWorker::run(Pool &pool) {
    auto running = os_task_is_running(&network_task);

    switch (desired_) {
    case DesiredState::Enabled:
        if (!running) {
            os_task_start(&network_task);
        }
        break;
    case DesiredState::Disabled:
        if (running) {
            os_task_stop(&network_task);

            Timer timer{ TenSecondsMs };
            while (os_task_is_running(&network_task)) {
                fk_delay(500);

                if (timer.done()) {
                    // NOTE Display error?
                    return;
                }
            }
        }
        break;
    case DesiredState::Toggle:
        if (running) {
            os_task_stop(&network_task);
        } else {
            os_task_start(&network_task);
        }
        break;
    case DesiredState::Restart:
        if (running) {
            os_task_stop(&network_task);

            Timer timer{ TenSecondsMs };
            while (os_task_is_running(&network_task)) {
                fk_delay(500);

                if (timer.done()) {
                    // NOTE Display error?
                    return;
                }
            }

            os_task_start(&network_task);
        } else {
            os_task_start(&network_task);
        }
        break;
    case DesiredState::ExternalAp:
        if (!running) {
            os_task_start_options(&network_task, FK_PRIORITY_NETWORK_TASK, &task_network_params_external_ap);

            auto started = fk_uptime();
            do {
                if (fk_uptime() - started > NetworkConnectionTimeoutMs) {
                    logwarn("offline");
                    return;
                }

                fk_delay(500);
            } while (!get_network()->online() && os_task_is_running(&network_task));
        }
        break;
    }
}

} // namespace fk
