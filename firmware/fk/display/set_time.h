#pragma once

#include "common.h"
#include "display_views.h"

namespace fk {

struct Field {
    uint32_t multiplier;
    uint8_t value;
};

enum TimeField { Year = 0, Month, Day, Hour, Minute, Second };

class SetTimeView : public DisplayView {
private:
    uint32_t time_{ 0 };
    TimeField field_{ TimeField::Year };
    bool dirty_{ true };

public:
    void tick(ViewController *views, Pool &pool) override;
    void up(ViewController *views) override;
    void down(ViewController *views) override;
    void enter(ViewController *views) override;

public:
    void prepare();
};

} // namespace fk
