
// baswed on https://github.com/TheHpman/mame/blob/master/src/devices/bus/megadrive/rom.cpp
/* 
 * File:   mame.h
 * Author: Igor
 *
 * Created on July 19, 2025, 12:11 PM
 */

#ifndef MAME_H
#define	MAME_H

typedef struct {
    vu16 autoinc;
    vu16 lenH;
    vu16 lenL;
    vu16 srcH;
    vu16 srcM;
    vu16 srcL;
    vu16 cmdH;
    vu16 cmdL;
} ppm_dma_cmd;

typedef struct { //VDP specs
    vu16 posY;
    vu16 sizeNext;
    vu16 attrs;
    vu16 posX;
} ppm_sat_item;

typedef struct {
    vu16 anim;
    vu16 nextAnim;
    vu16 objID; //b15 = fresh assign ?
    vu16 field_6;
    vu16 attrs;
    vu16 animCounter;
    vu16 posX;
    vu16 posY;
} ppm_intf_obj;

typedef struct {
    u16 vectors[0x80]; //0x000 68k vectors table
    u16 rom_hdr[0x80]; //0x100 megadrive header data
    u16 scaling_buff[0x300]; //0x200
    u16 save_buff[0x100]; //0x800 also part of scaling data
    u16 _pad1[0x80]; //0xa00
    ppm_sat_item sat_data[144];//0xb00 // sprite allocation table sits here
    ppm_intf_obj obj_data[64]; // objects table
    u16 _pad2[0x40];
    // 0x1400
    ppm_dma_cmd dma_cmd[121];
    u16 audio_data[0x70 / 2];
    u16 net_data[0x108];

    union {
        u16 cmd_args[128];
        u32 cmd_args_long[64];
    };

    vu16 dma_total; // total size in words
    vu16 dma_budget; // per frame budget (depends on system)
    vu16 dma_remaining; // remaining budget for current frame
    vu16 dma_cmd_count;
    vu16 sat_count; // # of items present in SAT table
    vu16 unk_1f1a;
    vu16 unk_1f1c;
    vu16 unk_1f1e;
    vu16 buff[0x60];
    // main registers
    u16 reg_unk0; // 1fe0
    u16 reg_unk1; // 1fe2
    vu16 reg_status_1; // 1fe4

    struct {

        union {
            vu16 word;

            struct {
                vu16 mwire_status : 3;
                vu16 bit_3 : 1;
                // sub_9B738
                vu16 bit_4 : 1; // MW? send a900 if set
                vu16 mwire_data_in : 1; // MW ack ?
                vu16 bit_6 : 1;
                vu16 bit_7 : 1;

                vu16 eep_error1 : 1; // b8 sum error?
                vu16 eep_error2 : 1; // b9 eepr error?
                vu16 bit_10 : 1;
                vu16 bit_11 : 1;

                vu16 bit_12 : 1;
                vu16 bit_13 : 1;
                vu16 busy : 1; // b14 task busy
                vu16 bit_15 : 1;
            } bits;
        };
    } reg_status_2; // 1fe6

    u16 reg_unk4; // 1fe8
    vu16 reg_cmd; //0x1fea
    u16 reg_wdog; // unconfirmed
    u16 reg_unk_1fee; // 1fee
    u16 reg_unk_1ff0; // 1ff0
    u16 reg_unk_1ff2; // 1ff2
    u16 reg_unk_1ff4; // 1ff4
    u16 reg_unk_1ff6; // 1ff6
    u16 reg_unk_1ff8; // 1ff8
    u16 reg_unk_1ffa; // 1ffa
    u16 reg_unk_1ffc; // 1ffc
    u16 reg_unk_1ffe; // 1ffe

} ppm_ramdp;

typedef struct {
    uint16_t block_num;
    uint16_t usage;
    uint16_t age;
} ppm_vram_slot;

typedef struct {
    uint32_t offset;
    uint16_t attributes;
    uint16_t length;
} ppm_sfx;

typedef struct {
    uint32_t anim_offset; //
    uint32_t lastDisplayedOffset; //
    uint16_t crtAnim;
    uint16_t counter;
} ppm_obj;

typedef struct { //byteswapped (endianess fix)
    int8_t posY;
    int8_t posX;
    int8_t flipPosX;
    uint8_t size; //lower nibble
    uint16_t blockNum;
    uint8_t offset; //block offset
    uint8_t attrs; //flip posY?
} ppm_spr_data;

typedef struct { //byteswapped (endianess fix)
    uint8_t flags;
    uint8_t count;
    ppm_spr_data sprites[];
} ppm_spr_data_hdr;

void ppm_init_mame();
u32 swapshorts(u32 val);
void ppm_setup_data(uint32_t bgm_file, uint32_t unk1_file, uint32_t smp_file, uint32_t unk2_file, uint32_t sfx_file, uint32_t anm_file, uint32_t blk_file);
void ppm_obj_add(uint8_t num);
void ppm_obj_frame_start();
void ppm_obj_frame_end();
void ppm_obj_reset();
void ppm_vram_set_budget(uint16_t blocks);
u32 ppm_block_addr(u32 num);
u32 ppm_bgm_addr(u32 num);
uint32_t ppm_unpack(uint32_t source_addr, uint32_t dest_addr);
uint32_t ppm_unpack_scal(uint32_t source_addr, uint32_t dest_addr, u8 is_scaling_stamp);
void ppm_stamp_rescale(uint16_t window_start, uint16_t window_end, uint16_t factor, uint16_t stamp_offset);

extern u32 ppm_sfx_base_addr;
extern u32 ppm_bgm_unpack_addr;

#endif	/* MAME_H */

