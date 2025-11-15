#include <malloc.h>
#include <loading.h>
#include <os.h>

#include "platform.h"
#include "utilities.h"
#include "hal/metal/metal.h"
#include "hal/flash.h"
#include "debugging.h"
#include "storage/storage.h"
#include "tasks/tasks.h"
#include "state.h"
#include "logging.h"
#include "status_logging.h"
#include "live_tests.h"
#include "startup/startup_worker.h"
#include "modules/dyn/process.h"
#include "storage/backup_worker.h"

#if defined(FK_UNDERWATER) && defined(FK_UW_ESP32_DIRECT)
#include "uw/esp32_passthru_worker.h"
#endif

extern const struct fkb_header_t fkb_header;

using namespace fk;

FK_DECLARE_LOGGER("main");

void run_tasks() {
    uint32_t stack_size = FK_TASK_STACK_SIZE_BYTES / sizeof(uint32_t);

    /**
     * This is very deliberate. By placing these on the stack this way, we
     * ensure that the stack pointer relative to the heap location is as
     * expected by code in the standard library.
     *
     * Declaring these static, for example, will cause them to be placed in the
     * .data section, which is below the heap in memory.
     */
    uint32_t scheduler_stack[stack_size];
    uint32_t display_stack[stack_size];
    uint32_t worker_stacks[NumberOfWorkerTasks][stack_size];
    uint32_t network_stack[stack_size];

    auto total_stacks = sizeof(scheduler_stack) + sizeof(display_stack) + sizeof(worker_stacks) + sizeof(network_stack);

    os_task_options_t scheduler_task_options = { "scheduler",     task_handler_scheduler,  nullptr,
                                                 scheduler_stack, sizeof(scheduler_stack), FK_PRIORITY_SCHEDULER_TASK };

    os_task_options_t display_task_options = { "display",     task_handler_display,  &task_display_params,
                                               display_stack, sizeof(display_stack), FK_PRIORITY_DISPLAY_TASK };

    os_task_options_t network_task_options = { "network",     task_handler_network,  nullptr,
                                               network_stack, sizeof(network_stack), FK_PRIORITY_NETWORK_TASK };

    OS_CHECK(os_initialize());

    OS_CHECK(os_task_initialize_options(&scheduler_task, &scheduler_task_options));
    OS_CHECK(os_task_initialize_options(&network_task, &network_task_options));
    OS_CHECK(os_task_initialize_options(&display_task, &display_task_options));

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        OS_CHECK(os_task_initialize(&worker_tasks[i], "worker", &task_handler_worker, nullptr, worker_stacks[i], sizeof(worker_stacks[i])));
    }

    auto mi = mallinfo();
    auto free_memory = fk_free_memory();
    loginfo("memory arena = %zd used = %zd", (size_t)mi.arena, (size_t)mi.uordblks);
    loginfo("stacks = %d", total_stacks);
    loginfo("free = %" PRIu32, free_memory);
    FK_ASSERT(free_memory > 0xff && free_memory < 0x40000);

    FK_ASSERT(get_ipc()->begin());

#if defined(FK_STARTUP_OVERRIDE)
    fk_logs_saved_free();
    FK_STARTUP_OVERRIDE();
#else
    FK_ASSERT(get_ipc()->launch_worker(create_pool_worker<StartupWorker>()));
#endif

    loginfo("starting os!");

    OS_CHECK(os_start());
}

static bool initialize_hardware() {
    FK_ASSERT(get_board()->initialize());

    FK_ASSERT(get_buttons()->begin());

    FK_ASSERT(fk_wdt_initialize() == 0);

    FK_ASSERT(fk_random_initialize() == 0);

    FK_ASSERT(get_flash()->initialize());

    delay(10); // Non FreeRTOS delay

    return true;
}

static void single_threaded_setup() {
    FK_ASSERT(fk_logging_initialize());

    FK_ASSERT(initialize_hardware());

    FK_ASSERT(fk_debugging_initialize());

    FK_ASSERT(fk_log_diagnostics());
}

void setup() {
    SEGGER_RTT_WriteString(0, "\n");
    single_threaded_setup();

#if defined(FK_DEBUG_DISABLE_BUFFERED_WRITES)
    // Disable memory write buffering, useful in tracking down imprecise bus faults.
    *(uint8_t *)0xE000E008 |= (1 << 1);
#endif

#if defined(FK_IPC_SINGLE_THREADED)
#if defined(__SAMD51__)
    get_board()->i2c_core().begin();
    auto clock = get_clock();
    if (!clock->begin()) {
        logerror("rtc error");
    }
    fk_live_tests();
#endif
#endif

#if defined(FK_UNDERWATER) && defined(FK_UW_ESP32_DIRECT)
    StandardPool pool{ "esp32-passthru" };
    Esp32PassthruWorker passthru;
    passthru.run(pool);
#endif

    run_tasks();
}

void loop() {
}
