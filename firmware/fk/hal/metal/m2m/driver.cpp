#if defined(__SAMD51__) && defined(FK_NETWORK_WINC1500_APRIL)

#include "utilities.h"
#include "driver.h"

extern "C" {

extern int8_t g_winc1500_pin_cs;
extern int8_t g_winc1500_pin_irq;
extern int8_t g_winc1500_pin_rst;
extern int8_t g_winc1500_pin_en;

static void wifi_cb(uint8_t message_type, void *message);
static void socket_cb(SOCKET sock, uint8_t message_type, void *message);
static void resolve_cb(uint8_t *name, uint32_t ip);

static TaskHandle_t g_isr_task = NULL;

void m2m_hif_isr_hook() {
    if (g_isr_task != NULL) {
        int32_t err = xTaskNotifyFromISR(g_isr_task, pdTRUE, eSetValueWithOverwrite, NULL);
        FK_ASSERT(err == pdTRUE);
    }
}
}

FK_DECLARE_LOGGER("network");

namespace fk {

static const char *driver_state_to_string(DriverState state) __attribute__((unused));
static const char *ipc_message_type_to_string(IpcMessageType state) __attribute__((unused));
static const char *wifi_mode_to_string(WifiMode mode) __attribute__((unused));

static void rtos_service_task(void *param) {
    Driver *driver = (Driver *)param;
    driver->service_task();
    vTaskDelete(NULL);
}

Driver::Driver(Pool *pool) : pool_(pool), sockets_(&lock_, pool) {
}

bool Driver::begin(Pool *pool) {
    enable();

    nm_bsp_init();

    tstrWifiInitParam param;
    memset(&param, 0, sizeof(tstrWifiInitParam));
    param.pfAppWifiCb = wifi_cb;
    int8_t err = m2m_wifi_init(&param);
    if (M2M_SUCCESS != err && M2M_ERR_FW_VER_MISMATCH != err) {
        return false;
    }

    if (M2M_ERR_FW_VER_MISMATCH == err) {
        logwarn("M2M_ERR_FW_VER_MISMATCH");
    }

    uint8_t mac[MacAddressLength];
    m2m_wifi_get_mac_address(mac);
    for (size_t i = 0u; i < MacAddressLength; i++) {
        mac_address_[i] = mac[MacAddressLength - 1 - i];
    }

    socketInit();
    registerSocketCallback(socket_cb, resolve_cb);

    auto queue_buffer = (StaticQueue_t *)pool->malloc(sizeof(StaticQueue_t));
    auto queue_data = (uint8_t *)pool->malloc(sizeof(IpcMessage) * IpcMessageQueueLength);
    auto queue = xQueueCreateStatic(10, sizeof(IpcMessage), queue_data, queue_buffer);
    FK_ASSERT(queue != nullptr);
    queue_ = queue;

    auto stack_size = NetworkM2mTaskStackSize;
    auto stack = (uint32_t *)pool->malloc(sizeof(uint32_t) * stack_size);
    auto tcb = (StaticTask_t *)pool->malloc(sizeof(StaticTask_t));
    auto task = xTaskCreateStatic(rtos_service_task, "m2m", stack_size, this, NetworkM2mTaskPriority, stack, tcb);
    FK_ASSERT(task != nullptr);
    g_isr_task = task;
    task_ = task;

    return true;
}

bool Driver::join(const char *ssid, const char *password, WifiMode mode) {
    tries_ = 3;
    ssid_ = pool_->strdup(ssid);
    password_ = pool_->strdup(password);
    mode_ = mode;
    state_ = DriverState::DS_CONNECTING;
    return true;
}

bool Driver::service() {
    switch (state_) {
    case DriverState::DS_ERROR: {
        return false;
    }
    case DriverState::DS_CONNECTING: {
        if (tries_ > 0) {
            FK_ASSERT(ssid_ != nullptr);

            if (mode_ == WifiMode::MODE_STATION) {
                loginfo("connecting...");
                auto err = m2m_wifi_connect((char *)ssid_, strlen(ssid_), M2M_WIFI_SEC_WPA_PSK, (void *)password_, M2M_WIFI_CH_ALL);
                if (err < 0) {
                    state_ = DriverState::DS_ERROR;
                    return false;
                }
                state_ = DriverState::DS_ATTEMPTING_STATION;
            }

            if (mode_ == WifiMode::MODE_AP) {
                loginfo("creating...");
                tstrM2MAPConfig ap_config;
                bzero(&ap_config, sizeof(tstrM2MAPConfig));
                strcpy((char *)&ap_config.au8SSID, ssid_);
                ap_config.u8ListenChannel = 2;
                ap_config.u8SecType = M2M_WIFI_SEC_OPEN;
                ap_config.au8DHCPServerIP[0] = 192;
                ap_config.au8DHCPServerIP[1] = 168;
                ap_config.au8DHCPServerIP[2] = 2;
                ap_config.au8DHCPServerIP[3] = 1;
                ip_address_ = ipv4_to_u32(192, 168, 2, 1);

                if (m2m_wifi_enable_ap(&ap_config) < 0) {
                    state_ = DriverState::DS_ERROR;
                    return false;
                }

                state_ = DriverState::DS_ATTEMPTING_AP;
            }
            tries_--;
        } else {
            state_ = DriverState::DS_ERROR;
        }
    }
    default: {
        break;
    }
    }

    IpcMessage item;
    if (xQueueReceive(queue_, (void *)&item, portTICK_PERIOD_MS * 100)) {
        loginfo("%s", ipc_message_type_to_string(item.type));
        switch (item.type) {
        case IpcMessageType::IPC_N_CONNECTED: {
            state_ = DriverState::DS_CONNECTED;
            break;
        }
        case IpcMessageType::IPC_N_DISCONNECTED: {
            state_ = DriverState::DS_CONNECTING;
            break;
        }
        case IpcMessageType::IPC_N_RESOLVE: {
            resolved_.ip = item.value;
            break;
        }
        default: {
            break;
        }
        }
    }

    return true;
}

int32_t Driver::wifi_handler(uint8_t message_type, void *message) {
    switch (message_type) {
    case M2M_WIFI_RESP_DEFAULT_CONNECT: {
        tstrM2MDefaultConnResp *conn_resp = (tstrM2MDefaultConnResp *)message;
        if (conn_resp->s8ErrorCode > 0) {
            loginfo("wifi_cb: %s (DISCONNECTED)", sta_cmd_to_string(message_type));
            queue_radio(IpcMessageType::IPC_N_DISCONNECTED);
        } else {
            loginfo("wifi_cb: %s", sta_cmd_to_string(message_type));
        }
        break;
    }
    case M2M_WIFI_RESP_CON_STATE_CHANGED: {
        tstrM2mWifiStateChanged *pstrWifiState = (tstrM2mWifiStateChanged *)message;
        if (pstrWifiState->u8CurrState == M2M_WIFI_CONNECTED) {
            if (mode_ == WifiMode::MODE_STATION) {
                loginfo("wifi_cb: %s", "CONNECTED (DHCP)");
            } else {
                loginfo("wifi_cb: %s", "CONNECTED (AP)");
                queue_radio(IpcMessageType::IPC_N_CONNECTED);
            }
        } else if (pstrWifiState->u8CurrState == M2M_WIFI_DISCONNECTED) {
            loginfo("wifi_cb: %s", "DISCONNECTED");
            queue_radio(IpcMessageType::IPC_N_DISCONNECTED);
        }
        break;
    }
    case M2M_WIFI_REQ_DHCP_CONF: {
        uint8_t *ip = (uint8_t *)message;
        loginfo("wifi_cb: %d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
        ip_address_ = ipv4_to_u32(ip[0], ip[1], ip[2], ip[3]);
        queue_radio(IpcMessageType::IPC_N_CONNECTED);
        break;
    }
    default: {
        loginfo("wifi_cb: %s (%d)", sta_cmd_to_string(message_type), message_type);
        break;
    }
    }

    return 0;
}

int32_t Driver::socket_handler(SOCKET sock, uint8_t message_type, void *message) {
    return sockets_.socket_handler(sock, message_type, message);
}

int32_t Driver::resolve_handler(uint8_t *name, uint32_t ip) {
    IpcMessage message{ -1, IpcMessageType::IPC_N_RESOLVE, ip };
    FK_ASSERT(xQueueSendToBack(queue_, &message, portMAX_DELAY));

    return 0;
}

int32_t Driver::service_task() {
    while (true) {
        if (xTaskNotifyWait(pdTRUE, ULONG_MAX, NULL, portMAX_DELAY)) {
            FK_ASSERT(lock_.take(portMAX_DELAY));
            if (m2m_wifi_handle_events(NULL) != M2M_SUCCESS) {
                logerror("m2m_wifi_handle_events failed");
            }
            FK_ASSERT(lock_.give());
        }
    }
    return 0;
}

bool Driver::gethostbyname(const char *name, uint32_t &ip) {
    resolved_ = {};

    FK_ASSERT(lock_.take(portMAX_DELAY));
    int32_t err = ::gethostbyname((uint8 *)name);
    FK_ASSERT(lock_.give());

    if (err < 0) {
        return false;
    }

    WaitingLoop waiting;
    while (waiting.check()) {
        if (!service()) {
            return false;
        }

        if (resolved_.ip != 0) {
            ip = resolved_.ip;
            resolved_ = {};
            return true;
        }
    }

    return false;
}

bool Driver::stop() {
    if (task_ != nullptr) {
        vTaskDelete(task_);
        task_ = nullptr;
        g_isr_task = nullptr;
    }
    if (queue_ != nullptr) {
        vQueueDelete(queue_);
        queue_ = nullptr;
    }
    sockets_.stop();
    m2m_wifi_deinit(NULL);
    nm_bsp_deinit();
    disable();

    return true;
}

void Driver::queue_radio(IpcMessageType type) {
    IpcMessage message{ type };
    FK_ASSERT(xQueueSendToBack(queue_, &message, portMAX_DELAY));
}

void Driver::enable() {
    g_winc1500_pin_cs = WINC1500_CS;
    g_winc1500_pin_irq = WINC1500_IRQ;
    g_winc1500_pin_rst = WINC1500_RESET;

    pinMode(WINC1500_CS, OUTPUT);
    pinMode(WINC1500_IRQ, INPUT);
    pinMode(WINC1500_RESET, OUTPUT);

    digitalWrite(WINC1500_POWER, HIGH);
    SPI1.begin();

    NVIC_SetPriority(EIC_11_IRQn, configLIBRARY_LOWEST_INTERRUPT_PRIORITY);
}

void Driver::disable() {
    digitalWrite(WINC1500_POWER, LOW);
    SPI1.end();

    pinMode(WINC1500_CS, INPUT_PULLUP);
    pinMode(WINC1500_IRQ, INPUT_PULLUP);
    pinMode(WINC1500_RESET, INPUT_PULLUP);
}

static const char *driver_state_to_string(DriverState state) {
    switch (state) {
    case DS_UNAVAILABLE:
        return "DS_UNAVAILABLE";
    case DS_READY:
        return "DS_READY";
    case DS_CONNECTING:
        return "DS_CONNECTING";
    case DS_ATTEMPTING_STATION:
        return "DS_ATTEMPTING_STATION";
    case DS_CONNECTED:
        return "DS_CONNECTED";
    case DS_ERROR:
        return "DS_ERROR";
    default:
        return "UNKNOWN";
    }
}

static const char *ipc_message_type_to_string(IpcMessageType state) {
    switch (state) {
    case IPC_NONE:
        return "IPC_NONE";
    case IPC_N_CONNECTED:
        return "IPC_N_CONNECTED";
    case IPC_N_DISCONNECTED:
        return "IPC_N_DISCONNECTED";
    case IPC_N_RESOLVE:
        return "IPC_N_RESOLVE";
    case IPC_S_IDLE:
        return "IPC_S_IDLE";
    case IPC_S_BOUND:
        return "IPC_S_BOUND";
    case IPC_S_LISTENING:
        return "IPC_S_LISTENING";
    case IPC_S_CONNECTED:
        return "IPC_S_CONNECTED";
    case IPC_S_ACCEPT:
        return "IPC_S_ACCEPT";
    case IPC_S_RECV:
        return "IPC_S_RECV";
    default:
        return "UNKNOWN";
    }
}

static const char *wifi_mode_to_string(WifiMode mode) {
    switch (mode) {
    case MODE_NONE:
        return "MODE_NONE";
    case MODE_STATION:
        return "MODE_STATION";
    case MODE_AP:
        return "MODE_AP";
    default:
        return "UNKNOWN";
    }
}

} // namespace fk

static void wifi_cb(uint8_t message_type, void *message) {
    auto network = reinterpret_cast<fk::AprilNetwork *>(fk::get_network());
    network->driver()->wifi_handler(message_type, message);
}

static void socket_cb(SOCKET sock, uint8_t message_type, void *message) {
    auto network = reinterpret_cast<fk::AprilNetwork *>(fk::get_network());
    network->driver()->socket_handler(sock, message_type, message);
}

static void resolve_cb(uint8_t *name, uint32_t ip) {
    auto network = reinterpret_cast<fk::AprilNetwork *>(fk::get_network());
    network->driver()->resolve_handler(name, ip);
}

#endif
