/* 
 * File:   paprium.h
 * Author: Igor
 *
 * Created on July 16, 2025, 7:24 PM
 */

#ifndef PAPRIUM_H
#define	PAPRIUM_H

typedef struct {

    struct {
        vu32 md_rst : 1;
        vu32 exit_to_menu : 1;
        vu32 sdram_en : 1;
        vu32 md_rst_status : 1; //md reset was pressed
    } ctrl;

    vu32 time; //ms ticks
    vu32 sdram_ptr; //sdram pointer for md side
    vu32 vol_sfx;
    vu32 vol_bgm;

} FpgaIO;

typedef struct {

    struct {
        vu8 fifo_empry : 1;
        vu8 fifo_full : 1;
    } status;
    u8 type;
    vu8 pan;
    vu8 flags;

    vu16 vol;
    vs16 sample;

} SfxIO;

typedef struct {
    ppm_ramdp *ramdp;
    u8 *flash;
    u8 *sdram;
    u8 *bram;
    SfxIO *sfx;
} ppm_io;


void ppm_start();

#define FPGAIO          ((FpgaIO *) ADDR_FPGIO)
extern ppm_io ppmio;
extern u32 tick_ctr;

#endif	/* PAPRIUM_H */

