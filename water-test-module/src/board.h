#pragma once

#define PIN_DISPLAY_SCL 22
#define PIN_DISPLAY_SDA 23

#define PIN_ADC_DRDY 12  // IO12 Active low
#define PIN_ADC_RESET 13 // IO13 Active low

#define MCP2803_ADDRESS 0x22
#define ADS1219_ADDRESS_MODULE 0x45
#define ADS1219_ADDRESS_LOCAL 0x44

class Board {
public:
  void begin();
  bool is_button_down();
  bool was_button_pressed();
  void enable_module();
  void disable_module();
  bool is_short_detected();
  bool local_adc_ready();
  void fail();
  void pass();
};
