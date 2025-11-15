#pragma once

#include "worker.h"

namespace fk {

class SdCard;
class Pool;

class UpgradeWincWorker : public Worker {
public:
    explicit UpgradeWincWorker();

public:
    void run(Pool &pool) override;
    bool upgrade_from_sd_card(SdCard *sd, Pool *pool);

private:
    bool write_file_region(SdCard *sd, uint32_t address, const char *file_name, Pool *pool);

public:
    const char *name() const override {
        return "upgwinc";
    }
};

FK_ENABLE_TYPE_NAME(UpgradeWincWorker);

} // namespace fk
