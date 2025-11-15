#pragma once

#include "common.h"
#include "utilities.h"
#include "../fk/utilities.h"
#include "storage/storage.h"

using namespace fk;

struct StaticPattern {
    uint8_t data[256];

    StaticPattern(uint8_t value = 0xcc) {
        memset(data, value, sizeof(data));
    }
};

struct SequentialPattern {
    uint8_t data[256];
};
