#include "exchange.h"
#include "state/dynamic.h"

namespace fk {

namespace state {

#define FK_MESSAGES_MAX 10

FK_DECLARE_LOGGER("state");

DynamicState::DynamicState()
    : pool_{ create_standard_pool_inside("modules-state") }, events_{ pool_->subpool("events", LinkedBufferSize) } {
    attached_ = new (pool_) state::AttachedModules{ *pool_ };
}

DynamicState::DynamicState(DynamicState &&rhs)
    : pool_(exchange(rhs.pool_, nullptr)), attached_(exchange(rhs.attached_, nullptr)), events_(rhs.events_) {
}

DynamicState::~DynamicState() {
    if (pool_ != nullptr) {
        delete pool_;
        pool_ = nullptr;
        attached_ = nullptr;
    }
}

DynamicState &DynamicState::operator=(DynamicState &&rhs) {
    alogf(LogLevels::INFO, "dynamic", "attaching");

    if (this != &rhs) {
        if (pool_ != nullptr) {
            delete pool_;
            pool_ = nullptr;
            attached_ = nullptr;
            events_ = {};
            messages_ = {};
        }
        pool_ = rhs.pool_;
        rhs.pool_ = nullptr;
        attached_ = rhs.attached_;
        rhs.attached_ = nullptr;
        events_ = rhs.events_;
        rhs.events_ = {};
        messages_ = rhs.messages_;
        rhs.messages_ = {};
    }

    return *this;
}

size_t MessageCenter::number_added_after(uint32_t time) const {
    auto n = 0u;
    for (auto i = head_; i != nullptr; i = i->np) {
        if (i->time > time) {
            n++;
        }
    }
    return n;
}

Message *MessageCenter::allocate(const char *body, Pool *pool) {
    auto m = new (pool) Message;
    m->body = pool->strdup(body);
    m->time = fk_uptime();
    m->np = nullptr;
    return m;
}

void MessageCenter::add_message(const char *body, Pool *pool) {
    if (head_ == nullptr) {
        head_ = allocate(body, pool);
    } else {
        for (auto i = head_;; i = i->np) {
            // If there's already a message with this body, bump that one's time
            // to avoid useless duplicates. If the # is important, we could keep
            // a quantity here.
            if (strcmp(i->body, body) == 0) {
                i->time = fk_uptime();
                break;
            }
            if (i->np == nullptr) {
                i->np = allocate(body, pool);
                break;
            }
        }
    }
}

MessageCenter MessageCenter::copy(Pool *pool) {
    auto total = length();
    auto skip = total > FK_MESSAGES_MAX ? total - FK_MESSAGES_MAX : 0;
    logwarn("lots of messages (%d) truncating to %d", total, FK_MESSAGES_MAX);

    Message *new_head = nullptr;
    Message *new_tail = nullptr;
    for (auto i = head_; i != nullptr; i = i->np) {
        if (skip > 0) {
            skip--;
        } else {
            auto copy = new (pool) Message;
            copy->body = pool->strdup(i->body);
            copy->time = i->time;
            copy->np = nullptr;
            if (new_tail == nullptr) {
                new_head = copy;
                new_tail = copy;
            } else {
                new_tail->np = copy;
                new_tail = copy;
            }
        }
    }
    return { new_head };
}

} // namespace state

} // namespace fk
