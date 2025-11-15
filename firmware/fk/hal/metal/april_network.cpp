#if defined(__SAMD51__) && defined(FK_NETWORK_WINC1500_APRIL)

#include "hal/metal/april_network.h"
#include "hal/hal.h"

#include "records.h"
#include "m2m/driver.h"
#include "m2m/sockets.h"

#include "hal/metal/udp_discovery.h"
#include "hal/metal/udp_server.h"
#include "hal/metal/simple_ntp.h"

FK_DECLARE_LOGGER("network");

namespace fk {

class Listener : public NetworkListener {
private:
    Sockets *sockets_{ nullptr };
    SOCKET sock_;

public:
    Listener(Pool *pool, Sockets *sockets, SOCKET sock) : sockets_(sockets), sock_(sock) {
    }

public:
    PoolPointer<NetworkConnection> *accept() override;
    bool stop() override;
};

class AprilConnection : public NetworkConnection {
private:
    Sockets *sockets_{ nullptr };
    SOCKET sock_;

public:
    AprilConnection(Pool *pool, Sockets *sockets, SOCKET sock) : sockets_(sockets), sock_(sock) {
    }

public:
    NetworkConnectionStatus status() override;
    virtual bool available() override;
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

FK_ENABLE_TYPE_NAME(AprilConnection);

class AprilUDP : public NetworkUDP {
private:
    Sockets *sockets_{ nullptr };
    SOCKET sock_{ -1 };
    uint32_t to_ip_{ 0 };
    uint16_t to_port_{ 0 };

public:
    AprilUDP(Sockets *sockets, SOCKET sock) : sockets_(sockets), sock_(sock) {
    }

public:
    int32_t begin(uint32_t ip, uint16_t port) override;
    int32_t write(uint8_t const *buffer, size_t size) override;
    int32_t flush() override;
    int32_t available() override;
    int32_t read(uint8_t *buffer, size_t size) override;
    uint32_t remote_ip() override;
    bool stop() override;
};

bool AprilNetwork::begin(NetworkSettings settings, Pool *pool) {
    FK_ASSERT(driver_ == nullptr);

    loginfo("begin");

    if (false) {
        loginfo("sizeof(AprilNetwork) = %d", sizeof(AprilNetwork));
        loginfo("sizeof(Driver) = %d", sizeof(Driver));
        loginfo("sizeof(Sockets) = %d", sizeof(Sockets));
        loginfo("sizeof(IpcMessage) = %d", sizeof(IpcMessage));
        loginfo("sizeof(LinkedBuffer) = %d", sizeof(LinkedBuffer));
        loginfo("sizeof(LinkedBuffers) = %d", sizeof(LinkedBuffers));
    }

    auto driver = new (pool) Driver(pool);
    if (!driver->begin(pool)) {
        return false;
    }

    driver_ = driver;
    pool_ = pool;

    if (!settings.valid) {
        return true;
    }

    WifiMode mode = settings.create ? WifiMode::MODE_AP : WifiMode::MODE_STATION;
    bool success = driver_->join(settings.ssid, settings.password, mode);
    if (!success) {
        driver_ = nullptr;
        return false;
    }

    return true;
}

bool AprilNetwork::serve() {
    loginfo("serve!");

    udp_discovery_ = new (pool_) UDPDiscovery();
    udp_discovery_->start();

    udp_server_ = new (pool_) UDPServer(create_udp(0, 22144, pool_));
    udp_server_->start();

    synchronize_time();

    return true;
}

NetworkStatus AprilNetwork::status() {
    switch (driver_->state()) {
    case DriverState::DS_UNAVAILABLE:
        return NetworkStatus::Off;
    case DriverState::DS_ERROR:
        return NetworkStatus::Error;
    case DriverState::DS_READY:
        return NetworkStatus::Ready;
    case DriverState::DS_CONNECTING:
        return NetworkStatus::Ready;
    case DriverState::DS_ATTEMPTING_STATION:
        return NetworkStatus::Ready;
    case DriverState::DS_ATTEMPTING_AP:
        return NetworkStatus::Listening;
    case DriverState::DS_CONNECTED:
        return NetworkStatus::Connected;
    default:
        return NetworkStatus::Error;
    }
}

uint32_t AprilNetwork::udp_activity() const {
    if (udp_server_ != nullptr) {
        return udp_server_->activity();
    }
    return 0;
}

uint32_t AprilNetwork::ip_address() {
    return driver_->ip_address();
}

void AprilNetwork::service(Pool *pool) {
    if (driver_ != nullptr) {
        driver_->service();

        if (pool != nullptr) {
            if (udp_discovery_ != nullptr) {
                udp_discovery_->service(pool);
            }
            if (udp_server_ != nullptr) {
                udp_server_->service(pool);
            }
            if (simple_ntp_ != nullptr) {
                simple_ntp_->service();
            }
        }
    }
}

PoolPointer<NetworkConnection> *AprilNetwork::open_connection(const char *scheme, const char *hostname, uint16_t port) {
    FK_ASSERT(driver_ != nullptr);

    Sockets *sockets = driver_->sockets();

    auto ssl = strcmp(scheme, "https") == 0;

    loginfo("connecting! %s %s %d", scheme, hostname, port);
    SOCKET sock = sockets->create(AF_INET, SOCK_STREAM, ssl ? SOCKET_FLAGS_SSL : 0);
    if (sock < 0) {
        return nullptr;
    }

    uint32_t ip = 0;
    if (!driver_->gethostbyname(hostname, ip)) {
        logwarn("gethostbyname failed");
        if (sockets->close(sock) < 0) {
            logwarn("close failed");
        }
        return nullptr;
    }

    if (ssl) {
        if (sockets->set_opt(sock, SOL_SSL_SOCKET, SO_SSL_SNI, hostname, m2m_strlen((uint8_t *)hostname)) < 0) {
            logwarn("set_opt(ssl) failed");
            if (sockets->close(sock) < 0) {
                logwarn("close failed");
            }
            return nullptr;
        }

        if (false) {
            logwarn("ssl verification disabled");
            uint8_t flag_val = 1U;
            if (sockets->set_opt(sock, SOL_SSL_SOCKET, SO_SSL_BYPASS_X509_VERIF, &flag_val, 1u) < 0) {
                logwarn("set_opt(bypass) failed");
                if (sockets->close(sock) < 0) {
                    logwarn("close failed");
                }
                return nullptr;
            }
        }
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(struct sockaddr_in));
    addr.sin_family = AF_INET;
    addr.sin_port = _htons(port);
    addr.sin_addr.s_addr = ip;
    auto err = sockets->connect(sock, (struct sockaddr *)&addr, sizeof(struct sockaddr_in));
    if (err < 0) {
        if (sockets->close(sock) < 0) {
            logwarn("close failed");
        }
        return nullptr;
    }

    loginfo("connected!");

    return create_network_connection_wrapper<AprilConnection>(sockets, sock);
}

PoolPointer<NetworkListener> *AprilNetwork::listen(uint16_t port) {
    FK_ASSERT(driver_ != nullptr);

    Sockets *sockets = driver_->sockets();

    loginfo("listen! %d", port);
    SOCKET sock = sockets->create(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        return nullptr;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(struct sockaddr_in));
    addr.sin_family = AF_INET;
    addr.sin_port = _htons(port);
    addr.sin_addr.s_addr = 0;
    if (sockets->bind(sock, (struct sockaddr *)&addr, sizeof(struct sockaddr_in)) < 0) {
        return nullptr;
    }

    if (sockets->listen(sock) < 0) {
        return nullptr;
    }

    return create_weak_network_listener_wrapper<Listener>(*pool_, sockets, sock);
}

NetworkUDP *AprilNetwork::create_udp(uint32_t ip, uint16_t port, Pool *pool) {
    FK_ASSERT(driver_ != nullptr);

    Sockets *sockets = driver_->sockets();

    SOCKET sock = sockets->create(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        logerror("create socket failed");
        return nullptr;
    }

    uint32_t disabling = 0;
    int32_t set_err = sockets->set_opt(sock, SOL_SOCKET, SO_SET_UDP_SEND_CALLBACK, &disabling, 0);
    if (set_err < 0) {
        logwarn("setsockopt(SO_SET_UDP_SEND_CALLBACK) failed (%d)", set_err);
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(struct sockaddr_in));
    addr.sin_family = AF_INET;
    addr.sin_port = _htons(port);
    addr.sin_addr.s_addr = 0;
    int32_t err = sockets->bind(sock, (struct sockaddr *)&addr, sizeof(struct sockaddr_in));
    if (err < 0) {
        logerror("bind failed (%d)", err);
        sockets->close(sock);
        return nullptr;
    }

    if (ip > 0) {
        if (sockets->set_opt(sock, SOL_SOCKET, IP_ADD_MEMBERSHIP, &ip, sizeof(uint32_t)) < 0) {
            logwarn("setsockopt(IP_ADD_MEMBERSHIP) failed");
        }
    }

    return new (pool) AprilUDP(sockets, sock);
}

bool AprilNetwork::stop() {
    if (driver_ != nullptr) {
        driver_->stop();
        driver_ = nullptr;
    }

    return true;
}

bool AprilNetwork::enabled() {
    return driver_ != nullptr;
}

bool AprilNetwork::synchronize_time() {
    if (driver_->mode() == WifiMode::MODE_STATION) {
        simple_ntp_ = new (pool_) SimpleNTP(create_udp(0, 2390, pool_));
        simple_ntp_->start();
    }

    return true;
}

bool AprilNetwork::get_mac_address(uint8_t *address) {
    if (driver_ == nullptr) {
        return false;
    }
    memcpy(address, driver_->mac_address(), MacAddressLength);
    return true;
}

const char *AprilNetwork::get_ssid() {
    if (driver_ != nullptr) {
        return driver_->ssid();
    }
    return nullptr;
}

bool AprilNetwork::get_created_ap() {
    if (driver_ != nullptr) {
        return driver_->mode() == WifiMode::MODE_AP;
    }
    return false;
}

NetworkScan AprilNetwork::scan(Pool &pool) {
    return NetworkScan{ nullptr, 0 };
}

PoolPointer<NetworkConnection> *Listener::accept() {
    SOCKET accepted = sockets_->accept(sock_);
    if (accepted == -1) {
        return nullptr;
    }
    return create_network_connection_wrapper<AprilConnection>(sockets_, accepted);
}

bool Listener::stop() {
    sockets_->close(sock_);
    return true;
}

NetworkConnectionStatus AprilConnection::status() {
    if (sockets_->is_connected(sock_)) {
        return NetworkConnectionStatus::Connected;
    } else {
        return NetworkConnectionStatus::Disconnected;
    }
}

bool AprilConnection::available() {
    return sockets_->read(sock_, nullptr, 0) > 0;
}

int32_t AprilConnection::read(uint8_t *buffer, size_t size) {
    return sockets_->read(sock_, buffer, size);
}

int32_t AprilConnection::write(const uint8_t *buffer, size_t size) {
    return sockets_->write(sock_, buffer, size);
}

int32_t AprilConnection::writef(const char *str, ...) {
    va_list args;
    va_start(args, str);
    int32_t err = vwritef(str, args);
    va_end(args);
    return err;
}

int32_t AprilConnection::vwritef(const char *str, va_list args) {
    return sockets_->vwritef(sock_, str, args);
}

int32_t AprilConnection::write(const char *str) {
    return sockets_->write(sock_, (uint8_t *)str, strlen(str));
}

int32_t AprilConnection::flush() {
    return sockets_->flush(sock_);
}

int32_t AprilConnection::try_flush_all(size_t bytes, uint32_t delay) {
    auto elapsed = 0u;
    auto total = 0;
    while (elapsed < delay * 10) {
        auto flushed = flush();
        if (flushed < 0) {
            return flushed;
        }
        total += flushed;
        if (flushed == (int32_t)bytes) {
            return bytes;
        }
        fk_delay(delay);
        elapsed += delay;
    }

    return -1;
}

uint32_t AprilConnection::remote_address() {
    return sockets_->remote_ip(sock_);
}

bool AprilConnection::stop() {
    sockets_->close(sock_);
    return true;
}

int32_t AprilUDP::begin(uint32_t ip, uint16_t port) {
    to_ip_ = ip;
    to_port_ = port;
    return 0;
}

int32_t AprilUDP::write(uint8_t const *buffer, size_t size) {
    return sockets_->write(sock_, buffer, size);
}

int32_t AprilUDP::flush() {
    if (to_ip_ == 0 || to_port_ == 0) {
        logwarn("udp: invalid destination");
    }
    int32_t err = sockets_->send_to(sock_, to_ip_, to_port_);
    if (err >= 0) {
        to_ip_ = 0;
        to_port_ = 0;
    }
    return err;
}

int32_t AprilUDP::available() {
    return sockets_->read(sock_, nullptr, 0);
}

int32_t AprilUDP::read(uint8_t *buffer, size_t size) {
    return sockets_->read(sock_, buffer, size);
}

uint32_t AprilUDP::remote_ip() {
    return sockets_->remote_ip(sock_);
}

bool AprilUDP::stop() {
    return sockets_->close(sock_) >= 0;
}

} // namespace fk

#endif
