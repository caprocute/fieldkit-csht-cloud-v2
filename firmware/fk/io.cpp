#include <tiny_printf.h>
#include <algorithm>

#include "io.h"
#include "config.h"

namespace fk {

int32_t Writer::write_u8(uint8_t b) {
    return write(&b, 1);
}

int32_t Writer::write_u32(uint32_t value) {
    return write((uint8_t *)&value, sizeof(value));
}

int32_t Writer::write_u16(uint16_t value) {
    return write((uint8_t *)&value, sizeof(value));
}

int32_t Writer::write_buffers(BufferPtr *m) {
    if (m == nullptr || m->length() == 0) {
        return 0;
    }

    auto total = 0u;
    for (; m != nullptr; m = m->link()) {
        auto copied = 0u;
        while (copied < m->position()) {
            auto bytes_copied = write(m->buffer() + copied, m->position() - copied);
            if (bytes_copied < 0) {
                return -1;
            }
            if (bytes_copied > 0) {
                copied += bytes_copied;
            }
        }
        total += copied;
    }

    return total;
}

int32_t Writer::write_varint(uint32_t value) {
    uint8_t buffer[8] = { 0 };
    auto stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    pb_encode_varint(&stream, value);
    return write(buffer, stream.bytes_written);
}

BufferedWriter::BufferedWriter(Writer *writer, uint8_t *buffer, size_t size) : writer_(writer), buffer_(buffer), buffer_size_(size) {
}

BufferedWriter::~BufferedWriter() {
    flush();
}

int32_t BufferedWriter::write(uint8_t const *buffer, size_t size) {
    FK_ASSERT(buffer_size_ > 0);

    size_t wrote = 0;

    // NOTE We could avoid copying in here if the data being written is larger.

    while (wrote < size) {
        auto available = buffer_size_ - position_;
        if (available == 0) {
            return -1;
        }
        auto writing = std::min<size_t>(available, size - wrote);
        memcpy(buffer_ + position_, buffer + wrote, writing);
        wrote += writing;
        position_ += writing;
        if (position_ == buffer_size_) {
            flush();
        }
    }

    return wrote;
}

static void write_buffered_writer(char c, void *arg) {
    if (c != 0) {
        reinterpret_cast<BufferedWriter *>(arg)->write(c);
    }
}

int32_t BufferedWriter::write(const char *s, ...) {
    va_list args;
    va_start(args, s);
    auto r = tiny_vfctprintf(write_buffered_writer, this, s, args);
    va_end(args);
    return r;
}

int32_t BufferedWriter::write(char c) {
    buffer_[position_++] = c;
    if (position_ == buffer_size_) {
        return flush();
    }
    return 0;
}

int32_t BufferedWriter::flush() {
    if (writer_ == nullptr) {
        return -1;
    }
    if (position_ > 0) {
        // This assertion is probably obsolete. I need to cleanup the
        // PoolPointer work for NetworkConnections. At one point the cpool was
        // freeing connections while they were still in use and we'd see crashes
        // in here.
        FK_ASSERT(writer_ != nullptr);
        auto rv = writer_->write(buffer_, position_);
        position_ = 0;
        return rv;
    }
    return position_;
}

BufferedReader::BufferedReader(Reader *reader, uint8_t *buffer, size_t buffer_size, size_t bytes_read)
    : reader_(reader), buffer_(buffer), buffer_size_(buffer_size), bytes_read_(bytes_read) {
}

BufferedReader::~BufferedReader() {
}

int32_t BufferedReader::read(uint8_t *buffer, size_t size) {
    auto returning = 0u;
    while (returning < size) {
        auto available = bytes_read_ - position_;
        if (bytes_read_ == 0 || available == 0) {
            if (reader_ == nullptr) {
                return -1;
            }

            auto nread = reader_->read(buffer_, buffer_size_);
            if (nread <= 0) {
                return 0;
            }

            position_ = 0;
            bytes_read_ = nread;
        }

        auto reading = std::min<size_t>(bytes_read_ - position_, size - returning);
        memcpy(buffer + returning, buffer_ + position_, reading);
        position_ += reading;
        returning += reading;
    }

    return returning;
}

int32_t BufferedReader::skip(size_t bytes) {
    position_ += bytes;
    return position_ < bytes_read_ ? bytes : -1;
}

BufferedReader BufferedReader::beginning() const {
    return BufferedReader{ nullptr, buffer_, buffer_size_, bytes_read_ };
}

BufferedReader BufferedReader::remaining() const {
    BufferedReader reader{ nullptr, buffer_, buffer_size_, bytes_read_ };
    reader.skip(position_);
    return reader;
}

static bool write_callback(pb_ostream_t *stream, const uint8_t *buf, size_t c) {
    auto s = reinterpret_cast<Writer *>(stream->state);
    return s->write(buf, c) == (int32_t)c;
}

static bool read_callback(pb_istream_t *stream, uint8_t *buf, size_t c) {
    auto s = reinterpret_cast<Reader *>(stream->state);
    auto nread = s->read(buf, c);
    if (nread <= 0) {
        stream->bytes_left = 0; /* EOF */
    }
    return nread == (int32_t)c;
}

Buffer::Buffer(uint8_t *ptr, size_t size) : ptr_(ptr), size_(size), position_(0) {
}

Buffer::Buffer(BufferPtr *encoded) : ptr_(encoded->take()), size_(encoded->size()), position_(0) {
}

void Buffer::write(char c) {
    FK_ASSERT(position_ < size_);
    ptr_[position_++] = c;
}

bool Buffer::full() const {
    return position_ == size_;
}

void Buffer::clear() {
    position_ = 0;
}

int32_t Buffer::read(uint8_t *buffer, size_t size) {
    auto reading = std::min<int32_t>(size, size_ - position_);
    memcpy(buffer, ptr_ + position_, reading);
    position_ += reading;
    return reading;
}

SerializedRecordReader::SerializedRecordReader(pb_msgdesc_t const *fields, void const *record, Pool &pool)
    : buffer_{ pool.encode(fields, record) } {
}

int32_t SerializedRecordReader::read(uint8_t *buffer, size_t size) {
    return buffer_.read(buffer, size);
}

LimitReader::LimitReader(Reader *reader, size_t length) : reader_(reader), remaining_(length) {
}

int32_t LimitReader::read(uint8_t *buffer, size_t size) {
    if (remaining_ == 0) {
        return 0;
    }

    auto reading = std::min(size, remaining_);
    auto read = reader_->read(buffer, reading);
    if (read == -1) {
        return -1;
    }
    remaining_ -= read;
    return read;
}

CopyIntoBuffers::CopyIntoBuffers(BufferAllocator *buffer_alloc) : buffer_alloc_(buffer_alloc), head_(nullptr), position_(0) {
}

int32_t CopyIntoBuffers::write(uint8_t const *buffer, size_t size) {
    if (head_ == nullptr) {
        head_ = buffer_alloc_->allocate();
    }

    auto remaining = size;
    while (remaining != 0) {
        auto copy = head_->copy_into(buffer + (size - remaining), remaining);
        FK_ASSERT(copy.copied > 0 || copy.necessary > 0);
        if (copy.necessary > 0) {
            head_->append(buffer_alloc_->allocate());
        }
        if (copy.copied > 0) {
            position_ += copy.copied;
            remaining -= copy.copied;
        }
    }

    return size;
}

pb_ostream_t pb_ostream_from_writable(Writer *s) {
    pb_ostream_t stream = { &write_callback, (void *)s, SIZE_MAX, 0 };
    return stream;
}

pb_istream_t pb_istream_from_readable(Reader *s, size_t bytes_left) {
    pb_istream_t stream = { &read_callback, (void *)s, bytes_left };
    return stream;
}

int32_t copy_between(Reader *reader, Writer *writer, uint8_t *buffer, size_t size) {
    int32_t copied = 0;

    while (true) {
        auto bytes_read = reader->read(buffer, size);
        if (bytes_read <= 0) {
            break;
        }

        auto bytes_wrote = 0;
        while (bytes_wrote <= bytes_read) {
            auto writing = bytes_read - bytes_wrote;
            auto wrote = writer->write(buffer + bytes_wrote, writing);
            if (wrote <= 0) {
                break;
            }

            bytes_wrote += wrote;
            copied += wrote;
        }
    }

    return copied;
}

int32_t copy_between(Reader *reader, Writer *writer, Pool &pool) {
    auto temporary_buffer = (uint8_t *)pool.malloc(LinkedBufferSize);
    return copy_between(reader, writer, temporary_buffer, LinkedBufferSize);
}

} // namespace fk
