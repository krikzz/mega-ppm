
module bram_io(

	input  McuBus mcu,
	
	output mcu_ack,
	output [31:0]mcu_dati,
	
	output MemBus mem,
	input  [15:0]mem_dato
);
	
	
	assign mem.dati	= mcu_a1 == 0 ?  mcu.dato[15:0] : mcu.dato[31:16];
	assign mem.addr	= mcu.addr | (mcu_a1 << 1);
	assign mem.oe		= mcu_oe;
	assign mem.we[0]	= mcu_we[0];
	assign mem.we[1]	= mcu_we[1];
	
	
	wire [1:0]mcu_we;
	wire mcu_ce			= mcu.map.bram & mcu.ce;
	wire mcu_oe			= !idle & mcu_ce & mcu.oe;
	assign mcu_we[0]	= !idle & mcu_ce & mcu.we[mcu_a1 * 2 + 0];
	assign mcu_we[1]	= !idle & mcu_ce & mcu.we[mcu_a1 * 2 + 1];

	reg idle;
	reg [3:0]delay;
	reg [3:0]state;
	reg mcu_a1;
	
	
	always @(posedge mcu.clk)
	begin
		
		
		if(!mcu_ce)
		begin
			idle						<= 0;
			mcu_ack					<= 0;
			delay						<= 0;
			state						<= 0;
		end
			else
		if(delay)
		begin
			delay						<= delay - 1;
		end
			else
		case(state)
			0:begin
				idle					<= 0;
				delay					<= `MEM_TIME - 1;
				mcu_a1				<= 0;
				state					<= state + 1;
			end
			1:begin
				idle					<= 1;
				mcu_dati[15:0]		<= mem_dato[15:0];
				state					<= state + 1;
			end
			2:begin
				idle					<= 0;
				delay					<= `MEM_TIME - 1;
				mcu_a1				<= 1;
				state					<= state + 1;
			end
			3:begin
				idle					<= 1;
				mcu_ack				<= 1;
				mcu_dati[31:16]	<= mem_dato[15:0];
				state					<= state + 1;
			end
			4:begin
				//end idle
			end
		endcase
		
	end
	
endmodule
