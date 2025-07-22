
typedef struct{
	
	bit [15:0]dati;
	bit [23:0]addr;
	bit [1:0]we;
	bit oe;
	
}MemBus;


typedef struct{
	
	bit [31:0]dato;
	bit [31:0]addr;
	bit [3:0]we;
	bit oe;
	bit ce;
	bit clk;
	McuMap map;
	
}McuBus;

typedef struct{//mcu memory map
	
	bit wrom;
	bit wram;
	bit fpgio;
	bit ramdp;
	bit sdram;
	bit flash;
	bit bram;
	bit sfx;
	bit mdp;
	
	bit fpgio_ctrl;//var control flags
	bit fpgio_time;//timer
	bit fpgio_sptr;//sdram ptr 
	bit fpgio_vols;//sfx vol
	bit fpgio_volb;//bgm vol
	
	bit mdp_ctrl;//md+ core control
	bit mdp_fifo;//link to everdrive mcu
	
}McuMap;


typedef struct{
	
	bit [15:0]dato;
	bit [23:0]addr;
	bit as;
	bit oe;
	bit we_hi;
	bit we_lo;
	bit ce_hi;
	bit ce_lo;
	bit tim;
	bit vclk;
	
	CpuMap map;
	
}CpuBus;


typedef struct{
	
	bit ramdp;
	bit sdram;
	bit flash;
	
}CpuMap;


typedef struct{

	bit clk;
	bit next_sample;
	bit [8:0]phase;
	
}SndCk;


typedef struct{

	bit [1:0]status;
	bit [7:0]pan[2];
	bit [10:0]vol;
	bit signed[15:0]pcm;
	
}SfxOut;

typedef struct{
	SfxOut sfx[8];
}SfxBank;