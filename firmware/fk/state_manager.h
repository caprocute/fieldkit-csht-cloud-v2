#pragma once

#include "common.h"
#include "pool.h"
#include "state_ref.h"

#include "l10n/l10n.h"

namespace fk {

class GlobalStateManager {
private:
    struct Initialize {
        const char *name = nullptr;
        uint8_t *generation = nullptr;
    };

    bool initialize(Initialize info, Pool &pool);

public:
    bool initialize_after_wipe(Pool &pool);
    bool initialize_after_startup(Pool &pool);

public:
    template <typename RT> RT read(std::function<RT(GlobalState *)> fn) {
        auto gs = get_global_state_ro();
        return fn(gs.get());
    }

    template <typename T> bool apply(T fn) {
        auto gs = get_global_state_rw();
        fn(gs.get());
        return true;
    }

    template <typename V, typename T> V apply_r(T fn) {
        auto gs = get_global_state_rw();
        return fn(gs.get());
    }

    template <typename T> bool apply_update(T has_apply) {
        auto gs = get_global_state_rw();
        gs.get()->apply(has_apply);
        return true;
    }

private:
    bool notify(NotificationState notification);

public:
    bool notify(const char *message) {
        return notify(NotificationState{ message });
    }

    bool notify(uint32_t message_key) {
        return notify(en_US[message_key]);
    }

    collection<NetworkSettings> copy_network_settings(Pool &pool);
};

} // namespace fk
