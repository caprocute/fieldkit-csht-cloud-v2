#include "storage/events.h"
#include "storage/storage.h"
#include "hal/hal.h"
#include "records.h"
#include "state.h"
#include "state_manager.h"

extern fkb_header_t fkb_header;

namespace fk {

FK_DECLARE_LOGGER("events");

#define EVENT_LORA_JOINED_OK      1
#define EVENT_LORA_JOINED_FAIL    2
#define EVENT_LORA_CONFIRMED_SEND 3

RestartEvent::RestartEvent(enum fk_reset_reason reason) {
    auto now = get_clock_now();
    event_ = fk_data_Event_init_default;
    event_.system = system();
    event_.severity = fk_data_Severity_SEVERITY_WARNING;
    event_.code = reason;
    event_.time = now;
}

LoraEvent::LoraEvent(uint32_t code) {
    auto now = get_clock_now();
    event_ = fk_data_Event_init_default;
    event_.system = system();
    event_.severity = fk_data_Severity_SEVERITY_INFO;
    event_.code = code;
    event_.time = now;
    event_.details.data.arg = nullptr;
    event_.debug.arg = nullptr;
}

LoraEvent LoraEvent::joined() {
    return LoraEvent{ EVENT_LORA_JOINED_OK };
}

LoraEvent LoraEvent::failed_join() {
    return LoraEvent{ EVENT_LORA_JOINED_FAIL };
}

LoraEvent LoraEvent::confirmed() {
    return LoraEvent{ EVENT_LORA_CONFIRMED_SEND };
}

#define EVENT_WIFI_STARTED_EXTERNAL  1

WifiEvent::WifiEvent(uint32_t code) {
    auto now = get_clock_now();
    event_ = fk_data_Event_init_default;
    event_.system = system();
    event_.severity = fk_data_Severity_SEVERITY_INFO;
    event_.code = code;
    event_.time = now;
    event_.details.data.arg = nullptr;
    event_.debug.arg = nullptr;
}

WifiEvent WifiEvent::external() {
    return WifiEvent{ EVENT_WIFI_STARTED_EXTERNAL };
}

Events::Events(Storage *storage) : storage_(storage) {
}

pb_array_t *filter_events_array(pb_array_t *array, fk_data_EventSystem system, Pool &pool) {
    auto filtered = fk_array_new_protobuf<fk_data_Event>(fk_data_Event_fields, &pool);
    if (array != nullptr) {
        for (auto i = 0u; i < array->length; ++i) {
            auto item = array->item<fk_data_Event>(i);
            if (item->system != system) {
                fk_prepare_events_record_encode(item, &pool);
                pb_append_array(filtered, item);
            }
        }
    }
    return filtered;
}

bool Events::append(EventRecord *event, GlobalState *gs, fkb_header_t const *fkb_header, Pool &pool) {
    MetaRecord existing{ pool };
    auto meta_ops = storage_->meta_ops();
    pb_array_t *events = NULL;
    if (!meta_ops->read_record(SignedRecordKind::Events, existing, pool)) {
        logwarn("no events record");
        events = fk_array_new_protobuf<fk_data_Event>(fk_data_Event_fields, &pool);
    } else {
        auto system = event->system();
        auto old_events = pb_get_array(existing.record()->events, &pool);
        events = filter_events_array(old_events, system, pool);
    }

    pb_append_array(events, event->record());

    MetaRecord appending{ pool };
    appending.include_metadata(gs, fkb_header, pool);
    pb_set_array_encode(appending.record()->events, events);
    if (!meta_ops->write_record(SignedRecordKind::Events, appending.record(), pool)) {
        return false;
    }

    SerializedRecordReader reader{ fk_data_DataRecord_fields, appending.record(), pool };
    BufferChain *destination = gs->dynamic.events();
    destination->clear();
    CopyIntoBuffers copier{ destination };
    if (copy_between(&reader, &copier, pool) < 0) {
        logwarn("events copy failed");
        return false;
    }
    // TODO Would be nice if this got handled for us.
    destination->head(copier.head());
    loginfo("new events %d", destination->head()->position());

    return true;
}

bool Events::read(MetaRecord &record, Pool &pool) {
    if (!storage_->meta_ops()->read_record(SignedRecordKind::Events, record, pool)) {
        return false;
    }

    return true;
}

bool Events::copy(BufferChain *chain, Pool &pool) {
    CopyIntoBuffers copier{ chain };
    auto reader = storage_->file_reader(Storage::Data, pool);
    if (reader->read_signed_record_bytes(SignedRecordKind::Events, &copier, pool) < 0) {
        return false;
    }

    // TODO Would be nice if this got handled for us.
    chain->head(copier.head());

    return true;
}

bool Events::flush() {
    return storage_->flush();
}

void EventWorker::run(Pool &pool) {
    auto lock = storage_mutex.acquire(UINT32_MAX);
    auto data_memory = MemoryFactory::get_data_memory();
    StatisticsMemory memory{ data_memory };
    Storage storage{ &memory, pool };
    if (!storage.begin()) {
        logerror("error opening storage");
        return;
    }

    run(storage, pool);
}

bool LoadEventsWorker::run(Storage &storage, Pool &pool) {
    auto gs = get_global_state_rw();
    return run(storage, gs.get(), pool);
}

bool LoadEventsWorker::run(Storage &storage, GlobalState *gs, Pool &pool) {
    BufferChain *destination = gs->dynamic.events();
    destination->clear();
    Events events{ &storage };
    if (!events.copy(destination, pool)) {
        return false;
    }

    return true;
}

AppendEventWorker::AppendEventWorker(EventRecord *event) : event_(event) {
}

bool AppendEventWorker::run(Storage &storage, Pool &pool) {
    // This makes testing way easier and honestly, so far having the phylum logs
    // be verbose hasn't been necessary. I'd love a way to keep DEBUG and only
    // flush on certain conditions.
    ScopedLogLevelChange temporary_info_only{ LogLevels::INFO };

    // Ugly, release read only lock before the last call.
    auto gs = get_global_state_rw();
    Events events{ &storage };
    if (!events.append(event_, gs.get(), &fkb_header, pool)) {
        return false;
    }

    if (!events.flush()) {
        return false;
    }

    return true;
}

} // namespace fk
