#include "tasks/tasks.h"

namespace fk {

os_task_t scheduler_task;
os_task_t display_task;
os_task_t network_task;
os_task_t worker_tasks[NumberOfWorkerTasks];

os_task_t *all_tasks[3 + NumberOfWorkerTasks + 1] = {
    &scheduler_task, &display_task, &network_task, &worker_tasks[0], &worker_tasks[1], nullptr,
};

NetworkTaskParameters task_network_params_external_ap{ true };

os_task_t **fk_tasks_all() {
    return all_tasks;
}

bool fk_can_start_task(os_task_t *task) {
    return !os_task_is_running(task);
}

bool fk_start_task_if_necessary(os_task_t *task) {
    if (fk_task_stop_requested(nullptr)) {
        alogf(LogLevels::ERROR, "tasks", "start-task:FAILED:stopping");
        return false;
    }
    if (!fk_can_start_task(task)) {
        alogf(LogLevels::ERROR, "tasks", "start-task:FAILED:status");
        return false;
    }
    os_task_start(task);
    return true;
}

bool fk_task_stop_requested(uint32_t *checked) {
    if (checked != nullptr) {
        if (*checked > 0 && fk_uptime() < *checked) {
            return false;
        }

        *checked = fk_uptime() + 100;
    }

    uint32_t signal = 0;
    if (os_signal_check(&signal) == OSS_SUCCESS) {
        if (signal > 0) {
            return true;
        }
    }
    return false;
}

} // namespace fk
