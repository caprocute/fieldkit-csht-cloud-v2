#include <algorithm>
#include <phylum.h>

#include "storage/storage.h"

#include "platform.h"
#include "hal/random.h"
#include "progress_tracker.h"
#include "utilities.h"

#include "storage/file_ops_phylum.h"

namespace fk {

FK_DECLARE_LOGGER("storage");

Storage::Storage(DataMemory *memory, Pool &pool, bool read_only)
    : data_memory_(memory), pool_(&pool), memory_(memory, pool),
      statistics_data_memory_(data_memory_), phylum_{ &statistics_data_memory_, pool }, read_only_(read_only) {
    FK_ASSERT(memory != nullptr);
}

Storage::~Storage() {
    if (!memory_.flush()) {
        logerror("flush failed");
    }
}

bool Storage::begin() {
    if (!data_memory_->available()) {
        return false;
    }

    if (phylum_.mount()) {
        data_ops_ = new (pool_) phylum_ops::DataOps(*this);
        meta_ops_ = new (pool_) phylum_ops::MetaOps(*this);
        bytes_used_ = phylum_.bytes_used();
        loginfo("storage-begin: phylum");
        return true;
    }

    loginfo("storage-begin: nothing");
    return false;
}

bool Storage::clear() {
    loginfo("storage: clearing");

    for (auto block = 0u; block < data_memory_->geometry().nblocks; ++block) {
        auto block_size = data_memory_->geometry().block_size;
        auto address = block * block_size;
        if (data_memory_->erase(address, block_size) < 0) {
            logerror("erasing block=%" PRIu32, block);
        }
    }

    loginfo("storage: formatting phylum-fs");

    if (!phylum_.format()) {
        logerror("format");
        return false;
    }

    auto data_ops = new (pool_) phylum_ops::DataOps(*this);

    if (!data_ops->touch(*pool_)) {
        logerror("touch");
        return false;
    }

    if (!phylum_.sync()) {
        logerror("sync");
        return false;
    }

    loginfo("storage: cleared");

    data_ops_ = data_ops;
    meta_ops_ = new (pool_) phylum_ops::MetaOps(*this);

    return true;
}

DataOps *Storage::data_ops() {
    FK_ASSERT(data_ops_ != nullptr);
    return data_ops_;
}

MetaOps *Storage::meta_ops() {
    FK_ASSERT(meta_ops_ != nullptr);
    return meta_ops_;
}

uint32_t Storage::installed() {
    return data_memory_->geometry().total_size;
}

uint32_t Storage::used() {
    return bytes_used_;
}

FileReader *Storage::file_reader(FileNumber file_number, Pool &pool) {
    return new (pool) phylum_ops::FileReader{ *this, Storage::Data, pool };
}

bool Storage::flush() {
    if (!phylum_.sync()) {
        return false;
    }

    statistics_data_memory_.log_statistics("flash usage: ");

    return true;
}

} // namespace fk
