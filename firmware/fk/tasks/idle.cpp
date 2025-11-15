#include "hal/clock.h"
#include "config.h"
#include "memory.h"
#include "status_logging.h"
#include "tasks/tasks.h"

namespace fk {

#define tskRUNNING_CHAR   ('X')
#define tskBLOCKED_CHAR   ('B')
#define tskREADY_CHAR     ('R')
#define tskDELETED_CHAR   ('D')
#define tskSUSPENDED_CHAR ('S')
#define tskINVALID_CHAR   ('?')

#if defined(FK_DEBUG_IDLE_TASK_INFO)
static void task_info() {
    auto array_size = uxTaskGetNumberOfTasks();

    auto pxTaskStatusArray = (TaskStatus_t *)malloc(array_size * sizeof(TaskStatus_t));

    if (pxTaskStatusArray != NULL) {
        unsigned long total_run_time;

        array_size = uxTaskGetSystemState(pxTaskStatusArray, array_size, &total_run_time);

        for (auto x = 0u; x < array_size; x++) {
            char status;

            switch (pxTaskStatusArray[x].eCurrentState) {
            case eRunning:
                status = tskRUNNING_CHAR;
                break;
            case eReady:
                status = tskREADY_CHAR;
                break;
            case eBlocked:
                status = tskBLOCKED_CHAR;
                break;
            case eSuspended:
                status = tskSUSPENDED_CHAR;
                break;
            case eDeleted:
                status = tskDELETED_CHAR;
                break;
            case eInvalid:
            default:
                status = tskINVALID_CHAR;
                break;
            }

            alogf(LogLevels::INFO, "tasks", "%-12s %c %2u %6u %8u", pxTaskStatusArray[x].pcTaskName, status,
                  (unsigned int)pxTaskStatusArray[x].uxCurrentPriority, (unsigned int)pxTaskStatusArray[x].usStackHighWaterMark,
                  (unsigned int)pxTaskStatusArray[x].xTaskNumber);
        }

        free(pxTaskStatusArray);
    }
}
#endif

void task_handler_idle() {
    static uint32_t counter = 0u;
    static uint32_t status_at = FiveSecondsMs;

    auto now = fk_uptime();

    if (now > status_at) {
        fk_status_log();

        counter++;
        status_at = now + FiveSecondsMs;

        if (counter == 10) {
            get_clock()->compare();
            fk_standard_page_log();
            counter = 0;
        }

#if defined(FK_DEBUG_IDLE_TASK_INFO)
        task_info();
#endif
    }
}

} // namespace fk
