#include "graceful_shutdown.h"
#include "logging.h"
#include "tasks/tasks.h"

namespace fk {

FK_DECLARE_LOGGER("system");

bool fk_graceful_shutdown() {
    auto all_tasks = os_tasks_iter_first();
    auto self = os_task_self();

    loginfo("graceful shutdown");

    for (auto iter = all_tasks; iter != nullptr; iter = os_tasks_iter(iter)) {
        if (iter != self && iter != &display_task) {
            if (os_task_is_running(iter)) {
                loginfo("stop %s", os_task_get_name(iter));
                os_task_stop(iter);
            }
        }
    }

    auto give_up = fk_uptime() + FiveSecondsMs;
    while (fk_uptime() < give_up) {
        fk_delay(100);

        auto running = false;
        for (auto iter = all_tasks; iter != nullptr; iter = os_tasks_iter(iter)) {
            if (iter != self && iter != &display_task) {
                if (os_task_is_running(iter)) {
                    loginfo("waiting on %s", os_task_get_name(iter));
                    running = true;
                }
            }
        }

        if (!running) {
            break;
        }
    }

    auto gave_up = fk_uptime() > give_up;
    if (gave_up) {
        loginfo("still have procs running, gave up");
    }

    loginfo("graceful shutdown done, flushing");

    fk_logs_flush();

    return true;
}

} // namespace fk
