#pragma once

#include "state/modules.h"

namespace fk {

namespace state {

class Message {
public:
    // TODO Include l10n index to ease memory overhead when possible.
    uint32_t time{ 0 };
    const char *body{ nullptr };
    Message *np{ nullptr };
};

class MessageCenter {
public:
    Message *head_{ nullptr };
    uint32_t opened_{ 0 };

public:
    MessageCenter() {
    }

protected:
    MessageCenter(Message *head) : head_(head), opened_(0) {
    }

public:
    Message const *get_first_message() const {
        return head_;
    }

    size_t number_added_after_last_open() const {
        return number_added_after(opened_);
    }

    size_t length() const {
        return number_added_after(0);
    }

    size_t number_added_after(uint32_t time) const;

    void add_message(const char *body, Pool *pool);

    MessageCenter copy(Pool *pool);

private:
    Message *allocate(const char *body, Pool *pool);
};

class DynamicState {
private:
    Pool *pool_{ nullptr };
    AttachedModules *attached_{ nullptr };
    BufferChain events_;
    MessageCenter messages_;

public:
    DynamicState();
    DynamicState(DynamicState &&rhs);
    virtual ~DynamicState();

public:
    AttachedModules *attached() const {
        return attached_;
    }

public:
    BufferChain const *events() const {
        return &events_;
    }

    BufferChain *events() {
        return &events_;
    }

    void events_from(DynamicState &other) {
        events_ = pool_->copy(other.events_);
        messages_ = other.messages_.copy(pool_);
    }

public:
    void add_message(const char *body) {
        messages_.add_message(body, pool_);
    }

    void mark_messages_opened() {
        messages_.opened_ = fk_uptime();
    }

    MessageCenter const &messages() const {
        return messages_;
    }

public:
    DynamicState &operator=(DynamicState &&rhs);
};

} // namespace state

} // namespace fk
