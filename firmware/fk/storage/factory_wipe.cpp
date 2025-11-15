#include "factory_wipe.h"
#include "config.h"
#include "storage/storage.h"
#include "state_ref.h"
#include "state_manager.h"

namespace fk {

FK_DECLARE_LOGGER("factory");

FactoryWipe::FactoryWipe(struct fkb_header_t const *fkb_header, Storage &storage) : fkb_header_(fkb_header), storage_(&storage) {
}

FactoryWipe::FactoryWipe(struct fkb_header_t const *fkb_header, Display *display, Buttons *buttons, Storage *storage)
    : fkb_header_(fkb_header), display_(display), buttons_(buttons), storage_(storage) {
}

bool FactoryWipe::wipe(ProgressCallbacks *progress, Pool &pool) {
    loginfo("factory wipe!");

    if (!storage_->clear()) {
        return false;
    }

    if (!create_new_state(pool)) {
        logerror("error creating new state");
        return false;
    }

    if (!storage_->flush()) {
        logerror("flush storage");
        return false;
    }

    loginfo("done");

    return true;
}

bool FactoryWipe::create_new_state(Pool &pool) {
    GlobalStateManager gsm;
    gsm.initialize_after_wipe(pool);

    auto gs = get_global_state_ro();

    MetaRecord meta_record{ pool };
    meta_record.include_state(gs.get(), fkb_header_, pool);

    if (!storage_->meta_ops()->write_record(SignedRecordKind::State, meta_record.record(), pool)) {
        logerror("writing state");
        fk_logs_flush();
        return false;
    }

    return true;
}

} // namespace fk
