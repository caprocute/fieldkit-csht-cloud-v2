#pragma once

#include <stddef.h>

#define tskIDLE_PRIORITY             0
#define configMINIMAL_STACK_SIZE     150
#define configSTACK_DEPTH_TYPE       uint32_t
#define configTIMER_TASK_STACK_DEPTH 150
#define portTICK_PERIOD_US           1000
#define portTICK_PERIOD_MS           1
#define portMAX_DELAY                UINT32_MAX

#define pdPASS 1

typedef int32_t BaseType_t;

typedef uint32_t StackType_t;

enum eTaskState {
    eRunning,
    eReady,
    eBlocked,
    eDeleted,
};

typedef struct StaticQueue_t {

} StaticQueue_t;

typedef struct StaticSemaphore_t {

} StaticSemaphore_t;

typedef struct StaticTask_t {

} StaticTask_t;

typedef uint32_t *QueueHandle_t;

typedef uint32_t *SemaphoreHandle_t;

typedef uint32_t *TaskHandle_t;

eTaskState eTaskGetState(TaskHandle_t handle);

#define taskSCHEDULER_SUSPENDED   ((BaseType_t)0)
#define taskSCHEDULER_NOT_STARTED ((BaseType_t)1)
#define taskSCHEDULER_RUNNING     ((BaseType_t)2)

BaseType_t xTaskGetSchedulerState();

TaskHandle_t xTaskCreateStatic(void (*handler)(void *), const char *name, uint32_t stack_size, void *params, uint8_t priority, void *stack,
                               StaticTask_t *buffer);

void vTaskDelete(TaskHandle_t handle);

TaskHandle_t xTaskGetCurrentTaskHandle();

QueueHandle_t xQueueCreateStatic(uint32_t size, uint32_t item_size, uint8_t *buffer, StaticQueue_t *queue);

BaseType_t xQueueSendToBackFromISR(QueueHandle_t queue, void *ptr, void *task);

BaseType_t xQueueSendToBack(QueueHandle_t queue, void *ptr, uint32_t to);

BaseType_t xQueueReceive(QueueHandle_t queue, void *ptr, uint32_t to);

SemaphoreHandle_t xSemaphoreCreateRecursiveMutexStatic(StaticSemaphore_t *semaphore);

SemaphoreHandle_t xSemaphoreCreateBinaryStatic(StaticSemaphore_t *semaphore);

BaseType_t xSemaphoreGive(SemaphoreHandle_t handle);

BaseType_t xSemaphoreTake(SemaphoreHandle_t handle, uint32_t to);

BaseType_t xSemaphoreTakeRecursive(SemaphoreHandle_t handle, uint32_t to);

BaseType_t xSemaphoreGiveRecursive(SemaphoreHandle_t handle);

void vTaskStartScheduler();

void vTaskDelay(uint32_t ms);

char *pcTaskGetName(TaskHandle_t handle);

uint8_t uxTaskPriorityGet(TaskHandle_t handle);

void vTaskPrioritySet(TaskHandle_t handle, uint8_t priority);

BaseType_t uxTaskGetStackHighWaterMark2(TaskHandle_t handle);