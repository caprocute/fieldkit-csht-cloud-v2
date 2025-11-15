#pragma once
#if defined(__SAMD51__) && defined(FK_UNDERWATER)

#include "worker.h"

namespace fk {

class FlashMarkerLightsWorker : public Worker {
public:
    FlashMarkerLightsWorker();

public:
    void run(Pool &pool) override;

public:
    const char *name() const override {
        return "markers";
    }
};

FK_ENABLE_TYPE_NAME(FlashMarkerLightsWorker);

} // namespace fk

#endif
