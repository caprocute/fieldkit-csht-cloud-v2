#include "tests.h"
#include "patterns.h"
#include "common.h"
#include "hal/linux/linux.h"
#include "startup/startup_worker.h"
#include "readings_worker.h"
#include "state_manager.h"
#include "state_ref.h"

#include "storage_suite.h"

using namespace fk;

FK_DECLARE_LOGGER("startup-worker-tests");

class StartupWorkerSuite : public StorageSuite {};

TEST_F(StartupWorkerSuite, FreshStart) {
    StandardPool pool{ "tests" };
    StartupWorker startup_worker;
    startup_worker.run(pool);
}