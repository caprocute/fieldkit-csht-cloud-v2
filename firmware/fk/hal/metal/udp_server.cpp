#if defined(__SAMD51__)

#include "hal/metal/metal_ipc.h"
#include "hal/metal/udp_server.h"
#include "hal/watchdog.h"
#include "common.h"
#include "config.h"
#include "platform.h"
#include "utilities.h"

#include "state_ref.h"
#include "varint.h"
#include "storage/storage.h"

namespace fk {

FK_DECLARE_LOGGER("serveudp");

#define FK_UDP_SEND_RETRIES 3

const uint16_t Port = 22144;

static void touch_udp_activity();
static uint32_t get_number_records();
static BufferPtr *get_identity(Pool *pool);

UDPServer::UDPServer(NetworkUDP *udp) : udp_(udp) {
}

UDPServer::~UDPServer() {
    stop();
}

bool UDPServer::start() {
    if (initialized_) {
        return true;
    }

    initialized_ = true;

    return true;
}

void UDPServer::stop() {
    if (initialized_) {
        if (udp_ != nullptr) {
            udp_->stop();
        }
        initialized_ = false;
    }
}

typedef struct __attribute__((__packed__)) packet_query_t {
    uint32_t kind;
} packet_query_t;

typedef struct __attribute__((__packed__)) packet_statistics_t {
    uint32_t kind;
    uint32_t nrecords;
} packet_statistics_t;

typedef struct __attribute__((__packed__)) packet_require_t {
    uint32_t kind;
    uint32_t head;
    uint32_t nrecords;
} packet_require_t;

typedef struct __attribute__((__packed__)) packet_records_t {
    uint32_t kind;
    uint32_t head;
    uint32_t flags;
    uint32_t sequence;
} packet_records_t;

typedef struct __attribute__((__packed__)) packet_batch_t {
    uint32_t kind;
    uint32_t flags;
    uint32_t errors;
} packet_batch_t;

typedef struct __attribute__((__packed__)) packet_t {
    union __attribute__((packed)) {
        packet_query_t query;
        packet_statistics_t statistics;
        packet_require_t require;
        packet_records_t records;
    } p;
} packet_t;

#define FK_UDP_PROTOCOL_KIND_QUERY      0
#define FK_UDP_PROTOCOL_KIND_STATISTICS 1
#define FK_UDP_PROTOCOL_KIND_REQUIRE    2
#define FK_UDP_PROTOCOL_KIND_RECORDS    3
#define FK_UDP_PROTOCOL_KIND_BATCH      4

#define FK_UDP_PROTOCOL_FLAG_NONE    0
#define FK_UDP_PROTOCOL_FLAG_PARTIAL 1

struct delimited_record_t {
    uint8_t *ptr{ nullptr };
    int32_t buffer_len{ 0 };
    int32_t record_len{ 0 };

    delimited_record_t() {
    }

    delimited_record_t(uint8_t *ptr, int32_t buffer_len, int32_t record_len) : ptr(ptr), buffer_len(buffer_len), record_len(record_len) {
    }

