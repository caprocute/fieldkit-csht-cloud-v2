#pragma once

#include <loading.h>
#include <fk-data-protocol.h>
#include <samd51_common.h>

#include "io.h"
#include "pool.h"
#include "meta_record.h"
#include "worker.h"

namespace fk {

class Storage;
class GlobalState;

class EventRecord {
public:
    virtual fk_data_EventSystem system() = 0;
    virtual fk_data_Event *record() = 0;
};

class RestartEvent : public EventRecord {
private:
    fk_data_Event event_;

public:
    RestartEvent(enum fk_reset_reason reason);

public:
    fk_data_EventSystem system() override {
        return fk_data_EventSystem_EVENT_SYSTEM_RESTART;
    }

    fk_data_Event *record() override {
        return &event_;
    };
};

class LoraEvent : public EventRecord {
private:
    fk_data_Event event_;

private:
    LoraEvent(uint32_t code);

public:
    static LoraEvent joined();
    static LoraEvent failed_join();
    static LoraEvent confirmed();

public:
    fk_data_EventSystem system() override {
        return fk_data_EventSystem_EVENT_SYSTEM_LORA;
    }

    fk_data_Event *record() override {
        return &event_;
    };
};

class WifiEvent: public EventRecord {
private:
    fk_data_Event event_;

public:
    WifiEvent(uint32_t code);

public:
    static WifiEvent external();

public:
    fk_data_EventSystem system() override {
        return fk_data_EventSystem_EVENT_SYSTEM_WIFI;
    }

    fk_data_Event *record() override {
        return &event_;
    };
};

class Events {
private:
    Storage *storage_{ nullptr };

public:
    Events(Storage *storage);

public:
    bool append(EventRecord *record, GlobalState *gs, fkb_header_t const *fkb_header, Pool &pool);
    bool read(MetaRecord &record, Pool &pool);
    bool copy(BufferChain *chain, Pool &pool);
    bool flush();
};

class EventWorker : public Worker {
public:
    void run(Pool &pool) override;

    virtual bool run(Storage &storage, Pool &pool) = 0;
};

class LoadEventsWorker : public EventWorker {
public:
    using EventWorker::run;

    bool run(Storage &storage, Pool &pool) override;

    bool run(Storage &storage, GlobalState *gs, Pool &pool);

    const char *name() const override {
        return "events";
    }
};

class AppendEventWorker : public LoadEventsWorker {
private:
    EventRecord *event_{ nullptr };

public:
    AppendEventWorker(EventRecord *event);

public:
    using EventWorker::run;

    bool run(Storage &storage, Pool &pool) override;

    const char *name() const override {
        return "event";
    }
};

} // namespace fk
