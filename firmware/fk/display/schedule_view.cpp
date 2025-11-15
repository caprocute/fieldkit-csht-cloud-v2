#include <tiny_printf.h>

#include "config.h"
#include "hal/board.h"
#include "hal/display.h"
#include "platform.h"
#include "schedule_view.h"
#include "state_manager.h"
#include "state_ref.h"

#include "l10n/l10n.h"

namespace fk {

FK_DECLARE_LOGGER("schedview");

struct Option {
    uint32_t label_key;
    int32_t interval;
};

static constexpr size_t NumberOfOptions = 8;

const Option options[NumberOfOptions] = { { FK_MENU_SCHEDULE_SET_1M, 60 },       { FK_MENU_SCHEDULE_SET_5M, 60 * 5 },
                                          { FK_MENU_SCHEDULE_SET_10M, 60 * 10 }, { FK_MENU_SCHEDULE_SET_30M, 60 * 30 },
                                          { FK_MENU_SCHEDULE_SET_1H, 60 * 60 },  { FK_MENU_SCHEDULE_SET_6H, 60 * 60 * 6 },
                                          { FK_MENU_SCHEDULE_CANCEL, -1 },       { FK_MENU_SCHEDULE_NEVER, 0 } };

void ScheduleView::tick(ViewController *views, Pool &pool) {
    auto bus = get_board()->i2c_core();
    auto display = get_display();

    auto now = fk_uptime();
    if (update_at_ == 0 || now > update_at_) {
        auto schedule = get();
        scheduled_ = schedule.upcoming;
        interval_ = schedule.interval;
        update_at_ = now + OneSecondMs;
    }

    char primary[64] = { 0 };
    char secondary[64] = { 0 };

    auto option = options[position_ % NumberOfOptions];
    auto selected = option.interval == interval_ ? "*" : "";

    tiny_snprintf(primary, sizeof(primary), "%s%s", en_US[option.label_key], selected);
    tiny_snprintf(secondary, sizeof(secondary), "%s %" PRIu32 "s", en_US[FK_MENU_SCHEDULE_NEXT], scheduled_.seconds);

    display->simple(SimpleScreen{ primary, secondary });
}

void ScheduleView::up(ViewController *views) {
    position_--;
}

void ScheduleView::down(ViewController *views) {
    position_++;
}

void ScheduleView::enter(ViewController *views) {
    auto &option = options[position_ % NumberOfOptions];
    if (option.interval >= 0) {
        loginfo("selected: %s", en_US[option.label_key]);
        set(option.interval);
    }

    views->show_home();
}

Schedule ScheduleView::get() {
    auto gs = get_global_state_ro();
    switch (type_) {
    case ScheduleType::Readings: {
        return gs.get()->scheduler.readings;
    }
    case ScheduleType::LoRa: {
        return gs.get()->scheduler.lora;
    }
    case ScheduleType::Network: {
        return gs.get()->scheduler.network;
    }
    default: {
        return gs.get()->scheduler.readings;
    }
    }
}

void ScheduleView::type(ScheduleType type) {
    type_ = type;
    update_at_ = 0; // Force display refresh.
}

void ScheduleView::set(uint32_t interval) {
    GlobalStateManager gsm;
    gsm.apply([=](GlobalState *gs) {
        switch (type_) {
        case ScheduleType::Readings: {
            gs->scheduler.readings.simple(interval);
            break;
        }
        case ScheduleType::LoRa: {
            gs->scheduler.lora.simple(interval);
            break;
        }
        case ScheduleType::Network: {
            gs->scheduler.network.simple(interval, NetworkMinimumDurationSeconds);
            break;
        }
        }

        StandardPool pool{ "flush" };
        gs->flush(OneSecondMs, pool);
    });

    update_at_ = 0; // Force display refresh.
}

} // namespace fk