    bool is_partial() const {
        return record_len > buffer_len;
    }
};

class DelimitedRecordIterator {
private:
    uint8_t *ptr_{ nullptr };
    size_t size_{ 0 };
    size_t position_{ 0 };
    int32_t error_{ 0 };
    delimited_record_t record_;
    int32_t records_{ 0 };

public:
    DelimitedRecordIterator(uint8_t *ptr, size_t size) : ptr_(ptr), size_(size) {
    }

public:
    bool read() {
        record_ = delimited_record_t{};
        error_ = 0;

        if (position_ >= size_) {
            return false;
        }

        auto cursor = ptr_ + position_;
        auto record_len = (int32_t)phylum::varint_decode(cursor, size_ - position_, &error_);
        if (error_ != 0) {
            error_ = 0;

            // Little bit of a hack right here. What's happening is we were unable to parse
            // a valid varint from the buffer, which typically means that the varint was
            // split across two pages. So, we need to flag this as a partial record to the
            // surrounding code. Only, we don't know how big the record is! Which is why you
            // see the INT32_MAX use here. Perhaps we should just specify partial directly.
            auto buffer_len = (int32_t)(size_ - position_);
            record_ = delimited_record_t{
                cursor, buffer_len,
                INT32_MAX, // HACK
            };

            position_ += buffer_len;

            return true;
        }

        auto delimiter_len = (int32_t)phylum::varint_encoding_length(record_len);
        auto delimiter_and_record_len = delimiter_len + record_len;
        auto buffer_len = std::min<int32_t>(delimiter_and_record_len, size_ - position_);

        record_ = delimited_record_t{
            cursor,
            buffer_len,
            delimiter_and_record_len,
        };

        position_ += buffer_len;

        return true;
    }

    int32_t error() const {
        return error_;
    }

    delimited_record_t const &record() const {
        return record_;
    }
};

class SendingRecords {
private:
    uint32_t head_;
    uint32_t nrecords_;
    uint32_t processed_{ 0 };

public:
    SendingRecords(uint32_t head, uint32_t nrecords) : head_(head), nrecords_(nrecords) {
    }

public:
    bool busy() const {
        return processed_ < nrecords_;
    }

    bool processed(uint32_t records) {
        processed_ += records;
        return busy();
    }

    uint32_t processed() const {
        return processed_;
    }

    uint32_t sending_head() const {
        return head_ + processed_;
    }
};

class PacketSender {
private:
    NetworkUDP *udp_{ nullptr };
    uint32_t addr_;
    size_t queued_{ 0 };
    size_t send_failures_{ 0 };
    bool flush_failure_{ false };

public:
    PacketSender(NetworkUDP *udp, uint32_t addr) : udp_(udp), addr_(addr) {
    }

public:
    size_t queued() const {
        return queued_;
    }

    size_t send_failures() const {
        return send_failures_;
    }

    bool flush_failure() const {
        return flush_failure_;
    }

    bool can_queue(size_t size) {
        return queued_ + size <= MaximumUdpPacketSize;
    }

    bool write(uint8_t const *ptr, size_t size) {
        if (!can_queue(size)) {
            loginfo("!can_queue(%d) queued=%d", size, queued_);
            FK_ASSERT(can_queue(size));
        }

        if (queued_ == 0) {
            if (udp_->begin(addr_, Port) < 0) {
                logerror("begin packet failed");
                return false;
            }
        }

        FK_ASSERT(udp_->write(ptr, size) == (int32_t)size);

        queued_ += size;

        return true;
    }

    bool flush() {
        if (queued_ > 0) {
            for (auto i = 0u; i < FK_UDP_SEND_RETRIES; ++i) {
                auto err = udp_->flush();
                if (err < 0) {
                    send_failures_++;
                    if (err == FK_SOCK_ERR_BUFFER_FULL) {
                        logwarn("%d send failed (flush) (err=%d) (total=%d)", i, err, send_failures_);
                    } else {
                        logerror("%d send failed (flush) (err=%d) (total=%d)", i, err, send_failures_);
                    }
                    if (i == FK_UDP_SEND_RETRIES - 1) {
                        flush_failure_ = true;
                        return false;
                    }
                    fk_delay(150 * (i + 1));
                } else {
                    if (i > 0) {
                        logwarn("%d send ok", i);
                        fk_delay(150 * (i + 1));
                    }
                    break;
                }
            }

            queued_ = 0;
        }

        touch_udp_activity();

        return true;
    }

