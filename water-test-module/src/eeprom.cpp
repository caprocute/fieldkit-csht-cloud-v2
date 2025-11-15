#include <Wire.h>

#include "eeprom.h"
#include "two_wire.h"

static bool read_page(uint16_t address, uint8_t *data, size_t size) {
  // FK_ASSERT(size <= ModuleEeprom::EepromPageSize);
  // FK_ASSERT(address + size <= ModuleEeprom::EepromSize);

  uint8_t buffer[sizeof(uint16_t)];
  buffer[0] = (address >> 8) & 0xff;
  buffer[1] = (address) & 0xff;

  if (!I2C_CHECK(
          wire_write(ModuleEeprom::EepromAddress, buffer, sizeof(buffer)))) {
    // logwarn("i2c write failed");
    return false;
  }

  if (!I2C_CHECK(wire_read(ModuleEeprom::EepromAddress, data, size))) {
    // logwarn("i2c read failed");
    return false;
  }

  return true;
}

static bool eeprom_read(uint16_t address, uint8_t *data, uint32_t size) {
  uint8_t *ptr = data;
  uint32_t remaining = size;

  while (remaining > 0) {
    uint32_t to_read = std::min((uint32_t)EEPROM_PAGE_SIZE, remaining);
    if (!read_page(address, ptr, to_read)) {
      return false;
    }

    ptr += to_read;
    remaining -= to_read;
    address += to_read;
  }

  return true;
}

bool ModuleEeprom::is_available() {
  Wire.beginTransmission(ModuleEeprom::EepromAddress);
  return Wire.endTransmission() == 0;
}

bool ModuleEeprom::read_header() {
  uint32_t header = 0;

  if (!eeprom_read(HeaderAddress, (uint8_t *)&header, sizeof(header))) {
    return false;
  }

  return false;
}
