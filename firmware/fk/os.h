#pragma once

#include <stdint.h>
#include <stdarg.h>
#include <FreeRTOS_SAMD51.h>
#include <task_stack.h>

#undef min
#undef max

#define SAMD51_FREERTOS

#define OSH_STACK_MAGIC_WORD 0x0

#define OS_PRIORITY_NORMAL tskIDLE_PRIORITY + 2

#define OS_IRQ_PRIORITY (configLIBRARY_LOWEST_INTERRUPT_PRIORITY)

#define OSS_SUCCESS 0
#define OSS_FAIL    -1

#define OS_CHECK(expr) FK_ASSERT((expr) == OSS_SUCCESS)

typedef uint32_t os_status_t;

typedef eTaskState os_task_status;

typedef uint32_t os_start_status;

typedef uint32_t os_priority_t;

typedef struct os_task_options_t {
    const char *name;
    void (*handler)(void *);
    void *params;
    uint32_t *stack;
    uint32_t stack_size;
    os_priority_t priority;
} os_task_options_t;

struct fk_task_data_t {
    task_stack log_stack{ 10 };
};

typedef struct os_task_t {
    os_task_options_t options;
    TaskHandle_t handle;
    uint32_t signal;
    fk_task_data_t locals;
    StaticTask_t tcb;
} os_task_t;

typedef void (*os_task_status_hook_fn_t)(os_task_t *task, os_task_status previous_status);

typedef void (*os_logging_hook_fn_t)(char const *f, va_list args);

os_status_t os_configure_hooks(os_task_status_hook_fn_t status_hook, os_logging_hook_fn_t logging_hook);
os_status_t os_task_start_options(os_task_t *task, uint8_t priority, void *params);
os_status_t os_initialize();
os_status_t os_task_initialize(os_task_t *task, const char *name, void (*handler)(void *params), void *params, uint32_t *stack,
                               uint32_t stack_size);
os_status_t os_task_initialize_options(os_task_t *task, os_task_options_t *options);
os_status_t os_start();
os_status_t os_task_start(os_task_t *task);

os_task_status os_task_get_status(os_task_t *task);
bool os_task_is_running(os_task_t *task);
os_task_t *os_task_self();
os_status_t os_task_stop(os_task_t *task);
os_status_t os_signal_check(uint32_t *signal);
bool os_is_running();
uint32_t os_task_highwater(os_task_t *task);
uint32_t os_task_get_stack_size(os_task_t *task);

void os_step_tick(uint32_t ms);
void os_log_task_statistics(os_task_t *task);

os_task_t *os_tasks_iter_first();
os_task_t *os_tasks_iter(os_task_t *iter);

os_priority_t os_task_get_priority(os_task_t *task);
os_status_t os_task_set_priority(os_task_t *task, os_priority_t priority);

os_priority_t fk_task_self_priority_get();
os_priority_t fk_task_self_priority_set(os_priority_t priority);

const char *os_task_get_name_self();
const char *os_task_get_name(os_task_t *task);
os_status_t os_task_set_name(os_task_t *task, const char *name);

fk_task_data_t *os_task_user_data_get(os_task_t *task);

#define os_word_size(n) (((sizeof(n) + sizeof(uint32_t) - 1) & ~(sizeof(uint32_t) - 1)) / sizeof(uint32_t))

typedef struct {
    int32_t status;
    union {
        uint32_t u32;
        void *ptr;
    } value;
} os_tuple_t;

typedef struct os_queue_definition_t {
    const char *name;
    uint16_t size;
    uint16_t item_size;
    uint16_t flags;
    uint8_t *buffer;
    StaticQueue_t queue;
} os_queue_definition_t;

typedef struct os_queue_t {
    QueueHandle_t handle;
} os_queue_t;

#define OS_QUEUE_FLAGS_QUEUE_ONLY 0
#define OS_QUEUE_FLAGS_NONE       1

#define os_queue_define(name, size, item_size, flags)                                                                                      \
    uint8_t _os_queue_buffer_##name[size * item_size];                                                                                     \
    os_queue_definition_t _os_queue_def_##name = { #name, size, item_size, flags, _os_queue_buffer_##name };                               \
    os_queue_t _os_queue_##name;

#define os_queue(name) ((os_queue_t *)&_os_queue_##name)

#define os_queue_def(name) (os_queue_definition_t *)&_os_queue_def_##name

os_status_t os_queue_create(os_queue_t *queue, os_queue_definition_t *def);
os_tuple_t os_queue_enqueue(os_queue_t *queue, void *message, uint32_t to);
os_tuple_t os_queue_dequeue(os_queue_t *queue, uint32_t to);
os_status_t os_queue_enqueue_isr(os_queue_t *queue, void *message);

typedef struct os_mutex_definition_t {
    StaticSemaphore_t semaphore;
} os_mutex_definition_t;

typedef struct os_mutex_t {
    SemaphoreHandle_t handle;
} os_mutex_t;

os_status_t os_mutex_create(os_mutex_t *mutex, os_mutex_definition_t *def);
os_status_t os_mutex_acquire(os_mutex_t *mutex, uint32_t to);
os_status_t os_mutex_release(os_mutex_t *mutex);

typedef struct os_rwlock_definition_t {
    StaticSemaphore_t read;
    StaticSemaphore_t resource;
} os_rwlock_definition_t;

typedef struct os_rwlock_t {
    SemaphoreHandle_t read;
    SemaphoreHandle_t resource;
    uint32_t readers;
} os_rwlock_t;

os_status_t os_rwlock_create(os_rwlock_t *rwlock, os_rwlock_definition_t *def);
os_status_t os_rwlock_acquire_read(os_rwlock_t *rwlock, uint32_t to);
os_status_t os_rwlock_acquire_write(os_rwlock_t *rwlock, uint32_t to);
os_status_t os_rwlock_release_read(os_rwlock_t *rwlock);
os_status_t os_rwlock_release_write(os_rwlock_t *rwlock);

uint32_t os_delay(uint32_t ms);

uint32_t os_free_memory();

#define OS_PANIC_ASSERTION -1

typedef uint32_t os_panic_kind_t;

os_status_t os_panic(os_panic_kind_t kind);

// NOTE: If you are using CMSIS, the registers can also be
// accessed through CoreDebug->DHCSR & CoreDebug_DHCSR_C_DEBUGEN_Msk
#if defined(__SAMD51__)
#define HALT_IF_DEBUGGING()                                                                                                                \
    do {                                                                                                                                   \
        if ((*(volatile uint32_t *)0xE000EDF0) & (1 << 0)) {                                                                               \
            __asm("bkpt 1");                                                                                                               \
        }                                                                                                                                  \
    } while (0)
#endif