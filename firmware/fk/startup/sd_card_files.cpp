#include "startup/sd_card_files.h"

#include "state_manager.h"

#include "hal/hal.h"

#include "battery_status.h"

#include "tasks/tasks.h"
#include "display/display_views.h"

#include "upgrade_from_sd_worker.h"
#include "modules/configure_module_worker.h"
#include "storage/factory_wipe_worker.h"
#include "poll_sensors_worker.h"
#include "readings_worker.h"
#include "graceful_shutdown.h"

#include "networking/winc_upgrade.h"

namespace fk {

FK_DECLARE_LOGGER("startup");

bool SdCardFiles::check(Pool &pool) {
    auto lock = sd_mutex.acquire(UINT32_MAX);
    auto sd = get_sd_card();

    if (!sd->begin()) {
        return true;
    }

    SdCardFiles files{ sd, &pool };

    return files.check();
}

SdCardFiles::SdCardFiles(SdCard *card, Pool *pool) : sd_(card), pool_(pool) {
}

bool SdCardFiles::check() {
    if (check_for_self_test_startup()) {
        return false;
    }

    if (check_for_provision_startup()) {
        return false;
    }

    if (check_for_upgrading_startup()) {
        return false;
    }

    if (check_for_program_modules_startup()) {
        return false;
    }

    if (check_for_configure_modules_startup()) {
        return false;
    }

    return true;
}

bool SdCardFiles::check_for_self_test_startup() {
    loginfo("check for self test startup");

    auto config_file = "testing.cfg";
    if (!sd_->is_file(config_file)) {
        loginfo("no %s found", config_file);
        return false;
    }

    GlobalStateManager gsm;
    gsm.notify(FK_MENU_STARTUP_SELF_CHECK);

    fk_debug_mode_configure("Self Test");

    FK_ASSERT(os_task_start(&display_task) == OSS_SUCCESS);

    // This is so risky, thankfully we're rarely in here. This is here
    // to allow the display task to start so the controller is available.
    fk_delay(100);

    auto vc = ViewController::get();
    if (vc != nullptr) {
        vc->show_self_check();
    }

    return true;
}

bool SdCardFiles::check_for_upgrading_startup() {
    loginfo("check for upgrading startup");

    auto config_file = "upgrade.cfg";
    if (!sd_->is_file(config_file)) {
        loginfo("no %s found", config_file);
        return false;
    }

    if (!sd_->unlink(config_file)) {
        loginfo("error unlinking %s", config_file);
        return false;
    }

    GlobalStateManager gsm;
    gsm.notify(FK_MENU_STARTUP_UPGRADING);

    fk_debug_mode_configure("Upgrading");

    FK_ASSERT(os_task_start(&display_task) == OSS_SUCCESS);

    auto swap = true;
    auto main_binary = "fk-bundled-fkb-network.bin";
    auto bl_binary = "fkbl-fkb-network.bin";
    auto params = SdCardFirmware{ SdCardFirmwareOperation::Load, bl_binary, main_binary, swap, true, OneSecondMs };
    UpgradeFirmwareFromSdWorker upgrade_worker{ params };
    upgrade_worker.run(*pool_);

    fk_graceful_shutdown();

    fk_restart();

    return true;
}

bool SdCardFiles::check_for_provision_startup() {
    loginfo("check for provision startup");

    auto config_file = "fk.cfg";
    if (!sd_->is_file(config_file)) {
        loginfo("no %s found", config_file);
        return false;
    }

    GlobalStateManager gsm;
    gsm.notify(FK_MENU_STARTUP_PROVISIONING);

    fk_debug_mode_configure("Provision");

    FK_ASSERT(os_task_start(&display_task) == OSS_SUCCESS);

    if (!check_for_winc_firmware()) {
        gsm.notify("winc1500 upgrade failed");
        return false;
    }

    auto swap = true;
    auto main_binary = "fk-bundled-fkb.bin";
    auto bl_binary = "fkbl-fkb.bin";
    auto params = SdCardFirmware{ SdCardFirmwareOperation::Load, bl_binary, main_binary, swap, true, OneSecondMs };
    UpgradeFirmwareFromSdWorker upgrade_worker{ params };
    upgrade_worker.run(*pool_);

    FactoryWipeWorker factory_wipe_worker{ false };
    factory_wipe_worker.run(*pool_);

    fk_logs_flush();

    return true;
}

bool SdCardFiles::check_for_configure_modules_startup() {
    loginfo("check for program modules startup");

    auto config_file = "fk-configure.cfg";
    if (!sd_->is_file(config_file)) {
        loginfo("no %s found", config_file);
        return false;
    }

    auto file = sd_->open(config_file, OpenFlags::Read, *pool_);
    if (file == nullptr || !file->is_open()) {
        logerror("unable to open '%s'", config_file);
        return false;
    }

    auto file_size = (int32_t)file->file_size();
    if (file_size == 0) {
        logerror("empty file '%s'", config_file);
        return false;
    }

    auto buffer = (uint8_t *)pool_->malloc(file_size);
    auto bytes_read = file->read(buffer, file_size);
    if (bytes_read != file_size) {
        logerror("error reading file '%s'", config_file);
        return false;
    }

    log_bytes("modcfg-file", buffer, file_size);

    BatteryChecker battery_checker;
    battery_checker.refresh(true);

    ModuleRegistry registry;
    registry.initialize();

    get_modmux()->begin();

#if defined(FK_UNDERWATER)
    // Right now we're using this for fkuw and the pin based modmux can only
    // power one module at a time.
    get_modmux()->enable_module(ModulePosition::from(0), ModulePower::Always);
#else
    get_modmux()->enable_all_modules();

    get_modmux()->choose(ModulePosition::from(1));
#endif

    auto module_bus = get_board()->i2c_module();

    loginfo("erasing configuration for %" PRIu32, file_size);
    UnknownEeprom unknown{ module_bus };
    auto eeprom = unknown.find();
    if (eeprom) {
        if (!eeprom->erase_configuration(file_size)) {
            logerror("erasing module configuration");
        }

        loginfo("after erase");
        auto reading = (uint8_t *)pool_->malloc(256);
        eeprom->read_data(EEPROM_ADDRESS_CONFIG, reading, 256);
        log_bytes("modcfg-read", reading, 256);

        loginfo("writing configuration");
        log_bytes("modcfg-file", buffer, file_size);
        if (!eeprom->write_configuration(buffer, bytes_read)) {
            logerror("writing module configuration");
        }

        loginfo("after write");
        eeprom->read_data(EEPROM_ADDRESS_CONFIG, reading, 256);
        log_bytes("modcfg-read", reading, 256);
        ReadingsWorker readings_worker{ false, true, false, false };
        readings_worker.run(*pool_);

        get_ipc()->launch_worker(WorkerCategory::Polling, create_pool_worker<PollSensorsWorker>(false, true, true, ThirtySecondsMs));

        task_display_params.readings = true;
        FK_ASSERT(os_task_start_options(&display_task, os_task_get_priority(&display_task), &task_display_params) == OSS_SUCCESS);
    }

    return false;
}

bool SdCardFiles::check_for_program_modules_startup() {
    loginfo("check for configure modules startup");

    auto config_file = "fk-program.cfg";
    if (!sd_->is_file(config_file)) {
        loginfo("no %s found", config_file);
        return false;
    }

    auto file = sd_->open(config_file, OpenFlags::Read, *pool_);
    if (file == nullptr || !file->is_open()) {
        logerror("unable to open '%s'", config_file);
        return false;
    }

    auto file_size = file->file_size();
    if (file_size == 0) {
        logerror("empty file '%s'", config_file);
        return false;
    }

    ModuleHeader header;
    auto bytes_read = file->read((uint8_t *)&header, sizeof(ModuleHeader));
    if (bytes_read != sizeof(ModuleHeader)) {
        logerror("error reading header '%s'", config_file);
        return false;
    }

    get_modmux()->enable_all_modules();

    BatteryChecker battery_checker;
    battery_checker.refresh(true);

    ModuleRegistry registry;
    registry.initialize();

    ConfigureModuleWorker configure_worker{ ModulePosition::All, header };
    configure_worker.run(*pool_);

    ReadingsWorker readings_worker{ false, true, false, false };
    readings_worker.run(*pool_);

    get_ipc()->launch_worker(WorkerCategory::Polling, create_pool_worker<PollSensorsWorker>(false, true, true, ThirtySecondsMs));

    task_display_params.readings = true;
    FK_ASSERT(os_task_start_options(&display_task, os_task_get_priority(&display_task), &task_display_params) == OSS_SUCCESS);

    return true;
}

bool SdCardFiles::check_for_winc_firmware() {
#if defined(__SAMD51__) && !defined(FK_NETWORK_ESP32_WIFI101)
// This is disabled right now because we can't tell if this is necessary, so
// having this in could cause us to upgrade on every boot, which would be annoying.
#if defined(FK_NETWORK_WINC1500_UPGRADE_BOOT)
    loginfo("check for winc1500 firmware");

    auto file_name = "winc1500.bin";
    if (!sd_->is_file(file_name)) {
        loginfo("no %s found", file_name);
        return false;
    }

    return winc_upgrade_from_sd_card(sd_, pool_);
#else
    return false;
#endif
#else
    return false;
#endif
}

} // namespace fk
