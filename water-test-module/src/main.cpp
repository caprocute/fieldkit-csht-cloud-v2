#include <Arduino.h>
#include <U8x8lib.h>
#include <Wire.h>
#include <stdint.h>

#include "ads_1219.h"
#include "board.h"
#include "eeprom.h"
#include "mcp_2803.h"
#include "mpl_3115a2.h"
#include "soc/io_mux_reg.h"

enum Test {
  Unknown = 0xff,
  Pass = 0x1,
  Fail = 0x0,
};

struct WaterMcpGpioConfig {
  uint8_t io_dir;
  uint8_t pullups;
  uint8_t on;
  uint8_t off;
  uint8_t excite_on;
  uint8_t excite_off;
};

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
#if defined(MODALITY_TEMPERATURE)
  u8x8.drawString(0, 0, "Temp Ready!");
#elif defined(MODALITY_EC)
  u8x8.drawString(0, 0, "EC Ready!");
#elif defined(MODALITY_DO)
  u8x8.drawString(0, 0, "DO Ready!");
#elif defined(MODALITY_PH)
  u8x8.drawString(0, 0, "PH Ready!");
#endif
  u8x8.setInverseFont(0);
  u8x8.drawString(0, 1, "Insert Module");
  u8x8.drawString(0, 2, "Attach SMA");
  u8x8.drawString(0, 3, "Press Button");
  u8x8.refreshDisplay();
}

class LocalAdcReadyChecker : public Ads1219ReadyChecker {
public:
  bool block_until_ready() override {
    uint32_t loops = 0;
    auto give_up = millis() + 1000;
    while (millis() < give_up) {
      if (digitalRead(PIN_ADC_DRDY) == 0) {
        Serial.println(loops);
        return true;
      }

      loops += 1;

      delay(20);
    }

    return false;
  }
};

class Module : public Ads1219ReadyChecker {
public:
  LocalAdcReadyChecker local_checker_;
  Ads1219 module_adc_ = Ads1219(ADS1219_ADDRESS_MODULE, this);
  Ads1219 local_adc_ = Ads1219(ADS1219_ADDRESS_LOCAL, &local_checker_);
  Mcp2803 mcp_ = Mcp2803(MCP2803_ADDRESS);
  Test test_short = Test::Unknown;
  Test test_eeprom = Test::Unknown;
  Test test_expander = Test::Unknown;
  Test test_local_adc = Test::Unknown;
  Test test_module_adc = Test::Unknown;
  Test test_reading = Test::Unknown;
#if defined(MODALITY_DO)
  Test test_mpl = Test::Unknown;
  Mpl3115a2 mpl_ = Mpl3115a2(MPL3115A2_I2C_ADDRESS);
#endif
  float module_reading = 0.0f;
  float local_reading = 0.0f;

public:
  bool failed() {
#if defined(MODALITY_EC)
    if (test_local_adc != Test::Pass) {
      return true;
    }
#endif
    if (test_short != Test::Pass) {
      return true;
    }
    if (test_eeprom != Test::Pass) {
      return true;
    }
    if (test_expander != Test::Pass) {
      return true;
    }
    if (test_module_adc != Test::Pass) {
      return true;
    }
    if (test_reading != Test::Pass) {
      return true;
    }
#if defined(MODALITY_DO)
    if (test_mpl != Test::Pass) {
      return true;
    }
#endif
    return false;
  }

public:
  bool block_until_ready() override;
  void test(Board &board, Display &display);
  void modality_test(Board &board, Display &display);
};

bool Module::block_until_ready() {
  auto give_up = millis() + 1000;
  while (millis() < give_up) {
    uint8_t gpio{0};

    if (!mcp_.read_gpio(gpio)) {
      return false;
    }

    if (!(gpio & 0x2)) {
      return true;
    }

    delay(20);
  }

  return false;
}

