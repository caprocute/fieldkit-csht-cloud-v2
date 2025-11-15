#pragma once

#include "common.h"
#include "hal/hal.h"
#include "state.h"

namespace fk {

struct SelfCheckSettings {
    bool check_gps{ false };
    bool check_sd_card{ false };
    bool check_backplane{ false };
    bool check_lora{ false };
    bool flash_leds{ false };
    bool module_presence{ true };
    bool check_network{ false };
    bool check_battery{ true };
    bool check_temperature{ true };

private:
    SelfCheckSettings() {
    }

    SelfCheckSettings(bool gps, bool sd_card, bool backplane, bool lora, bool flash_leds, bool module_presence, bool check_network,
                      bool check_battery, bool check_temperature)
        : check_gps(gps), check_sd_card(sd_card), check_backplane(backplane), check_lora(lora), flash_leds(flash_leds),
          module_presence(module_presence), check_network(check_network), check_battery(check_battery),
          check_temperature(check_temperature) {
    }

public:
#if defined(FK_UNDERWATER)
    static SelfCheckSettings defaults() {
        return { true, true, false, false, false, true, true, false, false };
    }

    static SelfCheckSettings detailed() {
        return { true, true, false, false, false, true, true, false, false };
    }

    static SelfCheckSettings low_power() {
        return { false, false, false, false, false, false, false, true, true };
    }
#else
    static SelfCheckSettings defaults() {
        return { true, true, true, false, false, false, true, true, true };
    }

    static SelfCheckSettings detailed() {
        return { true, true, true, true, true, true, true, true, true };
    }

    static SelfCheckSettings low_power() {
        return { false, false, false, false, false, false, false, true, true };
    }
#endif
};

class SelfCheckCallbacks {
public:
    virtual void update(SelfCheckStatus status) = 0;
};

class NoopSelfCheckCallbacks : public SelfCheckCallbacks {
public:
    void update(SelfCheckStatus status) override {
    }
};

class SelfCheck {
private:
    SelfCheckStatus status_;
    Display *display_;
    Network *network_;
    ModMux *mm_;
    ModuleLeds *leds_;

public:
    SelfCheck(Display *display, Network *network, ModMux *mm, ModuleLeds *leds);

public:
    void check(SelfCheckSettings settings, SelfCheckCallbacks &callback, Pool *pool);
    void save();

private:
    bool rtc();
    bool temperature();
    bool battery_gauge();
    bool solar_gauge();
    bool qspi_memory();
    bool spi_memory();
    bool gps();
    bool wifi(Pool *pool);
    bool sd_card_open();
    bool sd_card_write();
    bool backplane_shift();
    bool backplane_mux();
    bool backplane_leds();
    bool lora();
    ModuleCheckStatus modules(Pool *pool);
    void flash_leds();
};

} // namespace fk