    bool finish_batch() {
        if (!flush()) {
            logerror("sender flush failed");
            return false;
        }

        if (udp_->begin(addr_, Port) < 0) {
            logerror("begin failed");
            return false;
        }

        packet_batch_t reply;
        memzero(&reply, sizeof(packet_batch_t));
        reply.kind = FK_UDP_PROTOCOL_KIND_BATCH;
        // I intend to make this just an uint16 in the future.
        reply.errors = (send_failures_ & 0xff);
        write((uint8_t *)&reply, sizeof(packet_batch_t));

        if (!flush()) {
            return false;
        }

        return true;
    }
};

class CopyingPage {
private:
    uint8_t *ptr_{ nullptr };
    size_t size_{ 0 };
    size_t position_{ 0 };

public:
    CopyingPage() {
        ptr_ = (uint8_t *)fk_standard_page_malloc(StandardPageSize, "udp-records");
        size_ = StandardPageSize;
    }

    virtual ~CopyingPage() {
        fk_standard_page_free(ptr_);
    }

public:
    size_t position() const {
        return position_;
    }

    bool fill(FileReader *file_reader) {
        while (position_ < size_) {
            auto to_read = size_ - position_;
            auto bytes_read = file_reader->read(ptr_ + position_, to_read);
            if (bytes_read == 0) {
                break;
            }
            if (bytes_read < 0) {
                logerror("read error (%" PRId32 " != %" PRId32 ")", bytes_read, to_read);
                return false;
            }

            position_ += bytes_read;
        }

        return true;
    }

    int32_t begin_records_packet(PacketSender &sender, SendingRecords &sending, uint32_t flags, uint32_t sequence) {
        packet_records_t reply;
        memzero(&reply, sizeof(packet_records_t));
        reply.kind = FK_UDP_PROTOCOL_KIND_RECORDS;
        reply.head = sending.sending_head();
        reply.flags = flags;
        reply.sequence = sequence;
        sender.write((uint8_t *)&reply, sizeof(packet_records_t));

        return sizeof(packet_records_t);
    }

    bool send(PacketSender &sender, CopyingPage &other_page, SendingRecords &sending) {
        auto copied = 0u;
        DelimitedRecordIterator iterator{ ptr_, position_ };
        while (iterator.read()) {
            auto record = iterator.record();

            // If this record is partial we push to the other page and we're done.
            if (record.is_partial()) {
                logtrace("record %" PRIu32 " %s", record.buffer_len, record.is_partial() ? "partial" : "");
                memcpy(other_page.ptr_, record.ptr, record.buffer_len);
                other_page.position_ += record.buffer_len;
                break;
            }

            // If this packet would create a packet that's too large, we flush and reset.
            if (!sender.can_queue(record.buffer_len)) {
                if (!sender.flush()) {
                    return false;
                }

                copied = 0;
            }

            // Check for a record that won't fit in a packet. There's definitely
            // a way to make this use the same code path for partial and
            // complete records, though maybe that's not worth the effort?
            if (record.buffer_len > (int32_t)MaximumUdpPacketSize) {
                FK_ASSERT(sender.queued() == 0);

                loginfo("#%" PRIu32 " multiple packets (%" PRIu32 " bytes)", sending.sending_head(), record.buffer_len);

                auto record_sent = 0;
                auto seq = 0u;
                while (record_sent < record.buffer_len) {
                    auto header_size = begin_records_packet(sender, sending, FK_UDP_PROTOCOL_FLAG_PARTIAL, seq++);
                    copied += header_size;

                    auto this_packet = std::min(record.buffer_len - record_sent, (int32_t)MaximumUdpPacketSize - header_size);
                    sender.write(record.ptr + record_sent, this_packet);

                    if (!sender.flush()) {
                        return false;
                    }

                    record_sent += this_packet;
                    copied += this_packet;
                }
            } else {
                if (sender.queued() == 0) {
                    copied += begin_records_packet(sender, sending, FK_UDP_PROTOCOL_FLAG_NONE, 0);
                }

                // Copy record to packet.
                sender.write(record.ptr, record.buffer_len);
                copied += record.buffer_len;
            }

            sending.processed(1);
        }

        // This.... should be pretty rare.
        if (iterator.error() > 0) {
            logerror("iterator failed");
            return false;
        }

        // Reset for our next use.
        position_ = 0;
        memzero(ptr_, size_);

        return true;
    }
};

struct incoming_packet_t {
    uint8_t *ptr{ nullptr };
    size_t size{ 0 };
    size_t position{ 0 };
    uint32_t remote_ip;
    incoming_packet_t *np{ nullptr };

