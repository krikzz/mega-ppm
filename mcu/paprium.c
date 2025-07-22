
#include "appmain.h"


void ppm_reset();
void ppm_md_rst(u8 rst);
void ppm_init_cmd_ptr();
void ppm_cmd_handler();
void cmd_unknown();
void cmd_unknown_muted();
void cmd_00();
void cmd_81_init();
void cmd_84_sdram_off();
void cmd_8C_bgm_play();
void cmd_8D_bgm_cfg();
void cmd_AD_obj_add();
void cmd_AE_frame_start();
void cmd_AF_frame_end();
void cmd_B1_sprite_pause();
void cmd_C6_setup_data();
void cmd_C9_vol_bgm();
void cmd_CA_vol_sfx();
void cmd_D1_sfx_play();
void cmd_D2_sfx_stop();
void cmd_D3_sfx_loop();
void cmd_D5_sfx_stopall();
void cmd_DA_unpack();
void cmd_DB_set_dma_ptr();
void cmd_DF_eep_rd();
void cmd_E0_eep_wr();
void cmd_E7_mwire();
void cmd_EC_vram_budget();
void cmd_F2_unpack();
void cmd_F4_unpack_scal();
void cmd_F5_stamp_rescale();

void sfx_player_update();

ppm_io ppmio;
u32 tick_ctr;

void (*cmp_ptr[256])();

void ppm_start() {

    tick_ctr = 0;
    ppm_reset();

    printf("\n");

    while (1) {

        ppm_cmd_handler();
        sfx_player_update();
        tick_ctr++;

        if (FPGAIO->ctrl.md_rst_status) {
            return;
        }
    }
}

void ppm_reset() {

    ppm_md_rst(1);
    FPGAIO->ctrl.sdram_en = 1;
    FPGAIO->sdram_ptr = 0;

    printf("ppm init...\n");

    ppmio.ramdp = (ppm_ramdp *) ADDR_RAMDP;
    ppmio.flash = (u8 *) ADDR_FLA;
    ppmio.sdram = (u8 *) ADDR_SDR;
    ppmio.bram = (u8 *) ADDR_BRM;
    ppmio.sfx = (SfxIO *) ADDR_SFX;

    memcpy(ppmio.ramdp, ppmio.flash, 8192);

    ppmio.ramdp->reg_cmd = 0;
    ppmio.ramdp->reg_status_1 = 0;
    ppmio.ramdp->reg_status_2.word = 0;
    ppmio.ramdp->reg_status_2.bits.mwire_status = 7; // let's pretend MW is plugged & connected

    // boot check
    ((u16 *) ppmio.ramdp)[0x1d1c / 2] = 0x0004; //SWAP_WORD(0x0004); // 0xc00004
    ((u16 *) ppmio.ramdp)[0x1d2c / 2] |= 0x0100; //SWAP_WORD(0x0100); // switch to beq.s (0x670e)

    // post splash jump location
    ((u16 *) ppmio.ramdp)[0x1562 / 2] = 0x0001; //SWAP_WORD(0x0001);
    ((u16 *) ppmio.ramdp)[0x1564 / 2] = 0x0100; //SWAP_WORD(0x0100);

    ppm_init_mame();
    ppm_init_cmd_ptr();

    mdp_init();

    FPGAIO->vol_sfx = 0xff;
    FPGAIO->vol_bgm = 0xff;

    //rom patches  (flash should be writable)
    *(u16 *)&ppmio.flash[0x81104] = 0x4e71; // emulator check
    //printf("f: %x\n", *(u32 *) & ppmio.flash[0x81104]);


    //printHex((u8 *) 0x00000, 128);
    //printHex((u8 *) 0x10000, 128);

    //should be last init step
    printf("rom ver: %x\n", *(u16 *) & ppmio.flash[0x1000a]);
    ppm_md_rst(0);
}

void ppm_md_rst(u8 rst) {

    if (rst) {
        FPGAIO->ctrl.md_rst = 1;
    } else {

        FPGAIO->ctrl.md_rst = 0;

        while (FPGAIO->ctrl.md_rst_status) {

            FPGAIO->ctrl.md_rst_status = 0;
            asm("nop");
        }
    }
}

