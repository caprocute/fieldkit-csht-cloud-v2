#pragma once

#define PIN_DISPLAY_SCL 22
#define PIN_DISPLAY_SDA 23

#define PIN_TARGET_SWDIO 15
#define PIN_TARGET_SWCLK 33
#define PIN_TARGET_SWRST 27

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
