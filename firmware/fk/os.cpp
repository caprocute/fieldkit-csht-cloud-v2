#include "os.h"
#include <FreeRTOS_SAMD51.h>
#include "common.h"

namespace fk {
extern os_task_t **fk_tasks_all();
}

void free_rtos_task(void *params) {
    os_task_t *task = (os_task_t *)params;

    alogf(LogLevels::INFO, "os", "started");

    FK_ASSERT(task != NULL);
    FK_ASSERT(task->options.handler != NULL);

    task->options.handler(task->options.params);

    os_log_task_statistics(task);

#if defined(__SAMD51__)
    // Calling vTaskDelete(NULL) doesn't actually stop the task from executing again
    // and I can't for the life of me figure out why. The documentation is pretty
    // clear on this, and yet, that's not what I see. To work around that, we suspend
    // and treat suspended tasks as stopped.
    vTaskSuspend(NULL);
#endif

    while (true) {
        os_delay(1000);
    }
}

os_status_t os_configure_hooks(os_task_status_hook_fn_t status_hook, os_logging_hook_fn_t logging_hook) {
    return OSS_SUCCESS;
}

os_status_t os_initialize() {
    return OSS_SUCCESS;
}

os_status_t os_task_initialize(os_task_t *task, const char *name, void (*handler)(void *params), void *params, uint32_t *stack,
                               uint32_t stack_size) {
    os_task_options_t options;
    options.name = name;
    options.handler = handler;
    options.params = params;
    options.stack = stack;
    options.stack_size = stack_size;
    options.priority = FK_PRIORITY_NORMAL;

    return os_task_initialize_options(task, &options);
}

os_status_t os_task_initialize_options(os_task_t *task, os_task_options_t *options) {
    memcpy(&task->options, options, sizeof(os_task_options_t));

    task->handle = NULL;

    bzero(&task->tcb, sizeof(StaticTask_t));

    return OSS_SUCCESS;
}

os_status_t os_start() {
    vTaskStartScheduler();
    return OSS_SUCCESS;
}

os_status_t os_task_start_options(os_task_t *task, uint8_t priority, void *params) {
    task->options.params = params;
    task->options.priority = priority;

    // Calling vTaskDelete(NULL) from the worker itself ends up scheduling the
    // task to run again, for me, despite the documentations insistence. To work
    // around this, the task function will suspend itself, and we treat
    // suspended tasks as not running and clean them up outside of their contexts.
    if (task->handle != NULL) {
        vTaskDelete(task->handle);
        task->handle = NULL;
    }

    FK_ASSERT(task->handle == NULL);
    FK_ASSERT(task->options.stack != NULL);

    alogf(LogLevels::INFO, "os", "starting %s: priority=%d task=0x%p", task->options.name, (uint8_t)task->options.priority, task);

    // Tasks are initially created at the lowest priority so that we can keep
    // executing to store the handle. Then we set to the true/actual priority.
    // If we don't do this then resolving the os_task_t using the handle can
    // fail early on.
    task->handle = xTaskCreateStatic(free_rtos_task, task->options.name, task->options.stack_size / sizeof(uint32_t), task,
                                     tskIDLE_PRIORITY, task->options.stack, &task->tcb);
    if (task->handle == NULL) {
        return OSS_FAIL;
    }

    // See above.
    vTaskPrioritySet(task->handle, task->options.priority);

    return OSS_SUCCESS;
}

os_status_t os_task_start(os_task_t *task) {
    return os_task_start_options(task, task->options.priority, NULL);
}

os_task_status os_task_get_status(os_task_t *task) {
    FK_ASSERT(task != NULL && task->handle != NULL);
    return eTaskGetState(task->handle);
}

bool os_task_is_running(os_task_t *task) {
    if (task->handle == NULL) {
        return false;
    }
    switch (os_task_get_status(task)) {
    case eRunning:
        return true;
    case eBlocked:
        return true;
    case eReady:
        return true;
    default:
        return false;
    }
}

os_task_t *os_task_self() {
    TaskHandle_t self = xTaskGetCurrentTaskHandle();
    os_task_t **tasks = fk::fk_tasks_all();
    for (size_t i = 0; tasks[i] != nullptr; ++i) {
        if (tasks[i]->handle == self) {
            return tasks[i];
        }
    }
    return NULL;
}

