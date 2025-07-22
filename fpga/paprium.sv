
module paprium(

	input clk, 
	input rst,
	
	input  [15:0]cpu_dato,
	output [15:0]cpu_dati,
	input  [23:1]cpu_addr,
	input  as, cas, ce_lo, ce_hi, vclk, eclk, oe, srst, we_lo, we_hi, 
	output cart, dtak, md_rst, 
	
	output md_bus_oe,
	
	//mcu work ram/rom 512k
	input  [15:0]wrm_dato,
	output [15:0]wrm_dati,
	output [18:0]wrm_addr,
	output [1:0]wrm_we,
	output wrm_oe,
	output wrm_ce,
	
	//flash rom 8mb
	input  [15:0]fla_dato,
	output [15:0]fla_dati,
	output [22:0]fla_addr,
	output [1:0]fla_we,
	output fla_oe,
	output fla_ce,
	
	//sdram 2mb
	input  [15:0]sdr_dato,
	output [15:0]sdr_dati,
	output [20:0]sdr_addr,
	output [1:0]sdr_we,
	output sdr_oe,
	output sdr_ce,
	
	//backup memory 8k
	input  [15:0]brm_dato,
	output [15:0]brm_dati,
	output [12:0]brm_addr,
	output [1:0]brm_we,
	output brm_oe,
	output brm_ce,
	
	//audio output
	output snd_clk,
	output snd_next_sample,
	output [8:0]snd_phase,
	output signed[15:0]snd_l,
	output signed[15:0]snd_r,
	
	//everdrive mcu interface (for md+)
	input  mosi,
	input  ss,
	input  spi_clk,
	output miso,
	output fifo_rxf,
	
	//dbg
	input  uart_rx,
	output uart_tx,
	output led_r,
	output led_g,
	
	output exit
	
);

	McuBus mcu;
	CpuBus cpu;
	
