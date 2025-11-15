#if defined(__SAMD51__) && defined(FK_NETWORK_WINC1500_APRIL)

#include <algorithm>

#include "hal/metal/april_network.h"
#include "hal/hal.h"
#include "utilities.h"
#include "sockets.h"

FK_DECLARE_LOGGER("network");

#if FK_SOCK_ERR_BUFFER_FULL != SOCK_ERR_BUFFER_FULL
#error "Unexpected SOCK_ERR_BUFFER_FULL value."
#endif

namespace fk {

static const char *socket_state_to_string(SocketState state);

Sockets::Sockets(SemaphoreMutex *lock, Pool *pool) : lock_(lock), buffers_{ 16, SOCKET_BUFFER_MAX_LENGTH, pool } {
}

Socket *Sockets::alloc(SOCKET skt, uint8_t type, SocketState state) {
    int32_t index = -1;

    for (size_t i = 0u; i < MAXIMUM_SOCKETS; ++i) {
        if (sockets_[i].skt == skt) {
            FK_ASSERT(sockets_[i].type == type);
            logwarn("socket_cb[%d]: socket exists (%s)", skt, socket_state_to_string(sockets_[i].state));
            index = i;
            break;
        }
    }

    if (index == -1) {
        for (size_t i = 0u; i < MAXIMUM_SOCKETS; ++i) {
            if (sockets_[i].skt == -1) {
                FK_ASSERT(sockets_[i].work == nullptr);
                FK_ASSERT(sockets_[i].read == nullptr);
                FK_ASSERT(sockets_[i].write == nullptr);
                index = i;
                break;
            }
        }

        if (index == -1) {
            return nullptr;
        }
    }

    sockets_[index].skt = skt;
    sockets_[index].state = state;
    sockets_[index].type = type;
    return &sockets_[index];
}

Socket *Sockets::get(SOCKET skt) {
    for (size_t i = 0u; i < MAXIMUM_SOCKETS; ++i) {
        if (sockets_[i].skt == skt) {
            return &sockets_[i];
        }
    }

    return nullptr;
}

SOCKET Sockets::create(uint16_t domain, uint8_t type, uint8_t flags) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    SOCKET skt = socket(domain, type, flags);
    if (skt >= 0) {
        if (alloc(skt, type, SocketState::S_IDLE) == nullptr) {
            ::close(skt);
            skt = -1;
        }
    }

    FK_ASSERT(lock_->give());
    return skt;
}

int32_t Sockets::prime_receive(Socket *socket) {
    // Prime the pump to start receiving data... if we don't have a 'working'
    // buffer yet, allocate one. Otherwise, let the sockets layer know we're
    // ready to receive data.
    if (socket->work == nullptr) {
        LinkedBuffer *buffer = buffers_.get();
        FK_ASSERT(buffer != nullptr);
        socket->work = buffer;
    }

    int32_t err = -1;
    if (socket->type == SOCK_STREAM) {
        err = ::recv(socket->skt, socket->work->ptr, socket->work->size, 0);
    } else {
        err = ::recvfrom(socket->skt, socket->work->ptr, socket->work->size, 0);
    }
    FK_ASSERT(err == 0);

    return 0;
}

bool Sockets::is_connected(SOCKET skt) {
    bool connected = false;

    FK_ASSERT(lock_->take(portMAX_DELAY));
    Socket *socket = get(skt);
    connected = socket != nullptr;
    FK_ASSERT(lock_->give());

    return connected;
}

int32_t Sockets::set_opt(SOCKET skt, uint8_t level, uint8_t option, const void *option_value, uint16_t option_length) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    int32_t err = ::setsockopt(skt, level, option, option_value, option_length);

    FK_ASSERT(lock_->give());
    return err;
}