os_status_t os_task_stop(os_task_t *task) {
    FK_ASSERT(task != NULL);
    FK_ASSERT(task->signal == 0 || task->signal == 9);

    task->signal = 9;

    return OSS_SUCCESS;
}

os_status_t os_signal_check(uint32_t *signal) {
    os_task_t *self = os_task_self();
    FK_ASSERT(self != NULL);

    if (self->signal > 0) {
        *signal = self->signal;
        self->signal = 0;
    }

    return OSS_SUCCESS;
}

bool os_is_running() {
    switch (xTaskGetSchedulerState()) {
    case taskSCHEDULER_NOT_STARTED:
        return false;
    case taskSCHEDULER_RUNNING:
        return true;
    // We never suspend the scheduler, but this seems like a safe outcome.
    case taskSCHEDULER_SUSPENDED:
        return false;
    }
    return false;
}

void os_log_task_statistics(os_task_t *task) {
    if (task == NULL) {
        task = os_task_self();
        if (task == NULL) {
            return;
        }
    }

    // Highwater is kind of a nisnomer because it's the number of dwords still
    // remaining on the stack. So we're gonna tell the user how much was left.
    uint32_t bytes_left = os_task_highwater(task);
    uint32_t stack_size = os_task_get_stack_size(task);
    float stack_percentage = bytes_left / (float)stack_size * 100.0f;

    alogf(LogLevels::INFO, "os", "stack: %" PRIu32 " / %" PRIu32 " bytes %.2f%% free", stack_size, bytes_left, stack_percentage);
}

void os_step_tick(uint32_t ms) {
#if (configUSE_TICKLESS_IDLE != 0)
    vTaskStepTick(ms * portTICK_PERIOD_MS);
#endif
}

uint32_t os_task_highwater(os_task_t *task) {
    return uxTaskGetStackHighWaterMark2(task->handle) * sizeof(uint32_t);
}

uint32_t os_task_get_stack_size(os_task_t *task) {
    return task->options.stack_size;
}

os_task_t *os_tasks_iter_first() {
    return nullptr;
}

os_task_t *os_tasks_iter(os_task_t *iter) {
    return nullptr;
}

os_priority_t os_task_get_priority(os_task_t *task) {
    FK_ASSERT(task != NULL);
    if (task->handle != NULL) {
        return uxTaskPriorityGet(task->handle);
    }
    return task->options.priority;
}

os_status_t os_task_set_priority(os_task_t *task, os_priority_t priority) {
    FK_ASSERT(task != NULL && task->handle != NULL);
    vTaskPrioritySet(task->handle, priority);
    return OSS_SUCCESS;
}

os_priority_t fk_task_self_priority_get() {
    return os_task_get_priority(os_task_self());
}

os_priority_t fk_task_self_priority_set(os_priority_t priority) {
    auto old_priority = os_task_get_priority(os_task_self());
    os_task_set_priority(os_task_self(), priority);
    return old_priority;
}

const char *os_task_get_name_self() {
    if (xTaskGetCurrentTaskHandle() == NULL) {
        return NULL;
    }
    os_task_t *self = os_task_self();
    if (self == NULL) {
        return NULL;
    }
    if (self->handle != NULL) {
        return pcTaskGetName(self->handle);
    }
    return self->options.name;
}

const char *os_task_get_name(os_task_t *task) {
    if (task == NULL || task->handle == NULL) {
        return NULL;
    }
    if (task->options.name == NULL) {
        return "unknown";
    }
    return task->options.name;
}

os_status_t os_task_set_name(os_task_t *task, const char *name) {
    FK_ASSERT(task != NULL);
    task->options.name = name;
    return OSS_SUCCESS;
}

fk_task_data_t *os_task_user_data_get(os_task_t *task) {
    FK_ASSERT(task != NULL);
    return &task->locals;
}

os_status_t os_queue_create(os_queue_t *queue, os_queue_definition_t *def) {
    FK_ASSERT(queue != NULL && queue->handle == NULL);

    queue->handle = xQueueCreateStatic(def->size, def->item_size, def->buffer, &def->queue);
    if (queue->handle == NULL) {
        return OSS_FAIL;
    }

    return OSS_SUCCESS;
}

