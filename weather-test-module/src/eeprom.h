#pragma once

#include <stdint.h>

#define EEPROM_I2C_ADDRESS (0x50)
#define EEPROM_PAGE_SIZE (0x20)
#define EEPROM_ADDRESS_HEADER (0x00)

class ModuleEeprom {
public:
  constexpr static uint8_t EepromAddress = EEPROM_I2C_ADDRESS;
  constexpr static uint32_t EepromPageSize = EEPROM_PAGE_SIZE;
  constexpr static uint16_t HeaderAddress = EEPROM_ADDRESS_HEADER;

public:
  bool is_available();
  bool read_header();
};
