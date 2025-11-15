#include <os.h>

#include "hal/hal.h"
#include "tasks/tasks.h"
#include "state_manager.h"
#include "networking/network_services.h"
#include "timer.h"

namespace fk {

FK_DECLARE_LOGGER("network");

struct ConnectionIterator {
    uint32_t version{ 0 };
    uint32_t index{ 0 };
    NetworkSettings settings;

    void update(collection<NetworkSettings> &all) {
        if (index == 0) {
            loginfo("iter: first");
        } else {
            loginfo("iter: index = %d", index);
        }
        auto trying = all.get(index);
        if (trying != nullptr) {
            settings = *trying;
        } else {
            settings = NetworkSettings{};
        }
        index += 1;
    }
};

void try_and_serve_connections(NetworkTaskParameters *params) {
    ConnectionIterator iter;

    while (true) {
        StandardPool pool{ "network-task" };
        NetworkServices services{ get_network(), pool };
        GlobalStateManager gsm;

        gsm.apply([=](GlobalState *gs) { gs->network.state = {}; });

        loginfo("starting network...");

        auto network_settings = gsm.copy_network_settings(pool);

        iter.update(network_settings);

        gsm.apply([&](GlobalState *gs) {
            gs->network.state.enabled = fk_uptime();
            gs->network.state.connected = 0;
        });

        if (!iter.settings.valid) {
            loginfo("iter: invalid");
            return;
        }

#if defined(FK_WIFI_FORCE_AP)
        if (!iter.settings.create) {
            logwarn("iter: force-ap");
            continue;
        }
#endif

        if (params != nullptr) {
            loginfo("iter: checking params");
            if (params->external_ap && iter.settings.create) {
                loginfo("iter: external ap requested, skip create");
                return;
            }
        }

        if (!services.try_begin(iter.settings, NetworkConnectionTimeoutMs, pool)) {
            gsm.notify(pool.sprintf("%s network failed", iter.settings.ssid));
            continue;
        }

        loginfo("started");

        gsm.apply([&](GlobalState *gs) {
            auto ssid = services.ssid();
            if (ssid != nullptr) {
                strncpy(gs->network.state.ssid, ssid, sizeof(gs->network.state.ssid));
            }
            gs->network.state.ip = get_network()->ip_address();
        });

        loginfo("waiting to serve");

        // In self AP mode we're waiting for connections now, and hold off doing
        // anything useful until something joins.
        while (services.waiting_to_serve()) {
            if (services.should_stop()) {
                return;
            }

            services.tick();

            fk_delay(10);
        }

        if (!services.can_serve()) {
            loginfo("unable to serve, retrying");
            continue;
        }

        // Start the network services now that we've got things to talk to.
        if (!services.serve()) {
            logerror("error serving");
            continue;
        }

        loginfo("awaiting connections...");

        gsm.apply([=](GlobalState *gs) {
            gs->network.state.enabled = fk_uptime();
            gs->network.state.connected = fk_uptime();
            gs->network.state.ip = get_network()->ip_address();
        });

        IntervalTimer refresh_statistics{ OneSecondMs };
        while (services.serving()) {
            if (services.should_stop()) {
                return;
            }

            services.tick();

            if (!services.active_http_connections()) {
                fk_delay(10);
            }

            if (refresh_statistics.expired()) {
                gsm.apply([&](GlobalState *gs) {
                    gs->network.state.bytes_rx = services.bytes_rx();
                    gs->network.state.bytes_tx = services.bytes_tx();
                    gs->network.state.activity = services.activity();
                });
            }
        }

        loginfo("try-again");
    }
}

void task_handler_network(void *params) {
    try_and_serve_connections((NetworkTaskParameters *)params);

    GlobalStateManager gsm;
    gsm.apply([=](GlobalState *gs) {
        gs->network.state.ssid[0] = 0;
        gs->network.state.enabled = 0;
        gs->network.state.connected = 0;
        gs->network.state.activity = 0;
        gs->network.state.ip = 0;
    });
}

} // namespace fk