int32_t Sockets::bind(SOCKET skt, struct sockaddr *addr, uint8_t addr_len) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket == nullptr) {
        FK_ASSERT(lock_->give());
        return SOCK_ERR_INVALID;
    }
    socket->state = SocketState::S_BINDING;
    int32_t err = ::bind(skt, addr, addr_len);

    FK_ASSERT(lock_->give());
    if (err < 0) {
        return err;
    }

    WaitingLoop waiting;
    while (waiting.check()) {
        if (socket->state == SocketState::S_BOUND) {
            if (socket->type == SOCK_DGRAM) {
                FK_ASSERT(lock_->take(portMAX_DELAY));
                FK_ASSERT(prime_receive(socket) == 0);
                FK_ASSERT(lock_->give());
            }

            return 0;
        }
        if (socket->state != SocketState::S_BINDING) {
            logerror("bind failed");
            break;
        }
    }

    return -1;
}

int32_t Sockets::connect(SOCKET skt, struct sockaddr *addr, uint8_t addr_len) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket == nullptr) {
        FK_ASSERT(lock_->give());
        return SOCK_ERR_INVALID;
    }
    socket->state = SocketState::S_CONNECTING;
    int32_t err = ::connect(skt, addr, addr_len);

    FK_ASSERT(lock_->give());
    if (err < 0) {
        return err;
    }

    WaitingLoop waiting;
    while (waiting.check()) {
        if (socket->state == SocketState::S_CONNECTED) {
            FK_ASSERT(lock_->take(portMAX_DELAY));
            FK_ASSERT(prime_receive(socket) == 0);
            FK_ASSERT(lock_->give());
            return 0;
        }
        if (socket->state != SocketState::S_CONNECTING) {
            break;
        }
    }

    return -1;
}

int32_t Sockets::listen(SOCKET skt) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    FK_ASSERT(socket != nullptr);
    socket->state = SocketState::S_LISTEN;
    int32_t err = ::listen(skt, 0);

    FK_ASSERT(lock_->give());
    if (err < 0) {
        return err;
    }

    WaitingLoop waiting;
    while (waiting.check()) {
        if (socket->state == SocketState::S_LISTENING) {
            return 0;
        }
        if (socket->state != SocketState::S_LISTEN) {
            break;
        }
    }

    return -1;
}

SOCKET Sockets::accept(SOCKET skt) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    SOCKET accepted = -1;
    for (size_t i = 0u; i < MAXIMUM_SOCKETS; ++i) {
        Socket *socket = &sockets_[i];
        if (socket->state == SocketState::S_ACCEPTED) {
            if (socket->parent == skt) {
                // This is a noop and unnecessary.
                // ::accept(sockets_[i].parent, NULL, NULL);
                socket->state = SocketState::S_CONNECTED;
                accepted = socket->skt;
                FK_ASSERT(prime_receive(socket) == 0);
            }
        }
    }

    FK_ASSERT(lock_->give());

    return accepted;
}

uint32_t Sockets::remote_ip(SOCKET skt) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);

    uint32_t ip = 0;
    if (socket != nullptr) {
        ip = socket->remote_addr.sin_addr.s_addr;
    }

    FK_ASSERT(lock_->give());

    return ip;
}

int32_t Sockets::read(SOCKET skt, uint8_t *buffer, size_t size) {
    int32_t err = 0;

    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket == nullptr) {
        FK_ASSERT(lock_->give());
        return SOCK_ERR_INVALID;
    }

    if (buffer == nullptr || size == 0) {
        if (socket->read != nullptr) {
            err = socket->read->filled - socket->read->position;
        }
    } else {
        err = socket->read_into(buffer, size);
        LinkedBuffer *freed = socket->try_free();
        if (err > 0 || freed != nullptr) {
            FK_ASSERT(prime_receive(socket) == 0);
            buffers_.free(freed);
        }
    }

    FK_ASSERT(lock_->give());

    return err;
}

struct WriteLinkedBuffer {
    LinkedBuffers *buffers;
    LinkedBuffer *lb;
};

