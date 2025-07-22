
#include "appmain.h"

//based on libretro

#define SFX_CHAN_NUM    8

#define SFX_FLAG_AMP    0x0100//6db gain?
#define SFX_FLAG_PI_H   0x2000
#define SFX_FLAG_ECHO   0x4000
#define SFX_FLAG_PI_T   0x8000

typedef struct {
    u32 age;
    u32 ptr;
    u32 size;
    u32 step;
    u32 step_num;
    u32 decay;
    u32 looped;
    u32 ptr_base;
    u32 size_base;
    u32 flags;
} SfxChan;


SfxChan sfx_chan[SFX_CHAN_NUM];

void sfx_play(u8 arg) {

    u8 chan_idx = 0;
    u32 oldest_age = 0;

    u8 *sfx = &ppmio.flash[ppm_sfx_base_addr + arg * 8];
    u8 cmask = ppmio.ramdp->cmd_args[0];
    u16 vol = ppmio.ramdp->cmd_args[1];
    u16 pan = ppmio.ramdp->cmd_args[2];
    u16 flags = ppmio.ramdp->cmd_args[3];

    //seek free chan
    for (int i = 0; i < SFX_CHAN_NUM; i++, cmask >>= 1) {

        if ((cmask & 1) == 0) {
            continue;
        }

        if (sfx_chan[i].size || !ppmio.sfx[i].status.fifo_empry) {

            //oldest chan will be used in case if no free channels
            if (sfx_chan[i].age < oldest_age) {
                oldest_age = sfx_chan[i].age;
                chan_idx = i;
            }
            continue;
        }

        chan_idx = i;
        break;
    }

    sfx_chan[chan_idx].age = tick_ctr;
    sfx_chan[chan_idx].flags = flags;

    sfx_chan[chan_idx].ptr = ppm_sfx_base_addr + swapshorts(*(u32 *) & sfx[0]);
    sfx_chan[chan_idx].size = (sfx[4] << 16) | *(u16 *) & sfx[6];
    sfx_chan[chan_idx].step_num = sfx[5] & 0x03;
    sfx_chan[chan_idx].step = 0;
    sfx_chan[chan_idx].looped = 0;
    sfx_chan[chan_idx].decay = 0;
    sfx_chan[chan_idx].ptr_base = sfx_chan[chan_idx].ptr;
    sfx_chan[chan_idx].size_base = sfx_chan[chan_idx].size;


    ppmio.sfx[chan_idx].type = sfx[5]; //sample rate
    ppmio.sfx[chan_idx].flags = flags >> 8;
    ppmio.sfx[chan_idx].vol = vol * 96 / 128; //reduce sample vol a bit?
    ppmio.sfx[chan_idx].pan = pan;


    /*
    if (flags) {
        printf("flags: %x\n", flags);
    }*/

    //printf("d: %i\n", sfx_chan[chan_idx].type & 0x03); 
    //printf("d: %i\n", ppmio.ramdp->cmd_args[1]); 
}

void sfx_loop(u8 arg) {

    //printf("+lop: %x\n", arg);

    for (int i = 0; i < SFX_CHAN_NUM; i++, arg >>= 1) {

        if ((arg & 1) == 0) {
            continue;
        }

        ppmio.sfx[i].vol = ppmio.ramdp->cmd_args[0];
        ppmio.sfx[i].pan = ppmio.ramdp->cmd_args[1];
        sfx_chan[i].decay = ppmio.ramdp->cmd_args[2];
        sfx_chan[i].looped = 1;

        //break; //rem me?
    }
}

void sfx_stop(u8 arg) {

    int flags = ppmio.ramdp->cmd_args[0];

    //printf("-stp: %x\n", arg);

    for (int i = 0; i < SFX_CHAN_NUM; i++) {

        if (!(arg & (1 << i))) {
            continue;
        }

        if (flags == 0) {
            sfx_chan[i].size = 0;
        }

        sfx_chan[i].decay = flags;
        sfx_chan[i].looped = 0;

        //break;//rem me?
    }
}

void sfx_player_update() {

    int sample;

    for (int ch = 0; ch < SFX_CHAN_NUM; ch++) {

        if (sfx_chan[ch].size == 0) {
            continue;
        }

        if (ppmio.sfx[ch].status.fifo_full) {
            //printf("fifo full\n");
            continue;
        }

        sample = ppmio.flash[sfx_chan[ch].ptr^1]; //use flash_sw


        if (sfx_chan[ch].step_num == 2) {

            if (sfx_chan[ch].step == 0) {
                sample >>= 4;
                sfx_chan[ch].step = 1;
            } else {
                sfx_chan[ch].step = 0;
                sfx_chan[ch].ptr++;
            }

            sample = (((sample & 0x0F) * 65536) / 16) - 32768;

        } else {

            sfx_chan[ch].ptr++;
            sample = (((sample & 0xFF) * 65536) / 256) - 32768;
        }

        ppmio.sfx[ch].sample = sample;

        sfx_chan[ch].size--;

        if (sfx_chan[ch].size == 0 && sfx_chan[ch].looped) {
            sfx_chan[ch].ptr = sfx_chan[ch].ptr_base;
            sfx_chan[ch].size = sfx_chan[ch].size_base;
        }
    }
}
