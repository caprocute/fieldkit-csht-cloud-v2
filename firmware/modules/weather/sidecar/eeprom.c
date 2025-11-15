#if defined(FK_WEATHER_JIG)

#include <string.h>

#include <atmel_start_pins.h>

#include <hal_delay.h>

#include "eeprom.h"
#include "crc.h"
#include "board.h"
#include "modules.h"

/**
 * Return the smaller of two values.
 */
#define MIN(a, b)   ((a > b) ? (b) : (a))

int32_t eeprom_read_page(struct i2c_m_sync_desc *i2c, uint8_t i2c_address, uint16_t address, uint8_t *data, size_t size) {
    // FK_ASSERT(size <= EEPROM_PAGE_SIZE);
    // FK_ASSERT(address + size <= EEPROM_ADDRESS_END);

    struct _i2c_m_msg msg;
    int32_t           rv;

    uint8_t buffer[sizeof(address)];
    buffer[0] = (address >> 8) & 0xff;
    buffer[1] = (address) & 0xff;

    i2c_m_sync_enable(i2c);

    msg.addr   = i2c_address;
    msg.len    = sizeof(buffer);
    msg.flags  = 0;
    msg.buffer = (void *)buffer;
    rv = _i2c_m_sync_transfer(&i2c->device, &msg);
    if (rv != ERR_NONE) {
        return rv;
    }

    msg.flags  = I2C_M_STOP | I2C_M_RD;
    msg.buffer = data;
    msg.len    = size;
    rv = _i2c_m_sync_transfer(&i2c->device, &msg);
    if (rv != ERR_NONE) {
        return rv;
    }

    return FK_SUCCESS;
}

#endif