static void write_linked_buffer(char c, void *arg) {
    if (c <= 0) {
        return;
    }

    auto op = reinterpret_cast<WriteLinkedBuffer *>(arg);
    LinkedBuffer *tail = op->lb->tail();
    if (tail->filled == tail->size) {
        tail->np = op->buffers->get();
        FK_ASSERT(tail->np != nullptr);
        tail = tail->np;
    }
    tail->ptr[tail->filled++] = c;
}

int32_t Sockets::write(SOCKET skt, uint8_t const *buffer, size_t size) {
    int32_t err = 0;
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket == nullptr) {
        FK_ASSERT(lock_->give());
        return SOCK_ERR_INVALID;
    }

    while (size > 0) {
        if (socket->write == nullptr || socket->write->tail()->is_filled()) {
            socket->write = LinkedBuffer::append(socket->write, buffers_.get());
        }

        int32_t copied = socket->write_into(buffer + err, size);
        if (copied < 0) {
            err = copied;
            break;
        }

        err += copied;
        size -= copied;
    }

    FK_ASSERT(lock_->give());

    return err;
}

int32_t Sockets::vwritef(SOCKET skt, const char *str, va_list args) {
    int32_t err = 0;
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket == nullptr) {
        FK_ASSERT(lock_->give());
        return SOCK_ERR_INVALID;
    }

    if (socket->write == nullptr) {
        socket->write = buffers_.get();
    }

    WriteLinkedBuffer op;
    op.lb = socket->write;
    op.buffers = &buffers_;

    err = tiny_vfctprintf(write_linked_buffer, &op, str, args);

    FK_ASSERT(lock_->give());

    return err;
}

int32_t Sockets::flush(SOCKET skt) {
    int32_t err = 0;
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket != nullptr && socket->write != nullptr) {
        while (socket->write != nullptr) {
            FK_ASSERT(socket->write->filled <= SOCKET_BUFFER_MAX_LENGTH);
            int32_t send_err = ::send(skt, (void *)socket->write->ptr, socket->write->filled, 0);
            if (send_err < 0) {
                break;
            }
            if (send_err >= 0) {
                err += socket->write->filled;
                socket->pending++;
                logverbose("[%d] flush sz=%d p=%d", skt, socket->write->filled, socket->pending);
            }
            LinkedBuffer *freeing = socket->write;
            socket->write = socket->write->np;
            freeing->np = nullptr;
            buffers_.free(freeing);
        }
    }

    FK_ASSERT(lock_->give());

    return err;
}

int32_t Sockets::send_to(SOCKET skt, uint32_t ip, uint16_t port) {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    Socket *socket = get(skt);
    if (socket == nullptr) {
        FK_ASSERT(lock_->give());
        return SOCK_ERR_INVALID;
    }

    if (socket->write == nullptr) {
        logwarn("[%d] send-to no-data", skt);
    }

    int32_t err = -1;
    int32_t flushed = 0;

    while (socket->write != nullptr) {
        if (socket->write->filled > MaximumUdpPacketSize) {
            logwarn("[%d] send-to %s %" PRIu16 " bytes ip=%d port=%d", skt, "overflow", socket->write->filled, ip, port);
        }

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(struct sockaddr_in));
        addr.sin_family = AF_INET;
        addr.sin_port = _htons(port);
        addr.sin_addr.s_addr = ip;
        err = ::sendto(skt, (void *)socket->write->ptr, socket->write->filled, 0, (struct sockaddr *)&addr, sizeof(addr));
        if (err == 0) {
            auto np = socket->write->np;
            flushed += socket->write->filled;
            buffers_.free(socket->write);
            socket->write = np;
        } else {
            logwarn("[%d] send-to %s %d bytes ip=%d port=%d", skt, "error", err, ip, port);
            break;
        }
    }

    FK_ASSERT(lock_->give());

    if (err == 0) {
        err = flushed;
    }

    return err;
}

