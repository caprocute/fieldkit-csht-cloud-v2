#include "modules/bridge/modules_bridge.h"

#include "records.h"
#include "utilities.h"

namespace fk {

std::pair<BufferPtr *, fk_data_ModuleConfiguration *> Module::read_configuration_eeprom(ModuleEeprom &eeprom, Pool *pool) {
    size_t size = 0;
    uint8_t *buffer = nullptr;
    if (eeprom.read_configuration(&buffer, size, pool)) {
        if (size > 0) {
            log_bytes("mod-cfg", buffer, size);

            auto stream = pb_istream_from_buffer(buffer, size);
            auto cfg = fk_module_configuration_decoding_new(pool);
            if (!pb_decode_delimited(&stream, fk_data_ModuleConfiguration_fields, cfg)) {
                alogf(LogLevels::WARN, "mod-cfg", "decode error");
            } else {
                return { pool->wrap(buffer, size, size), cfg };
            }
        }
    }

    return { nullptr, nullptr };
}

ModuleEepromContents Module::read_eeprom(ModuleContext mc, Pool &pool) {
    UnknownEeprom unknown{ mc.module_bus() };
    auto eeprom = unknown.find();
    if (!eeprom) {
        return ModuleEepromContents{};
    }

    // We need the header to know the kind of module we are so if that
    // fails then we're in pretty bad shape.
    ModuleEepromContents contents;
    bzero(&contents.header, sizeof(ModuleHeader));
    if (!eeprom->read_header(contents.header)) {
        alogf(LogLevels::WARN, "mod-cfg", "error reading header");
        return ModuleEepromContents{};
    }

    if (!fk_module_header_valid(&contents.header)) {
        alogf(LogLevels::WARN, "mod-cfg", "invalid header");
        return contents;
    }

    alogf(LogLevels::INFO, "mod-cfg", "have header: mk=%02" PRIx32 "%02" PRIx32, contents.header.manufacturer, contents.header.kind);

    contents.config = read_configuration_eeprom(*eeprom, &pool);

    return contents;
}

} // namespace fk
