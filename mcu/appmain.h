/* 
 * File:   appmain.h
 * Author: Igor
 *
 * Created on July 14, 2025, 8:19 PM
 */

#ifndef APPMAIN_H
#define	APPMAIN_H

#include <neorv32.h>
#include <string.h>
#include "cfg.h"
#include "mame.h"
#include "paprium.h"
#include "sfx.h"
#include "mdp.h"
#include "everdrive.h"

#define printf neorv32_uart_printf

void printHex(void *src, u32 size);

#endif	/* APPMAIN_H */

