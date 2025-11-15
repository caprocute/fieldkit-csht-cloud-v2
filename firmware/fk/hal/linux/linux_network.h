#pragma once

#if !defined(__SAMD51__)

#include "hal/hal.h"

namespace fk {

class LinuxNetworkConnection : public NetworkConnection {
private:
    int32_t s_;
    uint32_t remote_address_;

public:
    LinuxNetworkConnection();
    LinuxNetworkConnection(Pool *pool, int32_t s, uint32_t remote_address);
    ~LinuxNetworkConnection() override;

public:
    NetworkConnectionStatus status() override;

    bool available() override;

    int32_t read(uint8_t *buffer, size_t size) override;

    int32_t write(const uint8_t *buffer, size_t size) override;

    int32_t writef(const char *str, ...) override;

    int32_t vwritef(const char *str, va_list args) override;

    int32_t write(const char *str) override;

    int32_t flush() override {
        return 0;
    }

    int32_t try_flush_all(size_t bytes, uint32_t delay) override {
        return bytes;
    }

    uint32_t remote_address() override;

    bool stop() override;
};

class LinuxNetworkListener : public NetworkListener {
private:
    uint16_t port_;
    int32_t listening_;

public:
    LinuxNetworkListener(Pool *pool, uint16_t port, int32_t listening);

public:
    PoolPointer<NetworkConnection> *accept() override;

    bool stop() override;
};

class LinuxNetwork : public Network {
private:
    bool enabled_{ false };
    NetworkSettings settings_;
    int32_t listening_;

public:
    bool begin(NetworkSettings settings, Pool *pool) override;

    NetworkStatus status() override;

    bool serve() override;

    uint32_t udp_activity() const override {
        return 0;
    }

    uint32_t ip_address() override;

    void service(Pool *pool) override;

    PoolPointer<NetworkConnection> *open_connection(const char *scheme, const char *hostname, uint16_t port) override;

    PoolPointer<NetworkListener> *listen(uint16_t port) override;

    NetworkUDP *create_udp(uint32_t ip, uint16_t port, Pool *pool) {
        return nullptr;
    }

    bool stop() override;

    bool enabled() override;

    bool synchronize_time() override;

    bool get_mac_address(uint8_t *address) override;

    const char *get_ssid() override;

    bool get_created_ap() override;

    NetworkScan scan(Pool &pool) override;

    void verify();
};

FK_ENABLE_TYPE_NAME(LinuxNetworkConnection);
FK_ENABLE_TYPE_NAME(LinuxNetworkListener);

} // namespace fk

#endif
