

`define CLK_FREQ	50_000_000 //set it in veorv_32_top also
`define MEM_TIME	4//80ns memory
`define SRM_DELAY	0

module top(
	
	inout  [15:0]MD_D,
	input  [23:1]MD_A,
	input  MD_ASn,
	input  MD_CASn,
	input  MD_CEHn,
	input  MD_CELn,
	input  MD_OEn,
	input  MD_WEHn,
	input  MD_WELn,
	input  MD_VCLK,
	input  MD_ECLK,
	inout  MD_SRSTFn,
	output MD_CART,
	output MD_DTAKn,
	output MD_HRSTFn,
	output [3:0]MD_SMS,
	
	output MD_DDIR,
	output MD_DOEn,
	
	output MKEY_ACT,
	output MKEY_SET,
	
	output [21:0]PSR0_A,
	inout  [15:0]PSR0_D,
	output PSR0_OEn,
	output PSR0_WEn,
	output PSR0_LBn,
	output PSR0_UBn,
	output PSR0_CEn,
	
	output [21:0]PSR1_A,
	inout  [15:0]PSR1_D,
	output PSR1_OEn,
	output PSR1_WEn,
	output PSR1_LBn,
	output PSR1_UBn,
	output PSR1_CEn,
	
	output [17:0]SRM_A,
	inout  [15:0]SRM_D,
	output SRM_OEn,
	output SRM_WEn,
	output SRM_LBn,
	output SRM_UBn,
	output SRM_CEn,
	
	output [17:0]BRM_A,
	inout  [15:0]BRM_D,	
	output BRM_OEn,
	output BRM_WEn,
	output BRM_LBn,
	output BRM_UBn,
	
	inout  [9:0]FCI_IO,
	input  FCI_MOSI,
	input  FCI_SCK,
	output FCI_MISO,
	//input  DCLK,//shorted with FCI_SCK
	
	input  FPG_GPCK,
	inout  [4:0]FPG_GPIO,
	
	input  CLK,
	input  BTN,
	output LED_G,
	output LED_R,
	
	output DAC_MCLK, 
	output DAC_LRCK, 
	output DAC_SCLK, 
	output DAC_SDIN
	
);

//************************************************************************************* unused signals
	assign MD_SMS			= 4'bzzzz;
	assign MKEY_ACT		= 1;
	assign MD_HRSTFn		= BTN ? 0 : 1'bz;
	assign MD_SRSTFn		= 1'bz;
//************************************************************************************* bus controll
	assign MD_D 			= MD_DDIR == 0	? 16'hzzzz : cpu_dati;
	assign MD_DTAKn		= dtak ? 0 : 1'bz;
	assign MD_SRSTFn		= md_rst ? 0 : 1'bz;
	assign MD_DDIR			= md_bus_oe ? 1 : 0;
	assign MD_DOEn			= 0;
//************************************************************************************* memory map
	assign SRM_D			= wrm_oe ? 16'hzzzz : wrm_dati;
	assign SRM_A			= wrm_addr[18:1];
	assign SRM_WEn			= !(wrm_we != 0);
	assign SRM_OEn			= !wrm_oe;
	assign SRM_CEn			= !wrm_ce;
	assign SRM_LBn			= !(wrm_oe | wrm_we[1]);
	assign SRM_UBn			= !(wrm_oe | wrm_we[0]);
	
	
	assign PSR0_D			= fla_oe ? 16'hzzzz : fla_dati;
	assign PSR0_A			= fla_addr[22:1];
	assign PSR0_WEn		= !(fla_we != 0);
	assign PSR0_OEn		= !fla_oe;
	assign PSR0_CEn		= !fla_ce;
	assign PSR0_LBn		= !(fla_oe | fla_we[1]);
	assign PSR0_UBn		= !(fla_oe | fla_we[0]);
	
	
	assign PSR1_D			= sdr_oe ? 16'hzzzz : sdr_dati;
	assign PSR1_A			= sdr_addr[20:1];
	assign PSR1_WEn		= !(sdr_we != 0);
	assign PSR1_OEn		= !sdr_oe;
	assign PSR1_CEn		= !sdr_ce;
	assign PSR1_LBn		= !(sdr_oe | sdr_we[1]);
	assign PSR1_UBn		= !(sdr_oe | sdr_we[0]);
	
	
	assign BRM_D			= brm_oe ? 16'hzzzz : brm_dati;
	assign BRM_A			= brm_addr[12:1];
	assign BRM_WEn			= !(brm_we != 0);
	assign BRM_OEn			= !brm_oe;
	assign BRM_LBn			= !(brm_ce & (brm_oe | brm_we[1]));
	assign BRM_UBn			= !(brm_ce & (brm_oe | brm_we[0]));

//************************************************************************************* ed mcu controls	
	wire use_mdp			= !exit_to_menu;
	//assign FCI_IO[2] 		= 1;//mcu fifo interface (unused, should be 1)
	assign FCI_IO[4] 		= !use_mdp;//mcu master mode (unused, should be 1)
	assign FCI_IO[0] 		= !use_mdp;//mdp handler enable
	assign FCI_IO[6]		= exit_to_menu;
//************************************************************************************* game core
	wire [15:0]cpu_dato	= MD_D;
	wire [15:0]cpu_dati;
	wire md_bus_oe;
	wire dtak;
	wire md_rst;
	
	
	wire [15:0]wrm_dato	= SRM_D;
	wire [15:0]wrm_dati;
	wire [18:0]wrm_addr;
	wire [1:0]wrm_we;
	wire wrm_oe;
	wire wrm_ce;
	
	wire [15:0]fla_dato	= PSR0_D;
	wire [15:0]fla_dati;
	wire [22:0]fla_addr;
	wire [1:0]fla_we;
	wire fla_oe;
	wire fla_ce;
	
	wire [15:0]sdr_dato	= PSR1_D;
	wire [15:0]sdr_dati;
	wire [20:0]sdr_addr;
	wire [1:0]sdr_we;
	wire sdr_oe;
	wire sdr_ce;
	
	wire [15:0]brm_dato	= BRM_D;
	wire [15:0]brm_dati;
	wire [12:0]brm_addr;
	wire [1:0]brm_we;
	wire brm_oe;
	wire brm_ce;
	
	wire snd_clk;
	wire snd_next_sample;
	wire [8:0]snd_phase;
	wire signed[15:0]snd_l;
	wire signed[15:0]snd_r;
	
	wire exit_to_menu;
	
	wire sys_clk	= CLK;
	
	
	
	paprium paprium_inst(

		.clk(sys_clk), 
		.rst(BTN),
		
		.cpu_dato(cpu_dato),
		.cpu_dati(cpu_dati),
		.cpu_addr(MD_A),
		.as(MD_ASn),
		.cas(MD_CASn), 
		.ce_lo(MD_CELn), 
		.ce_hi(MD_CEHn),
		.vclk(MD_VCLK),
		.eclk(MD_ECLK),
		.oe(MD_OEn),
		.srst(MD_SRSTFn),
		.we_lo(MD_WELn),
		.we_hi(MD_WEHn),
		
		.cart(MD_CART),
		.dtak(dtak),
		.md_rst(md_rst),
		
		.md_bus_oe(md_bus_oe),
		
		.wrm_dato(wrm_dato),
		.wrm_dati(wrm_dati),
		.wrm_addr(wrm_addr),
		.wrm_we(wrm_we),
		.wrm_oe(wrm_oe),
		.wrm_ce(wrm_ce),
		
		.fla_dato(fla_dato),
		.fla_dati(fla_dati),
		.fla_addr(fla_addr),
		.fla_we(fla_we),
		.fla_oe(fla_oe),
		.fla_ce(fla_ce),
		
		.sdr_dato(sdr_dato),
		.sdr_dati(sdr_dati),
		.sdr_addr(sdr_addr),
		.sdr_we(sdr_we),
		.sdr_oe(sdr_oe),
		.sdr_ce(sdr_ce),
		
		.brm_dato(brm_dato),
		.brm_dati(brm_dati),
		.brm_addr(brm_addr),
		.brm_we(brm_we),
		.brm_oe(brm_oe),
		.brm_ce(brm_ce),
		
		.snd_clk(snd_clk),
		.snd_next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_l(snd_l),
		.snd_r(snd_r),
		
		.mosi(FCI_MOSI),
		.ss(FCI_IO[1]),
		.spi_clk(FCI_SCK),
		.miso(FCI_MISO),
		.fifo_rxf(FCI_IO[2]),
		
		.uart_rx(FPG_GPIO[1]),
		.uart_tx(FPG_GPIO[0]),
		.led_r(LED_R),
		.led_g(LED_G),
		
		.exit(exit_to_menu)
		
	);
	
//************************************************************************************* audio dac
	assign DAC_SCLK	= 1;
	
	audio_out_i2s audio_out_inst(

		.clk(sys_clk),
		.snd_clk(snd_clk),
		.snd_next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_l(snd_l),
		.snd_r(snd_r),
		
		.dac_mclk(DAC_MCLK),
		.dac_lrck(DAC_LRCK),
		.dac_sdin(DAC_SDIN)
	);
	
	
endmodule

