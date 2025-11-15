#include "fk.h"

#include "hal/display.h"
#include "hal/metal/u8g2_display.h"

namespace fk {

MenuScreen::MenuScreen(const char *title, MenuOption **options) : title_(title), options_(options) {
    options_[0]->focused_ = true;

    for (auto i = 0u; options[i] != nullptr; ++i) {
        number_options_ = i + 1;
    }
}

static NullDisplay null_display;
#if defined(FK_HARDWARE_FULL)
static U8g2Display u8g2_display;
#else
static NullDisplay u8g2_display;
#endif

static Display *picked = nullptr;

Display *get_display() {
    if (picked == nullptr) {
        if (u8g2_display.begin()) {
            picked = &u8g2_display;
        } else {
            picked = &null_display;
        }
        FK_ASSERT(picked != nullptr);
    }
    return picked;
}

} // namespace fk
