#include <cstring>

#include <Arduino.h>
#include <FreeRTOS_SAMD51.h>

IPAddress::IPAddress() {
    _address.dword = 0;
}

IPAddress::IPAddress(uint8_t first_octet, uint8_t second_octet, uint8_t third_octet, uint8_t fourth_octet) {
    _address.bytes[0] = first_octet;
    _address.bytes[1] = second_octet;
    _address.bytes[2] = third_octet;
    _address.bytes[3] = fourth_octet;
}

IPAddress::IPAddress(uint32_t address) {
    _address.dword = address;
}

IPAddress::IPAddress(const uint8_t *address) {
    memcpy(_address.bytes, address, sizeof(_address.bytes));
}

IPAddress &IPAddress::operator=(const uint8_t *address) {
    memcpy(_address.bytes, address, sizeof(_address.bytes));
    return *this;
}

IPAddress &IPAddress::operator=(uint32_t address) {
    _address.dword = address;
    return *this;
}

bool IPAddress::operator==(const uint8_t *addr) const {
    return memcmp(addr, _address.bytes, sizeof(_address.bytes)) == 0;
}

void delay(uint32_t ms) {
}

eTaskState eTaskGetState(TaskHandle_t handle) {
    return eDeleted;
}

BaseType_t xTaskGetSchedulerState() {
    return taskSCHEDULER_NOT_STARTED;
}

TaskHandle_t xTaskCreateStatic(void (*handler)(void *), const char *name, uint32_t stack_size, void *params, uint8_t priority, void *stack,
                               StaticTask_t *buffer) {
    return NULL;
}

void vTaskDelete(TaskHandle_t handle) {
}

TaskHandle_t xTaskGetCurrentTaskHandle() {
    return NULL;
}

QueueHandle_t xQueueCreateStatic(uint32_t size, uint32_t item_size, uint8_t *buffer, StaticQueue_t *queue) {
    return NULL;
}

BaseType_t xQueueSendToBackFromISR(QueueHandle_t queue, void *ptr, void *task) {
    return 0;
}

BaseType_t xQueueSendToBack(QueueHandle_t queue, void *ptr, uint32_t to) {
    return 0;
}

BaseType_t xQueueReceive(QueueHandle_t queue, void *ptr, uint32_t to) {
    return 0;
}

SemaphoreHandle_t xSemaphoreCreateRecursiveMutexStatic(StaticSemaphore_t *semaphore) {
    return NULL;
}

SemaphoreHandle_t xSemaphoreCreateBinaryStatic(StaticSemaphore_t *semaphore) {
    return NULL;
}

BaseType_t xSemaphoreTake(SemaphoreHandle_t handle, uint32_t to) {
    return 0;
}

BaseType_t xSemaphoreGive(SemaphoreHandle_t handle) {
    return 0;
}

BaseType_t xSemaphoreTakeRecursive(SemaphoreHandle_t handle, uint32_t to) {
    return 0;
}

BaseType_t xSemaphoreGiveRecursive(SemaphoreHandle_t handle) {
    return 0;
}

char *pcTaskGetName(TaskHandle_t handle) {
    return NULL;
}

void vTaskStartScheduler() {
}

void vTaskDelay(uint32_t ms) {
}

uint8_t uxTaskPriorityGet(TaskHandle_t handle) {
    return 0;
}

void vTaskPrioritySet(TaskHandle_t handle, uint8_t priority) {
}

BaseType_t uxTaskGetStackHighWaterMark2(TaskHandle_t handle) {
    return 0;
}
