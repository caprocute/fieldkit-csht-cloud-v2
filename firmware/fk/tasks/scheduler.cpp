#include <lwcron/lwcron.h>

#include "hal/clock.h"
#include "tasks/tasks.h"
#include "state_ref.h"
#include "scheduling.h"
#include "battery_status.h"
#include "deep_sleep.h"
#include "timer.h"
#include "gps_service.h"
#include "state_manager.h"
#include "graceful_shutdown.h"

#if defined(__SAMD51__)
#include "hal/metal/metal_ipc.h"
#else
#include "hal/linux/linux_ipc.h"
#endif

#include "networking/wifi_toggle_worker.h"

#include "modules/refresh_modules_worker.h"
#include "modules/scan_modules_worker.h"

#include "storage/events.h"

#include "readings_worker.h"

#include "l10n/l10n.h"

namespace fk {

FK_DECLARE_LOGGER("schedule");

static CurrentSchedules get_config_schedules();
static bool has_schedule_changed(CurrentSchedules &running);
static bool has_module_topology_changed(Topology &existing);
static bool get_can_launch_captive_readings() __attribute__((unused));
static ScheduledTime get_next_task_time(uint32_t now, lwcron::Task &task);
static bool can_deep_sleep(Runnable const &runnable);

void task_handler_scheduler(void *params) {
    BatteryChecker battery;
    battery.refresh();

    GpsService gps_service{ get_gps() };

    if (!battery.low_power()) {
#if !defined(FK_DISABLE_GPS)
        if (!gps_service.begin()) {
            logerror("gps");
        }
#endif

#if !defined(FK_DISABLE_NETWORK)
        FK_ASSERT(fk_start_task_if_necessary(&network_task));
#endif
    }

    bool start_display = true;

    DateTime now{ get_clock_now() };
    uint32_t signal_checked = 0;
    while (!fk_task_stop_requested(&signal_checked)) {
        auto schedules = get_config_schedules();

        ReadingsTask readings_job{ schedules.readings };
        SynchronizeTimeTask synchronize_time_job{ DefaultSynchronizeTimeInterval };
        BackupTask backup_job{ schedules.backup };
        UploadDataTask upload_data_job{ schedules.network, schedules.network_jitter };
        LoraTask lora_readings_job{ schedules.lora, LoraWorkOperation::Readings };
        GpsTask gps_job{ schedules.gps, gps_service };
        ServiceModulesTask service_modules_job{ schedules.service_interval };

        lwcron::Task *tasks[]{ &synchronize_time_job,
                               &readings_job,
                               &backup_job,
                               &gps_job,
                               &service_modules_job
#if !defined(FK_DISABLE_NETWORK)
                               ,
                               &upload_data_job
#endif
#if !defined(FK_DISABLE_LORA) && defined(FK_LORA_FIXED)
                               ,
                               &lora_readings_job
#endif
        };
        lwcron::Scheduler scheduler{ tasks };
        Topology topology;

        IntervalTimer every_second{ OneSecondMs };
        IntervalTimer every_thirty_seconds{ ThirtySecondsMs };

        scheduler.begin(get_clock_now());

        while (!has_schedule_changed(schedules) && !fk_task_stop_requested(&signal_checked)) {
            // This throttles this loop, so we take a pass when we dequeue or timeout.
            Activity *activity = nullptr;
            if (get_ipc()->dequeue_activity(&activity, 50)) {
                loginfo("activity:dequeue");
            }

            if (fk_task_stop_requested(&signal_checked)) {
                loginfo("stopping");
                break;
            }

            if (activity != nullptr) {
                if (fk_can_start_task(&display_task)) {
                    start_display = true;
                }

                if (activity->start_network()) {
#if !defined(FK_DISABLE_NETWORK)
                    get_ipc()->launch_worker(create_pool_worker<WifiToggleWorker>(WifiToggleWorker::DesiredState::Enabled));
#endif
                    StandardPool pool{ "event" };
                    WifiEvent event = WifiEvent::external();
                    AppendEventWorker append{ &event };
                    append.run(pool);
                }
            }

            if (start_display) {
                if (battery.low_power()) {
                    task_display_params = DisplayTaskParameters::low_power();
                } else {
                    task_display_params = DisplayTaskParameters::normal();
                }
                if (fk_start_task_if_necessary(&display_task)) {
                    loginfo("activity:display-started");
                    get_ipc()->launch_worker(create_pool_worker<RefreshModulesWorker>());
                }

                start_display = false;
            }

            if (every_second.expired()) {
                if (every_thirty_seconds.expired()) {
                    battery.refresh();

                    DateTime new_now{ get_clock_now() };
                    if (new_now.day() != now.day()) {
#if defined(FK_LORA_STATUS_ENABLED)
                        get_ipc()->launch_worker(create_pool_worker<LoraWorker>(LoraWork{ LoraWorkOperation::Status }));
#endif
                    }

                    now = new_now;
                }

                if (!battery.low_power_dangerous()) {
                    // Only do this if we haven't enabled power save mode,
                    // which we do after the timer passes.  We're also
                    // skipping this if we're setup to always power
                    // modules on their own.
                    if (!ModulesPowerIndividually) {
                        if (has_module_topology_changed(topology)) {
                            loginfo("topology changed: [%s]", topology.string());
                            get_ipc()->launch_worker(create_pool_worker<ScanModulesWorker>());
                            fk_start_task_if_necessary(&display_task);
                        }
                    }

                    auto now = get_clock_now();
#if !defined(FK_DEBUG_DISABLE_SCHEDULED)
                    auto time = lwcron::DateTime{ now };
                    if (!scheduler.check(time, 0)) {
                        if (get_can_launch_captive_readings()) {
                            auto worker = create_pool_worker<ReadingsWorker>(false, false, true, ModulePowerState::AlwaysOn);
                            get_ipc()->launch_worker(WorkerCategory::Readings, worker);
                        }
                    }
#endif

                    UpcomingUpdate update;
                    update.readings = get_next_task_time(now, readings_job);
                    update.network = get_next_task_time(now, upload_data_job);
                    update.gps = get_next_task_time(now, gps_job);
                    update.lora = get_next_task_time(now, lora_readings_job);
                    update.backup = get_next_task_time(now, backup_job);
                    GlobalStateManager gsm;
                    gsm.apply_update(update);
                } else {
                    // This avoids showing the user ETAs that never move, as
                    // we're no longer servicing the same fields in the above
                    // update.
                    ScheduledTime zero{};
                    UpcomingUpdate update;
                    update.readings = zero;
                    update.network = zero;
                    update.gps = zero;
                    update.lora = zero;
                    update.backup = zero;
                    GlobalStateManager gsm;
                    gsm.apply_update(update);
                }

                if (can_deep_sleep(gps_service)) {
                    DeepSleep deep_sleep;
                    deep_sleep.try_deep_sleep(scheduler);
                } else {
                    if (get_ipc()->has_stalled_workers(WorkerCategory::Readings, FiveMinutesMs)) {
                        logwarn("stalled reading worker, restarting");

                        fk_delay(500);

                        fk_graceful_shutdown();

                        fk_restart();
                    }

#if defined(FK_WDT_ENABLE)
                    fk_wdt_feed();
#endif
                }
            }

#if !defined(FK_DISABLE_GPS)
            gps_service.service();
#endif

            if (gps_service.first_fix()) {
#if defined(FK_LORA_GPS_ENABLED)
                get_ipc()->launch_worker(create_pool_worker<LoraWorker>(LoraWork{ LoraWorkOperation::Location }));
#endif
            }

            task_handler_idle();
        }
    }

    loginfo("scheduler exited");
}

static ScheduledTime get_next_task_time(uint32_t now, lwcron::Task &task) {
    auto next_task_time = task.getNextTime(lwcron::DateTime{ now }, 0);
    auto remaining_seconds = next_task_time - now;
    return {
        .now = now,
        .time = next_task_time,
        .seconds = remaining_seconds,
    };
}

static bool can_deep_sleep(Runnable const &runnable) {
    if (get_ipc()->has_any_running_worker()) {
        logverbose("no-sleep: worker tasks");
        return false;
    }
    if (os_task_is_running(&network_task)) {
        logverbose("no-sleep: network task");
        return false;
    }
    if (os_task_is_running(&display_task)) {
        logverbose("no-sleep: display task");
        return false;
    }
    if (get_network()->enabled()) {
        logverbose("no-sleep: network");
        return false;
    }
    if (runnable.is_running()) {
        logverbose("no-sleep: runnable (gps)");
        return false;
    }

    return true;
}

static CurrentSchedules get_config_schedules() {
    auto gs = get_global_state_ro();
    return { gs.get() };
}

static bool has_schedule_changed(CurrentSchedules &running) {
    auto config = get_config_schedules();
    return !config.equals(running);
}

static void check_modules() {
    auto modules_lock = modules_mutex.acquire(UINT32_MAX);
    get_modmux()->check_modules();
}

static bool get_can_launch_captive_readings() {
    // We definitely don't if there's nothing connected.
    if (!get_network()->enabled()) {
        return false;
    }

    auto gs = get_global_state_ro();
    auto now = fk_uptime();

    // Don't if it's been more than a minute since we had network activity.
    auto since_activity = now - gs.get()->network.state.activity;
    if (since_activity > OneMinuteMs) {
        return false;
    }

    if (gs.get()->network.state.udp_activity > 0) {
        auto elapsed = now - gs.get()->network.state.udp_activity;
        if (elapsed < TenSecondsMs) {
            return false;
        }
    }

    // Will we be throttled?
    auto elapsed = now - gs.get()->scheduler.readings.mark;
    if (elapsed < TenSecondsMs) {
        return false;
    }

    if (ReadingsWorker::has_conflicting_worker(true)) {
        return false;
    }

    return true;
}

static bool has_module_topology_changed(Topology &existing) {
    auto topology = get_modmux()->get_topology();
    if (!topology) {
        return false;
    }

    if (existing == topology.value()) {
        return false;
    }

    existing = topology.value();

    check_modules();

    return true;
}

} // namespace fk
