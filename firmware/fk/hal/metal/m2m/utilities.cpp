#if defined(__SAMD51__) && defined(FK_NETWORK_WINC1500_APRIL)

#include "utilities.h"
#include "platform.h"
#include "hal/hal.h"
#include "m2m_all.h"

namespace fk {

LinkedBuffers::LinkedBuffers(size_t buffers, size_t buffer_size, Pool *pool) {
    for (size_t i = 0u; i < buffers; ++i) {
        uint8_t *buffer = (uint8_t *)pool->malloc(buffer_size);
        LinkedBuffer *lb = new (pool) LinkedBuffer();
        lb->ptr = buffer;
        lb->size = buffer_size;
        lb->filled = 0;
        lb->position = 0;
        lb->np = nullptr;

        lb->np = free_;
        free_ = lb;

        alogf(LogLevels::DEBUG, "lbufs", "lbuf[%d] %d 0x%" PRIx32, i, buffer_size, (uint32_t)buffer);
    }
}

LinkedBuffers::~LinkedBuffers() {
}

LinkedBuffer *LinkedBuffers::get() {
    if (free_ == nullptr) {
        FK_ASSERT(false);
        return nullptr;
    }
    LinkedBuffer *lb = free_;
    free_ = free_->np;
    lb->np = nullptr;
    alogf(LogLevels::VERBOSE, "lbufs", "lb[0x%" PRIx32 "] get", (uint32_t)lb);
    return lb;
}

void LinkedBuffers::free(LinkedBuffer *lb) {
    while (lb != nullptr) {
        alogf(LogLevels::VERBOSE, "lbufs", "lb[0x%" PRIx32 "] free", (uint32_t)lb);
        LinkedBuffer *np = lb->np;
        lb->np = free_;
        lb->position = 0;
        lb->filled = 0;
        free_ = lb;
        lb = np;
    }
}

SemaphoreMutex::SemaphoreMutex() {
    handle_ = xSemaphoreCreateMutexStatic(&static_);
    FK_ASSERT(handle_ != nullptr);
}

SemaphoreMutex::~SemaphoreMutex() {
}

bool SemaphoreMutex::give() {
    return xSemaphoreGive(handle_) == pdTRUE;
}

bool SemaphoreMutex::take(uint32_t to) {
    return xSemaphoreTake(handle_, to) == pdTRUE;
}

const char *sta_cmd_to_string(uint8_t cmd) {
    switch (cmd) {
    case M2M_WIFI_REQ_CONNECT:
        return "M2M_WIFI_REQ_CONNECT";
    case M2M_WIFI_REQ_DEFAULT_CONNECT:
        return "M2M_WIFI_REQ_DEFAULT_CONNECT";
    case M2M_WIFI_RESP_DEFAULT_CONNECT:
        return "M2M_WIFI_RESP_DEFAULT_CONNECT";
    case M2M_WIFI_REQ_DISCONNECT:
        return "M2M_WIFI_REQ_DISCONNECT";
    case M2M_WIFI_RESP_CON_STATE_CHANGED:
        return "M2M_WIFI_RESP_CON_STATE_CHANGED";
    case M2M_WIFI_REQ_SLEEP:
        return "M2M_WIFI_REQ_SLEEP";
    case M2M_WIFI_REQ_WPS_SCAN:
        return "M2M_WIFI_REQ_WPS_SCAN";
    case M2M_WIFI_REQ_WPS:
        return "M2M_WIFI_REQ_WPS";
    case M2M_WIFI_REQ_START_WPS:
        return "M2M_WIFI_REQ_START_WPS";
    case M2M_WIFI_REQ_DISABLE_WPS:
        return "M2M_WIFI_REQ_DISABLE_WPS";
    case M2M_WIFI_REQ_DHCP_CONF:
        return "M2M_WIFI_REQ_DHCP_CONF";
    case M2M_WIFI_RESP_IP_CONFIGURED:
        return "M2M_WIFI_RESP_IP_CONFIGURED";
    case M2M_WIFI_RESP_IP_CONFLICT:
        return "M2M_WIFI_RESP_IP_CONFLICT";
    case M2M_WIFI_REQ_ENABLE_MONITORING:
        return "M2M_WIFI_REQ_ENABLE_MONITORING";
    case M2M_WIFI_REQ_DISABLE_MONITORING:
        return "M2M_WIFI_REQ_DISABLE_MONITORING";
    case M2M_WIFI_RESP_WIFI_RX_PACKET:
        return "M2M_WIFI_RESP_WIFI_RX_PACKET";
    case M2M_WIFI_REQ_SEND_WIFI_PACKET:
        return "M2M_WIFI_REQ_SEND_WIFI_PACKET";
    case M2M_WIFI_REQ_LSN_INT:
        return "M2M_WIFI_REQ_LSN_INT";
    case M2M_WIFI_REQ_DOZE:
        return "M2M_WIFI_REQ_DOZE";
    case M2M_WIFI_REQ_CONN:
        return "M2M_WIFI_REQ_CONN";
    case M2M_WIFI_IND_CONN_PARAM:
        return "M2M_WIFI_IND_CONN_PARAM";
    case M2M_WIFI_REQ_DHCP_FAILURE:
        return "M2M_WIFI_REQ_DHCP_FAILURE";
    case M2M_WIFI_MAX_STA_ALL:
        return "M2M_WIFI_MAX_STA_ALL";
    // tenuM2mConfigCmd
    case M2M_WIFI_RESP_GET_PRNG:
        return "M2M_WIFI_RESP_GET_PRNG";
    default:
        // HALT_IF_DEBUGGING();
        return "M2M_WIFI_UNKNOWN";
    }
}

bool WaitingLoop::check() {
    fk_delay(10);
    if (counter_ > 0) {
        counter_--;
    }
    return counter_ > 0;
}

} // namespace fk

#endif
