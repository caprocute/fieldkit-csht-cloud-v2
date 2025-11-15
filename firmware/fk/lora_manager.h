#pragma once

#include "hal/lora.h"
#include "pool.h"
#include "state.h"

namespace fk {

enum LoraOutcome {
    None,
    JoinOk,
    JoinFailed,
    ConfirmedSendOk,
};

class LoraManager {
private:
    LoraNetwork *network_{ nullptr };
    LoraOutcome outcome_{ LoraOutcome::None };
    bool awake_{ false };

public:
    explicit LoraManager(LoraNetwork *network);

public:
    bool begin(Pool &pool);
    bool factory_reset();
    bool power_cycle();
    bool join_if_necessary(Pool &pool, bool force_join = false);
    bool force_join(Pool &pool);
    void stop();

public:
    bool send_bytes(uint8_t port, uint8_t const *data, size_t size, Pool &pool);
    LoraOutcome outcome() {
        return outcome_;
    }

private:
    bool verify_configuration(LoraState const &state, uint8_t const *device_eui, Pool &pool);
    bool verify_rx_delays(Rn2903State const *rn, Pool &pool);

private:
    void update_lora_status(LoraState &lora, Rn2903State const *rn);
};

} // namespace fk
