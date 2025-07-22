

//************************************************************************************* clock divider
module clk_dvp(

	input clk,
	input rst,
	input [31:0]ck_base,
	input [31:0]ck_targ,
	
	output reg ck_out
);

	
	parameter CLK_INC = 64'h20000;
	
	wire [31:0]ratio 	= ck_base * CLK_INC / ck_targ;
	
	reg [31:0]clk_ctr;
		
	always @(posedge clk)
	if(rst)
	begin
		clk_ctr	<= 0;
		ck_out	<= 0;
	end
		else
	begin
		
		if(clk_ctr >= (ratio-CLK_INC))
		begin
			clk_ctr	<= clk_ctr - (ratio-CLK_INC);
			ck_out 	<= 1;
		end
			else
		begin
			clk_ctr 	<= clk_ctr + CLK_INC;
			ck_out 	<= 0;
		end
		
	end
	

endmodule

//************************************************************************************* dac clocker
module dac_clocker(

	input  clk,
	input  rst,
	input	 [15:0]rate,
	input  [31:0]ck_base,
	
	output dac_clk,
	output next_sample,
	output [8:0]phase
);
	
	assign next_sample	= dac_clk & phase == 511;
	
	
	always @(posedge clk)
	if(rst)
	begin
		phase		<= 0;
	end
		else
	if(dac_clk)
	begin
		phase		<= phase + 1;
	end
	
	
	clk_dvp clk_dvp_inst(
		.clk(clk),
		.rst(rst),
		.ck_base(ck_base),
		.ck_targ(rate * 512),
		.ck_out(dac_clk)
	);
	
endmodule