void ppm_init_cmd_ptr() {

    for (int i = 0; i < 256; i++) {
        cmp_ptr[i] = cmd_unknown;
    }

    cmp_ptr[0x83] = cmd_unknown_muted; // unk startup thing
    cmp_ptr[0x88] = cmd_unknown_muted; // set audio config
    cmp_ptr[0x95] = cmd_unknown_muted; // (bgm related)
    cmp_ptr[0x96] = cmd_unknown_muted; // (bgm related)
    cmp_ptr[0xA4] = cmd_unknown_muted; // megawire settings
    //cmp_ptr[0xB1] = cmd_unknown_muted; // seems used to keep previous SAT data in VRAM, do nothing?
    cmp_ptr[0xB6] = cmd_unknown_muted; // likely instructs to restore boot code to allow back HW reset
    cmp_ptr[0xD6] = cmd_unknown_muted; //???

    //unknown stuff
    cmp_ptr[0xB0] = cmd_unknown_muted;
    cmp_ptr[0xD0] = cmd_unknown_muted;

    cmp_ptr[0x00] = cmd_00;
    cmp_ptr[0x81] = cmd_81_init;
    cmp_ptr[0x84] = cmd_84_sdram_off;
    cmp_ptr[0x8C] = cmd_8C_bgm_play;
    cmp_ptr[0x8D] = cmd_8D_bgm_cfg;
    cmp_ptr[0xAD] = cmd_AD_obj_add;
    cmp_ptr[0xAE] = cmd_AE_frame_start;
    cmp_ptr[0xAF] = cmd_AF_frame_end;
    cmp_ptr[0xB1] = cmd_B1_sprite_pause;
    cmp_ptr[0xC6] = cmd_C6_setup_data;
    cmp_ptr[0xDA] = cmd_DA_unpack;
    cmp_ptr[0xDB] = cmd_DB_set_dma_ptr;
    cmp_ptr[0xDF] = cmd_DF_eep_rd;
    cmp_ptr[0xE0] = cmd_E0_eep_wr;
    cmp_ptr[0xE7] = cmd_E7_mwire;
    cmp_ptr[0xEC] = cmd_EC_vram_budget;
    cmp_ptr[0xF2] = cmd_F2_unpack;
    cmp_ptr[0xF4] = cmd_F4_unpack_scal;
    cmp_ptr[0xF5] = cmd_F5_stamp_rescale;

    cmp_ptr[0xC9] = cmd_C9_vol_bgm;
    cmp_ptr[0xCA] = cmd_CA_vol_sfx;
    cmp_ptr[0xD1] = cmd_D1_sfx_play;
    cmp_ptr[0xD2] = cmd_D2_sfx_stop;
    cmp_ptr[0xD3] = cmd_D3_sfx_loop;
    cmp_ptr[0xD5] = cmd_D5_sfx_stopall;
}
//============================================================================== cmd handler

u16 cmd_resp;

void ppm_cmd_handler() {

    if (ppmio.ramdp->reg_cmd == 0) {
        return;
    }

    ppmio.ramdp->reg_status_1 |= 0x0004;
    ppmio.ramdp->reg_status_2.bits.busy = 1;

    u8 cmd = ppmio.ramdp->reg_cmd >> 8;

    cmd_resp = 0;

    cmp_ptr[cmd]();

    ppmio.ramdp->reg_status_1 &= ~0x0004;
    ppmio.ramdp->reg_status_2.bits.busy = 0;

    ppmio.ramdp->reg_cmd = cmd_resp;
}

void cmd_unknown() {

    printf("unknown cmd: %x\n", ppmio.ramdp->reg_cmd);
}

void cmd_unknown_muted() {
    //cmd_unknown();
}

void cmd_00() {

    u8 arg = ppmio.ramdp->reg_cmd;

    if (arg == 0xaa) {
        cmd_resp = 0x00ff;
    } else {
        cmd_resp = 0x0000;
    }
}

void cmd_81_init() {

    // initial startup/reset? - 3 0w8100 writes on startup
    // finding arcade mode sends 0x810f

    FPGAIO->ctrl.sdram_en = 1;
    ppm_vram_set_budget(0);
    ppm_obj_reset();
}

void cmd_84_sdram_off() {
    FPGAIO->ctrl.sdram_en = 0;
}

void cmd_AD_obj_add() {

    u8 arg = ppmio.ramdp->reg_cmd;

    ppm_obj_add(arg);
}

void cmd_AE_frame_start() {
    // frame begin
    ppm_obj_frame_start();
}

void cmd_AF_frame_end() {

    // frame finish
    // af01: no scaling ongoing
    // af02: must reserve bandwith for scaling buffer?

    ppm_obj_frame_end();
}

void cmd_B1_sprite_pause() {

    if (ppmio.ramdp->sat_count == 0) {
        memset(&ppmio.ramdp->sat_data[0], 0, 8);
    }
}

void cmd_C6_setup_data() {

    // load/setup base data

    u32 time = FPGAIO->time;

    printf("===== data setup =====\n");


    ppm_setup_data(
            swapshorts(ppmio.ramdp->cmd_args_long[0]),
            swapshorts(ppmio.ramdp->cmd_args_long[1]),
            swapshorts(ppmio.ramdp->cmd_args_long[2]),
            swapshorts(ppmio.ramdp->cmd_args_long[3]),
            swapshorts(ppmio.ramdp->cmd_args_long[4]),
            swapshorts(ppmio.ramdp->cmd_args_long[5]),
            swapshorts(ppmio.ramdp->cmd_args_long[6])
            );

    time = FPGAIO->time - time;
    printf("setup time: %i\n", time); //just for mcu core speed test
    printf("======================\n");
}

void cmd_DA_unpack() {

    // unpack request

    u32 src = (ppmio.ramdp->cmd_args[1] << 16) + ppmio.ramdp->cmd_args[2];
    u32 dst = ppmio.ramdp->cmd_args[0];

    ppm_unpack(src, dst);
    FPGAIO->sdram_ptr = ppmio.ramdp->cmd_args[0]; // optional ?
}

