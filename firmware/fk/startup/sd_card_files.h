#pragma once

#include "pool.h"

namespace fk {

class SdCard;

class SdCardFiles {
public:
    static bool check(Pool &pool);

private:
    SdCard *sd_;
    Pool *pool_;

public:
    SdCardFiles(SdCard *card, Pool *pool);

public:
    bool check();

private:
    bool check_for_upgrading_startup();
    bool check_for_provision_startup();
    bool check_for_self_test_startup();
    bool check_for_configure_modules_startup();
    bool check_for_program_modules_startup();
    bool check_for_winc_firmware();
};

} // namespace fk
