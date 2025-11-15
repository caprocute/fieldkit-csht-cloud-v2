#pragma once

#include <stdint.h>

#define MPL3115A2_I2C_ADDRESS (0x60)

class Mpl3115a2 {
private:
  uint8_t address_{0};

public:
  Mpl3115a2(uint8_t address);

public:
  bool begin();
};
