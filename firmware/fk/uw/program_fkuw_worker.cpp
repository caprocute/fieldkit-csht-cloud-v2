#if defined(__SAMD51__) && defined(FK_NETWORK_ESP32_WIFI101)

#include "uw/program_fkuw_worker.h"
#include "modules/configure_module_worker.h"
#include "modules/refresh_modules_worker.h"
#include "hal/ipc.h"

namespace fk {

FK_DECLARE_LOGGER("progfkuw");

ProgramFkuwWorker::ProgramFkuwWorker() {
}

bool ProgramFkuwWorker::program_bay(ModulePosition bay, ModuleHeader header, Pool &pool) {
    ConfigureModuleWorker configurer{ bay, header };
    return configurer.configure(pool);
}

void ProgramFkuwWorker::run(Pool &pool) {
    auto lock = get_modmux()->lock();

    get_ipc()->signal_workers(WorkerCategory::Polling, 9);

    if (!program_bay(ModulePosition::from(0), ConfigureModuleWorker::ph_header(), pool)) {
        logwarn("error programming");
    }

    if (!program_bay(ModulePosition::from(1), ConfigureModuleWorker::ec_header(), pool)) {
        logwarn("error programming");
    }

    if (!program_bay(ModulePosition::from(2), ConfigureModuleWorker::do_header(), pool)) {
        logwarn("error programming");
    }

    if (!program_bay(ModulePosition::from(3), ConfigureModuleWorker::ms5837_header(), pool)) {
        logwarn("error programming");
    }

    auto worker = create_pool_worker<RefreshModulesWorker>(false);
    worker->run();
}

} // namespace fk

#endif
