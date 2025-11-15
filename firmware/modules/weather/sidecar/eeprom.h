#pragma once

#include <modules.h>

#if defined(FK_WEATHER_JIG)

#include <hal_i2c_m_sync.h>

#include "sidecar.h"
#include "unwritten.h"

int32_t eeprom_read_page(struct i2c_m_sync_desc *i2c, uint8_t i2c_address, uint16_t address, uint8_t *data, size_t size);

#endif
