#pragma once

#include "os.h"
#include "pool.h"

namespace fk {

typedef struct LinkedBuffer {
    uint16_t size;
    uint16_t filled;
    uint16_t position;
    LinkedBuffer *np;
    uint8_t *ptr;

    static LinkedBuffer *append(LinkedBuffer *head, LinkedBuffer *tail) {
        if (head == nullptr) {
            return tail;
        } else {
            for (LinkedBuffer *iter = head;; iter = iter->np) {
                if (iter->np == nullptr) {
                    iter->np = tail;
                    tail->np = nullptr;
                    break;
                }
            }
            return head;
        }
    }

    LinkedBuffer *tail() {
        if (np == nullptr) {
            return this;
        } else {
            return np->tail();
        }
    }

    bool is_filled() const {
        return filled == size;
    }
} LinkedBuffer;

class LinkedBuffers {
private:
    LinkedBuffer *free_{ nullptr };

public:
    LinkedBuffers(size_t buffers, size_t buffer_size, Pool *pool);
    virtual ~LinkedBuffers();

public:
    LinkedBuffer *get();
    void free(LinkedBuffer *lb);
};

class SemaphoreMutex {
private:
    StaticSemaphore_t static_;
    SemaphoreHandle_t handle_{ nullptr };

public:
    SemaphoreMutex();
    virtual ~SemaphoreMutex();

public:
    bool give();
    bool take(uint32_t to);
};

template <size_t length, size_t item_size> class Queue {
private:
    StaticQueue_t static_;
    QueueHandle_t handle_{ nullptr };
    uint8_t buffer_[length * item_size];

public:
    Queue() {
        handle_ = xQueueCreateStatic(length, item_size, &buffer_, &static_);
    }

    virtual ~Queue() {
    }
};

constexpr uint32_t SOCKET_TIMEOUT = 5000;

class WaitingLoop {
private:
    uint32_t counter_{ SOCKET_TIMEOUT / 10 };

public:
    bool check();
};

const char *sta_cmd_to_string(uint8_t cmd);

} // namespace fk
