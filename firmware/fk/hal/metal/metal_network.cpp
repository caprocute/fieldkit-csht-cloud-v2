#include <tiny_printf.h>

#include "utilities.h"
#include "hal/metal/metal_network.h"

#if defined(__SAMD51__) && (defined(FK_NETWORK_WINC1500_WIFI101) || defined(FK_NETWORK_ESP32_WIFI101))

namespace fk {

FK_DECLARE_LOGGER("network");

const char *get_wifi_status(uint8_t status) {
    switch (status) {
    case WL_NO_SHIELD:
        return "WL_NO_SHIELD";
    case WL_IDLE_STATUS:
        return "WL_IDLE_STATUS";
    case WL_NO_SSID_AVAIL:
        return "WL_NO_SSID_AVAIL";
    case WL_SCAN_COMPLETED:
        return "WL_SCAN_COMPLETED";
    case WL_CONNECTED:
        return "WL_CONNECTED";
    case WL_CONNECT_FAILED:
        return "WL_CONNECT_FAILED";
    case WL_CONNECTION_LOST:
        return "WL_CONNECTION_LOST";
    case WL_DISCONNECTED:
        return "WL_DISCONNECTED";
    case WL_AP_LISTENING:
        return "WL_AP_LISTENING";
    case WL_AP_CONNECTED:
        return "WL_AP_CONNECTED";
    case WL_AP_FAILED:
        return "WL_AP_FAILED";
#if defined(WL_PROVISIONING)
    case WL_PROVISIONING:
        return "WL_PROVISIONING";
#endif
#if defined(WL_PROVISIONING_FAILED)
    case WL_PROVISIONING_FAILED:
        return "WL_PROVISIONING_FAILED";
#endif
    default:
        return "Unknown";
    }
}

MetalNetworkConnection::MetalNetworkConnection() {
}

MetalNetworkConnection::MetalNetworkConnection(Pool *pool, WiFiClient wcl) : wcl_(wcl) {
    buffered_writer_ = new (pool) WifiBufferedWriter();
    buffered_writer_->buffer = (uint8_t *)pool->malloc(256);
    buffered_writer_->buffer_size = 256;
    if (debugging_) {
        size_ = StandardPageSize;
        buffer_ = reinterpret_cast<uint8_t *>(fk_standard_page_malloc(size_, __func__));
        bzero(buffer_, size_);
    }
}

MetalNetworkConnection::~MetalNetworkConnection() {
    if (buffer_ != nullptr) {
        fk_standard_page_free(buffer_);
    }
}

NetworkConnectionStatus MetalNetworkConnection::status() {
    if (wcl_.connected()) {
        return NetworkConnectionStatus::Connected;
    }
    return NetworkConnectionStatus::Disconnected;
}

bool MetalNetworkConnection::available() {
    return wcl_.available();
}

int32_t MetalNetworkConnection::read(uint8_t *buffer, size_t size) {
    auto nread = wcl_.read(buffer, size);
    if (nread < 0) {
        return 0;
    }

    if (buffer_ != nullptr) {
        auto copying = std::min<size_t>(size_ - position_, nread);
        if (copying > 0) {
            memcpy(buffer_ + position_, buffer, copying);
            position_ += copying;
        }
    }

    return nread;
}

int32_t MetalNetworkConnection::write(const char *str) {
    auto writing = strlen(str);
    auto wrote = wcl_.write((const uint8_t *)str, writing);
    if (wrote > writing) {
        return -1;
    }
    return wrote;
}

int32_t MetalNetworkConnection::write(const uint8_t *buffer, size_t size) {
    return wcl_.write(buffer, size);
}

int32_t MetalNetworkConnection::writef(const char *str, ...) {
    va_list args;
    va_start(args, str);
    auto rv = vwritef(str, args);
    va_end(args);
    return rv;
}

int32_t MetalNetworkConnection::flush() {
    return 0;
}

int32_t MetalNetworkConnection::try_flush_all(size_t bytes, uint32_t delay) {
    // Default implementations of write will handle flushing for us. For the
    // time being just assume things will go fine there. Long term I do think
    // there are some places where the error values on write aren't being
    // checked.
    return bytes;
}

int32_t WifiBufferedWriter::flush() {
    if (position > 0) {
        // loginfo("flushing %d bytes", position);
        size_t wrote = wcl->write(buffer, position);
        if (wrote > 0) {
            if (wrote > position) {
                logerror("error writing (too big)");
                // fk_debugger_break();
                return_value = -1;
            } else {
                return_value += wrote;
            }
        } else {
            logerror("error writing (0 or less)");
            // fk_debugger_break();
            return_value = -1;
        }
        position = 0;
    }
    return return_value;
}

static void write_connection(char c, void *arg) {
    if (c > 0) {
        auto bw = reinterpret_cast<WifiBufferedWriter *>(arg);
        bw->buffer[bw->position++] = c;
        if (bw->position == bw->buffer_size) {
            bw->flush();
        }
    }
}

int32_t MetalNetworkConnection::vwritef(const char *str, va_list args) {
    buffered_writer_->wcl = &wcl_;
    tiny_vfctprintf(write_connection, buffered_writer_, str, args);
    buffered_writer_->flush();
    return buffered_writer_->return_value;
}

uint32_t MetalNetworkConnection::remote_address() {
    return wcl_.remoteIP();
}

bool MetalNetworkConnection::stop() {
    wcl_.flush();
    wcl_.stop();

    return true;
}

bool MetalNetwork::begin(NetworkSettings settings, Pool *pool) {
    if (availability_ == Availability::Unavailable) {
        logwarn("wifi unavailable");
        return false;
    }

    auto started = fk_uptime();

    FK_ASSERT(pool != nullptr);

    pool_ = pool;

    enable();

    fk_delay(100);

    status_ = WiFi.status();
    if (status_ == WL_NO_SHIELD) {
        disable();
        availability_ = Availability::Unavailable;
        return false;
    }

    auto fv = WiFi.firmwareVersion();
    loginfo("wifi: version %s", fv);

    availability_ = Availability::Available;

    if (settings.ssid != nullptr) {
        if (settings.create) {
            if (settings.password != nullptr && settings.password[0] != 0) {
                loginfo("creating '%s' '%s'", settings.ssid, settings.password);
                WiFi.beginAP(settings.ssid, settings.password);
            } else {
                loginfo("creating '%s'", settings.ssid);

                if (!start_ap(settings)) {
                    return false;
                }
            }
        } else {
            loginfo("connecting '%s'", settings.ssid);
            WiFi.begin(settings.ssid, settings.password);
        }
    }

    settings_ = settings;
    enabled_ = true;
    serving_ = false;

    logdebug("begin exiting after %dms", fk_uptime() - started);

    return true;
}

void MetalNetwork::check_status() {
    auto new_status = WiFi.status();
    if (new_status != status_) {
        loginfo("wifi: status change (%s -> %s)", get_wifi_status(status_), get_wifi_status(new_status));
        status_ = new_status;
    }
}

bool MetalNetwork::serve() {
    fk_delay(500);

#if defined(FK_NETWORK_ENABLE_MDNS)
    mdns_discovery_.pool(pool_);
    if (!mdns_discovery_.start()) {
        logwarn("mdns discovery failed");
    }
#endif

#if defined(FK_NETWORK_ENABLE_UDP_DISCOVERY)
    udp_discovery_ = new (pool_) UDPDiscovery();
    udp_discovery_->pool(pool_);
    if (!udp_discovery_->start()) {
        logwarn("udp discovery failed");
    }
#endif

    udp_server_ = new (pool_) UDPServer(create_udp(0, 22144, pool_));
    udp_server_->pool(pool_);
    if (!udp_server_->start()) {
        logwarn("udp server failed");
    }

    synchronize_time();

    check_status();

    IPAddress ip = WiFi.localIP();
    loginfo("ready (ip = %d.%d.%d.%d) (status = %s)", ip[0], ip[1], ip[2], ip[3], get_wifi_status(status_));

    if (status_ == WL_AP_CONNECTED) {
        if (!connected()) {
            return false;
        }
    }

    serving_ = true;

    return true;
}

NetworkStatus MetalNetwork::status() {
    switch (status_) {
    case WL_NO_SHIELD:
        return NetworkStatus::Error;
    case WL_CONNECTED:
        return NetworkStatus::Connected;
    case WL_AP_LISTENING:
        return NetworkStatus::Listening;
    case WL_AP_CONNECTED:
        return NetworkStatus::Connected;
    }
    return NetworkStatus::Ready;
}

uint32_t MetalNetwork::ip_address() {
    if (enabled()) {
        return WiFi.localIP();
    }
    return 0;
}

int32_t MetalNetwork::rssi() {
    if (enabled()) {
        return WiFi.RSSI();
    }
    return 0;
}

PoolPointer<NetworkListener> *MetalNetwork::listen(uint16_t port) {
    auto listener = create_weak_network_listener_wrapper<MetalNetworkListener>(*pool_, port);

    if (!listener->get<MetalNetworkListener>()->begin()) {
        return nullptr;
    }

    return listener;
}

NetworkUDP *MetalNetwork::create_udp(uint32_t ip, uint16_t port, Pool *pool) {
    auto udp = new (pool) MetalNetworkUDP();
    if (!udp->initialize(ip, port)) {
        return nullptr;
    }
    return udp;
}

void MetalNetwork::service(Pool *pool) {
    check_status();

    if (pool != nullptr) {
        if (serving_) {
#if defined(FK_NETWORK_ENABLE_MDNS)
            mdns_discovery_.service(pool);
#endif
#if defined(FK_NETWORK_ENABLE_UDP_DISCOVERY)
            if (udp_discovery_ != nullptr) {
                udp_discovery_->service(pool);
            }
#endif
#if defined(FK_NETWORK_ENABLE_NTP)
            if (ntp_ != nullptr) {
                ntp_->service();
            }
#endif
            if (udp_server_ != nullptr) {
                udp_server_->service(pool);
            }
        }
    }
}

bool MetalNetwork::stop() {
    if (enabled_) {
        if (serving_) {
#if defined(FK_NETWORK_ENABLE_NTP)
            if (ntp_ != nullptr) {
                logdebug("ntp-stop");
                ntp_->stop();
            }
#endif
            if (udp_server_ != nullptr) {
                logdebug("udp-server-stop");
                udp_server_->stop();
            }
#if defined(FK_NETWORK_ENABLE_UDP_DISCOVERY)
            if (udp_discovery_ != nullptr) {
                logdebug("udp-stop");
                udp_discovery_->stop();
            }
#endif
#if defined(FK_NETWORK_ENABLE_MDNS)
            logdebug("mdns-stop");
            mdns_discovery_.stop();
            // Ensure the previous removal gets loose?
            fk_delay(500);
#endif
            serving_ = false;
        }
        logdebug("wifi-end");
        WiFi.end();
        logdebug("disable-wifi");
        disable();
        enabled_ = false;
    }
    pool_ = nullptr;
    return true;
}

bool MetalNetwork::enabled() {
    return enabled_;
}

bool MetalNetwork::synchronize_time() {
    if (!settings_.create) {
#if defined(FK_NETWORK_ENABLE_NTP)
        ntp_ = new (pool_) SimpleNTP(create_udp(0, 2390, pool_));
        ntp_->pool(pool_);
        ntp_->start();
#endif
    }
    return true;
}

bool MetalNetwork::get_mac_address(uint8_t *address) {
    WiFi.macAddress(address);
    return true;
}

const char *MetalNetwork::get_ssid() {
    return WiFi.SSID();
}

bool MetalNetwork::get_created_ap() {
    return status_ == WL_AP_LISTENING || status_ == WL_AP_CONNECTED;
}

NetworkScan MetalNetwork::scan(Pool &pool) {
    size_t number_ssids = WiFi.scanNetworks();
    if (number_ssids == 0) {
        return NetworkScan{ nullptr, 0 };
    }

    auto ssids = (const char **)pool.malloc(sizeof(const char *) * number_ssids);

    for (auto i = 0u; i < number_ssids; ++i) {
        auto ssid = WiFi.SSID(i);
        if (ssid != nullptr) {
            ssids[i] = pool.strdup(ssid);
        }
    }

    return NetworkScan{ ssids, number_ssids };
}

void MetalNetwork::verify() {
}

MetalNetworkListener::MetalNetworkListener(Pool *pool, uint16_t port) : port_(port) {
}

bool MetalNetworkListener::begin() {
    server_.begin();
    return true;
}

PoolPointer<NetworkConnection> *MetalNetworkListener::accept() {
#if defined(FK_NETWORK_ESP32_WIFI101)
    auto wcl = server_.available(nullptr);
#else
    auto wcl = server_.available(nullptr, true);
#endif
    if (!wcl) {
        return nullptr;
    }

    return create_network_connection_wrapper<MetalNetworkConnection>(wcl);
}

bool MetalNetworkListener::stop() {
    return true;
}

bool MetalNetworkUDP::initialize(uint32_t ip, uint16_t port) {
    if (ip > 0) {
        return udp_.beginMulticast(ip, port);
    } else {
        return udp_.begin(port);
    }
}

int32_t MetalNetworkUDP::begin(uint32_t ip, uint16_t port) {
    udp_.beginPacket(ip, port);
    return 0;
}

int32_t MetalNetworkUDP::write(uint8_t const *buffer, size_t size) {
    return udp_.write(buffer, size);
}

int32_t MetalNetworkUDP::flush() {
#if defined(FK_NETWORK_ESP32_WIFI101)
    return udp_.endPacket() ? 0 : -1;
#else
    return udp_.endPacket();
#endif
}

int32_t MetalNetworkUDP::available() {
    return udp_.available();
}

int32_t MetalNetworkUDP::read(uint8_t *buffer, size_t size) {
    return udp_.read(buffer, size);
}

uint32_t MetalNetworkUDP::remote_ip() {
    return udp_.remoteIP();
}

bool MetalNetworkUDP::stop() {
    udp_.stop();
    return true;
}

} // namespace fk

#endif
