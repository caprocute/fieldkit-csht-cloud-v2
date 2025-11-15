#include <samd51_common.h>

#include "deep_sleep.h"
#include "graceful_shutdown.h"
#include "hal/board.h"
#include "menu_view.h"
#include "hal/display.h"
#include "platform.h"
#include "state_ref.h"
#include "device_name.h"

#include "compare_banks_worker.h"
#include "export_data_worker.h"
#include "lora_ranging_worker.h"
#include "poll_sensors_worker.h"
#include "simple_workers.h"
#include "upgrade_from_sd_worker.h"

#include "modules/configure_module_worker.h"
#include "modules/refresh_modules_worker.h"

#include "networking/download_firmware_worker.h"
#include "networking/upload_data_worker.h"
#include "networking/winc_upgrade.h"

#include "display/debug_module_view.h"
#include "display/readings_view.h"

#include "storage/dump_flash_memory_worker.h"
#include "storage/backup_worker.h"

#include "uw/esp32_passthru_worker.h"
#include "uw/program_fkuw_worker.h"
#include "uw/flash_marker_lights_worker.h"

#include "l10n/l10n.h"

namespace fk {

FK_DECLARE_LOGGER("menu");

typedef MenuHandlerReturn (*menu_handler_fn_t)(MenuContext &menus, void *arg);

class StaticMenuOption : public MenuOption {
private:
    menu_handler_fn_t handler_;

public:
    StaticMenuOption(uint32_t label_key, menu_handler_fn_t handler) : MenuOption(en_US[label_key]), handler_(handler) {
    }

public:
    MenuHandlerReturn on_selected(MenuContext &menus) override {
        return handler_(menus, nullptr);
    }
};

static MenuHandlerReturn handle_confirm_no(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::back();
}

static MenuOption *pending_confirmation{ nullptr };

static MenuHandlerReturn handle_confirm_yes(MenuContext &menus, void *arg) {
    if (pending_confirmation != nullptr) {
        auto mhr = pending_confirmation->on_selected(menus);
        pending_confirmation = nullptr;
        return mhr;
    } else {
        return MenuHandlerReturn::home();
    }
}

static StaticMenuOption confirm_no(FK_MENU_OPTION_CONFIRM_NO_CANCEL, handle_confirm_no);
static StaticMenuOption confirm_yes(FK_MENU_OPTION_CONFIRM_YES, handle_confirm_yes);
static MenuOption *confirm_options[] = { &confirm_no, &confirm_yes, nullptr };
static MenuScreen confirm_menu("confirm", confirm_options);

struct ConfirmOption : public MenuOption {
    MenuOption *yes_;

    ConfirmOption(MenuOption *yes) : MenuOption(yes->label_), yes_(yes) {
    }

    MenuHandlerReturn on_selected(MenuContext &menus) override {
        pending_confirmation = yes_;
        return MenuHandlerReturn::menu(&confirm_menu);
    }
};

static MenuHandlerReturn handle_back(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::back();
}

static StaticMenuOption back(FK_MENU_OPTION_BACK, handle_back);

static MenuHandlerReturn handle_home(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::home();
}

static StaticMenuOption home(FK_MENU_OPTION_HOME, handle_home);

static MenuHandlerReturn handle_info_menu_build(MenuContext &menus, void *arg) {
    menus.views->show_build();
    return MenuHandlerReturn::back();
}

static StaticMenuOption info_build(FK_MENU_OPTION_INFO_BUILD, handle_info_menu_build);
static MenuOption *info_options[] = { &back, &info_build, nullptr };
static MenuScreen info_menu("info", info_options);

static MenuHandlerReturn handle_module_bays_status(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<RefreshModulesWorker>());
    menus.views->show_module_status();
    return MenuHandlerReturn::back();
}

static StaticMenuOption module_bays_status(FK_MENU_OPTION_MODULE_BAY_STATUS, handle_module_bays_status);
static MenuOption *module_bays_options[] = { &back, &module_bays_status, nullptr };
static MenuScreen module_bays_menu("modules", module_bays_options);

static ModulePosition selected_module_bay(0);

