#pragma once

#include <stdlib.h>
#include <stdint.h>
#include "math.h"

uint32 fkb_external_printf(const char *str, ...);

#define CONF_WINC_USE_SPI
#define CONF_WINC_DEBUG  (1)
#define CONF_WINC_PRINTF fkb_external_printf

#define NM_EDGE_INTERRUPT (1)

#define NM_DEBUG      CONF_WINC_DEBUG
#define NM_BSP_PRINTF CONF_WINC_PRINTF

#ifndef __cplusplus
#if !defined(__bool_true_false_are_defined)
typedef unsigned char bool; //!< Boolean.
#define false 0
#define true  1
#endif
#endif

#if !defined(min)
#define min(a, b) (((a) < (b)) ? (a) : (b))
#endif