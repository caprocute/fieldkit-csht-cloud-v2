#include "ms5837_module.h"

using namespace fk;

extern "C" {

static Module *fk_module_create_ms5837(Pool &pool) {
    return new (pool) Ms5837Module(pool);
}

ModuleMetadata const fk_module_meta_ms5837 = {
    .manufacturer = FK_MODULES_MANUFACTURER,
    .kind = FK_MODULES_KIND_MS5837,
    .version = 0x01,
    .name = "water.depth",
    .flags = 0,
    .ctor = fk_module_create_ms5837,
};

__attribute__((constructor)) void fk_module_initialize_ms5837() {
    fk_modules_builtin_register(&fk_module_meta_ms5837);
}
}
