#if defined(__SAMD51__)

#include "platform.h"
#include "hal/metal/simple_ntp.h"
#include "hal/clock.h"

#include <WMath.h>

namespace fk {

FK_DECLARE_LOGGER("ntp");

constexpr uint32_t NtpSyncInterval = 24 * 60 * 1000 * 60;
constexpr uint32_t NtpRetryAfter = 2 * 1000;
constexpr uint64_t SeventyYears = 2208988800UL;
constexpr uint32_t PacketSize = 48;

SimpleNTP::SimpleNTP(NetworkUDP *udp) : udp_(udp) {
}

SimpleNTP::~SimpleNTP() {
    stop();
}

bool SimpleNTP::service() {
    if (!initialized_) {
        return true;
    }

    if (synced_ > 0 && fk_uptime() - synced_ < NtpSyncInterval) {
        return true;
    }

    if (queried_ == 0 || fk_uptime() - queried_ > NtpRetryAfter) {
        loginfo("asking for time...");
        start();
        queried_ = fk_uptime();
    }

    if (udp_ != nullptr && udp_->available()) {
        uint8_t buffer[PacketSize];

        FK_ASSERT(udp_->read(buffer, sizeof(buffer)) >= 0);

        // Pull time from the packet. Stored as a DWORD here as seconds since 1/1/1900
        auto high = word(buffer[40], buffer[41]);
        auto low = word(buffer[42], buffer[43]);
        auto seconds_since_1900 = high << 16 | low;
        auto new_epoch = (uint32_t)(seconds_since_1900 - SeventyYears);

        clock_adjust(new_epoch);

        synced_ = fk_uptime();

        stop();

        return true;
    }

    return true;
}

void SimpleNTP::start() {
    if (!initialized_) {
        initialized_ = true;
    }

    send();
}

void SimpleNTP::stop() {
    if (initialized_) {
        udp_->stop();
        initialized_ = false;
        synced_ = 0;
        queried_ = 0;
    }
}

bool SimpleNTP::send() {
    uint8_t buffer[PacketSize];

    bzero(buffer, sizeof(buffer));

    buffer[0] = 0b11100011; // LI, Version, Mode
    buffer[1] = 0;          // Stratum, or type of clock
    buffer[2] = 6;          // Polling Interval
    buffer[3] = 0xEC;       // Peer Clock Precision
    // 8 bytes of zero for Root Delay & Root Dispersion
    buffer[12] = 49;
    buffer[13] = 0x4E;
    buffer[14] = 49;
    buffer[15] = 52;

    static constexpr size_t NumberOfAddresses = 2;
    uint32_t addresses_[NumberOfAddresses]{
        ipv4_to_u32(129, 6, 15, 28),  //
        ipv4_to_u32(164, 67, 62, 194) //
    };
    if (udp_ != nullptr) {
        FK_ASSERT(udp_->begin(addresses_[index_ % NumberOfAddresses], 123) == 0);
        FK_ASSERT(udp_->write(buffer, sizeof(buffer)) >= 0);
        auto err = udp_->flush();
        if (err < 0) {
            logwarn("udp-flush: %d", err);
        }
    } else {
        logwarn("no udp");
    }

    index_++;

    return true;
}

} // namespace fk

#endif // defined(__SAMD51__)
