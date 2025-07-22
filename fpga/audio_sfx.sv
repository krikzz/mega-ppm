

module audio_sfx(
	
	input  McuBus mcu,
	input  SndCk  snd,
	
	output [31:0]mcu_dati_sfx,
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
);

	SfxBank bank0;
	
	assign mcu_dati_sfx	= bank0.sfx[mcu.addr[5:3]].status;
	
//****************************** clocks
	wire [7:0]aclk;
	aclk_bank aclk_bank_inst(

		.mcu(mcu),
		.dac_next_sample(snd.next_sample),
		.aclk(aclk)
	);
		
//****************************** sfx banks

	//more banks can be implemented for music synth
	
	sfx_bank sfx_bank0(

		.mcu(mcu),
		.aclk(aclk),
		.bank_idx(0),
		.bank(bank0)
	);
	
//****************************** mixer
	
	mix_bank mix_bank0(

		.clk(mcu.clk),
		.bank(bank0),
		.next_sample(snd.next_sample),
		
		.snd_l(snd_l),
		.snd_r(snd_r)
	);
	
endmodule

//************************************************************************************* audio clocks
module aclk_bank(

	input  McuBus mcu,
	input  dac_next_sample,
	
	output [7:0]aclk
);

	
	assign aclk[0] = dac_next_sample;
	assign aclk[6] = aclk[0];
	assign aclk[7] = aclk[0];
	
	
	
	dac_clocker aclk1(

		.clk(mcu.clk),
		.rate(24000),
		.ck_base(`CLK_FREQ),
		.next_sample(aclk[1]),
	);
	
	dac_clocker aclk2(

		.clk(mcu.clk),
		.rate(12000),
		.ck_base(`CLK_FREQ),
		.next_sample(aclk[2]),
	);
	
	dac_clocker aclk3(

		.clk(mcu.clk),
		.rate(9600),
		.ck_base(`CLK_FREQ),
		.next_sample(aclk[3]),
	);
	
	dac_clocker aclk4(

		.clk(mcu.clk),
		.rate(6000),
		.ck_base(`CLK_FREQ),
		.next_sample(aclk[4]),
	);
	
	dac_clocker aclk5(

		.clk(mcu.clk),
		.rate(5333),
		.ck_base(`CLK_FREQ),
		.next_sample(aclk[5]),
	);
	
endmodule

//************************************************************************************* sfx channels
module sfx_bank(

	input  McuBus mcu,
	input  [7:0]aclk,	
	input  [2:0]bank_idx,
	
	output SfxBank bank
);

	sfx_chan sfx_chan0(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(0+bank_idx*8),
		.sfx(bank.sfx[0])
	);
	
	sfx_chan sfx_chan1(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(1+bank_idx*8),
		.sfx(bank.sfx[1])
	);
	
	sfx_chan sfx_chan2(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(2+bank_idx*8),
		.sfx(bank.sfx[2])
	);
	
	sfx_chan sfx_chan3(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(3+bank_idx*8),
		.sfx(bank.sfx[3])
	);
	
	sfx_chan sfx_chan4(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(4+bank_idx*8),
		.sfx(bank.sfx[4])
	);
	
	sfx_chan sfx_chan5(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(5+bank_idx*8),
		.sfx(bank.sfx[5])
	);
	
	sfx_chan sfx_chan6(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(6+bank_idx*8),
		.sfx(bank.sfx[6])
	);
	
	sfx_chan sfx_chan7(
		
		.mcu(mcu),
		.aclk(aclk),
		.chan_idx(7+bank_idx*8),
		.sfx(bank.sfx[7])
	);

endmodule


module sfx_chan(
	
	input  McuBus mcu,
	input  [7:0]aclk,	
	input  [5:0]chan_idx,
	
	output SfxOut sfx
);
	
	parameter FIFO_SIZE	= 8;
	
	assign sfx.status[0]	= fifo_empty;
	assign sfx.status[1]	= fifo_full;
	
	wire chan_ce			= mcu.ce & mcu.map.sfx & mcu.addr[8:3] == chan_idx;
	
	wire type_we			= mcu.addr[2] == 0 & chan_ce & mcu.we[1];
	wire pan_we				= mcu.addr[2] == 0 & chan_ce & mcu.we[2];
	wire flags_we			= mcu.addr[2] == 0 & chan_ce & mcu.we[3];
	
	wire vol_we				= mcu.addr[2] == 1 & chan_ce & mcu.we[1:0] == 'b11;
	wire pcm_we				= mcu.addr[2] == 1 & chan_ce & mcu.we[3:2] == 'b11;
	
	wire [7:0]typev		= mcu.dato[15:8];
	wire [7:0]pan			= mcu.dato[23:16];
	wire [7:0]flags		= mcu.dato[31:24];
	wire [15:0]vol			= mcu.dato[15:0];
	
	//48000, 24000, 12000, 9600, 6000, 5333
	wire next_sample		= aclk[srate];
	
	wire fifo_empty		= addr_rd == addr_wr;
	wire fifo_full			= addr_rd[FIFO_SIZE-1:0] == addr_wr[FIFO_SIZE-1:0] & addr_rd[FIFO_SIZE] != addr_wr[FIFO_SIZE];
	
	reg [FIFO_SIZE:0]addr_rd;
	reg [FIFO_SIZE:0]addr_wr;
	
	reg pcm_we_st;
	reg [2:0]srate;
	reg [4:0]pitch;
	reg [4:0]pitch_ctr;
	
	always @(posedge mcu.clk)
	begin
	
		pcm_we_st		<= pcm_we;
		

		if(type_we)
		begin
			srate			<= typev[6:4];
		end
		
		if(pan_we)
		begin
			sfx.pan[0]	<= pan < 'h80 ? 'h80 : 'h100 - pan;//L
			sfx.pan[1]	<= pan > 'h80 ? 'h80 : pan;//R
		end
		
		if(flags_we)
		begin
			pitch		<= flags[7] ? 31 : flags[5] ? 1 : 0;//skip on of 2-32 cycles
		end
		
		
		if(vol_we)
		begin
			sfx.vol		<= vol;
		end
		
		
		if(!fifo_empty & next_sample & pitch_ctr != 1)
		begin
			addr_rd	<= addr_rd + 1;
			sfx.pcm	<= mem_dato;
		end
		
		
		if(!fifo_full & {pcm_we_st, pcm_we} == 'b10)
		begin
			addr_wr	<= addr_wr + 1;
		end
		
		if(next_sample)
		begin
			pitch_ctr	<= pitch_ctr >= pitch ? 0 : pitch_ctr + 1;
		end
		
	end
	
	
	
	wire [15:0]mem_dato;
	
	ram_dp16 pcm_buff(

		.clk_a(mcu.clk),
		.dati_a(mcu.dato[31:16]),
		.addr_a(addr_wr[FIFO_SIZE-1:0]),
		.we_a(pcm_we),
		
		.clk_b(mcu.clk),
		.addr_b(addr_rd[FIFO_SIZE-1:0]),
		.dato_b(mem_dato)
	);
	
endmodule

//************************************************************************************* mixer

module mix_bank(

	input clk,
	input SfxBank bank,
	input next_sample,
	
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
);

	
	reg mix_req;
	reg mix_next;
	reg mix_side;//0:L,1:R
	
	always @(posedge clk)
	if(next_sample)
	begin
		mix_req		<= 1;
		mix_next		<= 1;
		mix_side		<= 0;
	end
		else
	if(mix_next)
	begin		
		mix_next		<= 0;
	end
		else
	if(mix_req & mix_ack)
	begin
		
		if(mix_side == 0)
		begin
			snd_l		<= mix_snd;
			mix_next	<= 1;
			mix_side	<= 1;
		end
		
		if(mix_side == 1)
		begin
			snd_r		<= mix_snd;
			mix_req	<= 0;
		end
	
	end
	
	
	
	wire mix_ack;
	wire signed[15:0]mix_snd;
	
	mix_mono mix_mono_inst(

		.clk(clk),
		.bank(bank),
		.mix_next(mix_next),
		.side(mix_side),
		
		.ack(mix_ack),
		.snd(mix_snd)
	);

	
endmodule


module mix_mono(

	input  clk,
	input  SfxBank bank,
	input  mix_next,
	input  side,
	
	output ack,
	output signed[15:0]snd
);
	
	
	wire [3:0]chan_idx	= state[5:2];
	
	wire signed[7:0]pan	= bank.sfx[chan_idx[2:0]].pan[side];
	wire signed[10:0]vol	= bank.sfx[chan_idx[2:0]].vol;
	wire signed[15:0]pcm	= bank.sfx[chan_idx[2:0]].pcm;
	
	reg signed[15:0]val;
	reg signed[21:0]acc;
	reg[5:0]state;
	
	always @(posedge clk)
	if(mix_next)
	begin
		state		<= 0;
		acc		<= 0;
		ack		<= 0;
	end
		else
	if(!ack)
	begin
		
		state		<= state + 1;
		
		if(chan_idx < 8)
		begin
			case(state[1:0])
				0:val			<= pcm;
				1:val			<= $signed(val) * vol / 'h400;
				2:val			<= $signed(val) * pan / 'h80;
				3:acc			<= acc + val;
			endcase
		end
			else
		begin
		
			if(acc < -32768)
			begin
				snd	<= -32768;
			end
				else
			if(acc > 32767)
			begin
				snd	<= 32767;
			end
				else
			begin
				snd	<= acc;
			end
			
			ack		<= 1;
			
		end
		
	end
	
	
endmodule
