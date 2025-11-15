#pragma once

#include "common.h"
#include "hal/memory.h"
#include "progress.h"
#include "progress_tracker.h"
#include "storage/storage.h"
#include "storage/sequential_memory.h"
#include "storage/statistics_memory.h"
#include "storage/file_ops.h"
#include "storage/phylum.h"

namespace fk {

/**
 * Format specifier for addresses.
 */
#define PRADDRESS "0x%08" PRIx32

class Storage {
public:
    constexpr static FileNumber Data = 0;
    constexpr static FileNumber Meta = 1;

    friend class File;

private:
    DataMemory *data_memory_;
    Pool *pool_;
    SequentialWrapper<BufferedPageMemory> memory_;
    StatisticsMemory statistics_data_memory_;
    Phylum phylum_;
    bool read_only_;
    MetaOps *meta_ops_{ nullptr };
    DataOps *data_ops_{ nullptr };
    int32_t bytes_used_{ 0 };

public:
    Storage(DataMemory *memory, Pool &pool, bool read_only = true);
    virtual ~Storage();

public:
    Phylum &phylum() {
        return phylum_;
    }

    DataOps *data_ops();

    MetaOps *meta_ops();

    FileReader *file_reader(FileNumber file_number, Pool &pool);

    uint32_t installed();

    uint32_t used();

public:
    bool begin();
    bool clear();
    bool flush();

public:
    FlashGeometry geometry() const {
        return memory_.geometry();
    }
};

} // namespace fk
