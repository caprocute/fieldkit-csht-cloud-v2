#include <lwcron/lwcron.h>

#include "runnable.h"

namespace fk {

class DeepSleep {
public:
    uint32_t once();
    void try_deep_sleep(lwcron::Scheduler &scheduler);
};

} // namespace fk