os_tuple_t os_queue_enqueue(os_queue_t *queue, void *message, uint32_t to) {
    FK_ASSERT(queue != NULL && queue->handle != NULL);

    if (xQueueSendToBack(queue->handle, message, to == UINT32_MAX ? portMAX_DELAY : to) != pdPASS) {
        return os_tuple_t{ .status = OSS_FAIL };
    }

    return os_tuple_t{ .status = OSS_SUCCESS };
}

os_status_t os_queue_enqueue_isr(os_queue_t *queue, void *message) {
    FK_ASSERT(queue != NULL && queue->handle != NULL);

    if (xQueueSendToBackFromISR(queue->handle, message, NULL) != pdPASS) {
        return OSS_FAIL;
    }

    return OSS_SUCCESS;
}

os_tuple_t os_queue_dequeue(os_queue_t *queue, uint32_t to) {
    os_tuple_t rv;

    FK_ASSERT(queue != NULL && queue->handle != NULL);

    if (xQueueReceive(queue->handle, &rv.value.ptr, to == UINT32_MAX ? portMAX_DELAY : to) != pdPASS) {
        rv.status = OSS_FAIL;
    } else {
        rv.status = OSS_SUCCESS;
    }

    return rv;
}

os_status_t os_mutex_create(os_mutex_t *mutex, os_mutex_definition_t *def) {
    FK_ASSERT(mutex != NULL && mutex->handle == NULL);

    mutex->handle = xSemaphoreCreateRecursiveMutexStatic(&def->semaphore);
    if (mutex->handle == NULL) {
        return OSS_FAIL;
    }

    return OSS_SUCCESS;
}

os_status_t os_mutex_acquire(os_mutex_t *mutex, uint32_t to) {
    FK_ASSERT(mutex != NULL && mutex->handle != NULL);

    if (!xSemaphoreTakeRecursive(mutex->handle, to == UINT32_MAX ? portMAX_DELAY : to)) {
        return OSS_FAIL;
    }
    return OSS_SUCCESS;
}

os_status_t os_mutex_release(os_mutex_t *mutex) {
    FK_ASSERT(mutex != NULL && mutex->handle != NULL);

    if (!xSemaphoreGiveRecursive(mutex->handle)) {
        return OSS_FAIL;
    }
    return OSS_SUCCESS;
}

os_status_t os_rwlock_create(os_rwlock_t *rwlock, os_rwlock_definition_t *def) {
    FK_ASSERT(rwlock != NULL);
    FK_ASSERT(rwlock->read == NULL);
    FK_ASSERT(rwlock->resource == NULL);

    rwlock->read = xSemaphoreCreateRecursiveMutexStatic(&def->read);
    if (rwlock->read == NULL) {
        return OSS_FAIL;
    }

    rwlock->resource = xSemaphoreCreateBinaryStatic(&def->resource);
    if (rwlock->resource == NULL) {
        return OSS_FAIL;
    }

    xSemaphoreGive(rwlock->resource);

    return OSS_SUCCESS;
}

os_status_t os_rwlock_acquire_read(os_rwlock_t *rwlock, uint32_t to) {
    FK_ASSERT(rwlock != NULL && rwlock->read != NULL);

    if (!xSemaphoreTakeRecursive(rwlock->read, to == UINT32_MAX ? portMAX_DELAY : to)) {
        return OSS_FAIL;
    }

    rwlock->readers++;
    if (rwlock->readers == 1) {
        FK_ASSERT(xSemaphoreTake(rwlock->resource, portMAX_DELAY));
    }

    if (!xSemaphoreGiveRecursive(rwlock->read)) {
        return OSS_FAIL;
    }
    return OSS_SUCCESS;
}

os_status_t os_rwlock_acquire_write(os_rwlock_t *rwlock, uint32_t to) {
    FK_ASSERT(rwlock != NULL && rwlock->resource != NULL);

    if (!xSemaphoreTake(rwlock->resource, to == UINT32_MAX ? portMAX_DELAY : to)) {
        return OSS_FAIL;
    }
    return OSS_SUCCESS;
}

os_status_t os_rwlock_release_read(os_rwlock_t *rwlock) {
    FK_ASSERT(rwlock != NULL && rwlock->read != NULL);

    if (!xSemaphoreTakeRecursive(rwlock->read, portMAX_DELAY)) {
        return OSS_FAIL;
    }

    rwlock->readers--;
    if (rwlock->readers == 0) {
        xSemaphoreGive(rwlock->resource);
    }

    if (!xSemaphoreGiveRecursive(rwlock->read)) {
        return OSS_FAIL;
    }
    return OSS_SUCCESS;
}

