#pragma once

#include <cstdlib>
#include <cstdint>

namespace fk {

struct copy_into_t {
    size_t copied{ 0 };
    size_t necessary{ 0 };

    copy_into_t(size_t copied, size_t necessary) : copied(copied), necessary(necessary) {
    }
};

class BufferPtr {
private:
    size_t size_{ 0 };
    size_t position_{ 0 };
    uint8_t *buffer_{ nullptr };
    BufferPtr *link_{ nullptr };

public:
    BufferPtr() {
    }

    BufferPtr(size_t size, size_t position, uint8_t *buffer) : size_(size), position_(position), buffer_(buffer) {
    }

    BufferPtr(size_t size, size_t position, uint8_t *buffer, BufferPtr *link)
        : size_(size), position_(position), buffer_(buffer), link_(link) {
    }

public:
    bool solo() const {
        return link_ == nullptr;
    }

    bool empty() const {
        return size_ == 0 || position_ == 0;
    }

    bool full() const {
        return size_ == position_;
    }

    size_t size() const {
        return size_;
    }

    size_t position() const {
        return position_;
    }

    uint8_t *take() {
        auto buffer = buffer_;
        buffer_ = nullptr;
        return buffer;
    }

    uint8_t const *buffer() const {
        return buffer_;
    }

    BufferPtr *link() const {
        return link_;
    }

    size_t append(BufferPtr *tail);

    size_t length() const;

    copy_into_t copy_into(uint8_t const *source, size_t size);

    void clear();
};

class Pool;

class BufferAllocator {
public:
    virtual BufferPtr *allocate() = 0;
};

class PoolBufferAllocator : public BufferAllocator {
private:
    Pool *pool_{ nullptr };

public:
    PoolBufferAllocator(Pool *pool);

public:
    BufferPtr *allocate() override;
};

class BufferChain : public BufferAllocator {
private:
    Pool *pool_{ nullptr };
    BufferPtr *head_{ nullptr };

public:
    BufferChain();
    BufferChain(Pool *pool);

public:
    BufferPtr *allocate() override;

public:
    void head(BufferPtr *head);

    BufferPtr const *head() const {
        return head_;
    }

    size_t length() const {
        if (head_ == nullptr) {
            return 0;
        }
        return head_->length();
    }

    void clear();
};

} // namespace fk
