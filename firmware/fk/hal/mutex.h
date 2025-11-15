#pragma once

#include "common.h"

namespace fk {

class Releasable {
public:
    virtual bool release(uint32_t elapsed, bool exclusive) = 0;
};

class Lock {
private:
    bool exclusive_{ true };
    Releasable *releasable_;
    uint32_t acquired_{ 0 };

public:
    explicit Lock();
    explicit Lock(bool exclusive, Releasable *releasable);
    Lock(Lock &&rhs);
    virtual ~Lock();

public:
    Lock &operator=(Lock &&rhs) {
        if (this != &rhs) {
            exclusive_ = rhs.exclusive_;
            releasable_ = rhs.releasable_;
            rhs.releasable_ = nullptr;
            acquired_ = rhs.acquired_;
            rhs.acquired_ = 0;
        }
        return *this;
    }

public:
    operator bool() {
        return releasable_ != nullptr;
    }
};

class Mutex;
class Lock;

class Mutex : public Releasable {
public:
    virtual bool create() = 0;
    virtual Lock acquire(uint32_t to) = 0;

public:
    template <typename TReturn, typename TFn> TReturn with(TFn work) {
        auto lock = this->acquire(UINT32_MAX);
        return work();
    }
};

class RwLock : public Releasable {
public:
    virtual bool create() = 0;
    virtual Lock acquire_read(uint32_t to) = 0;
    virtual Lock acquire_write(uint32_t to) = 0;
};

class NoopMutex : public Mutex {
public:
    bool create() override {
        return true;
    }

    Lock acquire(uint32_t to) override {
        return Lock{ false, this };
    }

    bool release(uint32_t elapsed, bool exclusive) override {
        return true;
    }
};

} // namespace fk
