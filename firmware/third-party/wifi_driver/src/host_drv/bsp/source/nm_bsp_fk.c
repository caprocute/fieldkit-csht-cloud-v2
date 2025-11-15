#include <Arduino.h>

#include "bsp/include/nm_bsp.h"
#include "bsp/include/nm_bsp_fk.h"
#include "common/include/nm_common.h"

int8_t g_winc1500_pin_cs = -1;
int8_t g_winc1500_pin_irq = -1;
int8_t g_winc1500_pin_rst = -1;
int8_t g_winc1500_pin_en = -1;

static tpfNmBspIsr gpfIsr = NULL;

static void chip_isr(void) {
    if (gpfIsr != NULL) {
        gpfIsr();
    }
}

static void init_chip_pins(void) {
    if (g_winc1500_pin_rst > -1) {
        pinMode(g_winc1500_pin_rst, OUTPUT);
        digitalWrite(g_winc1500_pin_rst, HIGH);
    }

    if (g_winc1500_pin_en > -1) {
        pinMode(g_winc1500_pin_en, INPUT_PULLUP);
    }

    pinMode(g_winc1500_pin_irq, INPUT);
}

static void deinit_chip_pins(void) {
    if (g_winc1500_pin_rst > -1) {
        digitalWrite(g_winc1500_pin_rst, LOW);
        pinMode(g_winc1500_pin_rst, INPUT);
    }

    if (g_winc1500_pin_en > -1) {
        pinMode(g_winc1500_pin_en, INPUT);
    }
}

int8_t nm_bsp_init(void) {
    gpfIsr = NULL;

    init_chip_pins();

    nm_bsp_reset();

    return M2M_SUCCESS;
}

int8_t nm_bsp_deinit(void) {
    deinit_chip_pins();

    return M2M_SUCCESS;
}

void nm_bsp_reset(void) {
    if (g_winc1500_pin_rst > -1) {
        digitalWrite(g_winc1500_pin_rst, LOW);
        nm_bsp_sleep(100);
        digitalWrite(g_winc1500_pin_rst, HIGH);
        nm_bsp_sleep(100);
    }
}

void nm_bsp_sleep(uint32 u32TimeMsec) {
    delay(u32TimeMsec);
}

void nm_bsp_register_isr(tpfNmBspIsr pfIsr) {
    gpfIsr = pfIsr;
    attachInterrupt(g_winc1500_pin_irq, chip_isr, FALLING);
}

void nm_bsp_interrupt_ctrl(uint8 u8Enable) {
    if (u8Enable) {
        attachInterrupt(g_winc1500_pin_irq, chip_isr, FALLING);
    } else {
        detachInterrupt(g_winc1500_pin_irq);
    }
}
