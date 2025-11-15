#include "winc_upgrade.h"

#include "utilities.h"
#include "pool.h"
#include "hal/hal.h"

#include "state_manager.h"
#include "wifi_toggle_worker.h"

#if defined(__SAMD51__) && !defined(FK_NETWORK_ESP32_WIFI101)
#include <driver/include/m2m_wifi.h>

extern "C" {

#include <spi_flash/include/spi_flash.h>

extern int8_t g_winc1500_pin_cs;
extern int8_t g_winc1500_pin_irq;
extern int8_t g_winc1500_pin_rst;
extern int8_t g_winc1500_pin_en;
}

namespace fk {

constexpr size_t WincFlashUpgradeBufferSize = 1024;

FK_DECLARE_LOGGER("winc1500");

UpgradeWincWorker::UpgradeWincWorker() {
}

bool UpgradeWincWorker::upgrade_from_sd_card(SdCard *sd, Pool *pool) {
    // Since we'll only ever be working with the winc1500 this kind coupling seems fine.
    g_winc1500_pin_cs = WINC1500_CS;
    g_winc1500_pin_irq = WINC1500_IRQ;
    g_winc1500_pin_rst = WINC1500_RESET;

    pinMode(WINC1500_CS, OUTPUT);
    pinMode(WINC1500_IRQ, INPUT);
    pinMode(WINC1500_RESET, OUTPUT);

    digitalWrite(WINC1500_POWER, HIGH);
    SPI1.begin();

    nm_bsp_init();

    if (m2m_wifi_download_mode() != M2M_SUCCESS) {
        logerror("module refused download mode");
        return false;
    }

    // Write main firmware to 0x0 region.
    if (!write_file_region(sd, 0x0000, "winc1500.bin", pool)) {
        return false;
    }

    // This region is erased above, and in the firmware we ship this is always v1.... I hope.
    const size_t CertHeaderSize = 16;
    uint8_t buffer[CertHeaderSize];
    if (spi_flash_read(buffer, 0x4000, CertHeaderSize) != M2M_SUCCESS) {
        logerror("read error");
        return false;
    }

    fk_dump_memory("certs ", buffer, CertHeaderSize);

    // Write SSL certificates.
    if (!write_file_region(sd, 0x4000, "ssl-v1.bin", pool)) {
        return false;
    }

    loginfo("done!");
    return true;
}

bool UpgradeWincWorker::write_file_region(SdCard *sd, uint32_t flash_address, const char *file_name, Pool *pool) {
    auto file = sd->open(file_name, OpenFlags::Read, *pool);
    if (file == nullptr || !file->is_open()) {
        logerror("error opening '%s'", file_name);
        return false;
    }

    auto file_size = file->file_size();
    if (file_size == 0) {
        logerror("empty file '%s'", file_name);
        file->close();
        return false;
    }

    file->seek_beginning();

    loginfo("erasing %d bytes...", file_size);
    uint32_t len = file_size;
    if (spi_flash_erase(flash_address, len) != M2M_SUCCESS) {
        logerror("erase error");
        file->close();
        return false;
    }

    loginfo("writing %d bytes...", file_size);
    auto buffer = (uint8_t *)pool->malloc(WincFlashUpgradeBufferSize);
    auto total_bytes = (uint32_t)0u;
    while (total_bytes < file_size) {
        auto nread = file->read(buffer, WincFlashUpgradeBufferSize);
        if (nread <= 0) {
            break;
        }

        if (spi_flash_write(buffer, flash_address, nread) != M2M_SUCCESS) {
            logerror("write error");
            file->close();
            return false;
        }

        total_bytes += nread;
        flash_address += nread;
    }

    file->close();

    return true;
}

void UpgradeWincWorker::run(Pool &pool) {
    WifiToggleWorker disable_wifi{ WifiToggleWorker::DesiredState::Disabled };
    disable_wifi.run(pool);

    auto lock = sd_mutex.acquire(UINT32_MAX);
    auto sd = get_sd_card();

    if (!sd->begin()) {
        return;
    }

    GlobalStateManager gsm;

    if (upgrade_from_sd_card(sd, &pool)) {
        gsm.notify("upgrade success");
    } else {
        gsm.notify("upgrade failed!");
    }
}

} // namespace fk
#endif
