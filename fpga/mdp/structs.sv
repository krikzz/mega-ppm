
typedef struct{
	
	
	bit dst_mem;
	bit dst_map;
	
	bit ce_rom0;
	bit ce_rom1;
	bit ce_sram;
	bit ce_bram;
	
	bit ce_sys;
	bit ce_fifo;
	bit ce_map;
	bit ce_mcd;
	bit ce_mdp;
	bit ce_mst;
	
	
	bit ce_ggc;
	bit ce_cfg;
	bit ce_sst;
	
	bit ce_mcfg;
	
}PiMap;

//********

typedef struct{
	
	bit [31:0]addr;
	bit [7:0]dato;
	bit oe; 
	bit we;
	bit act;
	bit clk;
	bit sync;
	bit we_sync;
	
	PiMap map;
	
}PiBus;

