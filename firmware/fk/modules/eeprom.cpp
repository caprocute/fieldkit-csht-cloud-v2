#include "eeprom.h"
#include "common.h"
#include "hal/board.h"
#include "modules/shared/modules.h"
#include "platform.h"
#include "protobuf.h"

namespace fk {

FK_DECLARE_LOGGER("mod-ee");

/**
 * Return the smaller of two values.
 */
#define MIN(a, b) ((a > b) ? (b) : (a))

#define EEPROM_PAGE_SIZE_SMALL (16)

#define EEPROM_PAGE_SIZE_LARGE (32)

enum TwoWireTransactionStatus { TxOk, TxWriteError, TxReadError, TxNotReady };

class Eeprom {
private:
    TwoWireWrapper *wire_;
    ChipKind kind_;

public:
    Eeprom(TwoWireWrapper *wire, ChipKind kind) : wire_(wire), kind_(kind) {
    }

public:
    size_t page_size() {
        return kind_ == ChipKind::OneByteAddress ? EEPROM_PAGE_SIZE_SMALL : EEPROM_PAGE_SIZE_LARGE;
    }

    TwoWireTransactionStatus read_page(uint16_t address, uint8_t *data, size_t size) {
        // FK_ASSERT(size <= ModuleEeprom::EepromPageSize);
        // FK_ASSERT(address + size <= ModuleEeprom::EepromSize);

        uint8_t buffer[sizeof(uint16_t)];
        size_t buffer_size;
        if (kind_ == ChipKind::OneByteAddress) {
            buffer[0] = (address) & 0xff;
            buffer_size = sizeof(uint8_t);
        } else {
            buffer[0] = (address >> 8) & 0xff;
            buffer[1] = (address) & 0xff;
            buffer_size = sizeof(uint16_t);
        }

        if (!I2C_CHECK(wire_->write(ModuleEeprom::EepromAddress, buffer, buffer_size))) {
            return TwoWireTransactionStatus::TxWriteError;
        }

        if (!I2C_CHECK(wire_->read(ModuleEeprom::EepromAddress, data, size))) {
            return TwoWireTransactionStatus::TxReadError;
        }

        return TwoWireTransactionStatus::TxOk;
    }

    TwoWireTransactionStatus write_page(uint16_t address, uint8_t *data, size_t size) {
        // FK_ASSERT(size <= ModuleEeprom::EepromPageSize);
        // FK_ASSERT(address + size <= ModuleEeprom::EepromSize);

        // TODO This could be done better.
        uint8_t buffer[sizeof(uint16_t) + size];
        size_t buffer_size;
        if (kind_ == ChipKind::OneByteAddress) {
            buffer[0] = (address) & 0xff;
            buffer_size = sizeof(uint8_t) + size;
            memcpy(buffer + sizeof(uint8_t), data, size);
        } else {
            buffer[0] = (address >> 8) & 0xff;
            buffer[1] = (address) & 0xff;
            buffer_size = sizeof(uint16_t) + size;
            memcpy(buffer + sizeof(uint16_t), data, size);
        }

        if (!I2C_CHECK(wire_->write(ModuleEeprom::EepromAddress, buffer, buffer_size))) {
            return TwoWireTransactionStatus::TxWriteError;
        }

        return wait_ready();
    }

    TwoWireTransactionStatus wait_ready() {
        auto to = EEPROM_TIMEOUT_WRITE;
        while (to > 0) {
            if (I2C_CHECK(wire_->read(ModuleEeprom::EepromAddress, nullptr, 0))) {
                return TwoWireTransactionStatus::TxOk;
            }

            fk_delay(1);
            to--;
        }

        return TwoWireTransactionStatus::TxNotReady;
    }

    bool write(uint16_t address, uint8_t *data, size_t size) {
        uint8_t *ptr = data;
        size_t remaining = size;

        while (remaining > 0) {
            size_t to_write = MIN(page_size(), remaining);
            if (write_page(address, ptr, to_write) != TxOk) {
                return false;
            }

            ptr += to_write;
            remaining -= to_write;
            address += to_write;
        }

        return true;
    }