//************************************************************************************* cpu (megadrive bus)
	assign cpu.dato[15:0]		= cpu_dato[15:0];
	assign cpu.addr[23:1] 		= cpu_addr[23:1];
	assign cpu.as 					= !as;
	assign cpu.oe 					= !oe;
	assign cpu.we_hi 				= !we_hi;
	assign cpu.we_lo 				= !we_lo;
	assign cpu.ce_hi 				= !ce_hi;
	assign cpu.ce_lo 				= !ce_lo;
	assign cpu.tim 				= {cpu_addr[23:8], 8'd0} == 24'hA13000 & !as ? 1 : 0;
	assign cpu.vclk 				= vclk;
	
	
	assign cart 					= 0;
	assign dtak 					= 0;
	
	assign md_bus_oe				= cpu.oe & (cpu.ce_lo | cpu.tim);
	
	assign cpu.map.ramdp			= cpu.ce_lo & cpu.addr <  8192;
	assign cpu.map.sdram			= cpu.ce_lo & cpu.addr >= 8192 & cpu.addr < 65536 & sdram_en;
	assign cpu.map.flash			= cpu.ce_lo & cpu.addr >= 8192 & !cpu.map.sdram;
	
	assign cpu_dati 				= 
	cpu.map.ramdp	? cpu_dati_ramdp :
	cpu.map.sdram	? cpu_dati_sdram :
	cpu.map.flash	? cpu_dati_flash :
	16'hffff;
//************************************************************************************* mcu
	MemBus wram;
	assign wrm_dati		= wram.dati;
	assign wrm_addr		= wram.addr;
	assign wrm_we			= wram.we;
	assign wrm_oe			= wram.oe;
	assign wrm_ce			= wram.oe | wram.we != 0;

	
	wire mcu_ack			= 
	mcu.map.sdram 	? mcu_ack_sdram :
	mcu.map.flash 	? mcu_ack_flash :
	mcu.map.bram 	? mcu_ack_bram :
	1;
	
	wire [31:0]mcu_dati	= 
	mcu.map.fpgio 	? mcu_dati_fpgio :
	mcu.map.ramdp 	? mcu_dati_ramdp :
	mcu.map.sdram 	? mcu_dati_sdram :
	mcu.map.flash 	? mcu_dati_flash :
	mcu.map.bram 	? mcu_dati_bram :
	mcu.map.sfx		? mcu_dati_sfx :
	mcu.map.mdp		? mcu_dati_mdp :
	32'hffffffff;
	
	mcu_core mcu_inst(

		.clk(clk),
		.rst(rst),
		.mcu(mcu),
		.mcu_dati(mcu_dati),
		.mcu_ack(mcu_ack),
		
		.wram(wram),
		.wram_dato(wrm_dato),
		
		.gpio_o({led_r, led_g}),
		.gpio_i(0),
		
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
		
	);

//************************************************************************************* system registers
	wire mcu_ack_sys;
	wire [31:0]mcu_dati_fpgio;
	wire sdram_en;
	
	fpgio fpgio_inst(
	
		.mcu(mcu),
		.md_srst(!srst),
		.mcu_dati(mcu_dati_fpgio),
		
		.md_rst(md_rst),
		.exit(exit),
		.sdram_en(sdram_en)
	);
//************************************************************************************* dual port ram
	wire [31:0]mcu_dati_ramdp;
	wire [15:0]cpu_dati_ramdp;
	
	ramdp_io ramdp_io_inst(
	
		.mcu(mcu),
		.cpu(cpu),
		
		.mcu_dati(mcu_dati_ramdp),
		
		.cpu_dati(cpu_dati_ramdp)
	);
//************************************************************************************* sdram
	MemBus sdram;
	assign sdr_dati	= sdram.dati;
	assign sdr_addr	= sdram.addr;
	assign sdr_we		= sdram.we;
	assign sdr_oe		= sdram.oe;
	assign sdr_ce		= sdram.oe | sdram.we != 0;
	
	
	wire mcu_ack_sdram;
	wire [31:0]mcu_dati_sdram;
	wire [15:0]cpu_dati_sdram;
	
	sdram_io sdram_io_inst(

		.mcu(mcu),
		.cpu(cpu),
		
		.mcu_ack(mcu_ack_sdram),
		.mcu_dati(mcu_dati_sdram),
		.cpu_dati(cpu_dati_sdram),
		
		.mem(sdram),
		.mem_dato(sdr_dato)
	);
//************************************************************************************* flash
	MemBus flash;
	assign fla_dati	= flash.dati;
	assign fla_addr	= flash.addr;
	assign fla_we		= flash.we;
	assign fla_oe		= flash.oe;
	assign fla_ce		= flash.oe | flash.we != 0;
	
	
	wire mcu_ack_flash;
	wire [31:0]mcu_dati_flash;
	wire [15:0]cpu_dati_flash;
	
	flash_io flash_io_inst(

		.mcu(mcu),
		.cpu(cpu),
		
		.mcu_ack(mcu_ack_flash),
		.mcu_dati(mcu_dati_flash),
		.cpu_dati(cpu_dati_flash),
		
		.mem(flash),
		.mem_dato(fla_dato)
	);
//************************************************************************************* bram

	MemBus bram;
	assign brm_dati	= bram.dati;
	assign brm_addr	= bram.addr;
	assign brm_we		= bram.we;
	assign brm_oe		= bram.oe;
	assign brm_ce		= bram.oe | bram.we != 0;
	
	
	wire mcu_ack_bram;
	wire [31:0]mcu_dati_bram;
	
	bram_io bram_io_inst(

		.mcu(mcu),
		
		.mcu_ack(mcu_ack_bram),
		.mcu_dati(mcu_dati_bram),
		
		.mem(bram),
		.mem_dato(brm_dato)
	);
//************************************************************************************* audio clock
	SndCk snd;
	
	assign snd_clk				= snd.clk;
	assign snd_next_sample	= snd.next_sample;
	assign snd_phase			= snd.phase;
	
	//sfx module expecs dac clocked at 48000
	dac_clocker snd_48000(

		.clk(mcu.clk),
		.rst(0),
		.rate(48000),
		.ck_base(`CLK_FREQ),
		
		.dac_clk(snd.clk),
		.next_sample(snd.next_sample),
		.phase(snd.phase)
	);
//************************************************************************************* audio sfx
	wire [31:0]mcu_dati_sfx;
	wire  signed[15:0]sfx_l;
	wire  signed[15:0]sfx_r;
	
	audio_sfx sfx_inst(
	
		.mcu(mcu),
		.snd(snd),
		
		.mcu_dati_sfx(mcu_dati_sfx),
		.snd_l(sfx_l),
		.snd_r(sfx_r)
	);
//************************************************************************************* audio md+
	wire [31:0]mcu_dati_mdp;
	wire  signed[15:0]bgm_l;
	wire  signed[15:0]bgm_r;
	
	audio_mdp mdp_inst(
		
		.rst(rst),
		.mcu(mcu),
		.snd(snd),
		.mcu_dati_mdp(mcu_dati_mdp),

		.mosi(mosi),
		.ss(ss),
		.spi_clk(spi_clk),
		.miso(miso),
		.fifo_rxf(fifo_rxf),
		
		.snd_l(bgm_l),
		.snd_r(bgm_r)
	);
//************************************************************************************* mixer
		
	audio_mix mix_inst(

		.mcu(mcu),
		.next_sample(snd.next_sample),
		.sfx_l(sfx_l),
		.sfx_r(sfx_r),
		.bgm_l(bgm_l),
		.bgm_r(bgm_r),
		
		.snd_l(snd_l),
		.snd_r(snd_r)
	);
		
endmodule


module audio_mix(
	
	input  McuBus mcu,
	input  next_sample,
	input  signed[15:0]sfx_l,
	input  signed[15:0]sfx_r,
	input  signed[15:0]bgm_l,
	input  signed[15:0]bgm_r,
	
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
);
	
	
	reg [7:0]vol_sfx;
	reg [7:0]vol_bgm;
	
	always @(posedge mcu.clk)
	if(mcu.ce & mcu.we[0])
	begin
	
		if(mcu.map.fpgio_vols)
		begin
			vol_sfx		<= mcu.dato;
		end
		
		if(mcu.map.fpgio_volb)
		begin
			vol_bgm		<= mcu.dato;
		end
		
	end
	
	audio_mix_mono audio_mix_l(

		.clk(mcu.clk),
		.next_sample(next_sample),
		.vol_sfx(vol_sfx),
		.vol_bgm(vol_bgm),
		.sfx(sfx_l),
		.bgm(bgm_l),
		.snd(snd_l)
	);
	
	
	audio_mix_mono audio_mix_r(

		.clk(mcu.clk),
		.next_sample(next_sample),
		.vol_sfx(vol_sfx),
		.vol_bgm(vol_bgm),
		.sfx(sfx_r),
		.bgm(bgm_r),
		.snd(snd_r)
	);
	
endmodule


module audio_mix_mono(

	input  clk,
	input  next_sample,
	input  [7:0]vol_sfx,
	input  [7:0]vol_bgm,
	input  signed[15:0]sfx,
	input  signed[15:0]bgm,
	
	output signed[15:0]snd
);
	
	reg signed [15:0]sfx_v;
	reg signed [15:0]bgm_v;
	reg signed [16:0]acc;
	
	
	always @(posedge clk)
	if(next_sample)
	begin
		sfx_v	<= $signed(sfx) * vol_sfx / 256;
		bgm_v	<= $signed(bgm) * vol_bgm / 256;
		acc	<= sfx_v + bgm_v;
		snd	<= acc < -32768 ? -32768 : acc > 32767 ? 32767 : acc;
	end
		
	
endmodule
