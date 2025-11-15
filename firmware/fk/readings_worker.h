#pragma once

#include "worker.h"
#include "storage/storage.h"

namespace fk {

enum TryTake { TryTakeSkipped, TryTakeSuccess, TryTakeError };

class ReadingsWorker : public Worker {
private:
    bool scan_;
    bool read_only_;
    bool throttle_;
    bool unattended_;
    ModulePowerState power_state_{ ModulePowerState::Unknown };
    StorageUpdate storage_update_;

public:
    ReadingsWorker(bool scan, bool read_only, bool throttle, bool unattended, ModulePowerState power_state = ModulePowerState::Unknown);

public:
    void run(Pool &pool) override;

    uint8_t priority() const override {
        return FK_PRIORITY_READINGS_TASK;
    }

    const char *name() const override {
        if (read_only_) {
            return "livedata";
        }
        return "readings";
    }

protected:
    struct ThrottleAndScanState {
        bool throttle;
        bool scanned;
    };

    ThrottleAndScanState read_state();

protected:
    TryTake try_take(state::ReadingsListener *listener, Pool &pool);
    bool scan(Pool &pool);
    bool take(state::ReadingsListener *listener, Pool &pool);
    bool save(Pool &pool);
    bool update_global_state(Pool &pool);
    bool spawn_lora_if_due(Pool &pool);

public:
    static bool has_conflicting_worker(bool check_readings);
};

FK_ENABLE_TYPE_NAME(ReadingsWorker);

} // namespace fk