int32_t Sockets::close_internal(Socket *socket) {
    loginfo("[%d] closed", socket->skt);
    ::close(socket->skt);
    socket->skt = -1;
    socket->parent = -1;
    socket->state = SocketState::S_NONE;
    socket->type = 0;
    socket->pending = 0;
    if (socket->work != nullptr) {
        buffers_.free(socket->work);
        socket->work = nullptr;
    }
    if (socket->read != nullptr) {
        buffers_.free(socket->read);
        socket->read = nullptr;
    }
    if (socket->write != nullptr) {
        buffers_.free(socket->write);
        socket->write = nullptr;
    }

    return 0;
}

int32_t Sockets::close(SOCKET skt) {
    int32_t err = flush(skt);

    FK_ASSERT(lock_->take(portMAX_DELAY));
    Socket *socket = get(skt);
    if (socket != nullptr) {
        if (socket->pending > 0) {
            logwarn("[%d] close: pending %d (%d)", skt, socket->pending, socket->skt);
            socket->state = SocketState::S_CLOSING;
        } else {
            logverbose("[%d] close: closing", skt);
            err = close_internal(socket);
        }
    } else {
        logwarn("[%d] close: no socket", skt);
        err = 0;
    }
    FK_ASSERT(lock_->give());

    return err;
}

int32_t Sockets::stop() {
    FK_ASSERT(lock_->take(portMAX_DELAY));

    for (size_t i = 0u; i < MAXIMUM_SOCKETS; ++i) {
        if (sockets_[i].skt != -1) {
            if (close_internal(&sockets_[i]) < 0) {
                logwarn("stop-close-failed");
            }
        }
    }
    socketDeinit();

    FK_ASSERT(lock_->give());

    return 0;
}

int32_t Sockets::socket_handler(SOCKET sock, uint8_t message_type, void *message) {
    Socket *socket = get(sock);
    if (socket == nullptr) {
        logwarn("socket_cb[%d]: unknown socket (%d)", sock, message_type);
        return 0;
    }

    switch (message_type) {
    case SOCKET_MSG_BIND: {
        tstrSocketBindMsg *m = (tstrSocketBindMsg *)message;
        logdebug("socket_cb[%d]: %s", sock, "BIND");
        if (m != nullptr && m->status == 0) {
            socket->state = SocketState::S_BOUND;
        } else {
            logwarn("socket_cb[%d] %d", sock, m->status);
            socket->state = SocketState::S_IDLE;
        }
        break;
    }
    case SOCKET_MSG_LISTEN: {
        tstrSocketListenMsg *m = (tstrSocketListenMsg *)message;
        logdebug("socket_cb[%d]: %s", sock, "LISTEN");
        if (m != nullptr && m->status == 0) {
            socket->state = SocketState::S_LISTENING;
        } else {
            socket->state = SocketState::S_IDLE;
        }
        break;
    }
    case SOCKET_MSG_ACCEPT: {
        tstrSocketAcceptMsg *m = (tstrSocketAcceptMsg *)message;
        if (m != nullptr && m->sock > -1) {
            logdebug("socket_cb[%d]: %s (%d)", sock, "ACCEPT", m->sock);
            Socket *accepted = alloc(m->sock, SOCK_STREAM, SocketState::S_ACCEPTED);
            if (accepted != nullptr) {
                accepted->remote_addr = m->strAddr;
                accepted->parent = sock;
            } else {
                logwarn("socket_cb[%d]: ACCEPT failed");
                // Allocation failed, so not using close_internal.
                ::close(m->sock);
            }
        } else {
            logdebug("socket_cb[%d]: %s", sock, "ACCEPT-ERROR");
        }
        break;
    }
    case SOCKET_MSG_CONNECT: {
        tstrSocketConnectMsg *m = (tstrSocketConnectMsg *)message;
        logdebug("socket_cb[%d]: %s", sock, "CONNECT");
        if (m != nullptr && m->s8Error == 0) {
            socket->state = SocketState::S_CONNECTED;
        } else {
            socket->state = SocketState::S_IDLE;
        }
        break;
    }
    case SOCKET_MSG_RECVFROM:
    case SOCKET_MSG_RECV: {
        tstrSocketRecvMsg *m = (tstrSocketRecvMsg *)message;
        if (m->s16BufferSize <= 0) {
            logdebug("socket_cb[%d]: %s %s", sock, "RECV", "close");
            close_internal(socket);
        } else if (socket->state == SocketState::S_ACCEPTED || socket->state == SocketState::S_CONNECTED ||
                   socket->state == SocketState::S_BOUND) {
            logdebug("socket_cb[%d]: %s %s %d/%d 0x%x", sock, "RECV", "read", m->s16BufferSize, m->u16RemainingSize, m->pu8Buffer);

            if (socket->type == SOCK_DGRAM) {
                socket->remote_addr = m->strRemoteAddr;
            }

            LinkedBuffer *read = buffers_.get();
            FK_ASSERT(m->s16BufferSize <= read->size);
            memcpy(read->ptr, m->pu8Buffer, m->s16BufferSize);
            read->filled = m->s16BufferSize;
            socket->read = LinkedBuffer::append(socket->read, read);

            if (m->u16RemainingSize > 0) {
                logdebug("socket_cb[%d]: %s %d remaining", sock, "RECV", m->u16RemainingSize);
            }
        } else {
            logdebug("socket_cb[%d]: %s %s %s", sock, "RECV", "discard", socket_state_to_string(socket->state));
        }
        break;
    }
    case SOCKET_MSG_SENDTO:
    case SOCKET_MSG_SEND: {
        int16_t bytes = *(int16_t *)message;
        if (bytes == SOCK_ERR_INVALID) {
            logdebug("socket_cb[%d]: %s %s (%d)", sock, "SEND", "ERR_INVALID", socket->pending);
            close_internal(socket);
        } else {
            if (socket->pending > 0) {
                socket->pending--;
                logdebug("socket_cb[%d]: %s %d bytes (%d)", sock, "SEND", bytes, socket->pending);
                if (socket->state == SocketState::S_CLOSING && socket->pending == 0) {
                    close_internal(socket);
                }
            } else {
                logdebug("socket_cb[%d]: %s %d bytes", sock, "SEND", bytes);
            }
        }
        break;
    }
    default: {
        logdebug("socket_cb[%d]: %d", sock, message_type);
        break;
    }
    }

    return 0;
}

