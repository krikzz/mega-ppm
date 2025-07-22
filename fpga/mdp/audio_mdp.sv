
module audio_mdp(
	
	input  rst,
	input  McuBus mcu,
	input  SndCk snd,
	output [31:0]mcu_dati_mdp,
	input  mosi,
	input  ss,
	input  spi_clk,
	output miso,
	output fifo_rxf,
	
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
);


//************************************************************************************* everdrive mcu interface
	PiBus pi;
	
	wire [7:0]pi_dati			= pi.map.ce_fifo ? pi_dati_fifo : pi_dati_mdp;
	
	pi_io pi_io_inst(

		.clk(mcu.clk),
		.dati(pi_dati),
		.mosi(mosi), 
		.ss(ss), 
		.spi_clk(spi_clk),
		.miso(miso),
		.pi(pi)
	);
//************************************************************************************* fifo (link to ed mcu)
	wire [7:0]pi_dati_fifo;
	wire [7:0]mcu_dati_fifo;
	
	fifo fifo_inst(

		.mcu(mcu),
		.pi(pi),
		
		.fifo_rxf_pi(fifo_rxf),
		.dato_cp(mcu_dati_fifo),
		.dato_pi(pi_dati_fifo)
	);

//************************************************************************************* MD cpu simulation
		CpuBus cpu;
		
		assign mcu_dati_mdp	= mcu.map.mdp_fifo ? {24'h0, mcu_dati_fifo[7:0]} : {mdp_data[15:0], mdp_data[15:0]};
		
		wire mdp_ce				= mcu.map.mdp_ctrl & mcu.ce;
		
		assign cpu.addr		= mcu.addr;
		assign cpu.dato		= mcu.dato[15:0];
		assign cpu.oe			= !(mdp_ce & mcu.oe);
		assign cpu.we_lo		= !(mdp_ce & mcu.we[mcu.addr[1] * 2 + 0]);
		assign cpu.we_hi		= !(mdp_ce & mcu.we[mcu.addr[1] * 2 + 1]);
		assign cpu.ce_lo		= !(mdp_ce);
		
//************************************************************************************* MD+
	
	wire [15:0]mdp_data;
	wire [7:0]pi_dati_mdp;
	
	mdp mdp_inst(
	
		.clk(mcu.clk),
		.rst(rst),
		.snd(snd),
		.pi(pi),
		.cpu(cpu),
		
		.mdp_data(mdp_data),
		.pi_di(pi_dati_mdp),
		
		.snd_l(snd_l),
		.snd_r(snd_r)
	);
		
endmodule
