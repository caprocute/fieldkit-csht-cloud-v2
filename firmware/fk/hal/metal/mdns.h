#pragma once

#if defined(__SAMD51__) && (defined(FK_NETWORK_WINC1500_WIFI101) || defined(FK_NETWORK_ESP32_WIFI101))

#include <WiFi101.h>
#include <WiFiUdp.h>
#include <ArduinoMDNS.h>

#include "common.h"
#include "pool.h"

namespace fk {

#undef min
#undef max
#undef abs

class MDNSDiscovery {
private:
    Pool *pool_;
    WiFiUDP udp_;
    MDNS mdns_{ udp_ };
    bool initialized_{ false };
    uint32_t registered_{ 0 };
    uint32_t publish_{ 0 };
    char service_name_[64];
    char name_[64];

public:
    MDNSDiscovery();
    virtual ~MDNSDiscovery();

public:
    void pool(Pool *pool) {
        pool_ = pool;
    }

public:
    bool start();
    bool service(Pool *pool);
    void stop();
};

} // namespace fk

#endif
