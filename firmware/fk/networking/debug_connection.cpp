#include <SEGGER_RTT.h>

#include "debug_connection.h"

namespace fk {

DebugServerConnection::DebugServerConnection(Pool *pool, NetworkConnection *conn, uint32_t number)
    : Connection(pool, conn, number), writer_(this, (uint8_t *)pool->malloc(NetworkBufferSize), NetworkBufferSize) {
    iter_ = fk_log_buffer().begin();
}

DebugServerConnection::~DebugServerConnection() {
}

bool DebugServerConnection::service() {
    if (!Connection::service()) {
        return false;
    }

    if (fk_uptime() - activity_ < OneSecondMs) {
        return true;
    }

    activity_ = fk_uptime();

    auto &lb = fk_log_buffer();
    if (iter_ == lb.end()) {
        return true;
    }

    LogBufferLock lock;

    for (; iter_ != lb.end(); ++iter_) {
        if (*iter_ != 0) {
            writer_.write(*iter_);
        }
    }

    writer_.flush();

    return true;
}

} // namespace fk
