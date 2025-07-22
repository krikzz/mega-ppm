//------------------------------------------------------------------------------------ audio_out_i2s
module audio_out_i2s(

	input  clk,
	input  snd_clk,
	input  snd_next_sample,
	input  [8:0]snd_phase,
	input  signed[15:0]snd_l,
	input  signed[15:0]snd_r,
	
	output dac_mclk,
	output dac_lrck,
	output dac_sdin
);
	
	
	dac_i2s dac_inst(
	
		.clk(clk),
		.dac_clk(snd_clk),
		.next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_l(snd_l),
		.snd_r(snd_r),
		
		
		.mclk(dac_mclk),
		.lrck(dac_lrck),
		.sdin(dac_sdin)

	);
	
endmodule
//------------------------------------------------------------------------------------
 module dac_i2s(
	
	input clk,
	input dac_clk,
	input next_sample,
	input [8:0]snd_phase,
	input signed[15:0]snd_l,
	input signed[15:0]snd_r,
	
	output mclk, 
	output lrck,
	output sdin

);
	
	assign mclk 			= snd_phase[0];
	assign lrck 			= snd_phase[8];
	assign sdin 			= snd_bit;
	
	wire next_bit 			= snd_phase[3:0] == 4'b1111;
	wire [3:0]bit_ctr 	= snd_phase[7:4];

	
	
	reg snd_bit;
	reg signed[15:0]snd_l_st, snd_r_st;
	
	
	always @(posedge clk)
	if(dac_clk)
	begin
	
		
		if(next_bit & lrck == 0)
		begin
			snd_bit		<= snd_l_st[15 - bit_ctr[3:0]];
		end
		
		
		if(next_bit & lrck == 1)
		begin
			snd_bit 		<= snd_r_st[15 - bit_ctr[3:0]];
		end
		

		if(next_sample)
		begin
			snd_l_st 	<= snd_l;
			snd_r_st 	<= snd_r;
		end
		
	end
	
endmodule
