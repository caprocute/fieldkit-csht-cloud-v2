#if defined(__SAMD51__) && defined(FK_NETWORK_ESP32_WIFI101)

#include "uw/esp32_passthru_worker.h"
#include "networking/wifi_toggle_worker.h"
#include "hal/pins.h"
#include "platform.h"

#include <Arduino.h>

namespace fk {

FK_DECLARE_LOGGER("esp32");

Esp32PassthruWorker::Esp32PassthruWorker() {
}

void Esp32PassthruWorker::run(Pool &pool) {
    WifiToggleWorker disable_wifi{ WifiToggleWorker::DesiredState::Disabled };

    disable_wifi.run(pool);

    pinMode(WIFI_ESP32_POWER, OUTPUT);
    pinMode(WIFI_ESP32_CS, OUTPUT);
    pinMode(WIFI_ESP32_GPIO0, OUTPUT);
    pinMode(WIFI_ESP32_EN, OUTPUT);

    Serial.begin(115200);
    Serial0.begin(115200);

    // Manually put the ESP32 in upload mode
    digitalWrite(WIFI_ESP32_POWER, LOW);
    digitalWrite(WIFI_ESP32_CS, LOW);
    digitalWrite(WIFI_ESP32_GPIO0, LOW);
    digitalWrite(WIFI_ESP32_EN, LOW);
    digitalWrite(WIFI_ESP32_POWER, HIGH);
    delay(100);
    digitalWrite(WIFI_ESP32_EN, HIGH);
    delay(100);

    loginfo("beginning passthru");

    uint32_t to_device = 0;
    uint32_t from_device = 0;
    uint32_t to_device_delta = 0;
    uint32_t from_device_delta = 0;
    uint32_t activity = fk_uptime();

    while (true) {
        while (Serial.available()) {
            // SEGGER_RTT_PutChar(0, '>');
            Serial0.write(Serial.read());
            to_device++;
            to_device_delta++;
            activity = fk_uptime();
        }

        while (Serial0.available()) {
            // SEGGER_RTT_PutChar(0, '<');
            Serial.write(Serial0.read());
            from_device++;
            from_device_delta++;
            activity = fk_uptime();
        }

        if (fk_uptime() - activity > 1000) {
            loginfo("%d %d %d %d", to_device, from_device, to_device_delta, from_device_delta);
            to_device_delta = 0;
            from_device_delta = 0;
            activity = fk_uptime();
        }
    }
}

} // namespace fk

#endif