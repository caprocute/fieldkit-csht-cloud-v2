
#include "error_hooks.h"
#include "FreeRTOSConfig.h" // for configCAL_FACTOR
#include "logging.h"

#if defined(__SAMD51__)
#include <Arduino.h>
#endif

void rtosFatalError(void) {
	taskDISABLE_INTERRUPTS();

	alogf(LogLevels::ERROR, "error", "fatal error, restarting...");

#if defined(__SAMD21__) || defined(__SAMD51__)
    NVIC_SystemReset();
#endif // defined(__SAMD21__) || defined(__SAMD51__)
}

void rtosFatalErrorSerial(unsigned long ulLine, const char *pcFileName) {
	alogf(LogLevels::ERROR, "error", "[%s:%d] fatal error", pcFileName, ulLine);

	rtosFatalError();
}

void rtosFatalErrorSerialPrint(unsigned long ulLine, const char *pcFileName, uint8_t valueA, const char* evaluation, uint8_t valueB) {
	alogf(LogLevels::ERROR, "error", "[%s:%d] fatal error: '%d %s %d'", pcFileName, ulLine, valueA, evaluation, valueB);

	rtosFatalError();
}

void vApplicationMallocFailedHook(void) {
	alogf(LogLevels::ERROR, "error", "malloc failed!");
  
#if defined(__SAMD21__) || defined(__SAMD51__)
    NVIC_SystemReset();
#endif // defined(__SAMD21__) || defined(__SAMD51__)
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
	alogf(LogLevels::ERROR, "error", "stack overflow in '%s'!", pcTaskName);

#if defined(__SAMD21__) || defined(__SAMD51__)
    NVIC_SystemReset();
#endif // defined(__SAMD21__) || defined(__SAMD51__)
}
