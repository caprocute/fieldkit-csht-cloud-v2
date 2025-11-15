#include <Arduino.h>

#include "board.h"
#include "esp32-hal-gpio.h"

#define PIN_BUTTON 14
#define PIN_ENABLE 12
#define PIN_SHORT 21

void Board::begin() {
  pinMode(PIN_ENABLE, OUTPUT);
  // Board has a pullup but pH test jig needed this, can't hurt.
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_SHORT, INPUT);
}

bool Board::is_button_down() { return digitalRead(PIN_BUTTON) == LOW; }

bool Board::was_button_pressed() {
  if (is_button_down()) {
    Serial.println("button:down");
    while (is_button_down()) {
      delay(10);
    }
    Serial.println("button:up");
    return true;
  }
  return false;
}

void Board::enable_module() { digitalWrite(PIN_ENABLE, HIGH); }

void Board::disable_module() { digitalWrite(PIN_ENABLE, LOW); }

bool Board::is_short_detected() { return digitalRead(PIN_SHORT) != LOW; }

void Board::pass() {}

void Board::fail() {}
