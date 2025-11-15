#include <fk-data-protocol.h>

#include "tests.h"
#include "utilities.h"
#include "protobuf.h"
#include "platform.h"

namespace fk {

FK_DECLARE_LOGGER("tests");

fkb_header_t fake_header = { .signature = { 'F', 'K', 'B', 0 },
                             .version = 1,
                             .size = sizeof(fkb_header_t),
                             .firmware = { .flags = 0,
                                           .timestamp = 1580763366,
                                           .number = 1000,
                                           .reserved = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff },
                                           .safe = 0xff,
                                           .previous = UINT32_MAX,
                                           .binary_size = 65536,
                                           .tables_offset = 8192,
                                           .data_size = 8192,
                                           .bss_size = 8192,
                                           .got_size = 8192,
                                           .vtor_offset = 8192,
                                           .got_offset = 32768,
                                           .version = { 0x0 },
                                           .hash_size = 32,
                                           .hash = { 0xB2 } },
                             .number_symbols = 100,
                             .number_relocations = 100 };

fkb_header_t const *get_fake_header() {
    fake_string(fake_header.firmware.version);
    fake_string(fake_header.firmware.hash);
    return &fake_header;
}

} // namespace fk