#define FK_MCP2803_IODIR 0b00000010
#define FK_MCP2803_GPPU 0b00000010

#define FK_MCP2803_GPIO_ON 0b00000001
#define FK_MCP2803_GPIO_OFF 0b00000000

#define FK_MCP2803_GPIO_EXCITE_ON 0b00000101
#define FK_MCP2803_GPIO_EXCITE_OFF 0b00000001

static WaterMcpGpioConfig StandaloneWaterMcpConfig{
    FK_MCP2803_IODIR,    FK_MCP2803_GPPU,           FK_MCP2803_GPIO_ON,
    FK_MCP2803_GPIO_OFF, FK_MCP2803_GPIO_EXCITE_ON, FK_MCP2803_GPIO_EXCITE_OFF};

#if defined(MODALITY_TEMPERATURE) || defined(MODALITY_DO)
void Module::modality_test(Board &board, Display &display) {
  if (!module_adc_.configure(Ads1219VoltageReference::Internal,
                             Ads1219Channel::Single_0, Ads1219Gain::One,
                             Ads1219DataRate::DataRate_1000)) {
    test_module_adc = Test::Fail;
  }

  int32_t value = 0;
  if (!module_adc_.read(value)) {
    test_module_adc = Test::Fail;
  }

  // Bradley: Okay, voltage mystery solved, the high side is not the power
  // supply, it's a vref, because I was being all fancy pants, and because
  // that ref has to be biased, there's more resistance on the high side than
  // on the jig side, when you calculate all that out the EXPECTED voltage
  // from proper operation is 1.33
  float minimum = 1.0;
  float maximum = 1.6;
  module_reading = ((float)value * 2.048f) / 8388608.0f;
  if (module_reading >= minimum && module_reading <= maximum) {
    test_reading = Test::Pass;
  } else {
    test_reading = Test::Fail;
  }
}
#elif defined(MODALITY_EC)
// its DRDY is connected to IO12
// its RESET is connected to IO13
// the procedure is to fire up the module, check for hardware on i2c, turn on
// the EXCITE, and check for the excite volrage both on the module's ADC and the
// one on the jig. That verifies excite, voltage ref, ADC function on the
// module, and SMA soldering. that measurement is a differential measurement
// between AIN0 and AIN1 of the ADC on the jig, due to the module's isolation
// measurements against ground won't work.
void Module::modality_test(Board &board, Display &display) {
  if (!local_adc_.begin()) {
    Serial.println("local-adc: FAIL!");
    test_local_adc = Test::Fail;
  } else {
    Serial.println("local-adc: PASS");
    test_local_adc = Test::Pass;
  }

  if (!local_adc_.configure(Ads1219VoltageReference::Internal,
                            Ads1219Channel::Diff_0_1, Ads1219Gain::One,
                            Ads1219DataRate::DataRate_1000)) {
    Serial.println("local-adc: FAIL!");
    test_local_adc = Test::Fail;
  }

  if (!module_adc_.configure(Ads1219VoltageReference::Internal,
                             Ads1219Channel::Single_0, Ads1219Gain::One,
                             Ads1219DataRate::DataRate_1000)) {
    Serial.println("module-adc: FAIL!");
    test_module_adc = Test::Fail;
  }

  if (!mcp_.configure(StandaloneWaterMcpConfig.io_dir,
                      StandaloneWaterMcpConfig.pullups,
                      StandaloneWaterMcpConfig.excite_on)) {
    Serial.println("expander: FAIL!");
    test_expander = Test::Fail;
  }

  delay(100);

  int32_t local_value = 0;
  if (!local_adc_.read(local_value)) {
    Serial.println("local-adc: FAIL!");
    test_local_adc = Test::Fail;
  } else {
    Serial.print("local-adc: ");
    Serial.println(local_value);
  }

  int32_t module_value = 0;
  if (!module_adc_.read(module_value)) {
    Serial.println("module-adc: FAIL!");
    test_module_adc = Test::Fail;
  } else {
    Serial.print("module-adc: ");
    Serial.println(module_value);
  }

  if (!mcp_.configure(StandaloneWaterMcpConfig.io_dir,
                      StandaloneWaterMcpConfig.pullups,
                      StandaloneWaterMcpConfig.excite_off)) {
    Serial.println("expander: FAIL!");
  }

  module_reading = ((float)module_value * 2.048f) / 8388608.0f;
  local_reading = ((float)local_value * 2.048f) / 8388608.0f;

  if (module_reading > 1.8 && local_reading > 1.8) {
    test_reading = Test::Pass;
  } else {
    test_reading = Test::Fail;
  }
}
#elif defined(MODALITY_PH)
void Module::modality_test(Board &board, Display &display) {
  if (!module_adc_.configure(Ads1219VoltageReference::Internal,
                             Ads1219Channel::Single_0, Ads1219Gain::One,
                             Ads1219DataRate::DataRate_1000)) {
    test_module_adc = Test::Fail;
  }

  int32_t module_value = 0;
  if (!module_adc_.read(module_value)) {
    Serial.println("module-adc: FAIL!");
    test_module_adc = Test::Fail;
  } else {
    Serial.print("module-adc: ");
    Serial.println(module_value);
  }

  module_reading = ((float)module_value * 2.048f) / 8388608.0f;

  if (module_reading > 0.4 && module_reading < 0.6) {
    test_reading = Test::Pass;
  } else {
    test_reading = Test::Fail;
  }
}
#else
#error "no modality selected"
#endif

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
    Serial.println("short: PASS");
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

    if (mcp_.configure(StandaloneWaterMcpConfig.io_dir,
                       StandaloneWaterMcpConfig.pullups,
                       StandaloneWaterMcpConfig.off)) {
      Serial.println("expander: PASS");
      test_expander = Test::Pass;
    } else {
      Serial.println("expander: FAIL!");
      test_expander = Test::Fail;
    }

    delay(100);

    if (mcp_.configure(StandaloneWaterMcpConfig.io_dir,
                       StandaloneWaterMcpConfig.pullups,
                       StandaloneWaterMcpConfig.on)) {
      Serial.println("expander: PASS");
      test_expander = Test::Pass;
    } else {
      Serial.println("expander: FAIL!");
      test_expander = Test::Fail;
    }

    delay(100);

    if (module_adc_.begin()) {
      Serial.println("module-adc: PASS");
      test_module_adc = Test::Pass;
    } else {
      Serial.println("module-adc: FAIL!");
      test_module_adc = Test::Fail;
    }

    delay(100);

#if defined(MODALITY_DO)
    if (mpl_.begin()) {
      Serial.println("mpl3115a2: PASS");
      test_mpl = Test::Pass;

    } else {
      Serial.println("mpl3115a2: FAIL!");
      test_mpl = Test::Fail;
    }
#endif

    delay(100);

    modality_test(board, display);
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
  draw_test_item(row++, module.test_expander, "Expander");

#if defined(MODALITY_DO)
  draw_test_item(row++, module.test_mpl, "MPL");
#endif

  if (module.test_local_adc == Test::Fail) {
    draw_test_item(row++, module.test_local_adc, "Jig ADC");
    draw_test_item(row++, module.test_module_adc, "Mod ADC");
  } else {
    draw_test_item(row++, module.test_module_adc, "Mod ADC");
    draw_test_item(row++, module.test_reading, "Reading");

    char line[32];
#if defined(MODALITY_EC)
    snprintf(line, sizeof(line), "%.3f %.3f", module.module_reading,
             module.local_reading);
    draw_test_item(row++, module.test_reading, line);
#else
    snprintf(line, sizeof(line), "%.3f", module.module_reading);
    draw_test_item(row++, module.test_reading, line);
#endif
    u8x8.refreshDisplay();
  }
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
