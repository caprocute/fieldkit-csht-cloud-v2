#pragma once

#include <cinttypes>

extern "C" {

uint32_t millis();

void delay(uint32_t ms);

}

class Stream;

#include <Udp.h>
