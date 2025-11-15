#pragma once

#include <pb_decode.h>

#include "modules/shared/modules.h"
#include "hal/board.h"
#include "pool.h"

namespace fk {

enum ChipKind : uint8_t { OneByteAddress, TwoByteAddress };

class ModuleEeprom {
public:
    constexpr static uint8_t EepromAddress = EEPROM_I2C_ADDRESS;
    constexpr static uint16_t HeaderAddress = EEPROM_ADDRESS_HEADER;
    constexpr static uint16_t ConfigurationAddress = EEPROM_ADDRESS_CONFIG;

private:
    TwoWireWrapper *wire_;
    ChipKind kind_;
    size_t stream_position_{ 0 };

public:
    explicit ModuleEeprom(TwoWireWrapper &wire, ChipKind kind);

public:
    bool read_header(ModuleHeader &header);
    bool write_header(ModuleHeader &header);
    bool read_configuration(uint8_t **buffer, size_t &size, Pool *pool);
    bool read_configuration(void *record, pb_msgdesc_t const *fields);
    bool write_configuration(uint8_t const *buffer, size_t size);
    bool erase_configuration(size_t size);
    bool erase_all();

public:
    bool read_stream(void *data, size_t size);
    bool read_data(uint32_t address, void *data, size_t size);
    bool read_data_delimited(uint32_t address, uint8_t **buffer, size_t &bytes_read, Pool *pool);
    bool erase_page(uint32_t address);
};

class UnknownEeprom {
private:
    TwoWireWrapper *wire_;

public:
    explicit UnknownEeprom(TwoWireWrapper &wire);

public:
    optional<ModuleEeprom> find();
};

} // namespace fk
