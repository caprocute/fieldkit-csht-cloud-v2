
#include <Arduino.h>
#include "FreeRTOS.h"
#include "task.h"

#ifndef ERROR_HOOKS_H
#define ERROR_HOOKS_H

	#ifdef __cplusplus

	extern "C"
	{
	#endif
		// called on fatal error (interrupts disabled already)
		void rtosFatalError(void);

		// fatal error print out what file assert failed
		void rtosFatalErrorSerialPrint(unsigned long ulLine, const char *pcFileName, uint8_t valueA, const char* evaluation, uint8_t valueB);

		// called on full heap or malloc failure
		void vApplicationMallocFailedHook(void);

		// called on full stack
		void vApplicationStackOverflowHook( TaskHandle_t xTask, char *pcTaskName );
	#ifdef __cplusplus
	}
	#endif

#endif
