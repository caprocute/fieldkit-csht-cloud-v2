#include "hal/buttons.h"
#include "hal/metal/metal_buttons.h"

namespace fk {

constexpr uint32_t ButtonDebounceDelay = 50;

void Button::changed(bool down) {
    // DO NOT LOG
    auto now = fk_uptime();
    if (debounce_ > 0 && now - debounce_ < ButtonDebounceDelay) {
        return;
    }

    auto ipc = get_ipc();
    if (down) {
        if (!down_) {
            down_ = true;
            started_ = now;
            debounce_ = now;
            if (ipc != nullptr && ipc->available()) {
                touch(now);
                ipc->enqueue_button_down(this);
            }
        }
    } else if (down_) {
        down_ = false;
        debounce_ = now;
        if (ipc != nullptr && ipc->available()) {
            ipc->enqueue_button_up(this);
        }
    }
}

FK_DECLARE_LOGGER("buttons");

Button::Button(const char *name, uint8_t index) : name_(name), index_(index) {
}

bool Button::is_up() const {
    return index_ == Buttons::Left;
}

bool Button::is_enter() const {
    return index_ == Buttons::Middle;
}

bool Button::is_down() const {
    return index_ == Buttons::Right;
}

bool Button::is_external() const {
    return index_ == Buttons::External;
}

bool Button::start_network() {
    return index_ == Buttons::External;
}

#if defined(FK_HARDWARE_FULL)
static MetalButtons buttons;
#else
static LinuxButtons buttons;
#endif

Buttons *get_buttons() {
    return &buttons;
}

} // namespace fk
