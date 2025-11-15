## I2C Bus

### Peripherals

| Device            | Pins          | Peripheral |
| ----------------- | ------------- | ---------- |
| SPI               | B12, B13, B15 | SERCOM4    |
| SPI1              | B26, B27, B29 | SERCOM2    |
| SPI2              | B16, B17, B19 | SERCOM5    |
| Wire              | B20, B21      | SERCOM3    |
| Wire1             | C22, C23      | SERCOM1    |
| Wire2             | C16, C17      | SERCOM6    |
| Serial1           | B24, B25      | SERCOM0    |

### Core

| Device            | Address     | 
| ----------------- | ----------- | 
| RTC               | 0x51        | 
| Core Temperature  | 0x48        |
| OLED              | 0x3C        |

### Module

| Device                  | Address     | 
| ----------------------- | ----------- | 
| INA219 (Battery)        | 0x40        | 
| INA219 (Solar)          | 0x41        | 
| Backplane LP50 (LEDs)   | 0x14, 0xC   |
| Backplane MCP23008      | 0x20        |
| Backplane TCA9545A      | 0x70        |
| Module EERPOM           | 0x50, 0x58  |

### Radio

| Device                  | Address     | 
| ----------------------- | ----------- | 
| SC16IS740 (Lora)        | 0x4D        | 

### Module - Weather

| Device                  | Address     | 
| ----------------------- | ----------- | 
| Module EERPOM           | 0x50, 0x58  |
| ATSAMD09                | 0x42        |

### Module - Weather - Sensors

| Device                  | Address     | 
| ----------------------- | ----------- | 
| SHT31                   | 0x44        |
| MPL3115A2R1             | 0x60        |
| BME280                  | 0x76        |
| ADC081C021              | 0x50        |
| MCP (Control)           | 0x22        |
| MCP (Wind)              | 0x24        |
| MCP (Rain)              | 0x21        |

### Module - Distance

| Device                  | Address     | 
| ----------------------- | ----------- | 
| Module EERPOM           | 0x50, 0x58  |
| SC16IS740 (Ultrasonic)  | 0x4D        | 

### Module - Water

| Device                  | Address     | 
| ----------------------- | ----------- | 
| Module EERPOM           | 0x50, 0x58  |
| ADS1219                 | 0x45        |
| MCP23008                | 0x22        |

### Module - Atlas

| Device                  | Address     | 
| ----------------------- | ----------- | 
| Module EERPOM           | 0x50, 0x58  |
| Atlas (RTD)             | 0x68        |
| Atlas (ORP)             | 0x66        |
| Atlas (pH)              | 0x65        |
| Atlas (DO)              | 0x67        |
| Atlas (EC)              | 0x64        |
| MPL3115A2R1             | 0x60        |
