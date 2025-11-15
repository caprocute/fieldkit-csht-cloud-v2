#include <Wire.h>

#include "eeprom.h"
#include "two_wire.h"

static bool read_page(uint8_t i2c_address, uint16_t address, uint8_t *data,
                      size_t size) {
  uint8_t buffer[sizeof(uint16_t)];
  buffer[0] = (address >> 8) & 0xff;
  buffer[1] = (address) & 0xff;

  if (!I2C_CHECK(wire_write(i2c_address, buffer, sizeof(buffer)))) {
    return false;
  }

  if (!I2C_CHECK(wire_read(i2c_address, data, size))) {
    return false;
  }

  return true;
}

static bool eeprom_read(uint8_t i2c_address, uint16_t address, uint8_t *data,
                        uint32_t size) {
  uint8_t *ptr = data;
  uint32_t remaining = size;

  while (remaining > 0) {
    uint32_t to_read = std::min((uint32_t)EEPROM_PAGE_SIZE, remaining);
    if (!read_page(i2c_address, address, ptr, to_read)) {
      return false;
    }

    ptr += to_read;
    remaining -= to_read;
    address += to_read;
  }

  return true;
}

ModuleEeprom::ModuleEeprom(uint8_t address) : address_(address) {}

bool ModuleEeprom::is_available() {
  Wire.beginTransmission(address_);
  return Wire.endTransmission() == 0;
}

bool ModuleEeprom::read_header() {
  uint32_t header = 0;

  if (!eeprom_read(address_, HeaderAddress, (uint8_t *)&header,
                   sizeof(header))) {
    return false;
  }

  return false;
}