static MenuHandlerReturn handle_module_program_weather(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program weather: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::weather_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_water_ph(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program water-ph: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::ph_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_water_ec(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program water-ec: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::ec_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_water_do(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program water-do: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::do_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_water_temp(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program water-temp: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::temp_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));

    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_water_orp(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program water-orp: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::orp_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_distance(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program distance: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::distance_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_module_program_water_ms5837(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program ms5837: %d", selected_module_bay.integer());
    auto header = ConfigureModuleWorker::ms5837_header();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay, header));
    return MenuHandlerReturn::back();
}

#if defined(FK_UNDERWATER)
static MenuHandlerReturn handle_module_program_fkuw_all(MenuContext &menus, void *arg) {
    menus.views->show_module_status();
    loginfo("program fkuw");
    get_ipc()->launch_worker(create_pool_worker<ProgramFkuwWorker>());
    return MenuHandlerReturn::back();
}
static StaticMenuOption module_program_fkuw_all(FK_MENU_OPTION_MODULE_PROGRAM_FKUW_ALL, handle_module_program_fkuw_all);
#endif

static StaticMenuOption module_program_weather(FK_MENU_OPTION_MODULE_PROGRAM_WEATHER, handle_module_program_weather);
static StaticMenuOption module_program_water_ph(FK_MENU_OPTION_MODULE_PROGRAM_WATER_PH, handle_module_program_water_ph);
static StaticMenuOption module_program_water_ec(FK_MENU_OPTION_MODULE_PROGRAM_WATER_EC, handle_module_program_water_ec);
static StaticMenuOption module_program_water_do(FK_MENU_OPTION_MODULE_PROGRAM_WATER_DO, handle_module_program_water_do);
static StaticMenuOption module_program_water_temp(FK_MENU_OPTION_MODULE_PROGRAM_WATER_TEMP, handle_module_program_water_temp);
static StaticMenuOption module_program_water_orp(FK_MENU_OPTION_MODULE_PROGRAM_WATER_ORP, handle_module_program_water_orp);
static StaticMenuOption module_program_distance(FK_MENU_OPTION_MODULE_PROGRAM_DISTANCE, handle_module_program_distance);
static StaticMenuOption module_program_water_ms5837(FK_MENU_OPTION_MODULE_PROGRAM_MS5837, handle_module_program_water_ms5837);
static MenuOption *module_program_options[] = { &back,
                                                &module_program_weather,
                                                &module_program_water_ph,
                                                &module_program_water_ec,
                                                &module_program_water_do,
                                                &module_program_water_temp,
                                                &module_program_water_orp,
                                                &module_program_distance,
                                                &module_program_water_ms5837,
#if defined(FK_UNDERWATER)
                                                &module_program_fkuw_all,
#endif
                                                nullptr

};
static MenuScreen module_program_menu("program", module_program_options);

static MenuHandlerReturn handle_module_program(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&module_program_menu);
}

static MenuHandlerReturn handle_module_erase(MenuContext &menus, void *arg) {
    menus.views->show_home();
    get_ipc()->launch_worker(create_pool_worker<ConfigureModuleWorker>(selected_module_bay));
    return MenuHandlerReturn::back();
}

static void disable_readings_this_run() {
    auto gs = get_global_state_rw();
    gs.get()->scheduler.readings.interval = 0;
    gs.get()->scheduler.readings.cron = {};
}

static MenuHandlerReturn handle_module_debug(MenuContext &menus, void *arg) {
    disable_readings_this_run();

    auto gs = get_global_state_ro();
    auto menu = create_debug_module_menu(selected_module_bay, gs.get(), &back, *menus.pool);
    if (menu != nullptr) {
        return MenuHandlerReturn::menu(menu, ThirtyMinutesMs);
    } else {
        return MenuHandlerReturn::back();
    }
}

static StaticMenuOption module_program(FK_MENU_OPTION_MODULE_PROGRAM, handle_module_program);
static StaticMenuOption module_erase_confirmed(FK_MENU_OPTION_MODULE_ERASE, handle_module_erase);
static ConfirmOption module_erase(&module_erase_confirmed);
static StaticMenuOption module_debug(FK_MENU_OPTION_MODULE_DEBUG, handle_module_debug);
static MenuOption *module_options[] = { &back, &home, &module_program, &module_erase, &module_debug, nullptr };
static MenuScreen module_menu("module", module_options);

static MenuHandlerReturn handle_tools_set_time(MenuContext &menus, void *arg) {
    menus.views->show_set_time();
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_self_check(MenuContext &menus, void *arg) {
    menus.views->show_self_check();
    return MenuHandlerReturn::reset();
}

enum Service {
    Gps,
    Wifi,
};

class ServiceDurationOption : public MenuOption {
private:
    Service service_;
    uint32_t duration_;

public:
    ServiceDurationOption(Service service, uint32_t label_key, uint32_t duration)
        : MenuOption(en_US[label_key]), service_(service), duration_(duration) {
    }

public:
    MenuHandlerReturn on_selected(MenuContext &menus) override {
        set_duration();
        return MenuHandlerReturn::back();
    }

    void refresh(GlobalState const *gs) override {
        auto current = get_current_duration(gs);
        logverbose("duration %" PRIu32, current);
        selected(current == duration_);
    }

private:
    void set_duration() {
        StandardPool pool{ "duration-option" };
        auto gs = get_global_state_rw();
        switch (service_) {
        case Service::Gps: {
            gs.get()->scheduler.gps.duration = duration_;
            gs.get()->flush(OneSecondMs, pool);
            break;
        }
        case Service::Wifi: {
            gs.get()->scheduler.network.duration = duration_;
            gs.get()->flush(OneSecondMs, pool);
            if (!get_network()->enabled()) {
                get_ipc()->launch_worker(create_pool_worker<WifiToggleWorker>(WifiToggleWorker::DesiredState::Toggle));
            }
            break;
        }
        }
    }

    uint32_t get_current_duration(GlobalState const *gs) {
        switch (service_) {
        case Service::Gps:
            return gs->scheduler.gps.duration;
        case Service::Wifi:
            return gs->scheduler.network.duration;
        default: {
            FK_ASSERT(0);
            return 0;
        }
        }
    }
};

static ServiceDurationOption gps_mode_idle_off(Service::Gps, FK_MENU_OPTION_GPS_MODE_IDLE_OFF, TenMinutesSeconds);
static ServiceDurationOption gps_mode_always_on(Service::Gps, FK_MENU_OPTION_GPS_MODE_ALWAYS_ON, UINT32_MAX);
static MenuOption *gps_mode_options[] = { &back, &gps_mode_idle_off, &gps_mode_always_on, nullptr };
static MenuScreen gps_mode_menu("gps-mode", gps_mode_options);

static MenuHandlerReturn handle_tools_gps_mode(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&gps_mode_menu);
}

static MenuHandlerReturn handle_tools_format_sd(MenuContext &menus, void *arg) {
    menus.views->show_message(en_US[FK_MENU_FORMAT_FORMATTING]);
    if (!get_sd_card()->format()) {
        menus.views->show_message(en_US[FK_MENU_FORMAT_ERROR]);
    } else {
        menus.views->show_message(en_US[FK_MENU_FORMAT_SUCCESS], FiveSecondsMs);
    }
    return MenuHandlerReturn::back();
}

static MenuHandlerReturn handle_tools_dump_flash(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(WorkerCategory::Transfer, create_pool_worker<DumpFlashMemoryWorker>());
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_backup(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(WorkerCategory::Transfer, create_pool_worker<BackupWorker>());
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_sd_upgrade(MenuContext &menus, void *arg) {
    auto params = SdCardFirmware{ SdCardFirmwareOperation::Load, "fkbl-fkb.bin", "fk-bundled-fkb.bin", true, false, OneSecondMs };
    get_ipc()->launch_worker(create_pool_worker<UpgradeFirmwareFromSdWorker>(params));
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_upgrade_winc1500(MenuContext &menus, void *arg) {
#if defined(__SAMD51__) && !defined(FK_NETWORK_ESP32_WIFI101)
    get_ipc()->launch_worker(create_pool_worker<UpgradeWincWorker>());
#endif
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_lora_ranging(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(WorkerCategory::Lora, create_pool_worker<LoraRangingWorker>());
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_lora_view(MenuContext &menus, void *arg) {
    menus.views->show_lora();
    return MenuHandlerReturn::none();
}

static MenuHandlerReturn handle_tools_lora_factory_reset(MenuContext &menus, void *arg) {
    auto network = get_lora_network();
    if (network->wake()) {
        network->factory_reset();
        network->sleep(OneDayMs);
    }
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_watch_gps(MenuContext &menus, void *arg) {
    menus.views->show_gps();
    return MenuHandlerReturn::none();
}

static MenuHandlerReturn handle_tools_factory_reset(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<FactoryWipeWorker>(true));
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_generate_name(MenuContext &menus, void *arg) {
    StandardPool pool{ "generate-name" };
    auto gs = get_global_state_rw();
    auto name = fk_device_name_generate(pool);
    strncpy(gs.get()->general.name, name, sizeof(gs.get()->general.name));
    gs.get()->flush(OneSecondMs, pool);

    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_tools_restart(MenuContext &menus, void *arg) {
    get_display()->off();
    fk_graceful_shutdown();
    fk_restart();
    return MenuHandlerReturn::none();
}

static MenuHandlerReturn handle_tools_export_csv(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<ExportDataWorker>());
    return MenuHandlerReturn::home();
}

#if defined(FK_UNDERWATER)
static MenuHandlerReturn handle_tools_esp32_passthru(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<Esp32PassthruWorker>());
    return MenuHandlerReturn::home();
}

static StaticMenuOption tools_esp32_passthru(FK_MENU_OPTION_TOOLS_ESP32_PASSTHRU, handle_tools_esp32_passthru);

static MenuHandlerReturn handle_tools_flash_marker_lights(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<FlashMarkerLightsWorker>());
    return MenuHandlerReturn::home();
}

static StaticMenuOption tools_flash_marker_lights(FK_MENU_OPTION_TOOLS_FLASH_MARKER_LIGHTS, handle_tools_flash_marker_lights);
#endif

static StaticMenuOption tools_set_time(FK_MENU_OPTION_TOOLS_SET_TIME, handle_tools_set_time);
static StaticMenuOption tools_gps_mode(FK_MENU_OPTION_TOOLS_GPS_MODE, handle_tools_gps_mode);

static StaticMenuOption tools_format_sd_confirmed(FK_MENU_OPTION_TOOLS_FORMAT_SD, handle_tools_format_sd);
static ConfirmOption tools_format_sd(&tools_format_sd_confirmed);
static StaticMenuOption tools_self_check(FK_MENU_OPTION_TOOLS_SELF_CHECK, handle_tools_self_check);
static StaticMenuOption tools_dump_flash(FK_MENU_OPTION_TOOLS_DUMP_FLASH, handle_tools_dump_flash);
static StaticMenuOption tools_backup(FK_MENU_OPTION_TOOLS_BACKUP, handle_tools_backup);
static StaticMenuOption tools_sd_upgrade(FK_MENU_OPTION_TOOLS_SD_UPGRADE, handle_tools_sd_upgrade);
static StaticMenuOption tools_upgrade_winc1500(FK_MENU_OPTION_TOOLS_UPGRADE_WINC1500, handle_tools_upgrade_winc1500);
static StaticMenuOption tools_lora_ranging(FK_MENU_OPTION_TOOLS_LORA_RANGING, handle_tools_lora_ranging);
static StaticMenuOption tools_lora_view(FK_MENU_OPTION_TOOLS_LORA_VIEW, handle_tools_lora_view);
static StaticMenuOption tools_lora_factory_reset_confirmed(FK_MENU_OPTION_TOOLS_LORA_FACTORY_RESET, handle_tools_lora_factory_reset);
static ConfirmOption tools_lora_factory_reset(&tools_lora_factory_reset_confirmed);
static StaticMenuOption tools_factory_reset_confirmed(FK_MENU_OPTION_TOOLS_FACTORY_RESET, handle_tools_factory_reset);
static ConfirmOption tools_factory_reset(&tools_factory_reset_confirmed);
static StaticMenuOption tools_generate_name_confirmed(FK_MENU_OPTION_TOOLS_GENERATE_NAME, handle_tools_generate_name);
static ConfirmOption tools_generate_name(&tools_generate_name_confirmed);
static StaticMenuOption tools_restart_confirmed(FK_MENU_OPTION_TOOLS_RESTART, handle_tools_restart);
static ConfirmOption tools_restart(&tools_restart_confirmed);
static StaticMenuOption tools_export_csv(FK_MENU_OPTION_TOOLS_EXPORT_CSV, handle_tools_export_csv);
static StaticMenuOption tools_watch_gps(FK_MENU_OPTION_TOOLS_WATCH_GPS, handle_tools_watch_gps);

#if defined(FK_UNDERWATER)
static MenuOption *tools_options[] = { &back,
                                       &tools_self_check,
                                       &tools_set_time,
                                       &tools_watch_gps,
                                       &tools_flash_marker_lights,
                                       &tools_gps_mode,
                                       &tools_lora_view,
                                       &tools_lora_ranging,
                                       &tools_lora_factory_reset,
                                       &tools_sd_upgrade,
                                       &tools_dump_flash,
                                       &tools_backup,
                                       &tools_format_sd,
                                       &tools_esp32_passthru,
                                       &tools_export_csv,
                                       &tools_factory_reset,
                                       &tools_generate_name,
                                       &tools_restart,
                                       nullptr };
#else
static MenuOption *tools_options[] = { &back,
                                       &tools_self_check,
                                       &tools_set_time,
                                       &tools_watch_gps,
                                       &tools_gps_mode,
                                       &tools_lora_view,
                                       &tools_lora_ranging,
                                       &tools_lora_factory_reset,
                                       &tools_sd_upgrade,
                                       &tools_upgrade_winc1500,
                                       &tools_dump_flash,
                                       &tools_backup,
                                       &tools_format_sd,
                                       &tools_export_csv,
                                       &tools_factory_reset,
                                       &tools_generate_name,
                                       &tools_restart,
                                       nullptr };
#endif

static MenuScreen tools_menu("tools", tools_options);

static void choose_active_network(WifiNetworkInfo network) {
    auto gs = get_global_state_rw();

    gs.get()->network.config.selected = network;
    gs.get()->network.config.modified = fk_uptime();

    if (!get_network()->enabled()) {
        auto worker = create_pool_worker<WifiToggleWorker>(WifiToggleWorker::DesiredState::Enabled);
        get_ipc()->launch_worker(worker);
    }
}

static WifiNetworkInfo get_self_ap_network() {
    auto gs = get_global_state_ro();
    return WifiNetworkInfo{ gs.get()->general.name };
}

static MenuHandlerReturn handle_network_choose_self_ap(MenuContext &menus, void *arg) {
    choose_active_network(get_self_ap_network());
    return MenuHandlerReturn::home();
}

class ConfiguredNetworkOption : public MenuOption {
private:
    WifiNetworkInfo network_;
    uint8_t index_{ 0 };

public:
    ConfiguredNetworkOption(uint8_t index) : MenuOption("?"), index_(index) {
    }

public:
    MenuHandlerReturn on_selected(MenuContext &menus) override {
        choose_active_network(network_);
        return MenuHandlerReturn::home();
    }

    bool active() const override {
        return network_.ssid[0] != 0;
    }

    const char *label() const override {
        return network_.ssid;
    }

    void refresh(GlobalState const *gs) override {
        network_ = gs->network.config.wifi_networks[index_];
    }
};

static StaticMenuOption network_choose_self_ap(FK_MENU_OPTION_NETWORK_CHOOSE_SELF_AP, handle_network_choose_self_ap);
static ConfiguredNetworkOption network_choose_0(0);
static ConfiguredNetworkOption network_choose_1(1);
static MenuOption *network_choose_options[] = { &back, &network_choose_self_ap, &network_choose_0, &network_choose_1, nullptr };
static MenuScreen network_choose_menu("choose", network_choose_options);

static MenuHandlerReturn handle_network_choose(MenuContext &menus, void *arg) {
    auto gs = get_global_state_ro();
    return MenuHandlerReturn::menu(&network_choose_menu);
}

/*
static MenuHandlerReturn handle_network_upgrade(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<DownloadFirmwareWorker>());
    return MenuHandlerReturn::home();
}

static StaticMenuOption network_upgrade("Network Upgrade", handle_network_upgrade);
*/

static ServiceDurationOption network_duration_idle_off(Service::Wifi, FK_MENU_OPTION_NETWORK_DURATION_IDLE_OFF, FiveMinutesSeconds);
static ServiceDurationOption network_duration_always_on(Service::Wifi, FK_MENU_OPTION_NETWORK_DURATION_ALWAYS_ON, UINT32_MAX);
static MenuOption *network_duration_options[] = { &back, &network_duration_idle_off, &network_duration_always_on, nullptr };
static MenuScreen network_duration_menu("network-duration", network_duration_options);

static MenuHandlerReturn handle_network_duration(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&network_duration_menu);
}

static MenuHandlerReturn handle_network_upload(MenuContext &menus, void *arg) {
    get_ipc()->launch_worker(create_pool_worker<UploadDataWorker>(false, false));
    return MenuHandlerReturn::home();
}

static MenuHandlerReturn handle_network_forget(MenuContext &menus, void *arg) {
    StandardPool pool{ "forget-networks" };
    auto gs = get_global_state_rw();
    memzero((void *)&gs.get()->network.config, sizeof(NetworkConfiguration));
    gs.get()->flush(OneSecondMs, pool);
    return MenuHandlerReturn::home();
}

struct ToggleWifiOption : public MenuOption {
    ToggleWifiOption() : MenuOption("") {
    }

    MenuHandlerReturn on_selected(MenuContext &menus) override {
        menus.views->show_home();
        get_ipc()->launch_worker(create_pool_worker<WifiToggleWorker>(WifiToggleWorker::DesiredState::Toggle));
        return MenuHandlerReturn::home();
    }

    const char *label() const override {
        if (get_network()->enabled()) {
            return "Disable";
        }
        return "Enable";
    }
};

static ToggleWifiOption network_toggle;
static StaticMenuOption network_choose(FK_MENU_OPTION_NETWORK_CHOOSE, handle_network_choose);
static StaticMenuOption network_upload(FK_MENU_OPTION_NETWORK_UPLOAD, handle_network_upload);
static StaticMenuOption network_duration(FK_MENU_OPTION_NETWORK_DURATION, handle_network_duration);
static StaticMenuOption network_forget(FK_MENU_OPTION_NETWORK_FORGET, handle_network_forget);
static MenuOption *network_options[] = { &back,           &network_toggle, &network_choose, &network_upload, &network_duration,
                                         &network_forget, nullptr };
static MenuScreen network_menu("network", network_options);

static MenuHandlerReturn handle_schedule_readings(MenuContext &menus, void *arg) {
    menus.views->show_schedule(ScheduleType::Readings);
    return MenuHandlerReturn::none();
}

static MenuHandlerReturn handle_schedule_lora(MenuContext &menus, void *arg) {
    menus.views->show_schedule(ScheduleType::LoRa);
    return MenuHandlerReturn::none();
}

static MenuHandlerReturn handle_schedule_network(MenuContext &menus, void *arg) {
    menus.views->show_schedule(ScheduleType::Network);
    return MenuHandlerReturn::none();
}

static StaticMenuOption schedule_readings(FK_MENU_OPTION_SCHEDULE_READINGS, handle_schedule_readings);
static StaticMenuOption schedule_lora(FK_MENU_OPTION_SCHEDULE_LORA, handle_schedule_lora);
static StaticMenuOption schedule_network(FK_MENU_OPTION_SCHEDULE_NETWORK, handle_schedule_network);
static MenuOption *schedule_options[] = { &back, &schedule_readings, &schedule_lora, &schedule_network, nullptr };
static MenuScreen schedule_menu("schedule", schedule_options);

static MenuOption *messages_options[] = { &back, nullptr };
static MenuScreen messages_menu("messages", messages_options);

static MenuHandlerReturn handle_main_readings(MenuContext &menus, void *arg) {
    auto gs = get_global_state_ro();
    // TODO Move to subpool to allow for repeated presses.
    auto menu = create_readings_menu(gs.get(), *menus.pool);
    return MenuHandlerReturn::menu(menu, OneMinuteMs);
}

MenuScreen *create_message_center(GlobalState const *gs, Pool &pool);

static MenuHandlerReturn handle_main_messages(MenuContext &menus, void *arg) {
    auto gs = get_global_state_rw();
    gs.get()->dynamic.mark_messages_opened();
    // TODO Move to subpool to allow for repeated presses.
    auto menu = create_message_center(gs.get(), *menus.pool);
    return MenuHandlerReturn::menu(menu, OneMinuteMs);
}

static MenuHandlerReturn handle_main_info(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&info_menu);
}

static MenuHandlerReturn handle_main_schedules(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&schedule_menu);
}

static MenuHandlerReturn handle_main_network(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&network_menu);
}

static MenuHandlerReturn handle_main_module_bays(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&module_bays_menu);
}

static MenuHandlerReturn handle_main_tools(MenuContext &menus, void *arg) {
    return MenuHandlerReturn::menu(&tools_menu);
}

static StaticMenuOption main_readings(FK_MENU_OPTION_MAIN_READINGS, handle_main_readings);
static StaticMenuOption main_info(FK_MENU_OPTION_MAIN_INFO, handle_main_info);
static StaticMenuOption main_schedules(FK_MENU_OPTION_MAIN_SCHEDULES, handle_main_schedules);
static StaticMenuOption main_network(FK_MENU_OPTION_MAIN_NETWORK, handle_main_network);
static StaticMenuOption main_module_bays(FK_MENU_OPTION_MAIN_MODULES, handle_main_module_bays);
static StaticMenuOption main_messages(FK_MENU_OPTION_MAIN_MESSAGES, handle_main_messages);
static StaticMenuOption main_tools(FK_MENU_OPTION_MAIN_TOOLS, handle_main_tools);
static MenuOption *main_options[] = {
    &main_readings, &main_messages, &main_info, &main_schedules, &main_network, &main_module_bays, &main_tools, nullptr,
};
static MenuScreen main_menu("main", main_options);

MenuView::MenuView(ViewController *views, Pool &pool) : pool_(&pool), views_(views) {
    active_menu_ = &main_menu;
    refresh_visible(*active_menu_, 0);
}

void MenuView::show() {
    FK_ASSERT(hold_time_ > 0);
    menu_time_ = fk_uptime() + hold_time_;
}

void MenuView::show_for_module(uint8_t bay) {
    selected_module_bay = ModulePosition::from(bay);
    goto_menu(&module_menu);
    show();
}

void MenuView::show_readings() {
    auto gs = get_global_state_ro();
    auto readings_menu = create_readings_menu(gs.get(), *pool_);
    goto_menu(readings_menu, nullptr, TenMinutesMs);
}

MenuScreen *create_message_center(GlobalState const *gs, Pool &pool) {
    auto mc = gs->dynamic.messages();

    auto noptions = 2 + mc.length();
    auto option_index = 0;
    auto options = (MenuOption **)pool.malloc(sizeof(MenuOption *) * noptions);
    auto back = to_lambda_option(&pool, en_US[FK_MENU_READINGS_BACK], [=](MenuContext &menus) { return MenuHandlerReturn::home(); });

    options[option_index++] = back;

    for (auto i = mc.get_first_message(); i != nullptr; i = i->np) {
        options[option_index++] = to_lambda_option(&pool, i->body, [=](MenuContext &menus) { return MenuHandlerReturn::none(); });
    }

    options[option_index] = nullptr;

    return new (pool) MenuScreen("messages", options);
}

void MenuView::tick(ViewController *views, Pool &pool) {
    auto bus = get_board()->i2c_core();
    auto display = get_display();
    display->menu(*active_menu_);

    if (fk_uptime() > menu_time_) {
        views->show_home();
    }

    if (fk_uptime() > refresh_time_) {
        refresh();
        refresh_time_ = fk_uptime() + MenuRefreshInterval;
    }
}

void MenuView::refresh() {
    if (active_menu_ != nullptr) {
        auto gs = try_get_global_state_ro();
        if (gs) {
            active_menu_->refresh(gs.get());
        }
    }
}

void MenuView::up(ViewController *views) {
    show();
    focus_up(*active_menu_);
}

void MenuView::down(ViewController *views) {
    show();
    focus_down(*active_menu_);
}

void MenuView::enter(ViewController *views) {
    show();

    auto menus = MenuContext(views, pool_);
    auto mhr = selected(*active_menu_)->on_selected(menus);

    if (mhr.go_back()) {
        auto title = active_menu_->get_title();
        if (previous_menu_ == nullptr || previous_menu_ == active_menu_) {
            loginfo("selected '%s' (main)", title);
            goto_menu(&main_menu, previous_menu_);
        } else {
            loginfo("selected '%s' (previous)", title);
            goto_menu(previous_menu_, previous_menu_);
        }
    } else if (mhr.go_home()) {
        menus.views->show_home();
        goto_menu(&main_menu, nullptr);
    } else if (mhr.go_menu() != nullptr) {
        goto_menu(mhr.go_menu(), active_menu_, mhr.menu_timeout());
    } else if (mhr.reset_menu()) {
        active_menu_->reset();
    }
}

void MenuView::focus_up(MenuScreen &screen) {
    auto focus_last = false;
    auto previous_focusable_index = -1;

    for (auto i = 0u; i < screen.number_of_options(); ++i) {
        auto option = screen.get_option(i);
        if (option->active()) {
            if (option->focused()) {
                option->focused(false);

                if (previous_focusable_index == -1) {
                    focus_last = true;
                } else {
                    screen.get_option(previous_focusable_index)->focused(true);
                    refresh_visible(screen, previous_focusable_index);
                    break;
                }
            }

            previous_focusable_index = i;
        }
    }

    if (focus_last) {
        FK_ASSERT(previous_focusable_index >= 0);
        auto option = screen.get_option(previous_focusable_index);
        option->focused(true);
        refresh_visible(screen, previous_focusable_index);
    }
}

void MenuView::focus_down(MenuScreen &screen) {
    auto noptions = screen.number_of_options();
    for (auto i = 0u; i < noptions; ++i) {
        auto option = screen.get_option(i);
        if (option->focused()) {
            option->focused(false);
            for (auto j = i + 1; j < noptions; ++j) {
                auto option = screen.get_option(j);
                if (option->active()) {
                    option->focused(true);
                    refresh_visible(screen, j);
                    return;
                }
            }
            for (auto j = 0u; j < noptions; ++j) {
                auto option = screen.get_option(j);
                if (option->active()) {
                    option->focused(true);
                    refresh_visible(screen, j);
                    return;
                }
            }
        }
    }
}

void MenuView::refresh_visible(MenuScreen &screen, int8_t focused_index) {
    static constexpr int8_t MaximumVisible = 4;

    auto nvisible = 0u;

    for (auto i = 0u; i < screen.number_of_options(); ++i) {
        auto o = screen.get_option(i);
        if (focused_index - (int8_t)i >= MaximumVisible || nvisible >= MaximumVisible) {
            o->visible(false);
        } else {
            o->visible(true);
            nvisible++;
        }
    }
}

MenuOption *MenuView::selected(MenuScreen &screen) {
    for (auto i = 0u; i < screen.number_of_options(); ++i) {
        auto o = screen.get_option(i);
        if (o->focused()) {
            return o;
        }
    }

    FK_ASSERT(0);
    return nullptr;
}

MenuScreen *MenuView::goto_menu(MenuScreen *screen, MenuScreen *previous_menu, uint32_t hold_time) {
    screen->reset();

    previous_menu_ = (previous_menu != nullptr) ? previous_menu : active_menu_;

    auto focusable = -1;
    for (auto i = 0u; i < screen->number_of_options(); ++i) {
        auto option = screen->get_option(i);
        if (option->focused()) {
            focusable = i;
            break;
        }
        if (option->active()) {
            if (focusable < 0) {
                focusable = i;
            }
        }
    }

    if (focusable >= 0) {
        screen->get_option(focusable)->focused(true);
        refresh_visible(*screen, focusable);
    }

    active_menu_ = screen;
    hold_time_ = hold_time;
    menu_time_ = fk_uptime() + hold_time;
    refresh();

    return screen;
}

} // namespace fk
