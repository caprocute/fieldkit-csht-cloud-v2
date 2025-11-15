#pragma once

#include "worker.h"

namespace fk {

class WifiToggleWorker : public Worker {
public:
    enum class DesiredState {
        Enabled,
        Disabled,
        Toggle,
        Restart,
        ExternalAp,
    };

private:
    DesiredState desired_;

public:
    WifiToggleWorker(DesiredState desired);

public:
    void run(Pool &pool) override;

public:
    const char *name() const override {
        return "wifi";
    }
};

FK_ENABLE_TYPE_NAME(WifiToggleWorker);

} // namespace fk
