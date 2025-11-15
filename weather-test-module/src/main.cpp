#include <Adafruit_DAP.h>
#include <Arduino.h>
#include <U8x8lib.h>
#include <Wire.h>
#include <stdint.h>

#include "board.h"
#include "eeprom.h"
#include "fk-weather-sidecar-jig.h"
#include "fk-weather-sidecar-normal.h"
#include "two_wire.h"

enum Test {
  Unknown = 0xff,
  Pass = 0x1,
  Fail = 0x0,
};

#define FK_JIG_I2C_FORCE_READ_LOOP false
#define FK_WEATHER_I2C_ADDRESS (0x42)
#define FK_WEATHER_I2C_COMMAND_READ (0x00)
#define FK_WEATHER_JIG_FAIL 2
#define FK_WEATHER_JIG_PASS 1

const size_t DAP_BUFFER_SIZE = Adafruit_DAP_SAM::PAGESIZE;

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
  Test test_flash_test = Test::Unknown;
  Test test_comms = Test::Unknown;
  Test test_flash_prod = Test::Unknown;

public:
  bool failed() {
    if (test_short != Test::Pass) {
      return true;
    }
    if (test_eeprom != Test::Pass) {
      return true;
    }
    if (test_flash_test != Test::Pass) {
      return true;
    }
    if (test_comms != Test::Pass) {
      return true;
    }
    if (test_flash_prod != Test::Pass) {
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

static bool dap_program_blob(Adafruit_DAP &dap, uint8_t const *buffer,
                             size_t size) {
  Serial.println("dap: erasing...");

  dap.erase();

  uint32_t position = 0;
  uint32_t addr = dap.program_start(position, size);

  Serial.print("dap: programming @ ");
  Serial.println(addr);

  while (position < size) {
    uint32_t remaining = std::min(size - position, DAP_BUFFER_SIZE);

    Serial.print("dap: block ");
    Serial.print(remaining);
    Serial.print(" ");
    Serial.print(position);
    Serial.println();

    // Partial programming of the tail block doesn't work. So we flash from a
    // page sized block to avoid flashing arbitrary garbage at the end.
    uint8_t block[DAP_BUFFER_SIZE];
    memset(block, 0x00, sizeof(block));
    memcpy(block, buffer + position, remaining);

    dap.programBlock(addr + position, block, DAP_BUFFER_SIZE);

    dap.dap_read_block(addr + position, block, DAP_BUFFER_SIZE);

    if (memcmp(block, buffer + position, remaining) != 0) {
      Serial.println("dap: verify failed!");
      fk_dump_memory(block, remaining);
      fk_dump_memory(buffer + position, remaining);
      return false;
    }

    position += remaining;
  }

  // Finish up
  Serial.println("dap: finishing...");

  return true;
}

static bool dap_flash(uint8_t const *buffer, size_t size) {
  bool pass = false;

  Adafruit_DAP_SAM dap;

  dap.begin(PIN_TARGET_SWCLK, PIN_TARGET_SWDIO, PIN_TARGET_SWRST, &dap_error);

  if (!dap.targetConnect()) {
    Serial.println("dap: FAIL!");
  } else {
    Serial.println("dap: ready");

    char debugger_name[100];
    dap.dap_get_debugger_info(debugger_name);
    Serial.print("dap: ");
    Serial.println(debugger_name);

    uint32_t dsu_did;
    if (!dap.select(&dsu_did)) {
      Serial.print("dap: FAIL! unknown device found 0x");
      Serial.println(dsu_did, HEX);
    } else {
      Serial.print("dap: target: ");
      Serial.println(dap.target_device.name);
      Serial.print("dap: flash size: ");
      Serial.println(dap.target_device.flash_size);
      Serial.print("dap: flash pages: ");
      Serial.println(dap.target_device.n_pages);

      if (!dap_program_blob(dap, buffer, size)) {
        Serial.println("dap: FAIL! program");
      } else {
        Serial.println("dap: PASS");
        pass = true;
      }

      dap.dap_set_clock(50);

      dap.deselect();

      dap.dap_disconnect();

      Serial.println("dap: success!");
    }
  }

  return pass;
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

    while (FK_JIG_I2C_FORCE_READ_LOOP) {
      uint32_t buffer[2] = {0, 0};
      int32_t rv = wire_read_register_buffer(
          FK_WEATHER_I2C_ADDRESS, FK_WEATHER_I2C_COMMAND_READ,
          (uint8_t *)&buffer, sizeof(buffer));

      if (rv == 0) {
        Serial.print("regs[0]: ");
        Serial.println(buffer[0]);
        Serial.print("regs[1]: ");
        Serial.println(buffer[1]);
      } else {
        Serial.println("fail");
      }

      delay(5000);
    }

    ModuleEeprom eeprom;
    if (eeprom.is_available()) {
      Serial.println("eeprom: PASS");
      test_eeprom = Test::Pass;
    } else {
      Serial.println("eeprom: FAIL!");
      test_eeprom = Test::Fail;
    }

    if (dap_flash(fk_weather_sidecar_jig_bin, fk_weather_sidecar_jig_bin_len)) {
      test_flash_test = Test::Pass;
    } else {
      test_flash_test = Test::Fail;
    }

    if (test_flash_test == Test::Pass) {
      board.disable_module();
      delay(500);
      board.enable_module();

      Wire.begin();

      test_comms = Test::Fail;

      for (auto i = 0; i < 10; ++i) {
        delay(500);

        uint32_t buffer[2] = {0, 0};
        int32_t rv = wire_read_register_buffer(
            FK_WEATHER_I2C_ADDRESS, FK_WEATHER_I2C_COMMAND_READ,
            (uint8_t *)&buffer, sizeof(buffer));

        if (rv == 0) {
          Serial.print("regs[0]: ");
          Serial.println(buffer[0]);
          Serial.print("regs[1]: ");
          Serial.println(buffer[1]);

          if (buffer[1] == FK_WEATHER_JIG_PASS) {
            test_comms = Test::Pass;
            break;
          }
          if (buffer[1] == FK_WEATHER_JIG_FAIL) {
            break;
          }
        }
      }
    }
  }

  if (test_comms == Test::Pass) {
    if (dap_flash(fk_weather_sidecar_normal_bin,
                  fk_weather_sidecar_normal_bin_len)) {
      test_flash_prod = Test::Pass;
    } else {
      test_flash_prod = Test::Fail;
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
  draw_test_item(row++, module.test_flash_test, "FlashCheck");
  draw_test_item(row++, module.test_comms, "Comms");
  draw_test_item(row++, module.test_flash_prod, "FlashProd");
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
