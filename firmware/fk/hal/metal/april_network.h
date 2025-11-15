#pragma once

#if defined(__SAMD51__) && defined(FK_NETWORK_WINC1500_APRIL)

#include "hal/network.h"

namespace fk {

class Driver;
class UDPDiscovery;
class UDPServer;
class SimpleNTP;

class AprilNetwork : public Network {
private:
    Pool *pool_{ nullptr };
    Driver *driver_{ nullptr };
    UDPDiscovery *udp_discovery_{ nullptr };
    UDPServer *udp_server_{ nullptr };
    SimpleNTP *simple_ntp_{ nullptr };

public:
    Driver *driver() {
        return driver_;
    }

public:
    bool begin(NetworkSettings settings, Pool *pool) override;
    bool serve() override;
    NetworkStatus status() override;
    uint32_t udp_activity() const override;
    uint32_t ip_address() override;
    void service(Pool *pool) override;
    PoolPointer<NetworkConnection> *open_connection(const char *scheme, const char *hostname, uint16_t port) override;
    PoolPointer<NetworkListener> *listen(uint16_t port) override;
    NetworkUDP *create_udp(uint32_t ip, uint16_t port, Pool *pool) override;
    bool stop() override;
    bool enabled() override;
    bool synchronize_time() override;
    bool get_mac_address(uint8_t *address) override;
    const char *get_ssid() override;
    bool get_created_ap() override;
    NetworkScan scan(Pool &pool) override;
};

} // namespace fk

#endif