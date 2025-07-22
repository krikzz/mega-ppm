
#include "appmain.h"

#define MDP_TIMEOUT     100
#define MDP_OK          0
#define MDP_ERR_TOUT    1
#define MDP_ERR_ID      2
#define MDP_ERR_NOCD    3

#define MDP_CMD_VER     0x1000
#define MDP_CMD_PLAY_S  0x1100
#define MDP_CMD_PLAY_L  0x1200
#define MDP_CMD_PLAY_D  0x1A00 //loop offsed in args
#define MDP_CMD_PLAY_X  0x1B00
#define MDP_CMD_PAUSE   0x1300
#define MDP_CMD_RESUME  0x1400
#define MDP_CMD_VOL     0x1500
#define MDP_CMD_STAT    0x1600
#define MDP_CMD_TNUM    0x2700

#define MDP_OVLKEY      0xCD54
#define MDP_ID0         0x5241
#define MDP_ID1         0x5445

typedef struct {
    vu16 id[2];
    vu16 overlay;
    vu16 resp;
    vu16 cmd;
    u8 data[4096];
} Mdp;

#define MDP             ((Mdp *) (ADDR_MDP + 0x3F7F6))

u8 mdp_cmd(u16 cmd);
u8 mdp_init_();

u8 mdp_on;

void mdp_init() {

    u8 resp = mdp_init_();

    if (resp) {
        printf("mdp error: %x\n", resp);
    }
}

u8 mdp_init_() {

    u8 resp;
    printf("mdp init...\n");

    mdp_on = 0;


    MDP->overlay = MDP_OVLKEY; //unlock md+ overlay

    if (MDP->id[0] != MDP_ID0 || MDP->id[1] != MDP_ID1) {
        return MDP_ERR_ID;
    }

    u8 cue_path[1024];
    ed_fifo_flush();
    resp = ed_cmd_rom_path(cue_path, 1);
    if (resp)return resp;
    if (cue_path[0] == 0)return MDP_ERR_NOCD;
    
    printf("cd mount... %s\n", cue_path);
    resp = ed_cmd_cd_mount(cue_path);
    if (resp)return resp;


    /*
    printf("mdp id: %x\n", (MDP->id[0] << 16) | MDP->id[1]);

    if (MDP->id[0] != MDP_ID0 || MDP->id[1] != MDP_ID1) {
        return MDP_ERR_ID;
    }

    resp = mdp_cmd(MDP_CMD_TNUM);
    if (resp)return resp;
    printf("tacks : %i\n", MDP->resp >> 8);

    resp = mdp_cmd(MDP_CMD_STAT);
    if (resp)return resp;
    printf("status: %x\n", MDP->resp);*/

    resp = mdp_cmd(MDP_CMD_PAUSE);
    if (resp)return resp;

    mdp_set_vol(0xff);

    mdp_on = 1;

    return MDP_OK;
}

void mdp_play(u8 track) {

    if (!mdp_on) {
        return;
    }

    MDP->cmd = MDP_CMD_PLAY_L | track;
}

void mdp_stop() {

    if (!mdp_on) {
        return;
    }

    MDP->cmd = MDP_CMD_PAUSE; // | fade;
}

void mdp_set_vol(u8 vol) {

    MDP->cmd = MDP_CMD_VOL | vol;
}

u8 mdp_cmd(u16 cmd) {

    u32 time = FPGAIO->time + MDP_TIMEOUT;

    MDP->cmd = cmd;
    asm("nop");

    while (MDP->cmd == 0xffff) {
        if (FPGAIO->time > time) {
            return MDP_ERR_TOUT;
        }
    }

    return MDP_OK;
}