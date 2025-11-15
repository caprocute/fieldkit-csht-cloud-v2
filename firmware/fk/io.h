#pragma once

#include <pb_decode.h>
#include <pb_encode.h>

#include "common.h"
#include "buffers.h"
#include "pool.h"

namespace fk {

class Writer {
public:
    virtual int32_t write(uint8_t const *buffer, size_t size) = 0;

public:
    int32_t write_u8(uint8_t b);
    int32_t write_u32(uint32_t value);
    int32_t write_u16(uint16_t value);
    int32_t write_buffers(BufferPtr *m);
    int32_t write_varint(uint32_t value);
};

class Reader {
public:
    virtual int32_t read(uint8_t *buffer, size_t size) = 0;
};

class BufferedWriter : public Writer {
private:
    Writer *writer_;
    uint8_t *buffer_;
    size_t buffer_size_;
    size_t position_{ 0 };
    int32_t return_value_{ 0 };

public:
    BufferedWriter(Writer *writer, uint8_t *buffer, size_t size);
    virtual ~BufferedWriter();

public:
    size_t position() const {
        return position_;
    }

public:
    int32_t write(uint8_t const *buffer, size_t size) override;
    int32_t write(const char *s, ...);
    int32_t write(char c);
    int32_t flush();
};

class BufferedReader : public Reader {
private:
    Reader *reader_;
    uint8_t *buffer_;
    size_t buffer_size_;
    size_t position_{ 0 };
    size_t bytes_read_{ 0 };

public:
    BufferedReader(Reader *reader, uint8_t *buffer, size_t buffer_size, size_t bytes_read = 0);
    virtual ~BufferedReader();

public:
    BufferedReader beginning() const;
    BufferedReader remaining() const;

public:
    int32_t read(uint8_t *buffer, size_t size) override;
    int32_t skip(size_t bytes);
    int32_t reset() {
        position_ = 0;
        bytes_read_ = 0;
        return 0;
    }

    bool rewind(int32_t bytes) {
        FK_ASSERT(bytes > 0);
        FK_ASSERT(position_ >= (size_t)bytes);
        position_ -= bytes;
        return true;
    }

    size_t bytes_read() const {
        return bytes_read_;
    }

    size_t position() const {
        return position_;
    }

    size_t available() const {
        return buffer_size_ - position_;
    }
};

class LimitReader : public Reader {
private:
    Reader *reader_{ nullptr };
    size_t remaining_{ 0 };

public:
    LimitReader(Reader *reader, size_t length);

public:
    int32_t read(uint8_t *buffer, size_t size) override;
};

template <size_t Size> class StackBufferedWriter : public BufferedWriter {
private:
    uint8_t buffer_[Size]{};

public:
    explicit StackBufferedWriter(Writer *writer) : BufferedWriter(writer, buffer_, Size) {
    }
};

class Buffer : public Reader {
private:
    uint8_t *ptr_;
    size_t size_;
    size_t position_;

public:
    Buffer(uint8_t *ptr, size_t size);
    Buffer(BufferPtr *encoded);

public:
    const uint8_t *ptr() const {
        return ptr_;
    }

    size_t position() const {
        return position_;
    }

public:
    void write(char c);
    bool full() const;
    void clear();

public:
    int32_t read(uint8_t *buffer, size_t size) override;
};

class SerializedRecordReader : public Reader {
private:
    Buffer buffer_;

public:
    SerializedRecordReader(pb_msgdesc_t const *fields, void const *record, Pool &pool);

public:
    int32_t read(uint8_t *buffer, size_t size) override;
};

class CopyIntoBuffers : public Writer {
private:
    BufferAllocator *buffer_alloc_{ nullptr };
    BufferPtr *head_{ nullptr };
    size_t position_{ 0 };

public:
    CopyIntoBuffers(BufferAllocator *buffer_alloc);

public:
    BufferPtr *head() {
        return head_;
    }

public:
    int32_t write(uint8_t const *buffer, size_t size) override;
};

pb_ostream_t pb_ostream_from_writable(Writer *s);

pb_istream_t pb_istream_from_readable(Reader *s, size_t bytes_left = SIZE_MAX);

int32_t copy_between(Reader *reader, Writer *writer, uint8_t *buffer, size_t size);

int32_t copy_between(Reader *reader, Writer *writer, Pool &pool);

} // namespace fk
