#pragma once

#include "state/power_state.h"
#include "state/storage_state.h"
#include "state/schedule_state.h"
#include "state/network_state.h"
#include "state/lora_state.h"
#include "state/gps_state.h"
#include "state/dynamic.h"

#include "common.h"
#include "config.h"
#include "pool.h"

namespace fk {

enum class CheckStatus : uint8_t {
    Pending,
    Unknown,
    Pass,
    Fail,
};

struct SelfCheckCheck {
    const char *name;
    CheckStatus status;
};

class ModuleCheckStatus {
private:
    uint32_t value_{ 0 };

public:
    ModuleCheckStatus(uint32_t value) : value_(value) {
    }

public:
    const char *name() const {
        return "mods";
    }

    uint16_t value() const {
        return value_;
    }

    operator bool() const {
        return value_ > 0;
    }
};

struct SelfCheckStatus {
    uint32_t started{ 0 };
    SelfCheckCheck rtc{ "rtc", CheckStatus::Pending };
    SelfCheckCheck temperature{ "temp", CheckStatus::Pending };
    SelfCheckCheck battery_gauge{ "bg", CheckStatus::Pending };
    SelfCheckCheck solar_gauge{ "sg", CheckStatus::Pending };
    SelfCheckCheck qspi_memory{ "qspi", CheckStatus::Pending };
    SelfCheckCheck spi_memory{ "spi", CheckStatus::Pending };
    SelfCheckCheck gps{ "gps", CheckStatus::Pending };
    SelfCheckCheck wifi{ "wifi", CheckStatus::Pending };
    SelfCheckCheck sd_card_open{ "sdo", CheckStatus::Pending };
    SelfCheckCheck sd_card_write{ "sdw", CheckStatus::Pending };
    SelfCheckCheck bp_mux{ "bpm", CheckStatus::Pending };
    SelfCheckCheck bp_shift{ "bps", CheckStatus::Pending };
    SelfCheckCheck bp_leds{ "led", CheckStatus::Pending };
    SelfCheckCheck lora{ "lora", CheckStatus::Pending };
    ModuleCheckStatus modules{ 0 };
};

struct GeneralState {
    char name[MaximumNameLength];
    uint8_t generation[GenerationLength];
    uint32_t recording{ 0 };
    SelfCheckStatus self_check;
};

struct ProgressState {
    const char *operation;
    float progress;
};

class NotificationState {
public:
    uint32_t created{ 0 };
    const char *message{ nullptr };
    uint32_t delay{ 0 };

public:
    explicit NotificationState();
    explicit NotificationState(const char *message);

public:
    static NotificationState from_key(uint32_t message_key);
};

class DisplayTaskParameters {
public:
    bool disable_leds{ false };
    bool readings{ false };
    NotificationState notif{};

public:
    static DisplayTaskParameters normal();
    static DisplayTaskParameters low_power();
};

extern DisplayTaskParameters task_display_params;

struct OpenMenu {
    uint32_t time;
    bool readings;
};

struct DisplayState {
    OpenMenu open_menu;
};

struct ReadingsState {
    uint32_t nreadings{ 0 };
    uint32_t time{ 0 };
};

struct DebuggingState {
    DebuggingUdpTraffic udp_traffic;
    bool unexciting{ false };
};

struct GlobalState {
public:
    uint32_t version{ 0 };
    state::DynamicState dynamic;
    GeneralState general{};
    PowerState power{};
    GpsState gps{};
    MainNetworkState network{};
    NotificationState notification{};
    DisplayState display{};
    ProgressState progress{};
    StorageState storage{};
    LoraState lora{};
    SchedulerState scheduler{};
    ReadingsState readings{};
    TransmissionState transmission{};
    DebuggingState debugging{};

public:
    GlobalState();

public:
    void apply(StorageUpdate &update);
    void apply(UpcomingUpdate &update);
    void released(uint32_t locked) const;
    void released(uint32_t locked);
    bool flush(uint32_t timeout, Pool &pool);

public:
    GpsState const *location(Pool &pool) const;
};

} // namespace fk
