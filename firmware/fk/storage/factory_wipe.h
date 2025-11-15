#pragma once

#include "hal/hal.h"
#include "storage/storage.h"
#include "progress.h"

namespace fk {

class FactoryWipe {
private:
    struct fkb_header_t const *fkb_header_;
    Display *display_{ nullptr };
    Buttons *buttons_{ nullptr };
    Storage *storage_{ nullptr };

public:
    explicit FactoryWipe(struct fkb_header_t const *fkb_header, Storage &storage);
    explicit FactoryWipe(struct fkb_header_t const *fkb_header, Display *display, Buttons *buttons, Storage *storage);

public:
    bool wipe(ProgressCallbacks *progress, Pool &pool);
    bool create_new_state(Pool &pool);
};

} // namespace fk
