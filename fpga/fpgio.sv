

module fpgio(
	
	input  McuBus mcu,
	input  md_srst,
	
	output [31:0]mcu_dati,
	
	output md_rst,
	output exit,
	output sdram_en
);
	
	assign mcu_dati		= 
	mcu.map.fpgio_ctrl  	? ctrl :
	mcu.map.fpgio_time 	? time_st :
	32'hffffffff;
//************************************************************************************* regs

	wire [3:0]reg_addr	= mcu.addr[5:2];
	
	assign md_rst			= ctrl[0];
	assign exit				= ctrl[1];
	assign sdram_en		= ctrl[2];
	
	
	reg [7:0]ctrl;
	reg md_srst_st;
	
	always @(posedge mcu.clk)
	begin
		
		md_srst_st		<= md_srst;
		
		if(mcu.ce & mcu.we[0] & mcu.map.fpgio_ctrl)
		begin
			ctrl			<= mcu.dato;
		end
			else
		if(md_srst_st)
		begin
			ctrl[3]		<= 1;
		end
		
	end
	
	
//************************************************************************************* timer
	
	reg [31:0]ctr_c;
	reg [31:0]ctr_t;
	reg [31:0]time_st;
	
	always @(posedge mcu.clk)
	begin
		
		if(!mcu.ce)
		begin
			time_st	<= ctr_t;
		end
		
		if(ctr_c >= `CLK_FREQ / 1000 - 1)
		begin
			ctr_c		<= 0;
			ctr_t		<= ctr_t + 1;
		end
			else
		begin
			ctr_c		<= ctr_c + 1;
		end
		
	end
//************************************************************************************* 
endmodule