os_status_t os_rwlock_release_write(os_rwlock_t *rwlock) {
    FK_ASSERT(rwlock != NULL && rwlock->resource != NULL);

    if (!xSemaphoreGive(rwlock->resource)) {
        return OSS_FAIL;
    }
    return OSS_SUCCESS;
}

uint32_t os_delay(uint32_t ms) {
    vTaskDelay(ms * 1000 / portTICK_PERIOD_US);
    return ms;
}

extern "C" {
extern char *sbrk(int32_t i);
}

uint32_t os_free_memory() {
#if defined(__SAMD21__) || defined(__SAMD51__)
    return (uint32_t)__get_MSP() - (uint32_t)sbrk(0);
#else
    return 0;
#endif
}

os_status_t os_panic(os_panic_kind_t kind) {
    FK_ASSERT(0);
    return OSS_FAIL;
}

extern "C" {

/*
 * configSUPPORT_STATIC_ALLOCATION is set to 1, so the application must provide an
 * implementation of vApplicationGetIdleTaskMemory() to provide the memory that is
 * used by the Idle task.
 **/
void vApplicationGetIdleTaskMemory(StaticTask_t **ppxIdleTaskTCBBuffer, StackType_t **ppxIdleTaskStackBuffer,
                                   configSTACK_DEPTH_TYPE *puxIdleTaskStackSize) {
    /* If the buffers to be provided to the Idle task are declared inside this
    function then they must be declared static - otherwise they will be allocated on
    the stack and so not exists after this function exits. */
    static StaticTask_t xIdleTaskTCB;
    static StackType_t uxIdleTaskStack[configMINIMAL_STACK_SIZE];

    /* Pass out a pointer to the StaticTask_t structure in which the Idle task's
    state will be stored. */
    *ppxIdleTaskTCBBuffer = &xIdleTaskTCB;

    /* Pass out the array that will be used as the Idle task's stack. */
    *ppxIdleTaskStackBuffer = uxIdleTaskStack;

    /* Pass out the size of the array pointed to by *ppxIdleTaskStackBuffer.
    Note that, as the array is necessarily of type StackType_t,
    configMINIMAL_STACK_SIZE is specified in words, not bytes. */
    *puxIdleTaskStackSize = configMINIMAL_STACK_SIZE;
}
/*-----------------------------------------------------------*/

/*
 * configSUPPORT_STATIC_ALLOCATION and configUSE_TIMERS are both set to 1, so the
 * application must provide an implementation of vApplicationGetTimerTaskMemory()
 * to provide the memory that is used by the Timer service task.
 **/
void vApplicationGetTimerTaskMemory(StaticTask_t **ppxTimerTaskTCBBuffer, StackType_t **ppxTimerTaskStackBuffer,
                                    configSTACK_DEPTH_TYPE *puxTimerTaskStackSize) {
    /* If the buffers to be provided to the Timer task are declared inside this
    function then they must be declared static - otherwise they will be allocated on
    the stack and so not exists after this function exits. */
    static StaticTask_t xTimerTaskTCB;
    static StackType_t uxTimerTaskStack[configTIMER_TASK_STACK_DEPTH];

    /* Pass out a pointer to the StaticTask_t structure in which the Timer
    task's state will be stored. */
    *ppxTimerTaskTCBBuffer = &xTimerTaskTCB;

    /* Pass out the array that will be used as the Timer task's stack. */
    *ppxTimerTaskStackBuffer = uxTimerTaskStack;

    /* Pass out the size of the array pointed to by *ppxTimerTaskStackBuffer.
    Note that, as the array is necessarily of type StackType_t,
    configTIMER_TASK_STACK_DEPTH is specified in words, not bytes. */
    *puxTimerTaskStackSize = configTIMER_TASK_STACK_DEPTH;
}

#define SYSHND_CTRL (*(volatile unsigned int *)(0xE000ED24u))   // System Handler Control and State Register
#define NVIC_MFSR   (*(volatile unsigned char *)(0xE000ED28u))  // Memory Management Fault Status Register
#define NVIC_BFSR   (*(volatile unsigned char *)(0xE000ED29u))  // Bus Fault Status Register
#define NVIC_UFSR   (*(volatile unsigned short *)(0xE000ED2Au)) // Usage Fault Status Register
#define NVIC_HFSR   (*(volatile unsigned int *)(0xE000ED2Cu))   // Hard Fault Status Register
#define NVIC_DFSR   (*(volatile unsigned int *)(0xE000ED30u))   // Debug Fault Status Register
#define NVIC_BFAR   (*(volatile unsigned int *)(0xE000ED38u))   // Bus Fault Manage Address Register
#define NVIC_AFSR   (*(volatile unsigned int *)(0xE000ED3Cu))   // Auxiliary Fault Status Register

typedef struct cortex_hard_fault_t {
    struct {
        volatile void *R0;  // Register R0
        volatile void *R1;  // Register R1
        volatile void *R2;  // Register R2
        volatile void *R3;  // Register R3
        volatile void *R12; // Register R12
        volatile void *LR;  // Link register
        volatile void *PC;  // Program counter
        union {
            volatile uint32_t byte;
            struct {
                uint32_t IPSR : 8;  // Interrupt Program Status register (IPSR)
                uint32_t EPSR : 19; // Execution Program Status register (EPSR)
                uint32_t APSR : 5;  // Application Program Status register (APSR)
            } bits;
        } psr; // Program status register.
    } registers;

    union {
        volatile unsigned int byte;
        struct {
            unsigned int MEMFAULTACT : 1; // Read as 1 if memory management fault is active
            unsigned int BUSFAULTACT : 1; // Read as 1 if bus fault exception is active
            unsigned int UNUSED1 : 1;
            unsigned int USGFAULTACT : 1; // Read as 1 if usage fault exception is active
            unsigned int UNUSED2 : 3;
            unsigned int SVCALLACT : 1;  // Read as 1 if SVC exception is active
            unsigned int MONITORACT : 1; // Read as 1 if debug monitor exception is active
            unsigned int UNUSED3 : 1;
            unsigned int PENDSVACT : 1;      // Read as 1 if PendSV exception is active
            unsigned int SYSTICKACT : 1;     // Read as 1 if SYSTICK exception is active
            unsigned int USGFAULTPENDED : 1; // Usage fault pended; usage fault started but was replaced by a higher-priority exception
            unsigned int MEMFAULTPENDED : 1; // Memory management fault pended; memory management fault started but was replaced by a
                                             // higher-priority exception
            unsigned int
                BUSFAULTPENDED : 1; // Bus fault pended; bus fault handler was started but was replaced by a higher-priority exception
            unsigned int SVCALLPENDED : 1; // SVC pended; SVC was started but was replaced by a higher-priority exception
            unsigned int MEMFAULTENA : 1;  // Memory management fault handler enable
            unsigned int BUSFAULTENA : 1;  // Bus fault handler enable
            unsigned int USGFAULTENA : 1;  // Usage fault handler enable
        } bits;
    } syshndctrl; // System Handler Control and State Register (0xE000ED24)

    union {
        volatile unsigned char byte;
        struct {
            unsigned char IACCVIOL : 1; // Instruction access violation
            unsigned char DACCVIOL : 1; // Data access violation
            unsigned char UNUSED1 : 1;
            unsigned char MUNSTKERR : 1; // Unstacking error
            unsigned char MSTKERR : 1;   // Stacking error
            unsigned char UNUSED2 : 2;
            unsigned char MMARVALID : 1; // Indicates the MMAR is valid
        } bits;
    } mfsr; // Memory Management Fault Status Register (0xE000ED28)

    union {
        volatile unsigned int byte;
        struct {
            unsigned int IBUSERR : 1;    // Instruction access violation
            unsigned int PRECISERR : 1;  // Precise data access violation
            unsigned int IMPREISERR : 1; // Imprecise data access violation
            unsigned int UNSTKERR : 1;   // Unstacking error
            unsigned int STKERR : 1;     // Stacking error
            unsigned int UNUSED : 2;
            unsigned int BFARVALID : 1; // Indicates BFAR is valid
        } bits;
    } bfsr; // Bus Fault Status Register (0xE000ED29)

    volatile unsigned int bfar; // Bus Fault Manage Address Register (0xE000ED38)
    union {
        volatile unsigned short byte;
        struct {
            unsigned short UNDEFINSTR : 1; // Attempts to execute an undefined instruction
            unsigned short INVSTATE : 1;   // Attempts to switch to an invalid state (e.g., ARM)
            unsigned short INVPC : 1;      // Attempts to do an exception with a bad value in the EXC_RETURN number
            unsigned short NOCP : 1;       // Attempts to execute a coprocessor instruction
            unsigned short UNUSED : 4;
            unsigned short UNALIGNED : 1; // Indicates that an unaligned access fault has taken place
            unsigned short DIVBYZERO : 1; // Indicates a divide by zero has taken place (can be set only if DIV_0_TRP is set)
        } bits;
    } ufsr; // Usage Fault Status Register (0xE000ED2A)

    union {
        volatile unsigned int byte;
        struct {
            unsigned int UNUSED1 : 1;
            unsigned int VECTBL : 1; // Indicates hard fault is caused by failed vector fetch
            unsigned int UNUSED2 : 28;
            unsigned int FORCED : 1;   // Indicates hard fault is taken because of bus fault/memory management fault/usage fault
            unsigned int DEBUGEVT : 1; // Indicates hard fault is triggered by debug event
        } bits;
    } hfsr; // Hard Fault Status Register (0xE000ED2C)

    union {
        volatile unsigned int byte;
        struct {
            unsigned int HALTED : 1;    // Halt requested in NVIC
            unsigned int BKPT : 1;      // BKPT instruction executed
            unsigned int DWTTRAP : 1;   // DWT match occurred
            unsigned int VCATCH : 1;    // Vector fetch occurred
            unsigned int EXTERNAL_ : 1; // EDBGRQ signal asserted
        } bits;
    } dfsr;                     // Debug Fault Status Register (0xE000ED30)
    volatile unsigned int afsr; // Auxiliary Fault Status Register (0xE000ED3C) Vendor controlled (optional)
} cortex_hard_fault_t;

typedef struct __attribute__((packed)) cortex_state_frame_t {
    uint32_t r0;
    uint32_t r1;
    uint32_t r2;
    uint32_t r3;
    uint32_t r12;
    uint32_t lr;
    uint32_t return_address;
    uint32_t xpsr;
} cortex_state_frame_t __attribute__((aligned(sizeof(uint32_t))));

__attribute__((optimize("O0"))) void hard_fault(cortex_state_frame_t *frame) {
    cortex_hard_fault_t hfr;
    hfr.syshndctrl.byte = SYSHND_CTRL; // System Handler Control and State Register
    hfr.mfsr.byte = NVIC_MFSR;         // Memory Fault Status Register
    hfr.bfsr.byte = NVIC_BFSR;         // Bus Fault Status Register
    hfr.bfar = NVIC_BFAR;              // Bus Fault Manage Address Register
    hfr.ufsr.byte = NVIC_UFSR;         // Usage Fault Status Register
    hfr.hfsr.byte = NVIC_HFSR;         // Hard Fault Status Register
    hfr.dfsr.byte = NVIC_DFSR;         // Debug Fault Status Register
    hfr.afsr = NVIC_AFSR;              // Auxiliary Fault Status Register

#if defined(__SAMD51__)
    uint32_t *stack = (uint32_t *)frame;
    hfr.registers.R0 = (void *)stack[0];  // Register R0
    hfr.registers.R1 = (void *)stack[1];  // Register R1
    hfr.registers.R2 = (void *)stack[2];  // Register R2
    hfr.registers.R3 = (void *)stack[3];  // Register R3
    hfr.registers.R12 = (void *)stack[4]; // Register R12
    hfr.registers.LR = (void *)stack[5];  // Link register LR
    hfr.registers.PC = (void *)stack[6];  // Program counter PC
    hfr.registers.psr.byte = stack[7];    // Program status word PSR

    HALT_IF_DEBUGGING();
#endif

    (void)hfr;

    volatile uint32_t i = 0;
    while (true) {
        ++i;
    }
}

#define HARDFAULT_HANDLING_ASM(_x)                                                                                                         \
    __asm volatile("tst lr, #4 \n"                                                                                                         \
                   "ite eq \n"                                                                                                             \
                   "mrseq r0, msp \n"                                                                                                      \
                   "mrsne r0, psp \n"                                                                                                      \
                   "b hard_fault \n")

#if defined(__SAMD51__)
void HardFault_Handler() {
    HARDFAULT_HANDLING_ASM();
}
#endif
}
