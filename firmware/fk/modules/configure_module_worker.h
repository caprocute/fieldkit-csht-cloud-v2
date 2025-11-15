#pragma once

#include "modules/shared/modules.h"
#include "worker.h"

namespace fk {

class ConfigureModuleWorker : public Worker {
private:
    ModulePosition bay_;
    bool erase_{ false };
    ModuleHeader header_;

public:
    ConfigureModuleWorker(ModulePosition bay);
    ConfigureModuleWorker(ModulePosition bay, ModuleHeader header);

public:
    static ModuleHeader ph_header();
    static ModuleHeader ec_header();
    static ModuleHeader do_header();
    static ModuleHeader orp_header();
    static ModuleHeader temp_header();
    static ModuleHeader ms5837_header();
    static ModuleHeader distance_header();
    static ModuleHeader weather_header();

public:
    void run(Pool &pool) override;
    bool configure(Pool &pool);

public:
    const char *name() const override {
        return "modcfg";
    }
};

FK_ENABLE_TYPE_NAME(ConfigureModuleWorker);

} // namespace fk
