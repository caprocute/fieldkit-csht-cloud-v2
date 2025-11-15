#include "display_self_check_callbacks.h"

namespace fk {

DisplaySelfCheckCallbacks::DisplaySelfCheckCallbacks() {
    screen_.checks = queued_;
}

void DisplaySelfCheckCallbacks::update(SelfCheckStatus status) {
    number_ = 0;
    append(status.rtc);
    append(status.temperature);
    append(status.battery_gauge);
    append(status.solar_gauge);
    append(status.qspi_memory);
    append(status.spi_memory);
    append(status.wifi);
    append(status.gps);
    append(status.sd_card_open);
    append(status.sd_card_write);
    append(status.bp_mux);
    append(status.bp_shift);
    append(status.bp_leds);
    append(status.lora);
    append(status.modules);
}

void DisplaySelfCheckCallbacks::append(SelfCheckCheck check) {
    append(check.name, check.status);
}

void DisplaySelfCheckCallbacks::append(const char *name, CheckStatus status) {
    FK_ASSERT(number_ < NumberOfChecks);
    if (status == CheckStatus::Pass) {
        checks_[number_] = { name, CheckType::PassFail, true };
        queued_[number_] = &checks_[number_];
    } else if (status == CheckStatus::Fail) {
        checks_[number_] = { name, CheckType::PassFail, false };
        queued_[number_] = &checks_[number_];
    } else {
        checks_[number_] = { name, CheckType::Skipped, false };
        queued_[number_] = &checks_[number_];
    }
    number_++;
    FK_ASSERT(number_ < NumberOfChecks);
    queued_[number_] = nullptr;
}

void DisplaySelfCheckCallbacks::append(ModuleCheckStatus status) {
    checks_[number_] = { status.name(), CheckType::Flags, status.value() };
    queued_[number_] = &checks_[number_];
    number_++;
    FK_ASSERT(number_ < NumberOfChecks);
    queued_[number_] = nullptr;
}

void DisplaySelfCheckCallbacks::clear() {
    queued_[0] = nullptr;
    number_ = 0;
}

SelfCheckScreen &DisplaySelfCheckCallbacks::screen() {
    return screen_;
}

} // namespace fk
