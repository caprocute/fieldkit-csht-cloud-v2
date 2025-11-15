#include "networking/upload_data_worker.h"
#include "state_ref.h"
#include "utilities.h"
#include "progress_tracker.h"
#include "gs_progress_callbacks.h"
#include "storage/storage.h"
#include "hal/watchdog.h"

#include "networking/http_connection.h"
#include "networking/wifi_toggle_worker.h"

#if defined(__SAMD51__)
#include "hal/metal/metal_ipc.h"
#else
#include "hal/linux/linux_ipc.h"
#endif

namespace fk {

FK_DECLARE_LOGGER("upload");

UploadDataWorker::UploadDataWorker() {
}

UploadDataWorker::UploadDataWorker(bool all_meta, bool all_data) : all_meta_(all_meta), all_data_(all_data) {
}

ConnectionInfo get_connection_info(Pool &pool) {
    auto gs = get_global_state_ro();

    auto generation = bytes_to_hex_string_pool((uint8_t *)&gs.get()->general.generation, sizeof(gs.get()->general.generation), pool);

    return {
        pool.strdup(gs.get()->transmission.url),
        pool.strdup(gs.get()->transmission.token),
        pool.strdup(gs.get()->general.name),
        generation,
    };
}

struct RequestInfo {
    const ConnectionInfo *connection;
    const char *headers;
};

RequestInfo get_request_info(ConnectionInfo const *connection, uint32_t first, uint32_t last, uint32_t length, const char *type,
                             Pool &pool) {
    fk_serial_number_t sn;
    auto headers = pool.sprintf("Authorization: Bearer %s\r\n"
                                "Content-Type: application/vnd.fk.data+binary\r\n"
                                "Content-Length: %" PRIu32 "\r\n"
                                "Fk-DeviceID: %s\r\n"
                                "Fk-Generation: %s\r\n"
                                "Fk-DeviceName: %s\r\n"
                                "Fk-Blocks: %" PRIu32 ",%" PRIu32 "\r\n"
                                "Fk-Type: %s\r\n",
                                connection->token, length, bytes_to_hex_string_pool((uint8_t *)&sn, sizeof(sn), pool),
                                connection->generation, connection->name, first, last, type);

    return {
        connection,
        headers,
    };
}

UploadDataWorker::FileUpload UploadDataWorker::upload_file(ConnectionInfo connection_info, Storage &storage, uint8_t file_number,
                                                           uint32_t first_record, const char *type, Pool &pool) {
    ScopedLogLevelChange change{ LogLevels::INFO };

    auto started = fk_uptime();
    auto file = storage.file_reader(file_number, pool);

    PoolBufferAllocator buffers{ &pool };
    CopyIntoBuffers copier{ &buffers };
    loginfo("reading modules-meta record");
    if (file->read_signed_record_bytes(SignedRecordKind::Modules, &copier, pool) < 0) {
        logerror("get-size");
        return { 0 };
    }

    auto meta = copier.head();
    auto meta_size = meta->length();

    auto first_block = first_record;
    loginfo("reading size since %" PRIu32, first_block);
    auto size_info = file->get_size(first_block, UINT32_MAX, pool);
    if (!size_info) { // TODO
        logerror("get-size");
        return { 0 };
    }

    auto upload_length = size_info->size;
    auto last_block = size_info->last_block;
    if (upload_length == 0) {
        return { 0 };
    }

    auto request_info = get_request_info(&connection_info, first_block, last_block, meta_size + upload_length, type, pool);

    loginfo("uploading %" PRIu32 " -> %" PRIu32 " %" PRIu32 " bytes (%" PRIu32 " bytes meta)", first_block, last_block,
            meta_size + upload_length, meta_size);

    auto guard = wifi_mutex.acquire(UINT32_MAX);

    auto http = open_http_connection("POST", request_info.connection->url, request_info.headers, false, pool);
    if (http == nullptr) {
        logwarn("unable to open connection");
        return { 0 };
    }

    loginfo("status-code: %d", http->status_code());
    if (http->status_code() > 0 && http->status_code() != 200) {
        logwarn("unexpected status");
        return { 0 };
    }

    if (meta != nullptr) {
        loginfo("uploading %d meta...", meta_size);
        auto bytes_wrote = http->write_buffers(meta);
        if ((int32_t)meta_size != bytes_wrote) {
            logerror("write error (%" PRId32 " != %" PRId32 ")", bytes_wrote, meta_size);
        }
    }

    loginfo("uploading file...");

    auto buffer = (uint8_t *)pool.malloc(NetworkBufferSize);
    auto bytes_copied = 0u;
    GlobalStateProgressCallbacks gs_progress;
    auto tracker = ProgressTracker{ &gs_progress, Operation::Upload, "upload", "", upload_length };
    while (bytes_copied != upload_length) {
        auto to_read = std::min<int32_t>(NetworkBufferSize, upload_length - bytes_copied);
        auto bytes_read = file->read(buffer, to_read);
        if (bytes_read != to_read) {
            logwarn("read error (%" PRId32 " != %" PRId32 ")", bytes_read, to_read);
            break;
        }

        auto bytes_wrote = http->write(buffer, to_read);
        if (bytes_wrote != (int32_t)to_read) {
            logwarn("write error (%" PRId32 " != %" PRId32 ")", bytes_wrote, to_read);
            break;
        }

        tracker.update(bytes_read);

        bytes_copied += bytes_read;

#if defined(FK_WDT_ENABLE)
        fk_wdt_feed();
#endif
    }

    auto elapsed = fk_uptime() - started;
    auto speed = ((bytes_copied / 1024.0f) / (elapsed / 1000.0f));
    loginfo("done (%d) (%" PRIu32 "ms) %.2fkbps, waiting response", bytes_copied, elapsed, speed);

    auto success = false;

    if (!http->read_response()) {
        logerror("unable to read response");
    } else {
        loginfo("http status %" PRId32, http->status_code());
        if (http->status_code() == 200 || http->status_code() == 204) {
            success = true;
        }
    }

    http->close();

    if (success) {
        return { last_block };
    }

    return { 0 };
}

struct FileRecords {
    uint32_t meta;
    uint32_t data;
};

static FileRecords get_start_records() {
    auto gs = get_global_state_ro();
    return {
        gs.get()->transmission.meta_cursor,
        gs.get()->transmission.data_cursor,
    };
}

static void update_after_upload(FileRecords start_records) {
    auto gs = get_global_state_rw();

    gs.get()->transmission.meta_cursor = start_records.meta;
    gs.get()->transmission.data_cursor = start_records.data;
}

static bool has_network_configured() {
    auto gs = get_global_state_ro();

    return strlen(gs.get()->network.config.wifi_networks[0].ssid) > 0 || strlen(gs.get()->network.config.wifi_networks[1].ssid) > 0;
}

void UploadDataWorker::run(Pool &pool) {
    auto disable_network = false;

    // If we don't have any configured networks, don't even bother trying.
    if (!has_network_configured()) {
        logwarn("no networks");
        return;
    }

    auto connection_info = get_connection_info(pool);
    if (!connection_info.is_configured()) {
        loginfo("no configuration");
        return;
    }

    if (!get_network()->online()) {
        WifiToggleWorker enable(WifiToggleWorker::DesiredState::ExternalAp);
        enable.run(pool);

        if (!get_network()->online()) {
            logwarn("not online");
            return;
        }

        disable_network = true;
    }

    if (!get_network()->get_created_ap()) {
        auto lock = storage_mutex.acquire(UINT32_MAX);

        auto start_records = get_start_records();
        if (all_data_) {
            start_records.data = 0;
        }

        StatisticsMemory memory{ MemoryFactory::get_data_memory() };
        Storage storage{ &memory, pool };

        if (storage.begin()) {
            auto after = start_records;

            auto data_upload = upload_file(connection_info, storage, Storage::Data, start_records.data, "data", pool);
            if (data_upload) {
                after.data = data_upload.record;
            }

            update_after_upload(after);
        }
    }

    if (disable_network) {
        WifiToggleWorker enable(WifiToggleWorker::DesiredState::Disabled);
        enable.run(pool);
    }
}

} // namespace fk
