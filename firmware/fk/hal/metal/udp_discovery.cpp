#if defined(__SAMD51__)

#include "hal/metal/udp_discovery.h"
#include "common.h"
#include "config.h"
#include "platform.h"
#include "state_ref.h" // TODO Remove
#include "utilities.h"

namespace fk {

FK_DECLARE_LOGGER("udp");

/**
 * These libraries have different conventions for success from this call, and
 * actually now that I'm thinking of this I remember there being an earlier bug
 * with the value in the Winc1500 version of the library.
 */
#if defined(FK_NETWORK_ESP32_WIFI101)
#define CHECK_UDP_END_PACKET(rv) (rv) == 1
#else
#define CHECK_UDP_END_PACKET(rv) (rv) == 0
#endif

UDPDiscovery::UDPDiscovery() {
}

UDPDiscovery::~UDPDiscovery() {
    stop();
}

bool UDPDiscovery::start() {
    if (!initialized_) {
        initialized_ = true;
        publish_ = 0;
    }

    return true;
}

void UDPDiscovery::stop() {
    if (initialized_) {
        if (pool_ != nullptr) {
            for (auto i = 0; i < 3; ++i) {
                send(fk_app_UdpStatus_UDP_STATUS_BYE, pool_);
                fk_delay(50);
            }
        } else {
            logerror("missing pool");
        }

        initialized_ = false;
    }
}

static DebuggingUdpTraffic get_forced_udp_traffic() {
    auto gs = get_global_state_ro();
    return gs.get()->debugging.udp_traffic;
}

bool UDPDiscovery::service(Pool *pool) {
    if (!initialized_) {
        return true;
    }

    if (fk_uptime() > publish_) {
        auto forced_traffic = get_forced_udp_traffic();
        if (forced_traffic.start_time > 0) {
            if (fk_uptime() > forced_traffic.start_time && fk_uptime() < forced_traffic.stop_time) {
                for (auto i = 0u; i < forced_traffic.quantity; ++i) {
                    send(fk_app_UdpStatus_UDP_STATUS_ONLINE, pool);
                }
                publish_ = fk_uptime() + forced_traffic.interval;
            } else {
                publish_ = fk_uptime() + 100;
            }
        } else {
            send(fk_app_UdpStatus_UDP_STATUS_ONLINE, pool);
            publish_ = fk_uptime() + NetworkUdpDiscoveryInterval;
        }
    }

    return true;
}

bool UDPDiscovery::send(fk_app_UdpStatus status, Pool *pool) {
#if !defined(FK_NETWORK_UDP_DISCOVERY_DISABLE)
    fk_serial_number_t sn;
    pb_data_t device_id_data{
        .length = sizeof(sn),
        .buffer = &sn,
    };

    fk_app_UdpMessage message = fk_app_UdpMessage_init_default;
    message.deviceId.funcs.encode = pb_encode_data;
    message.deviceId.arg = &device_id_data;
    message.status = status;
    message.port = 80;

    auto encoded = pool->encode(fk_app_UdpMessage_fields, &message);
    if (encoded == nullptr) {
        loginfo("encode failed");
        return false;
    }

    uint32_t ip = ipv4_to_u32(224, 1, 2, 3);
    NetworkUDP *udp = get_network()->create_udp(ip, NetworkUdpDiscoveryPort, pool);
    if (udp == nullptr) {
        logerror("create_udp failed");
        return false;
    }

    logtrace("publishing");
    if (udp->begin(ip, NetworkUdpDiscoveryPort) < 0) {
        logerror("begin failed");
    } else {
        if (udp->write(encoded->buffer(), encoded->length()) < 0) {
            logerror("write failed");
        } else {
            while (true) {
                auto err = udp->flush();
                if (err < 0) {
                    if (err == FK_SOCK_ERR_BUFFER_FULL) {
                        fk_delay(100);
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }
        }
    }
    if (!udp->stop()) {
        logerror("stop failed");
    }
    logtrace("published");
#endif

    return true;
}

} // namespace fk

#endif
