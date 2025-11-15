#pragma once

#include "os.h"
#include "pool.h"
#include "hal/metal/april_network.h"
#include "hal/hal.h"

#include "sockets.h"
#include "utilities.h"
#include "ipc.h"

namespace fk {

enum DriverState {
    DS_UNAVAILABLE,
    DS_READY,
    DS_CONNECTING,
    DS_ATTEMPTING_STATION,
    DS_ATTEMPTING_AP,
    DS_CONNECTED,
    DS_ERROR,
};

enum WifiMode {
    MODE_NONE,
    MODE_STATION,
    MODE_AP,
};

constexpr size_t MacAddressLength = 6;

constexpr size_t NetworkM2mTaskStackSize = 512;

constexpr size_t IpcMessageQueueLength = 10;

constexpr size_t NetworkM2mTaskPriority = FK_PRIORITY_NETWORK_M2M_TASK;

struct HostByIp {
    uint32_t ip{ 0 };
};

class Driver {
private:
    Pool *pool_{ nullptr };
    TaskHandle_t task_{ nullptr };
    QueueHandle_t queue_{ nullptr };
    SemaphoreMutex lock_;
    DriverState state_{ DriverState::DS_UNAVAILABLE };
    Sockets sockets_;
    WifiMode mode_{ WifiMode::MODE_NONE };
    uint8_t tries_{ 0 };
    uint32_t ip_address_{ 0 };
    uint8_t mac_address_[MacAddressLength];
    HostByIp resolved_{};

private:
    const char *ssid_{ nullptr };
    const char *password_{ nullptr };

public:
    Driver(Pool *pool);

public:
    int32_t wifi_handler(uint8_t message_type, void *message);
    int32_t socket_handler(SOCKET sock, uint8_t message_type, void *message);
    int32_t resolve_handler(uint8_t *host_name, uint32_t ip);
    int32_t service_task();
    Sockets *sockets() {
        return &sockets_;
    }
    const uint8_t *mac_address() const {
        return mac_address_;
    }
    WifiMode mode() const {
        return mode_;
    }

private:
    void queue_radio(IpcMessageType type);

public:
    bool begin(Pool *pool);
    bool service();
    bool join(const char *ssid, const char *password, WifiMode mode);
    bool stop();
    bool gethostbyname(const char *name, uint32_t &ip);

public:
    const char *ssid() const {
        return ssid_;
    }

    DriverState state() const {
        return state_;
    }

    uint32_t ip_address() const {
        return ip_address_;
    }

private:
    void enable();
    void disable();
};

} // namespace fk
