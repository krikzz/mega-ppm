

module fifo(

	input McuBus mcu,
	input PiBus pi,
	
	output fifo_rxf_pi,
	output [7:0]dato_cp,
	output [7:0]dato_pi
);
	
	
	assign dato_cp = mcu_ce_stat ? fifo_status : fifo_do_a;
	assign dato_pi	= fifo_do_b;

	reg [7:0]fifo_status;
	
	always @(posedge mcu.clk)
	if(!mcu_ce_stat)
	begin
		fifo_status <= {fifo_rxf_cp, fifo_rxf_pi, 6'd1};
	end
	
	wire fifo_oe_pi 	= pi.map.ce_fifo & pi.oe & pi.act;
	wire fifo_we_pi 	= pi.map.ce_fifo & pi.we & pi.act;
	
	
	wire mcu_ce			= mcu.map.mdp_fifo & mcu.ce;
	wire mcu_ce_data	= mcu_ce & mcu.addr[2] == 0;
	wire mcu_ce_stat	= mcu_ce & mcu.addr[2] == 1;
		
	wire fifo_rxf_cp;
	wire fifo_oe_cp 	= mcu_ce_data & mcu.oe;
	wire fifo_we_cp 	= mcu_ce_data & mcu.we[0];
	
	//arm to cpu
	wire [7:0]fifo_do_a;
	fifo_buff fifo_a(

		.clk(mcu.clk),
		.dati(pi.dato),
		.oe(fifo_oe_cp),
		.we(fifo_we_pi),
		.dato(fifo_do_a),
		.fifo_empty(fifo_rxf_cp)
	);
	
	//cpu to arm
	wire [7:0]fifo_do_b;
	fifo_buff fifo_b(

		.clk(mcu.clk),
		.dati(mcu.dato[7:0]),
		.oe(fifo_oe_pi),
		.we(fifo_we_cp),
		.dato(fifo_do_b),
		.fifo_empty(fifo_rxf_pi)
	);
	

endmodule 


module fifo_buff(

	input clk, 
	input [7:0]dati,
	input oe, we,
	
	output [7:0]dato,
	output fifo_empty
);

	
	assign fifo_empty = we_addr == oe_addr;
	
	reg [10:0]we_addr;
	reg [10:0]oe_addr;
	reg [1:0]oe_st, we_st;	
	
	wire oe_end = oe_st[1:0] == 2'b10;
	wire we_end = we_st[1:0] == 2'b10;	
	
	always @(posedge clk)
	begin
	
		oe_st[1:0] <= {oe_st[0], (oe & !fifo_empty)};
		we_st[1:0] <= {we_st[0], we};
		
		if(oe_end)oe_addr <= oe_addr + 1;
		if(we_end)we_addr <= we_addr + 1;
		
	end
	
	
	
	ram_dp8 fifo_ram(
	
		.clk_a(clk),
		.dati_a(dati), 
		.addr_a(we_addr), 
		.we_a(we),
		
		.clk_b(clk),
		.addr_b(oe_addr), 
		.dato_b(dato)
	);

	
endmodule



