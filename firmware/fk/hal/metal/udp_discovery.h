#pragma once

#if defined(__SAMD51__)
#include "common.h"
#include "records.h"

namespace fk {

class UDPDiscovery {
private:
    Pool *pool_{ nullptr };
    bool initialized_{ false };
    uint32_t publish_{ 0 };
    uint32_t receive_{ 0 };

public:
    UDPDiscovery();
    virtual ~UDPDiscovery();

public:
    void pool(Pool *pool) {
        pool_ = pool;
    }

public:
    bool start();
    bool service(Pool *pool);
    void stop();

public:
    bool send(fk_app_UdpStatus status, Pool *pool);
};

} // namespace fk

#endif // defined(__SAMD51__)