LinkedBuffer *Socket::try_free() {
    if (read != nullptr) {
        if (read->position == read->filled) {
            LinkedBuffer *freeing = read;
            freeing->np = nullptr;
            read = read->np;
            return freeing;
        }
    }

    return nullptr;
}

int32_t Socket::read_into(uint8_t *buffer, size_t size) {
    if (read == nullptr) {
        return 0;
    }

    if (read->position < read->filled) {
        int32_t reading = std::min<int32_t>(size, read->filled - read->position);
        memcpy(buffer, read->ptr + read->position, reading);
        read->position += reading;
        return reading;
    }

    return 0;
}

int32_t Socket::write_into(uint8_t const *buffer, size_t size) {
    FK_ASSERT(write != nullptr);

    int32_t err = 0;

    LinkedBuffer *tail = write->tail();
    int32_t writing = std::min<int32_t>(size, tail->size - tail->filled);
    memcpy(tail->ptr + tail->filled, buffer, writing);
    tail->filled += writing;
    size -= writing;
    err += writing;

    return err;
}

static const char *socket_state_to_string(SocketState state) {
    switch (state) {
    case SocketState::S_NONE:
        return "NONE";
    case SocketState::S_IDLE:
        return "IDLE";
    case SocketState::S_BINDING:
        return "BINDING";
    case SocketState::S_BOUND:
        return "BOUND";
    case SocketState::S_LISTEN:
        return "LISTEN";
    case SocketState::S_LISTENING:
        return "LISTENING";
    case SocketState::S_CONNECTING:
        return "CONNECTING";
    case SocketState::S_CONNECTED:
        return "CONNECTED";
    case SocketState::S_ACCEPTED:
        return "ACCEPTED";
    case SocketState::S_CLOSING:
        return "CLOSING";
    default:
        return "UNKNOWN";
    }
}

} // namespace fk

#endif
