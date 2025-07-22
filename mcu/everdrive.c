
#include "appmain.h"

#define STATUS_KEY      0x5A
#define PROTOCOL_ID     0x05

#define CMD_STATUS      0x10
#define CMD_GET_MODE    0x11
#define CMD_IO_RST      0x12
#define CMD_GET_VDC     0x13
#define CMD_RTC_GET     0x14
#define CMD_RTC_SET     0x15
#define CMD_FLA_RD      0x16
#define CMD_FLA_WR      0x17
#define CMD_FLA_WR_SDC  0x18
#define CMD_MEM_RD      0x19
#define CMD_MEM_WR      0x1A
#define CMD_MEM_SET     0x1B
#define CMD_MEM_TST     0x1C
#define CMD_MEM_CRC     0x1D
#define CMD_FPG_USB     0x1E
#define CMD_FPG_SDC     0x1F
#define CMD_FPG_FLA     0x20
#define CMD_RTC_CAL     0x21
#define CMD_USB_WR      0x22
#define CMD_FIFO_WR     0x23
#define CMD_UART_WR     0x24
#define CMD_REINIT      0x25
#define CMD_SYS_INF     0x26
#define CMD_GAME_CTR    0x27
#define CMD_UPD_EXEC    0x28
#define CMD_HOST_RST    0x29
//**********************0x2A CMD_USB_STATUS
#define CMD_RAPP_SET    0x2B
#define CMD_SUB_STATUS  0x2C
//**********************0x2D CMD_BRAM_SAVE
#define CMD_EFU_UNPACK  0x2E//install menu to sd from flash
#define CMD_EFU_UPDATE  0x2F//write efu to flash
//**********************0x30 CMD_CALC_FILT
#define CMD_ROM_PATH    0x31
#define CMD_EFU_UNFILE  0x32//install menu to sd from file

#define CMD_STATUS2     0x40//do not implement for modern devices
#define CMD_CD_MOUNT    0x41

#define CMD_DISK_INIT   0xC0
#define CMD_DISK_RD     0xC1
#define CMD_DISK_WR     0xC2
#define CMD_F_DIR_OPN   0xC3
#define CMD_F_DIR_RD    0xC4
#define CMD_F_DIR_LD    0xC5
#define CMD_F_DIR_SIZE  0xC6
#define CMD_F_DIR_PATH  0xC7
#define CMD_F_DIR_GET   0xC8
#define CMD_F_FOPN      0xC9
#define CMD_F_FRD       0xCA
#define CMD_F_FRD_MEM   0xCB
#define CMD_F_FWR       0xCC
#define CMD_F_FWR_MEM   0xCD
#define CMD_F_FCLOSE    0xCE
#define CMD_F_FPTR      0xCF
#define CMD_F_FINFO     0xD0
#define CMD_F_FCRC      0xD1
#define CMD_F_DIR_MK    0xD2
#define CMD_F_DEL       0xD3
#define CMD_F_SEEK_IDX  0xD4
#define CMD_F_AVB       0xD5
#define CMD_F_FCP       0xD6
//#*********************0xD7 CMD_F_FMV
#define CMD_F_SEEK_PAT  0xD8 //seek data pattern
#define CMD_F_DTEST     0xD9 //check if dir exists
#define CMD_F_FTEST     0xDA //check if file exists

#define ACK_BLOCK_SIZE  1024


#define ERR_UNXP_STAT           0x40
#define ERR_NULL_PATH           0x41
#define ERR_PATH_SIZE           0x42
#define ERR_NAME_SIZE           0x43

typedef struct {
    vu32 data;

    struct {
        vu32 const01 : 6;
        vu32 arm_rxf : 1; //arm fifo empty
        vu32 cpu_rxf : 1; //cpu fifo empty
    } status;

} EdFifo;

typedef struct {
    u8 status_key;
    u8 protocol_id;
    u8 device_id;
    u8 status;
} EdioStatus;

#define EDFIFO  ((EdFifo *) ADDR_FIFO)

void ed_cmd_tx(u8 cmd);
void ed_fifo_wr(void *data, u16 len);
void ed_fifo_rd(void *data, u16 len);
void ed_cmd_status2(void *status);
u8 ed_check_status();
u16 ed_swap16(u16 val);
u16 ed_rx16();
void ed_tx16(u16 val);

void ed_cmd_tx(u8 cmd) {

    EDFIFO->data = '+';
    EDFIFO->data = '+' ^ 0xff;
    EDFIFO->data = cmd;
    EDFIFO->data = cmd ^ 0xff;
}

void ed_fifo_flush() {

    vu8 tmp;
    EDFIFO->data = 0;
    EDFIFO->data = 0;
    while (!EDFIFO->status.cpu_rxf) {
        tmp = EDFIFO->data;
    }
    tmp++;
}

void ed_fifo_wr(void *data, u16 len) {

    while (len--) {
        EDFIFO->data = *(u8 *) data++;
    }
}

void ed_fifo_rd(void *data, u16 len) {

    while (len--) {

        while (EDFIFO->status.cpu_rxf) {
            asm("nop");
        }
        *(u8 *) data++ = EDFIFO->data;
    }
}

void ed_fifo_rd_skip(u16 len) {

    vu8 tmp;

    while (len--) {

        while (EDFIFO->status.cpu_rxf) {
            asm("nop");
        }

        tmp = EDFIFO->data;
    }

    tmp++;
}

u16 ed_swap16(u16 val) {

    return (val >> 8) | (val << 8);
}

u16 ed_rx16() {

    u16 val;
    ed_fifo_rd(&val, 2);

    return ed_swap16(val);
}

void ed_tx16(u16 val) {

    val = ed_swap16(val);
    ed_fifo_wr(&val, 2);
}

void ed_rx_string(u8 *string) {

    u16 str_len = ed_rx16();

    if (string == 0) {
        ed_fifo_rd_skip(str_len);
        return;
    }

    string[str_len] = 0;

    ed_fifo_rd(string, str_len);
}

void ed_tx_string(u8 *string) {

    u16 str_len = 0;
    u8 *ptr = string;

    while (*ptr++ != 0)str_len++;

    ed_tx16(str_len);
    ed_fifo_wr(string, str_len);
}

void ed_cmd_status2(void *status) {

    ed_cmd_tx(CMD_STATUS2);
    ed_fifo_rd(status, 4);
}

u8 ed_check_status() {

    EdioStatus stat;

    ed_cmd_status2(&stat);

    if (stat.status_key != STATUS_KEY) {
        return ERR_UNXP_STAT;
    }

    return stat.status;
}

u8 ed_cmd_rom_path(u8 *path, u8 path_type) {

    ed_cmd_tx(CMD_ROM_PATH);
    ed_fifo_wr(&path_type, 1); //0-rom, 1-cue
    ed_rx_string(path);
    return ed_check_status();
}

u8 ed_cmd_cd_mount(u8 *path) {

    ed_cmd_tx(CMD_CD_MOUNT);
    ed_tx_string(path);
    return ed_check_status();
}