#include <Arduino.h>
#include <SPI.h>

extern "C" {
#include "bsp/include/nm_bsp.h"
#include "bsp/include/nm_bsp_fk.h"
#include "common/include/nm_common.h"
#include "bus_wrapper/include/nm_bus_wrapper.h"
}

extern "C" {

extern int8_t g_winc1500_pin_cs;

#define NM_BUS_MAX_TRX_SZ 256 // TODO Could this be larger? Should this be larger?

tstrNmBusCapabilities egstrNmBusCapabilities = { NM_BUS_MAX_TRX_SZ };

static const SPISettings wifi_SPISettings(12000000L, MSBFIRST, SPI_MODE0);

static sint8 spi_rw(uint8 *pu8Mosi, uint8 *pu8Miso, uint16 u16Sz) {
    uint8 u8Dummy = 0;
    uint8 u8SkipMosi = 0, u8SkipMiso = 0;

    if (!pu8Mosi) {
        pu8Mosi = &u8Dummy;
        u8SkipMosi = 1;
    } else if (!pu8Miso) {
        pu8Miso = &u8Dummy;
        u8SkipMiso = 1;
    } else {
        return M2M_ERR_BUS_FAIL;
    }

    WINC1501_SPI.beginTransaction(wifi_SPISettings);
    digitalWrite(g_winc1500_pin_cs, LOW);

    while (u16Sz) {
        *pu8Miso = WINC1501_SPI.transfer(*pu8Mosi);

        u16Sz--;
        if (!u8SkipMiso)
            pu8Miso++;
        if (!u8SkipMosi)
            pu8Mosi++;
    }

    digitalWrite(g_winc1500_pin_cs, HIGH);
    WINC1501_SPI.endTransaction();

    return M2M_SUCCESS;
}

int8_t nm_bus_init(void *) {
    WINC1501_SPI.begin();

    pinMode(g_winc1500_pin_cs, OUTPUT);
    digitalWrite(g_winc1500_pin_cs, HIGH);

    nm_bsp_reset();
    nm_bsp_sleep(1);

    return M2M_SUCCESS;
}

int8_t nm_bus_ioctl(uint8_t u8Cmd, void *pvParameter) {
    switch (u8Cmd) {
    case NM_BUS_IOCTL_RW: {
        tstrNmSpiRw *pstrParam = (tstrNmSpiRw *)pvParameter;
        return spi_rw(pstrParam->pu8InBuf, pstrParam->pu8OutBuf, pstrParam->u16Sz);
    } break;
    default:
        M2M_ERR("invalide ioclt cmd\n");
        return -1;
    }
}

int8_t nm_bus_deinit(void) {
    WINC1501_SPI.end();

    return 0;
}
}