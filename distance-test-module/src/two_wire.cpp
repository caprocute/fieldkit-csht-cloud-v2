#include "two_wire.h"
#include <Wire.h>

int32_t wire_write(uint8_t address, const void *data, size_t size, bool stop) {
  Wire.beginTransmission(address);
  auto ptr = (uint8_t *)data;
  for (auto i = 0; i < size; ++i) {
    Wire.write((uint8_t)*ptr++);
  }
  return Wire.endTransmission(stop);
}

int32_t wire_read(uint8_t address, void *data, int32_t size) {
  Wire.requestFrom(address, (uint8_t)size);
  auto ptr = (uint8_t *)data;
  for (auto i = 0; i < size; ++i) {
    *ptr++ = Wire.read();
  }
  return Wire.endTransmission();
}

int32_t wire_read_register_u8(uint8_t address, uint8_t reg, uint8_t &value,
                              bool stop) {
  int32_t rv;

  rv = wire_write(address, &reg, sizeof(reg), stop);
  if (!I2C_CHECK(rv)) {
    return rv;
  }

  rv = wire_read(address, &value, sizeof(value));
  if (!I2C_CHECK(rv)) {
    return rv;
  }

  return 0;
}

int32_t wire_write_u8(uint8_t address, uint8_t data) {
  uint8_t command[] = {data};
  return wire_write(address, &command, sizeof(command));
}

int32_t wire_read_register_buffer(uint8_t address, uint8_t reg, uint8_t *buffer,
                                  int32_t size) {
  int32_t rv;

  rv = wire_write(address, &reg, sizeof(reg));
  if (!I2C_CHECK(rv)) {
    return rv;
  }

  rv = wire_read(address, buffer, size);
  if (!I2C_CHECK(rv)) {
    return rv;
  }

  return 0;
}

int32_t wire_write_register_u8(uint8_t address, uint8_t reg, uint8_t value) {
  uint8_t command[] = {reg, value};
  return wire_write(address, &command, sizeof(command));
}
