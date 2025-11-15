#include "tasks/tasks.h"
#include "hal/hal.h"
#include "storage/storage.h"

namespace fk {

FK_DECLARE_LOGGER("task");

void task_handler_worker(void *params) {
    FK_ASSERT(params != nullptr);

    auto started = fk_uptime();
    auto worker = reinterpret_cast<TaskWorker *>(params);

    worker->run();

    get_ipc()->remove_worker(worker);

    delete worker;

    loginfo("done elapsed: %" PRIu32 "ms", fk_uptime() - started);
}

} // namespace fk
