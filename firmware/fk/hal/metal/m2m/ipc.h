#pragma once

#include "os.h"
#include "sockets.h"

namespace fk {

enum IpcMessageType {
    IPC_NONE,
    IPC_N_CONNECTED,
    IPC_N_DISCONNECTED,
    IPC_N_RESOLVE,
    IPC_S_IDLE,
    IPC_S_BOUND,
    IPC_S_LISTENING,
    IPC_S_CONNECTED,
    IPC_S_ACCEPT,
    IPC_S_RECV,
};

typedef struct IpcMessage {
    IpcMessageType type{ IpcMessageType::IPC_NONE };
    SOCKET skt{ -1 };
    uint32_t value{ 0 };

    IpcMessage() {
    }

    IpcMessage(IpcMessageType type) : type(type) {
    }

    IpcMessage(SOCKET skt, IpcMessageType type) : type(type), skt(skt) {
    }

    IpcMessage(SOCKET skt, IpcMessageType type, uint32_t value) : type(type), skt(skt), value(value) {
    }
} IpcMessage;

} // namespace fk
