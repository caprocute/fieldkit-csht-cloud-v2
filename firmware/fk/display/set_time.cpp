#include <tiny_printf.h>

#include "platform.h"
#include "hal/board.h"
#include "hal/display.h"
#include "hal/clock.h"
#include "display/set_time.h"
#include "state_manager.h"
#include "state_ref.h"

namespace fk {

FK_DECLARE_LOGGER("settime");

const char *ActiveFieldIndicator[] = {
    "^^^^               ", "     ^^            ", "        ^^         ",
    "           ^^      ", "              ^^   ", "                 ^^",
};

static optional<TimeField> get_next_field(TimeField field) {
    switch (field) {
    case TimeField::Year:
        return TimeField::Month;
    case TimeField::Month:
        return TimeField::Day;
    case TimeField::Day:
        return TimeField::Hour;
    case TimeField::Hour:
        return TimeField::Minute;
    case TimeField::Minute:
        return TimeField::Second;
    case TimeField::Second:
        return nullopt;
    }
    return nullopt;
}

static int32_t constrain(int32_t value, int32_t min, int32_t max) {
    if (value < min)
        return max;
    if (value > max)
        return min;
    return value;
}

constexpr uint8_t DaysInMonth[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

static DateTime adjust_time(TimeField field, DateTime dt, int32_t direction) {
    switch (field) {
    case TimeField::Year: {
        auto adjusted = dt.year() + direction;
        return DateTime(adjusted, dt.month(), dt.day(), dt.hour(), dt.minute(), dt.second());
    }
    case TimeField::Month: {
        auto adjusted = constrain(dt.month() + direction, 1, 12);
        return DateTime(dt.year(), adjusted, dt.day(), dt.hour(), dt.minute(), dt.second());
    }
    case TimeField::Day: {
        auto adjusted = constrain(dt.day() + direction, 1, DaysInMonth[dt.month()]);
        return DateTime(dt.year(), dt.month(), adjusted, dt.hour(), dt.minute(), dt.second());
    }
    case TimeField::Hour: {
        auto adjusted = constrain(dt.hour() + direction, 0, 23);
        return DateTime(dt.year(), dt.month(), dt.day(), adjusted, dt.minute(), dt.second());
    }
    case TimeField::Minute: {
        auto adjusted = constrain(dt.minute() + direction, 0, 59);
        return DateTime(dt.year(), dt.month(), dt.day(), dt.hour(), adjusted, dt.second());
    }
    case TimeField::Second: {
        auto adjusted = constrain(dt.second() + direction, 0, 59);
        return DateTime(dt.year(), dt.month(), dt.day(), dt.hour(), dt.minute(), adjusted);
    }
    }

    return dt;
}

void SetTimeView::tick(ViewController *views, Pool &pool) {
    if (!dirty_) {
        return;
    }

    auto bus = get_board()->i2c_core();
    auto display = get_display();

    char primary[64] = { 0 };
    char secondary[64] = { 0 };

    DateTime dt{ time_ };

    constexpr const char *FixedWidthFormat = "%d/%2d/%2d %02d:%02d:%02d";
    tiny_snprintf(primary, sizeof(primary), FixedWidthFormat, dt.year(), dt.month(), dt.day(), dt.hour(), dt.minute(), dt.second());
    tiny_snprintf(secondary, sizeof(secondary), ActiveFieldIndicator[field_]);

    display->simple(SimpleScreen{ primary, secondary });

    dirty_ = false;
}

void SetTimeView::up(ViewController *views) {
    time_ = adjust_time(field_, DateTime(time_), 1).unix_time();
    dirty_ = true;
}

void SetTimeView::down(ViewController *views) {
    time_ = adjust_time(field_, DateTime(time_), -1).unix_time();
    dirty_ = true;
}

void SetTimeView::enter(ViewController *views) {
    auto maybe_next = get_next_field(field_);
    if (!maybe_next) {
        clock_adjust(time_);
        views->show_home();
        return;
    }

    field_ = *maybe_next;

    dirty_ = true;
}

void SetTimeView::prepare() {
    field_ = TimeField::Year;
    time_ = get_clock_now();
    dirty_ = true;
}

} // namespace fk
