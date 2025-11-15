#pragma once

#include <inttypes.h>

namespace fk {

class Activity {
private:
    uint32_t touched_{ 0 };

public:
    Activity() {
    }

    Activity(uint32_t touched) : touched_(touched) {
    }

public:
    void touch(uint32_t touched) {
        touched_ = touched;
    }

    virtual bool start_network() {
        return false;
    }
};

} // namespace fk
