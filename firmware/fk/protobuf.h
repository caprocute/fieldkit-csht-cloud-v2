#pragma once

#include <pb_decode.h>
#include <pb_encode.h>

#include "pool.h"
#include "utilities.h"

namespace fk {

struct pb_array_t;

typedef bool (*pb_decode_array_item)(pb_istream_t *stream, pb_array_t *array);

bool pb_encode_string(pb_ostream_t *stream, const pb_field_t *field, void *const *arg);

bool pb_decode_string(pb_istream_t *stream, const pb_field_t *field, void **arg);

typedef struct pb_array_t {
    size_t length;
    size_t allocated;
    size_t item_size;
    void *buffer;
    const pb_msgdesc_t *fields;
    pb_decode_array_item decode_item_fn;
    Pool *pool;

    template <typename T> T *item(size_t index) {
        return &reinterpret_cast<T *>(buffer)[index];
    }
} pb_array_t;

bool pb_encode_array(pb_ostream_t *stream, const pb_field_t *field, void *const *arg);

bool pb_encode_uint32_array(pb_ostream_t *stream, const pb_field_t *field, void *const *arg);

bool pb_decode_array(pb_istream_t *stream, const pb_field_t *field, void **arg);

size_t pb_append_array(pb_array_t *array, void const *item);

bool pb_encode_buffer_ptr(pb_ostream_t *stream, const pb_field_t *field, void *const *arg);

typedef struct pb_data_t {
    size_t length;
    const void *buffer;
} pb_data_t;

pb_data_t *pb_data_allocate(Pool *pool, size_t size);

bool pb_encode_data(pb_ostream_t *stream, const pb_field_t *field, void *const *arg);

bool pb_decode_data(pb_istream_t *stream, const pb_field_t *field, void **arg);

size_t pb_varint_size(uint32_t value);

const char *pb_get_string_if_provided(void *arg, Pool const *pool);

pb_data_t *pb_get_data_if_provided(void *arg, Pool const *pool);

inline pb_array_t *pb_set_array_encode(pb_callback_s &callbacks, pb_array_t *array) {
    callbacks.funcs.encode = pb_encode_array;
    callbacks.arg = (void *)array;
    return array;
}

inline pb_array_t *pb_get_array(pb_callback_s &callbacks, Pool const *pool) {
    return (pb_array_t *)callbacks.arg;
}

template <typename T> inline T *pb_get_typed_array(pb_array_t *array) {
    return reinterpret_cast<T *>(array->buffer);
}

const char *pb_data_to_hex_string(pb_data_t const *data, Pool &pool);

template <typename T> pb_data_t *pb_data_create(T const &data, Pool &pool) {
    return pb_data_create(&data, sizeof(T), pool);
}

pb_data_t *pb_data_create(void const *data, size_t size, Pool &pool);

bool pb_encode_logs(pb_ostream_t *stream, const pb_field_t *field, void *const *arg);

template <typename T> pb_array_t *fk_array_new_protobuf(pb_msgdesc_t const *fields, Pool *pool) {
    auto array = pool->malloc<pb_array_t>();
    array->length = 0;
    array->allocated = 0;
    array->item_size = sizeof(T);
    array->buffer = nullptr;
    array->fields = fields;
    array->pool = pool;
    return array;
}

} // namespace fk
