#include <algorithm>

#include "networking/network_duration.h"
#include "config.h"
#include "platform.h"

namespace fk {

FK_DECLARE_LOGGER("network");

NetworkDuration::NetworkDuration() : seconds_{ FiveMinutesSeconds } {
    on_ = fk_uptime();
    loginfo("duration: %" PRIu32, seconds_);
}

bool NetworkDuration::always_on() const {
    return seconds_ == UINT32_MAX;
}

bool NetworkDuration::on(uint32_t activity) const {
    if (always_on()) {
        return true;
    }

    auto uptime = fk_uptime();
    if (activity > uptime) {
        logwarn("duration: %" PRIu32 "> %" PRIu32, activity, uptime);
        return true;
    }

#if defined(FK_ENABLE_NETWORK_UP_AND_DOWN)
    auto seconds_up = (uptime - on_) / 1000;
    return seconds_up < OneMinuteSeconds * 2;
#else
    auto seconds_up = (uptime - activity) / 1000;
    return seconds_up < seconds_;
#endif
}

NetworkDuration NetworkDuration::operator=(uint32_t seconds) {
    auto new_value = std::max(seconds, OneMinuteSeconds);
    if (new_value != seconds_) {
        seconds_ = new_value;
        loginfo("duration: %" PRIu32, seconds_);
    }
    return *this;
}

} // namespace fk
