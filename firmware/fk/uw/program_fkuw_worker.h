#pragma once
#if defined(__SAMD51__) && defined(FK_NETWORK_ESP32_WIFI101)

#include "worker.h"
#include "hal/modmux.h"
#include "modules/shared/modules.h"

namespace fk {

class ProgramFkuwWorker : public Worker {
public:
    ProgramFkuwWorker();

public:
    void run(Pool &pool) override;

private:
    bool program_bay(ModulePosition bay, ModuleHeader header, Pool &pool);

public:
    const char *name() const override {
        return "progfkuw";
    }
};

FK_ENABLE_TYPE_NAME(ProgramFkuwWorker);

} // namespace fk

#endif
