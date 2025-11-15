#include <tiny_printf.h>

#include "dump_flash_memory_worker.h"

#include "hal/hal.h"
#include "hal/memory.h"
#include "utilities.h"
#include "state_manager.h"

namespace fk {

FK_DECLARE_LOGGER("dumpmem");

constexpr size_t MaximumBadBlockRun = 10;

void DumpFlashMemoryWorker::run(Pool &pool) {
    auto lock = storage_mutex.acquire(UINT32_MAX);

    FormattedTime formatted{ get_clock_now(), TimeFormatMachine };
    auto path = pool.sprintf("/%s/%08x.bin", formatted.cstr(), 0);

    auto sd = get_sd_card();
    if (!sd->begin()) {
        logerror("error opening sd card");
        return;
    }

    if (!sd->mkdir(formatted.cstr())) {
        logerror("error making directory '%s'", formatted.cstr());
        return;
    }

    auto file = sd->open(path, OpenFlags::Write, pool);
    if (file == nullptr || !file) {
        logerror("unable to open '%s'", path);
        return;
    }

    dump_phylum_storage(file, pool);

    if (!file->close()) {
        logerror("error closing");
        return;
    }

    GlobalStateManager gsm;
    gsm.notify(FK_MENU_DUMP_FLASH_FLASH_COPIED);
}

void DumpFlashMemoryWorker::dump_phylum_storage(SdCardFile *file, Pool &pool) {
    auto flash_memory = MemoryFactory::get_data_memory();
    if (!flash_memory->begin()) {
        logerror("error opening flash memory");
        return;
    }

    auto sector_size = flash_memory->geometry().real_page_size;
    standard_page_buffer_memory buffer_memory{ &pool };
    phylum::working_buffers buffers{ &buffer_memory, sector_size, 8 };
    phylum::noop_page_cache page_cache;
    PhylumFlashMemory memory(flash_memory, &buffers);
    phylum::dhara_sector_map sectors{ buffers, memory, &page_cache };

    if (sectors.begin(false) < 0) {
        logerror("error initializing sector map");
        return;
    }

    auto buffer = (uint8_t *)pool.malloc(sector_size);
    auto nsectors = sectors.size();

    for (auto sector = 0u; sector < nsectors; ++sector) {
        auto err = sectors.read(sector, buffer, sector_size);
        if (err < 0) {
            logerror("error reading sector %d (%d)", sector, err);
        } else {
            memset(buffer, 0xff, sector_size);
        }

        if (file->write(buffer, sector_size) == 0) {
            logerror("error writing to file");
            return;
        }
    }

    loginfo("done writing %d sectors (%d bytes)", nsectors, nsectors * sector_size);
}

} // namespace fk
