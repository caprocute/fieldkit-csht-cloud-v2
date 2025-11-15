#pragma once

#include <Arduino.h>
#include <stdint.h>

#define I2C_CHECK(rv) ((rv) == 0)

int32_t wire_write(uint8_t address, const void *data, size_t size,
                   bool stop = true);
int32_t wire_write_u8(uint8_t address, uint8_t data);
int32_t wire_read(uint8_t address, void *data, int32_t size);
int32_t wire_read_register_u8(uint8_t address, uint8_t reg, uint8_t &value,
                              bool stop = true);
int32_t wire_write_register_u8(uint8_t address, uint8_t reg, uint8_t value);
int32_t wire_read_register_buffer(uint8_t address, uint8_t reg, uint8_t *buffer,
                                  int32_t size);
