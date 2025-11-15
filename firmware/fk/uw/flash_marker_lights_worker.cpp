#if defined(__SAMD51__) && defined(FK_UNDERWATER)

#include "uw/flash_marker_lights_worker.h"
#include "hal/marker_lights.h"
#include "platform.h"

namespace fk {

FK_DECLARE_LOGGER("markers");

FlashMarkerLightsWorker::FlashMarkerLightsWorker() {
}

void FlashMarkerLightsWorker::run(Pool &pool) {
    get_marker_lights()->begin();
    get_marker_lights()->off();

    fk_delay(3000);

    get_marker_lights()->on();

    fk_delay(50);

    get_marker_lights()->off();
}

} // namespace fk

#endif
