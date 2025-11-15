#pragma once

#if defined(__SAMD51__)
#include "common.h"
#include "hal/network.h"

namespace fk {

class SimpleNTP {
private:
    NetworkUDP *udp_{ nullptr };
    uint8_t index_{ 0 };
    bool initialized_{ false };
    uint32_t queried_{ 0 };
    uint32_t synced_{ 0 };

public:
    SimpleNTP(NetworkUDP *udp);
    virtual ~SimpleNTP();

public:
    void pool(Pool *pool) {
    }

public:
    void start();
    bool service();
    void stop();

private:
    bool send();
};

} // namespace fk

#endif // defined(__SAMD51__)
