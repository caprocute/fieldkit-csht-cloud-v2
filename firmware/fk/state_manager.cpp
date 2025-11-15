#include "state_manager.h"
#include "state.h"
#include "device_name.h"
#include "state_ref.h"
#include "hal/random.h"
#include "utilities.h"
#include "secrets.h"

namespace fk {

FK_DECLARE_LOGGER("gsm");

static void initialize_compile_time_wifi(WifiNetworkInfo &network, const char *ssid, const char *password) __attribute__((unused));

static void initialize_compile_time_wifi(WifiNetworkInfo &network, const char *ssid, const char *password) {
    loginfo("(hardcoded) wifi '%s'", ssid);
    strncpy(network.ssid, ssid, sizeof(network.ssid));
    strncpy(network.password, password, sizeof(network.password));
    network.valid = strlen(network.ssid) > 0;
}

static void initialize_compile_lora(LoraState &lora, const char *device_eui, const char *app_key, const char *join_eui)
    __attribute__((unused));

static void initialize_compile_lora(LoraState &lora, const char *device_eui, const char *app_key, const char *join_eui) {
    loginfo("(hardcoded) lora device-eui: '%s'", device_eui); // TODO SECURITY
    hex_string_to_bytes(lora.device_eui, sizeof(lora.device_eui), device_eui);
    hex_string_to_bytes(lora.app_key, sizeof(lora.app_key), app_key);
    if (join_eui != nullptr) {
        hex_string_to_bytes(lora.join_eui, sizeof(lora.join_eui), join_eui);
    }
}

bool GlobalStateManager::initialize_after_wipe(Pool &pool) {
    Initialize info;

    info.name = fk_device_name_generate(pool);

    uint8_t *gen = (uint8_t *)pool.malloc(GenerationLength);
    fk_random_fill_u8(gen, GenerationLength);
    info.generation = gen;

    return initialize(info, pool);
}

bool GlobalStateManager::initialize_after_startup(Pool &pool) {
    Initialize info;

    return initialize(info, pool);
}

bool GlobalStateManager::initialize(Initialize info, Pool &pool) {
    auto gs = get_global_state_rw();

    // If a station already has a name, continue to use that one. Otherwise we
    // generate a random one.
    const char *name = info.name;
    if (strlen(gs.get()->general.name) > 0) {
        name = pool.strdup(gs.get()->general.name);
    }

    *gs.get() = GlobalState{};

    if (name != nullptr) {
        strncpy(gs.get()->general.name, name, sizeof(gs.get()->general.name));
    }

    if (info.generation != nullptr) {
        memcpy(gs.get()->general.generation, info.generation, GenerationLength);
    }

    for (auto i = 0u; i < WifiMaximumNumberOfNetworks; ++i) {
        auto &nc = gs.get()->network.config.wifi_networks[i];
        nc.valid = false;
        nc.create = false;
        nc.ssid[0] = 0;
        nc.password[0] = 0;
    }

#if defined(__SAMD51__)
#if defined(FK_WIFI_0_SSID) && defined(FK_WIFI_0_PASSWORD)
    initialize_compile_time_wifi(gs.get()->network.config.wifi_networks[0], FK_WIFI_0_SSID, FK_WIFI_0_PASSWORD);
#endif

#if defined(FK_WIFI_1_SSID) && defined(FK_WIFI_1_PASSWORD)
    initialize_compile_time_wifi(gs.get()->network.config.wifi_networks[1], FK_WIFI_1_SSID, FK_WIFI_1_PASSWORD);
#endif

#if defined(FK_LORA_DEVICE_EUI) && defined(FK_LORA_APP_KEY)
#if defined(FK_LORA_JOIN_EUI)
    initialize_compile_lora(gs.get()->lora, FK_LORA_DEVICE_EUI, FK_LORA_APP_KEY, FK_LORA_JOIN_EUI);
#else
    initialize_compile_lora(gs.get()->lora, FK_LORA_DEVICE_EUI, FK_LORA_APP_KEY, nullptr);
#endif
#endif

#endif

    if (fk_debug_get_console_attached()) {
        gs.get()->scheduler.readings.interval = DefaultDebugReadingsInterval;
        gs.get()->scheduler.network.interval = DefaultDebugNetworkInterval;
        gs.get()->scheduler.gps.interval = DefaultDebugGpsInterval;
        gs.get()->scheduler.gps.duration = DefaultDebugGpsDuration;
        gs.get()->scheduler.lora.interval = DefaultDebugLoraInterval;
        gs.get()->scheduler.network.duration = FiveMinutesSeconds;
        gs.get()->scheduler.backup.interval = 0;
        loginfo("using debug schedule");
    } else {
        gs.get()->scheduler.readings.interval = DefaultReadingsInterval;
        gs.get()->scheduler.network.interval = DefaultNetworkInterval;
        gs.get()->scheduler.gps.interval = DefaultGpsInterval;
        gs.get()->scheduler.gps.duration = DefaultGpsDuration;
        gs.get()->scheduler.lora.interval = DefaultLoraInterval;
        gs.get()->scheduler.network.duration = FiveMinutesSeconds;
        gs.get()->scheduler.backup.interval = 0;
        loginfo("using default schedule");
    }

    gs.get()->scheduler.readings.recreate();
    gs.get()->scheduler.network.recreate();
    gs.get()->scheduler.gps.recreate();
    gs.get()->scheduler.lora.recreate();
    gs.get()->scheduler.backup.recreate();

    gs.get()->transmission.url[0] = 0;
    gs.get()->transmission.token[0] = 0;

    return true;
}

collection<NetworkSettings> GlobalStateManager::copy_network_settings(Pool &pool) {
    collection<NetworkSettings> settings{ pool };

    auto gs = get_global_state_ro();
    for (auto &wifi_network : gs.get()->network.config.wifi_networks) {
        if (wifi_network.ssid[0] != 0) {
            settings.add({
                .valid = wifi_network.ssid[0] != 0,
                .create = false,
                .ssid = wifi_network.ssid,
                .password = wifi_network.password,
                .port = 80,
            });
        }
    }

    auto name = pool.strdup(gs.get()->general.name);
    settings.add({
        .valid = true,
        .create = true,
        .ssid = name,
        .password = nullptr,
        .port = 80,
    });

    return settings;
}

bool GlobalStateManager::notify(NotificationState notification) {
    return apply([=](GlobalState *gs) {
        gs->notification = notification;
        gs->dynamic.add_message(notification.message);
    });
}

} // namespace fk
