#pragma once

#if defined(__SAMD51__) && (defined(FK_NETWORK_WINC1500_WIFI101) || defined(FK_NETWORK_ESP32_WIFI101))

#include "exchange.h"
#include "hal/hal.h"
#include "hal/metal/simple_ntp.h"
#include "hal/metal/udp_discovery.h"
#include "hal/metal/udp_server.h"
#include "hal/metal/mdns.h"

#include <Arduino.h>
#include <SPI.h>
#include <WiFi101.h>
#include <WiFiUdp.h>

#if defined(FK_NETWORK_WINC1500_WIFI101)
#include <WiFiSocket.h>
#endif

namespace fk {

struct WifiBufferedWriter {
    uint8_t *buffer{ nullptr };
    size_t buffer_size{ 0 };
    size_t position{ 0 };
    WiFiClient *wcl{ nullptr };
    int32_t return_value{ 0 };
    int32_t flush();
};

class MetalNetworkConnection : public NetworkConnection {
private:
    WiFiClient wcl_;
    WifiBufferedWriter *buffered_writer_{ nullptr };
    bool debugging_{ false };
    uint8_t *buffer_{ nullptr };
    size_t size_{ 0 };
    size_t position_{ 0 };

public:
    MetalNetworkConnection();
    MetalNetworkConnection(Pool *pool, WiFiClient wcl);
    virtual ~MetalNetworkConnection() override;

public:
    NetworkConnectionStatus status() override;

    bool available() override;

    int32_t read(uint8_t *buffer, size_t size) override;

    int32_t write(const uint8_t *buffer, size_t size) override;

    int32_t writef(const char *str, ...) override;

    int32_t vwritef(const char *str, va_list args) override;

    int32_t write(const char *str) override;

    int32_t flush() override;

    int32_t try_flush_all(size_t bytes, uint32_t delay) override;

    uint32_t remote_address() override;

    bool stop() override;
};

class MetalNetworkListener : public NetworkListener {
private:
    uint16_t port_;
    WiFiServer server_{ port_ };

public:
    MetalNetworkListener(Pool *pool, uint16_t port);

public:
    bool begin();

    PoolPointer<NetworkConnection> *accept() override;

    bool stop() override;
};

class MetalNetworkUDP : public NetworkUDP {
private:
    WiFiUDP udp_;

public:
    bool initialize(uint32_t ip, uint16_t port);

public:
    int32_t begin(uint32_t ip, uint16_t port) override;
    int32_t write(uint8_t const *buffer, size_t size) override;
    int32_t flush() override;
    int32_t available() override;
    int32_t read(uint8_t *buffer, size_t size) override;
    uint32_t remote_ip() override;
    bool stop() override;
};

class MetalNetwork : public Network {
private:
    Availability availability_{ Availability::Unknown };
    Pool *pool_{ nullptr };
    NetworkSettings settings_;
    bool enabled_{ false };
    bool serving_{ false };
    WiFiServer server_{ 80 };
#if defined(FK_NETWORK_ENABLE_MDNS)
    MDNSDiscovery mdns_discovery_;
#endif
#if defined(FK_NETWORK_ENABLE_UDP_DISCOVERY)
    UDPDiscovery *udp_discovery_{ nullptr };
#endif
#if defined(FK_NETWORK_ENABLE_NTP)
    SimpleNTP *ntp_{ nullptr };
#endif
    UDPServer *udp_server_{ nullptr };
    uint8_t status_{ 0 };

public:
    uint32_t udp_activity() const override {
        if (udp_server_ != nullptr) {
            return udp_server_->activity();
        }
        return 0;
    }

protected:
    Pool &network_pool() {
        return *pool_;
    }

public:
    bool begin(NetworkSettings settings, Pool *pool) override;

    NetworkStatus status() override;

    bool serve() override;

    uint32_t ip_address() override;

    int32_t rssi() override;

    void service(Pool *pool) override;

    PoolPointer<NetworkConnection> *open_connection(const char *scheme, const char *hostname, uint16_t port) = 0;

    PoolPointer<NetworkListener> *listen(uint16_t port) override;

    NetworkUDP *create_udp(uint32_t ip, uint16_t port, Pool *pool) override;

    bool stop() override;

    bool enabled() override;

    bool synchronize_time() override;

    bool get_mac_address(uint8_t *address) override;

    const char *get_ssid() override;

    bool get_created_ap() override;

    NetworkScan scan(Pool &pool) override;

    void verify() override;

protected:
    virtual void disable() = 0;
    virtual void enable() = 0;

public:
    virtual bool start_ap(NetworkSettings settings) = 0;
    virtual bool connected() {
        return true;
    }

private:
    void check_status();
};

FK_ENABLE_TYPE_NAME(MetalNetworkConnection);
FK_ENABLE_TYPE_NAME(MetalNetworkListener);

} // namespace fk

#endif
