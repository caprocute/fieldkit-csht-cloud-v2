#include "mpl_3115a2.h"

#include "two_wire.h"

#define MPL3115A2_WHOAMI (0x0C)
#define MPL3115A2_WHOAMI_EXPECTED (0xC4)

Mpl3115a2::Mpl3115a2(uint8_t address) : address_(address) {}

bool Mpl3115a2::begin() {
  uint8_t identity = 0x0;
  if (!I2C_CHECK(wire_read_register_u8(MPL3115A2_I2C_ADDRESS, MPL3115A2_WHOAMI,
                                       identity, false))) {
    Serial.println("mpl3115a2: read fail");
    return false;
  }

  if (identity != MPL3115A2_WHOAMI_EXPECTED) {
    Serial.println("mpl3115a2: bad identity");
    return false;
  } else {
    return true;
  }
}
