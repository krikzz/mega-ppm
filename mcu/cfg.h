
//****************************************************************************** types

#define u8      uint8_t
#define u16     uint16_t
#define u32     uint32_t
#define u64     uint64_t

#define vu8     volatile uint8_t
#define vu16    volatile uint16_t
#define vu32    volatile uint32_t
#define vu64    volatile uint64_t

#define s32     int32_t
#define s16     int16_t
#define s64     int64_t

#define vs32     volatile int32_t
#define vs16     volatile int16_t
#define vs64     volatile int64_t

#define bool    u8
#define true    1
#define false   0
//****************************************************************************** 

#define BAUD_RATE       921600
    
#define ADDR_FPGIO      0x1000000
#define ADDR_RAMDP      0x2000000
#define ADDR_SDR        0x3000000
#define ADDR_FLA        0x4000000
#define ADDR_BRM        0x5000000
#define ADDR_SFX        0x6000000
#define ADDR_MDP        0x7000000
#define ADDR_FIFO       0x7800000