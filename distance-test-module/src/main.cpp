#include <Arduino.h>
#include <U8x8lib.h>
#include <Wire.h>
#include <stdint.h>

#include "board.h"
#include "eeprom.h"
#include "two_wire.h"

enum Test {
  Unknown = 0xff,
  Pass = 0x1,
  Fail = 0x0,
};

#define FK_DISTANCE_I2C_ADDRESS (0x51)

class Module;

class Display {
private:
  U8X8_SH1106_128X64_NONAME_HW_I2C u8x8{U8X8_PIN_NONE, PIN_DISPLAY_SCL,
                                        PIN_DISPLAY_SDA};

public:
  void begin();
  void draw_ready();
  void draw_jig_fault();
  void draw_busy();
  void draw_test_item(uint8_t row, Test test, const char *label);

public:
  void draw_module(Module &module);
};

void Display::begin() {
  u8x8.begin();
  u8x8.setPowerSave(0);
}

void Display::draw_jig_fault() {
  u8x8.clear();
  u8x8.setFont(u8x8_font_chroma48medium8_r);
  u8x8.setInverseFont(1);
  u8x8.drawString(0, 0, "JIG FAULT");
  u8x8.setInverseFont(0);
  u8x8.refreshDisplay();
}

void Display::draw_busy() {
  u8x8.clear();
  u8x8.setFont(u8x8_font_chroma48medium8_r);
  u8x8.drawString(0, 0, "Busy, testing...");
  u8x8.refreshDisplay();
}

void Display::draw_ready() {
  u8x8.clear();
  u8x8.setFont(u8x8_font_chroma48medium8_r);
  u8x8.setInverseFont(1);
  u8x8.drawString(0, 0, "Ready!");
  u8x8.setInverseFont(0);
  u8x8.drawString(0, 1, "Insert Module");
  u8x8.drawString(0, 2, "Attach Cable");
  u8x8.drawString(0, 3, "Press Button");
  u8x8.refreshDisplay();
}

class Module {
public:
  Test test_short = Test::Unknown;
  Test test_eeprom = Test::Unknown;
  Test test_comms = Test::Unknown;

public:
  bool failed() {
    if (test_short != Test::Pass) {
      return true;
    }
    if (test_eeprom != Test::Pass) {
      return true;
    }
    if (test_comms != Test::Pass) {
      return true;
    }

    return false;
  }

public:
  void test(Board &board, Display &display);
};

static void dap_error(const char *text) {
  Serial.print("\ndap(error): ");
  Serial.println(text);
}

void fk_dump_memory(const uint8_t *p, size_t size) {
  for (size_t i = (size_t)0; i < size; ++i) {
    Serial.printf("%02x ", p[i]);
    if ((i + 1) % 32 == 0) {
      if (i + 1 < size) {
        Serial.println();
      }
    }
  }
  Serial.println();
}

void Module::test(Board &board, Display &display) {
  Serial.println("testing...");
  display.draw_busy();
  board.enable_module();
  delay(500);

  Serial.println("enabled...");
  if (board.is_short_detected()) {
    Serial.println("short: FAIL!");
    test_short = Test::Fail;
  } else {
    test_short = Test::Pass;

    Wire.begin();

    ModuleEeprom eeprom;
    if (eeprom.is_available()) {
      Serial.println("eeprom: PASS");
      test_eeprom = Test::Pass;
    } else {
      Serial.println("eeprom: FAIL!");
      test_eeprom = Test::Fail;
    }

    ModuleEeprom fake_sensor{FK_DISTANCE_I2C_ADDRESS};
    if (fake_sensor.is_available()) {
      Serial.println("fake-sensor: PASS");
      test_comms = Test::Pass;
    } else {
      Serial.println("fake-sensor: FAIL!");
      test_comms = Test::Fail;
    }
  }

  board.disable_module();
  display.begin();
  display.draw_module(*this);

  if (failed()) {
    board.fail();
  } else {
    board.pass();
  }
}

void Display::draw_module(Module &module) {
  u8x8.clear();
  u8x8.setFont(u8x8_font_chroma48medium8_r);
  if (module.failed()) {
    u8x8.setInverseFont(1);
    u8x8.drawString(0, 0, " FAILED  FAILED ");
    u8x8.setInverseFont(0);
  } else {
    u8x8.setInverseFont(1);
    u8x8.drawString(0, 0, "Pass!");
    u8x8.setInverseFont(0);
  }

  uint8_t row = 1;
  draw_test_item(row++, module.test_short, "Short");
  draw_test_item(row++, module.test_eeprom, "EEProm");
  draw_test_item(row++, module.test_comms, "Comms");
}

void Display::draw_test_item(uint8_t row, Test test, const char *label) {
  char prefix = '?';
  switch (test) {
  case (Test::Unknown): {
    u8x8.setInverseFont(0);
    prefix = ' ';
    break;
  }
  case (Test::Pass): {
    u8x8.setInverseFont(0);
    prefix = '+';
    break;
  }
  case (Test::Fail): {
    u8x8.setInverseFont(1);
    prefix = '!';
    break;
  }
  }
  char buffer[32];
  snprintf(buffer, sizeof(buffer), "%c %s", prefix, label);
  u8x8.drawString(0, row, buffer);
  u8x8.setInverseFont(0);
}

static Board board;
static Display display;

void setup(void) {
  Serial.begin(9600);
  board.begin();
  display.begin();
  display.draw_ready();
  Serial.println("ready");
}

void loop(void) {
  if (board.was_button_pressed()) {
    Serial.println("button");

    Module module;
    module.test(board, display);
    Serial.println("test: done");
    while (!board.was_button_pressed()) {
      delay(10);
    }
    display.draw_ready();
    board.pass();
    Serial.println("ready");
  }
}
