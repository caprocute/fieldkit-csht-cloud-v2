#include <algorithm>

#include "buffers.h"
#include "pool.h"
#include "config.h"

namespace fk {

size_t BufferPtr::append(BufferPtr *tail) {
    size_t length = 0u;

    auto ptr = this;
    for (; ptr->link_ != nullptr; ptr = ptr->link_) {
        length += ptr->position_;
    }
    ptr->link_ = tail;
    length += tail->position_;

    return length;
}

size_t BufferPtr::length() const {
    if (link_ == nullptr) {
        return position_;
    }
    return position_ + link_->length();
}

void BufferPtr::clear() {
    position_ = 0;
}

copy_into_t BufferPtr::copy_into(uint8_t const *source, size_t size) {
    auto tail = this;
    while (tail->full()) {
        if (tail->link_ == nullptr) {
            return copy_into_t{ 0, size };
        }
        tail = tail->link_;
    }

    auto available = tail->size_ - tail->position_;
    if (available == 0) {
        return copy_into_t{ 0, size };
    }
    auto copying = std::min(available, size);
    if (copying > 0) {
        memcpy(tail->buffer_ + tail->position_, source, copying);
        tail->position_ += copying;
    }

    return copy_into_t{ copying, 0 };
}

PoolBufferAllocator::PoolBufferAllocator(Pool *pool) : pool_(pool) {
}

BufferPtr *PoolBufferAllocator::allocate() {
    auto buffer = (uint8_t *)pool_->malloc(LinkedBufferSize);
    return pool_->wrap(buffer, LinkedBufferSize, 0);
}

BufferChain::BufferChain() {
}

BufferChain::BufferChain(Pool *pool) : pool_(pool), head_(nullptr) {
}

BufferPtr *BufferChain::allocate() {
    PoolBufferAllocator allocator{ pool_ };
    return allocator.allocate();
}

void BufferChain::head(BufferPtr *head) {
    head_ = head;
}

void BufferChain::clear() {
    pool_->clear();
    head_ = nullptr;
}

} // namespace fk