    bool read(uint16_t address, uint8_t *data, size_t size) {
        uint8_t *ptr = data;
        size_t remaining = size;

        while (remaining > 0) {
            size_t to_read = MIN(page_size(), remaining);
            if (read_page(address, ptr, to_read) != TxOk) {
                return false;
            }

            ptr += to_read;
            remaining -= to_read;
            address += to_read;
        }

        return true;
    }
};

ModuleEeprom::ModuleEeprom(TwoWireWrapper &wire, ChipKind kind) : wire_(&wire), kind_(kind) {
}

bool ModuleEeprom::read_header(ModuleHeader &header) {
    Eeprom eeprom{ wire_, kind_ };

    if (!eeprom.read(HeaderAddress, (uint8_t *)&header, sizeof(ModuleHeader))) {
        return false;
    }

    return true;
}

bool ModuleEeprom::write_header(ModuleHeader &header) {
    header.crc = fk_module_header_sign(&header);

    Eeprom eeprom{ wire_, kind_ };

    if (!eeprom.write(HeaderAddress, (uint8_t *)&header, sizeof(ModuleHeader))) {
        logerror("error writing header");
        return false;
    }

    return true;
}

bool ModuleEeprom::read_configuration(uint8_t **buffer, size_t &size, Pool *pool) {
    if (!read_data_delimited(ConfigurationAddress, buffer, size, pool)) {
        return false;
    }

    loginfo("configuration size=%zd", size);

    return true;
}

static bool read_callback(pb_istream_t *stream, uint8_t *buf, size_t c) {
    return reinterpret_cast<ModuleEeprom *>(stream->state)->read_stream(buf, c);
}

pb_istream_t pb_istream_from_eeprom(ModuleEeprom *eeprom) {
    return { &read_callback, (void *)eeprom, UINT32_MAX, 0 };
}

bool ModuleEeprom::read_configuration(void *record, pb_msgdesc_t const *fields) {
    stream_position_ = ConfigurationAddress;
    pb_istream_t istream = pb_istream_from_eeprom(this);
    if (!pb_decode_delimited(&istream, fields, record)) {
        return 0;
    }

    return true;
}

bool ModuleEeprom::write_configuration(uint8_t const *buffer, size_t size) {
    Eeprom eeprom{ wire_, kind_ };

    if (!eeprom.write(ConfigurationAddress, (uint8_t *)buffer, size)) {
        return false;
    }

    return true;
}

bool ModuleEeprom::erase_configuration(size_t size) {
    Eeprom eeprom{ wire_, kind_ };

    auto address = ConfigurationAddress;
    auto remaining = size;
    auto page_size = eeprom.page_size();

    while (remaining > 0) {
        if (!erase_page(address)) {
            return false;
        }

        if (remaining < page_size) {
            break;
        }

        remaining -= page_size;
        address += page_size;
    }

    loginfo("configuration erased");

    return true;
}

bool ModuleEeprom::read_stream(void *data, size_t size) {
    Eeprom eeprom{ wire_, kind_ };
    if (!eeprom.read(stream_position_, (uint8_t *)data, size)) {
        return false;
    }

    stream_position_ += size;

    return true;
}

bool ModuleEeprom::read_data(uint32_t address, void *data, size_t size) {
    Eeprom eeprom{ wire_, kind_ };
    if (!eeprom.read(address, (uint8_t *)data, size)) {
        return false;
    }

    return true;
}

bool ModuleEeprom::erase_all() {
    Eeprom eeprom{ wire_, kind_ };
    auto page_size = eeprom.page_size();
    for (auto address = 0u; address < page_size; address += page_size) {
        if (!erase_page(address)) {
            logerror("error erasing (0x%0" PRIx32 ")", (uint32_t)address);
            return false;
        }
    }

    return true;
}

bool ModuleEeprom::erase_page(uint32_t address) {
    Eeprom eeprom{ wire_, kind_ };
    uint8_t page[eeprom.page_size()];
    memset(page, 0xff, sizeof(page));
    if (!eeprom.write(address, (uint8_t *)page, sizeof(page))) {
        logerror("error erasing (0x%0" PRIx32 ")", (uint32_t)address);
        return false;
    }
    return true;
}

bool ModuleEeprom::read_data_delimited(uint32_t address, uint8_t **buffer, size_t &bytes_read, Pool *pool) {
    Eeprom eeprom{ wire_, kind_ };

    *buffer = nullptr;
    bytes_read = 0;

    pb_byte_t size_bytes_and_some[8];
    if (eeprom.read_page(address, size_bytes_and_some, sizeof(size_bytes_and_some)) != TxOk) {
        return false;
    }

    uint32_t encoded_size = 0u;
    auto stream = pb_istream_from_buffer((pb_byte_t *)size_bytes_and_some, sizeof(size_bytes_and_some));
    if (!::pb_decode_varint32(&stream, &encoded_size)) {
        return true;
    }

    auto buffer_size = pb_varint_size(encoded_size) + encoded_size;
    loginfo("eeprom: allocating %" PRIu32 " bytes", buffer_size);

    auto ptr = (uint8_t *)pool->malloc(buffer_size);
    auto remaining = buffer_size;
    auto start = ptr;

    memzero(ptr, buffer_size);

    while (remaining > 0) {
        size_t to_read = MIN(eeprom.page_size(), remaining);
        if (eeprom.read_page(address, ptr, to_read) != TxOk) {
            return false;
        }

        ptr += to_read;
        remaining -= to_read;
        address += to_read;
    }

    *buffer = start;
    bytes_read = buffer_size;

    return true;
}

UnknownEeprom::UnknownEeprom(TwoWireWrapper &wire) : wire_(&wire) {
}

optional<ModuleEeprom> UnknownEeprom::find() {
    // NOTE: On modules that use 1-byte addresses this will write 1 to 0xff,
    // 2-byte modules will see this as a read from byte 0x100.
    uint8_t test_byte[1];
    uint16_t test_address = 0xff + 0x1; // 0x100
    Eeprom two_byte{ wire_, ChipKind::TwoByteAddress };
    switch (two_byte.read_page(test_address, test_byte, sizeof(test_byte))) {
    case TxReadError: {
        // Our read was a write, so let's wait until that's done.
        two_byte.wait_ready();
        loginfo("eeprom: 1-byte address found");
        return ModuleEeprom{ *wire_, OneByteAddress };
    }
    case TxOk: {
        loginfo("eeprom: 2-byte address found");
        return ModuleEeprom{ *wire_, TwoByteAddress };
    }
    case TxWriteError: {
        loginfo("eeprom: not found");
        return nullopt;
    }
    case TxNotReady: {
        logerror("eeprom: unexpected not-ready");
        FK_ASSERT(false); // This should never happen.
        return nullopt;
    }
    }

    FK_ASSERT(false); // All cases should be handled.
    return nullopt;
}

} // namespace fk
