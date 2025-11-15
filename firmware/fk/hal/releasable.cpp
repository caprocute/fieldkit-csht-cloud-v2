#include <exchange.h>

#include "hal/mutex.h"
#include "platform.h"

namespace fk {

Lock::Lock() : releasable_(nullptr) {
}

Lock::Lock(bool exclusive, Releasable *releasable) : exclusive_(exclusive), releasable_(releasable) {
    acquired_ = fk_uptime();
}

Lock::Lock(Lock &&rhs) : exclusive_(rhs.exclusive_), releasable_(exchange(rhs.releasable_, nullptr)), acquired_(rhs.acquired_) {
}

Lock::~Lock() {
    if (releasable_ != nullptr) {
        auto elapsed = fk_uptime() - acquired_;
        FK_ASSERT(releasable_->release(elapsed, exclusive_));
        releasable_ = nullptr;
        acquired_ = 0;
    }
}

} // namespace fk
