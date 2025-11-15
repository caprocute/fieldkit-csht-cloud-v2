#pragma once

#include "data.h"

namespace fk {

template <size_t N> class NModuleReadings : public ModuleReadings {
private:
    size_t nreadings_{ N };
    SensorReading readings_[N];

public:
    NModuleReadings() : nreadings_(N) {
    }

    NModuleReadings(size_t size) : nreadings_(size) {
        FK_ASSERT(size <= N);
    }

public:
    void set(int32_t i, SensorReading reading) override {
        if ((size_t)i < N) {
            readings_[i] = reading;
        }
    }

    SensorReading get(int32_t i) const override {
        return readings_[i];
    }

    size_t size() const override {
        return nreadings_;
    }

    ModuleReadings *clone(Pool &pool) const override {
        auto clone = new (pool) NModuleReadings<N>();
        clone->nreadings_ = nreadings_;
        for (size_t i = 0u; i < nreadings_; ++i) {
            clone->readings_[i] = readings_[i];
        }
        return clone;
    }
};

} // namespace fk
