#pragma once

#include "m2m_all.h"
#include "utilities.h"

namespace fk {

enum SocketState {
    S_NONE,
    S_IDLE,
    S_BINDING,
    S_BOUND,
    S_LISTEN,
    S_LISTENING,
    S_CONNECTING,
    S_CONNECTED,
    S_ACCEPTED,
    S_CLOSING,
};

struct Socket {
    SOCKET skt{ -1 };
    SOCKET parent{ -1 };
    uint8_t type{ 0 };
    uint8_t pending{ 0 };
    struct sockaddr_in remote_addr;
    SocketState state{ SocketState::S_IDLE };
    LinkedBuffer *work{ nullptr };
    LinkedBuffer *read{ nullptr };
    LinkedBuffer *write{ nullptr };

    int32_t read_into(uint8_t *buffer, size_t size);
    int32_t write_into(uint8_t const *buffer, size_t size);
    LinkedBuffer *try_free();
};

constexpr size_t MAXIMUM_SOCKETS = MAX_SOCKET;

class Sockets {
private:
    SemaphoreMutex *lock_{ nullptr };
    LinkedBuffers buffers_;
    Socket sockets_[MAXIMUM_SOCKETS];

public:
    Sockets(SemaphoreMutex *lock, Pool *pool);

public:
    int32_t socket_handler(SOCKET sock, uint8_t message_type, void *message);

private:
    Socket *alloc(SOCKET skt, uint8_t type, SocketState state);
    Socket *get(SOCKET skt);
    int32_t close_internal(Socket *socket);
    int32_t prime_receive(Socket *socket);

public:
    bool is_connected(SOCKET skt);

public:
    SOCKET create(uint16_t domain, uint8_t type, uint8_t flags);
    int32_t set_opt(SOCKET skt, uint8_t level, uint8_t option, const void *option_value, uint16_t option_length);
    int32_t bind(SOCKET skt, struct sockaddr *addr, uint8_t addr_len);
    int32_t connect(SOCKET skt, struct sockaddr *addr, uint8_t addr_len);
    int32_t listen(SOCKET skt);
    SOCKET accept(SOCKET skt);
    uint32_t remote_ip(SOCKET skt);
    int32_t read(SOCKET skt, uint8_t *buffer, size_t size);
    int32_t write(SOCKET skt, uint8_t const *buffer, size_t size);
    int32_t vwritef(SOCKET skt, const char *str, va_list args);
    int32_t flush(SOCKET skt);
    int32_t send_to(SOCKET skt, uint32_t ip, uint16_t port);
    int32_t close(SOCKET skt);
    int32_t stop();
};

} // namespace fk