    uint8_t *has_room_for(size_t bytes) {
        if (size - position < bytes) {
            return nullptr;
        }

        auto record_ptr = ptr + position;
        position += bytes;
        return record_ptr;
    }

    template <typename T> bool dequeue(T &packet) {
        auto ptr = has_room_for(sizeof(T));
        if (ptr == nullptr) {
            return false;
        }

        memcpy((uint8_t *)&packet, ptr, sizeof(T));
        return true;
    }
};

bool UDPServer::service(Pool *pool) {
    if (!initialized_) {
        return true;
    }

    incoming_packet_t *incoming = nullptr;
    while (true) {
        auto err = udp_->available();
        if (err < 0) {
            return false;
        }
        if (err > 0) {
            auto size = err;
            if (size > (int32_t)sizeof(incoming_packet_t)) {
                logwarn("discarding %d bytes (expecting %d)", size, sizeof(incoming_packet_t));
                int32_t buffer_size = 256;
                auto discard = (uint8_t *)pool->malloc(buffer_size);
                while (size > 0) {
                    auto read = udp_->read(discard, std::min(buffer_size, size));
                    if (read <= 0) {
                        logerror("discard failed");
                        break;
                    }
                    size -= read;
                }
            } else {
                incoming_packet_t *receiving = (incoming_packet_t *)pool->malloc(sizeof(incoming_packet_t));
                receiving->size = size;
                receiving->ptr = (uint8_t *)pool->malloc(size);
                receiving->remote_ip = udp_->remote_ip();
                memzero(receiving->ptr, size);
                FK_ASSERT(udp_->read(receiving->ptr, size) == (int32_t)size);
                receiving->np = incoming;
                incoming = receiving;

                ip4_address ip{ receiving->remote_ip };
                loginfo("received (%d.%d.%d.%d) (%zu bytes)", ip.u.bytes[0], ip.u.bytes[1], ip.u.bytes[2], ip.u.bytes[3], size);
            }
        } else {
            break;
        }
    }

    if (incoming != nullptr) {
        packet_t received;
        memzero(&received, sizeof(packet_t));
        memcpy(&received, incoming->ptr, incoming->size);

        uint32_t remote_ip = incoming->remote_ip;
        PacketSender sender{ udp_, remote_ip };

        auto nrecords = get_number_records();

        switch (received.p.query.kind) {
        case FK_UDP_PROTOCOL_KIND_QUERY: {
            loginfo("query (nrecords=%" PRIu32 ")", nrecords);

            packet_statistics_t reply;
            memzero(&reply, sizeof(packet_statistics_t));
            reply.kind = FK_UDP_PROTOCOL_KIND_STATISTICS;
            reply.nrecords = nrecords;
            sender.write((uint8_t const *)&reply, sizeof(reply));

            auto identity = get_identity(pool);
            FK_ASSERT(identity->solo());
            sender.write(identity->buffer(), identity->length());

            loginfo("identity = %" PRIu32 " bytes", identity->length());

            loginfo("sending %d bytes", sender.queued());

            if (!sender.flush()) {
                logerror("sender flush failed");
            }

            break;
        }
        case FK_UDP_PROTOCOL_KIND_STATISTICS: {
            loginfo("statistics (TODO)");
            break;
        }
        case FK_UDP_PROTOCOL_KIND_REQUIRE: {
            loginfo("require!");

            auto lock = storage_mutex.acquire(UINT32_MAX);
            FK_ASSERT(lock);

            auto started = fk_uptime();
            auto old_level = (LogLevels)log_get_level();
            log_configure_level(LogLevels::INFO);

            StatisticsMemory memory_{ MemoryFactory::get_data_memory() };
            Storage storage{ &memory_, *pool };
            if (!storage.begin()) {
                logerror("begin failed");
                return false;
            }

            auto file_reader = storage.file_reader(Storage::Data, *pool);

            packet_require_t require;
            while (incoming->dequeue(require)) {
                FK_ASSERT(require.kind == FK_UDP_PROTOCOL_KIND_REQUIRE);

                // First time through this loop this will be a NOOP, if there's pending data
                // from a previous pass we force that out. For simplicity we're keeping
                // contiguous records in packets.
                if (!sender.flush()) {
                    logerror("sender flush failed");
                    return false;
                }

                loginfo("require #%" PRIu32 " -> #%" PRIu32 " (nrecords=%" PRIu32 ")", require.head, require.nrecords, nrecords);

                auto first_record = require.head;
                if (!file_reader->seek_record(first_record, *pool)) {
                    logerror("seek failed");
                    return false;
                }

                SendingRecords sending{
                    require.head,
                    require.nrecords,
                };

                loginfo("seek-done: %" PRIu32 "ms", fk_uptime() - started);

                auto active_page = 0u;
                CopyingPage pages[2];
                while (sending.busy()) {
                    auto &page = pages[active_page];
                    auto &other = pages[(active_page + 1) % 2];

                    if (!page.fill(file_reader)) {
                        loginfo("copying:fill break");
                        break;
                    }

                    if (page.position() == 0) {
                        loginfo("copying:eof");
                        break;
                    }

                    if (!page.send(sender, other, sending)) {
                        loginfo("copying:send break");
                        break;
                    }

#if defined(FK_WDT_ENABLE)
                    fk_wdt_feed();
#endif

                    active_page = (active_page + 1) % 2;
                }

                loginfo("processed=%" PRIu32, sending.processed());
            }

            if (!sender.finish_batch()) {
                if (sender.flush_failure()) {
                    logerror("sender finish_batch failed (flush)");
                } else {
                    logerror("sender finish_batch failed");
                }
                return false;
            }

            log_configure_level(old_level);
            auto elapsed = fk_uptime() - started;
            loginfo("send-elapsed: %" PRIu32 "ms", elapsed);

            break;
        }
        case FK_UDP_PROTOCOL_KIND_RECORDS: {
            loginfo("records (TODO)");
            break;
        }
        default: {
            logwarn("unknown %d", received.p.query.kind); // TODO
            break;
        }
        }

        activity_ = fk_uptime();
    }

    return true;
}

static void touch_udp_activity() {
    auto gs = get_global_state_rw();
    gs.get()->network.state.udp_activity = fk_uptime();
}

static uint32_t get_number_records() {
    auto gs = get_global_state_ro();
    return gs.get()->storage.data.block;
}

static BufferPtr *get_identity(Pool *pool) {
    auto gs = get_global_state_ro();

    fk_serial_number_t sn;

    auto device_id_data = pool->malloc_with<pb_data_t>({
        .length = sizeof(sn),
        .buffer = pool->copy(&sn, sizeof(sn)),
    });

    auto generation_data = pool->malloc_with<pb_data_t>({
        .length = sizeof(gs.get()->general.generation),
        .buffer = &gs.get()->general.generation,
    });

    fk_app_Identity identity = fk_app_Identity_init_default;
    identity.name.arg = (void *)gs.get()->general.name;
    identity.name.funcs.encode = pb_encode_string;
    identity.deviceId.arg = device_id_data;
    identity.deviceId.funcs.encode = pb_encode_data;
    identity.generationId.arg = generation_data;
    identity.generationId.funcs.encode = pb_encode_data;

    return pool->encode(fk_app_Identity_fields, &identity, true);
}

} // namespace fk

#endif
