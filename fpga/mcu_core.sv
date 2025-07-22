

module mcu_core(

	input  clk,
	input  rst,
	output McuBus mcu,
	input  [31:0]mcu_dati,
	input  mcu_ack,
	
	output MemBus wram,
	input  [15:0]wram_dato,
	
	output [31:0]gpio_o,
	input  [31:0]gpio_i,
	
	output uart_tx,
	input  uart_rx
);

//************************************************************************************* memory map
	assign mcu.map.wrom	= {mcu.addr[31:24], 24'd0} == 'h00000000;
	assign mcu.map.wram	= {mcu.addr[31:24], 24'd0} == 'h80000000;
	assign mcu.map.fpgio	= {mcu.addr[31:24], 24'd0} == 'h01000000;
	assign mcu.map.ramdp	= {mcu.addr[31:24], 24'd0} == 'h02000000;
	assign mcu.map.sdram	= {mcu.addr[31:24], 24'd0} == 'h03000000;
	assign mcu.map.flash	= {mcu.addr[31:24], 24'd0} == 'h04000000;
	assign mcu.map.bram	= {mcu.addr[31:24], 24'd0} == 'h05000000;
	assign mcu.map.sfx	= {mcu.addr[31:24], 24'd0} == 'h06000000;
	assign mcu.map.mdp	= {mcu.addr[31:24], 24'd0} == 'h07000000;
	
	assign mcu.map.fpgio_ctrl	= mcu.map.fpgio & mcu.addr[5:2] == 0;
	assign mcu.map.fpgio_time	= mcu.map.fpgio & mcu.addr[5:2] == 1;
	assign mcu.map.fpgio_sptr	= mcu.map.fpgio & mcu.addr[5:2] == 2;
	assign mcu.map.fpgio_vols	= mcu.map.fpgio & mcu.addr[5:2] == 3;
	assign mcu.map.fpgio_volb	= mcu.map.fpgio & mcu.addr[5:2] == 4;
	
	assign mcu.map.mdp_ctrl		= mcu.map.mdp & mcu.addr[23]	== 0;
	assign mcu.map.mdp_fifo		= mcu.map.mdp & mcu.addr[23]	== 1;
//************************************************************************************* cpu core
	assign mcu.dato 		= rv_do;
	assign mcu.addr 		= rv_ad;
	assign mcu.ce			= rv_stb & rv_cyc;
	assign mcu.oe			= mcu.ce & rv_we == 0;
	assign mcu.we[0]		= mcu.ce & rv_we == 1 & rv_sel[0];
	assign mcu.we[1]		= mcu.ce & rv_we == 1 & rv_sel[1];
	assign mcu.we[2]		= mcu.ce & rv_we == 1 & rv_sel[2];
	assign mcu.we[3]		= mcu.ce & rv_we == 1 & rv_sel[3];
	assign mcu.clk			= clk;
	
	wire [3:0]rv_sel/*synthesis keep*/;
	wire [31:0]rv_ad/*synthesis keep*/;
	wire [31:0]rv_do/*synthesis keep*/;
	wire [31:0]rv_di;
	wire rv_we, rv_stb, rv_cyc, rv_ack/*synthesis keep*/;
	
	assign rv_di	= 
	mcu.map.wrom ? mcu_dati_irom :
	//mcu.map.wrom ? mcu_dati_wram :
	mcu.map.wram ? mcu_dati_wram : mcu_dati;
	
	assign rv_ack	= 
	mcu.map.wrom ? ack_wram :
	mcu.map.wram ? ack_wram : mcu_ack;
	
	
	neorv32_top_stdlogic(
	
		.clk_i(clk),
		.rstn_i(!rst),	
		
		.wb_tag_o(),
		.wb_adr_o(rv_ad[31:0]),
		.wb_dat_i(rv_di[31:0]),
		.wb_dat_o(rv_do[31:0]),
		.wb_we_o(rv_we),
		.wb_sel_o(rv_sel[3:0]),
		.wb_stb_o(rv_stb),
		.wb_cyc_o(rv_cyc),
		.wb_lock_o(),
		.wb_ack_i(rv_ack),
		.wb_err_i(0),
		
		.gpio_o(gpio_o),
		.gpio_i(gpio_i),
		
		.uart_txd_o(uart_tx),
		.uart_rxd_i(uart_rx),
			
		.mtime_irq_i(0),
		.msw_irq_i(0),
		.mext_irq_i(0),
	);
	
	
//******************************************
	wire [31:0]mcu_dati_wram;
	wire ack_wram;
	
	wire mcu_ce_wrom	= mcu.addr[31] == 0 & mcu.addr[30:18] == 0;
	wire mcu_ce_wram	= mcu.addr[31] == 1 & mcu.addr[30:18] == 0;
	
	mcu_wram mcu_wram_inst(
		
		.mcu(mcu),
		.mcu_dati(mcu_dati_wram),
		
		.wram(wram),
		.wram_dato(wram_dato),
		
		.ce_wrom(mcu.map.wrom),
		.ce_wram(mcu.map.wram),
		.ack(ack_wram)
		
	);
	
//****************************************** mcu rom
	
	
	wire [31:0]mcu_dati_irom;
	
	mcu_irom mcu_irom_inst(

		.clk(mcu.clk),
		.addr(mcu.addr),
		.dato(mcu_dati_irom)
	);
		
endmodule

//************************************************************************************* wram controller


module mcu_wram(

	input  McuBus mcu,
	output [31:0]mcu_dati,
	
	output MemBus wram,
	input  [15:0]wram_dato,
	
	input ce_wrom,
	input ce_wram,
	output ack
	
);
	
	wire rom_ce					= mcu.ce & ce_wrom;
	wire ram_ce					= mcu.ce & ce_wram;
	wire wram_ce				= rom_ce | ram_ce;
		
		
	wire wram_bank 			= ce_wrom ? 0 : 1;
	assign wram.addr[23:2]	= {wram_bank, mcu.addr[17:2]};
	assign wram.dati			= wram.addr[1] == 0 ? {mcu.dato[7:0], mcu.dato[15:8]} : {mcu.dato[23:16], mcu.dato[31:24]};
	
	assign wram.we[0]			= !idle & mcu.oe == 0 & ram_ce & (wram.addr[1] == 0 ? mcu.we[0] : mcu.we[2]);
	assign wram.we[1]			= !idle & mcu.oe == 0 & ram_ce & (wram.addr[1] == 0 ? mcu.we[1] : mcu.we[3]);
	assign wram.oe				= !idle & mcu.oe == 1 & wram_ce;

	assign mcu_dati[31:16]	= idle ? mcu_dati_hi : {wram_dato[7:0], wram_dato[15:8]};
	
	reg [15:0]mcu_dati_hi;
	reg [3:0]state;
	reg idle;
	reg delay;
	
	always @(posedge mcu.clk)
	begin
		
		
		if(!wram_ce)
		begin
			state						<= 0;
			idle						<= 0;
			ack						<= 0;
			wram.addr[1]			<= 0;
			delay						<= `SRM_DELAY;
		end
			else
		if(delay)
		begin
			delay						<= 0;
		end
			else
		if(mcu.oe)
		case(state)
			0:begin
				mcu_dati[15:0]		<= {wram_dato[7:0], wram_dato[15:8]};
				wram.addr[1]		<= 1;
				ack					<= 1;
				state					<= state + 1;
			end
			1:begin
				mcu_dati_hi			<= {wram_dato[7:0], wram_dato[15:8]};
				idle					<= 1;
				state					<= state + 1;
			end
		endcase
			else
		case(state)
			0:begin
				idle 					<= 1;
				state					<= state + 1;
			end
			1:begin
				wram.addr[1]		<= 1;
				state					<= state + 1;
			end
			2:begin
				idle 					<= 0;
				state					<= state + 1;
				ack					<= 1;
			end
			3:begin
				idle 					<= 1;
				state					<= state + 1;
			end
		endcase

		
	end
	
	
endmodule

//************************************************************************************* mcu rom (optional)

module mcu_irom(

	input  clk,
	input  [13:0]addr,
	output [31:0]dato
);

	assign dato = {di[7:0], di[15:8], di[23:16], di[31:24]};

	reg[31:0]rom[16384/4];
	
	reg [31:0]di;
	
	always @(posedge clk)
	begin
		di		<= rom[addr[13:2]];
	end
	
	initial
	begin
		$readmemh("mcu.txt", rom);
	end

	
endmodule
