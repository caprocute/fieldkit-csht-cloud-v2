#include "tests.h"
#include "worker.h"
#include "collections.h"
#include "buffers.h"
#include "io.h"

using namespace fk;

FK_DECLARE_LOGGER("tests");

class BuffersSuite : public ::testing::Test {
protected:
};

class InfiniteReader : public Reader {
private:
    uint8_t index_{ 0 };

public:
    int32_t read(uint8_t *buffer, size_t size) override {
        for (auto i = 0u; i < size; ++i) {
            buffer[i] = index_++;
        }
        return size;
    }
};

TEST_F(BuffersSuite, Basic) {
    // log_configure_level(LogLevels::TRACE);

    StandardPool pool{ "top" };

    InfiniteReader infinite;
    LimitReader limited{ &infinite, 1024 };

    PoolBufferAllocator buffer_alloc{ &pool };
    CopyIntoBuffers copier{ &buffer_alloc };

    auto copied = copy_between(&limited, &copier, pool);

    ASSERT_EQ(copied, 1024);
    ASSERT_EQ(copier.head()->length(), 1024u);
}

TEST_F(BuffersSuite, CopyInto) {
    StandardPool pool{ "top" };

    auto buffer = pool.buffer(256);
    buffer->copy_into((uint8_t const *)"Hello", 5);
    buffer->copy_into((uint8_t const *)"World", 5);
    ASSERT_EQ(buffer->length(), 10u);
    ASSERT_EQ(memcmp(buffer->buffer(), "HelloWorld", 10), 0);
}