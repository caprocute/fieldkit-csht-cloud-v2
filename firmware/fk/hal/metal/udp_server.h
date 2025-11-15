#pragma once

#if defined(__SAMD51__)
#include "common.h"
#include "records.h"
#include "hal/network.h"

namespace fk {

class OpenStorageSession;

class UDPServer {
private:
    Pool *pool_{ nullptr };
    NetworkUDP *udp_{ nullptr };
    bool initialized_{ false };
    uint32_t activity_{ 0 };

public:
    UDPServer(NetworkUDP *udp);
    virtual ~UDPServer();

public:
    void pool(Pool *pool) {
        pool_ = pool;
    }

    uint32_t activity() const {
        return activity_;
    }

public:
    bool start();
    bool service(Pool *pool);
    void stop();
};

} // namespace fk

#endif // defined(__SAMD51__)
