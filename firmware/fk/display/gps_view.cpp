#include <tiny_printf.h>

#include "display/gps_view.h"
#include "state_ref.h"
#include "hal/board.h"
#include "hal/display.h"
#include "platform.h"

#include "l10n/l10n.h"

namespace fk {

void GpsView::tick(ViewController *views, Pool &pool) {
    auto bus = get_board()->i2c_core();
    auto display = get_display();
    auto gs = get_global_state_ro();

    char first[64] = { 0 };
    char second[64] = { 0 };

    if (gs.get()->gps.enabled) {
        tiny_snprintf(first, sizeof(first), "%.1f,  %.1f", gs.get()->gps.latitude, gs.get()->gps.longitude);
        tiny_snprintf(second, sizeof(second), "%d (%" PRIu32 ") %s", gs.get()->gps.satellites, gs.get()->gps.chars,
                      gs.get()->gps.fix ? "F" : "");
    } else {
        tiny_snprintf(first, sizeof(first), "%s", en_US[FK_MENU_GPS_OFF]);
    }

    display->simple(SimpleScreen{ first, second });
}

void GpsView::hide() {
}

} // namespace fk