void cmd_DB_set_dma_ptr() {
    // setup sdram pointer for read
    FPGAIO->sdram_ptr = swapshorts(ppmio.ramdp->cmd_args_long[0]);
}

void cmd_DF_eep_rd() {

    u8 arg = ppmio.ramdp->reg_cmd;

    u8 *ram_dp = (u8 *) ppmio.ramdp;

    switch (arg) {
        case 1:
        case 2:
        case 3:
            memcpy(&ram_dp[ppmio.ramdp->cmd_args[0]], &ppmio.bram[(0x200 + arg * 0x200)], 0x100);
            break;
        case 4:
            memcpy(&ram_dp[ppmio.ramdp->cmd_args[0]], &ppmio.bram[0], 0x200);
            break;
    }

    /*
    printf("eep rd %i: ", arg);
    //u32 *ptr = (u32 *) & ram_dp[ppmio.ramdp->cmd_args[0]];
    u32 *ptr = (u32 *) & ppmio.bram[(arg * 0x200)];
    for (int i = 0; i < 32 / 4; i++) {
        printf("%x", ptr[i]);
    }
    printf("\n", arg);*/
}

void cmd_E0_eep_wr() {

    // eeprom save (command_args[0]=0xbeef)

    u8 arg = ppmio.ramdp->reg_cmd;

    u8 *ram_dp = (u8 *) ppmio.ramdp;

    switch (arg) {
        case 1:
        case 2:
        case 3:
            memcpy(&ppmio.bram[(0x200 + arg * 0x200)], &ram_dp[ppmio.ramdp->cmd_args[1]], 0x100);
            break;
        case 4:
            memcpy(&ppmio.bram[0], &ram_dp[ppmio.ramdp->cmd_args[1]], 0x200);
            break;
    }

    ppmio.ramdp->reg_status_2.bits.eep_error1 = 0;
    ppmio.ramdp->reg_status_2.bits.eep_error2 = 0;

}

void cmd_E7_mwire() {

    // send some data over network
    ppmio.ramdp->reg_status_2.bits.mwire_data_in = 1; // pretend data is in
    ppmio.ramdp->net_data[0x10 / 2] = ppmio.ramdp->cmd_args[0] + 16; // pretend 16 bytes in?
}

void cmd_EC_vram_budget() {

    // set vram block budget

    //u16 blocks = SWAP_WORD(ppmio.ramdp->cmd_args[1]);
    u16 blocks = ppmio.ramdp->cmd_args[1];
    ppm_vram_set_budget(blocks);

    if (ppmio.ramdp->cmd_args[0]) {
        printf("PPM command 0xec: unk arg 0 (0x%x)", ppmio.ramdp->cmd_args[0]);
    }
}

void cmd_F2_unpack() {

    // todF2o: check block range
    //used in sprites test menu

    ppm_unpack(ppm_block_addr(ppmio.ramdp->cmd_args[0]), 0x9000);
    ppm_unpack(ppm_block_addr(ppmio.ramdp->cmd_args[0]), 0x9200);
    //ppm_sdram_pointer = &ppm_sdram[0x9000 / 2];
    FPGAIO->sdram_ptr = 0x9000;
}

void cmd_F4_unpack_scal() {
    ppm_unpack_scal(swapshorts(ppmio.ramdp->cmd_args_long[0]), 0, true);
}

void cmd_F5_stamp_rescale() {
    ppm_stamp_rescale(ppmio.ramdp->cmd_args[0], ppmio.ramdp->cmd_args[1], ppmio.ramdp->cmd_args[2], ppmio.ramdp->cmd_args[3]);
}
//============================================================================== audio

void cmd_8C_bgm_play() {

    // bgm play, check & 0x80
    u8 arg = ppmio.ramdp->reg_cmd;
    ppm_unpack(ppm_bgm_addr(arg & 0x7f), ppm_bgm_unpack_addr);

    if ((arg & 0x80)) {
        mdp_play(arg & 0x7f);
    } else {
        mdp_stop();
    }
}

void cmd_8D_bgm_cfg() {

    u8 arg = ppmio.ramdp->reg_cmd;

    if (arg == 0 || arg == 8) {
        mdp_stop();
    }
}

void cmd_C9_vol_bgm() {

    FPGAIO->vol_bgm = ppmio.ramdp->reg_cmd;
}

void cmd_CA_vol_sfx() {
    FPGAIO->vol_sfx = ppmio.ramdp->reg_cmd;
}

void cmd_D1_sfx_play() {

    sfx_play(ppmio.ramdp->reg_cmd);
}

void cmd_D2_sfx_stop() {
    sfx_stop(ppmio.ramdp->reg_cmd);
}

void cmd_D3_sfx_loop() {
    sfx_loop(ppmio.ramdp->reg_cmd);
}

void cmd_D5_sfx_stopall() {
    //not sure about this cmd, but game execute looped sfx at chan 0x40
    //then execute this cmd. looped sfx keep playing on score screen
    sfx_stop(0xC0);
}

//============================================================================== 
