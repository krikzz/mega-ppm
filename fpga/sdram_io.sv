
module sdram_io(

	input  McuBus mcu,
	input  CpuBus cpu,
	
	output mcu_ack,
	output [31:0]mcu_dati,
	output [15:0]cpu_dati,
	
	output MemBus mem,
	input  [15:0]mem_dato
);
	
	
	assign mem.dati	= cpu_master ? cpu.dato : mcu_a1 == 0 ? mcu.dato[15:0] : mcu.dato[31:16];
	assign mem.addr	= cpu_master ? cpu_ptr  : mcu.addr | (mcu_a1 << 1);
	assign mem.oe		= cpu_master ? cpu_oe : mcu_oe;
	assign mem.we[0]	= cpu_master ? 0 : mcu_we[1];
	assign mem.we[1]	= cpu_master ? 0 : mcu_we[0];
	
	assign cpu_dati	= cpu_ack ? cpu_dati_st : mem_dato;
	
	wire cpu_oe			= cpu.map.sdram & cpu.oe;	
	
	wire [1:0]mcu_we;
	wire mcu_ce			= mcu.map.sdram & mcu.ce;
	wire mcu_oe			= !idle & mcu_ce & mcu.oe;
	assign mcu_we[0]	= !idle & mcu_ce & mcu.we[mcu_a1 * 2 + 0];
	assign mcu_we[1]	= !idle & mcu_ce & mcu.we[mcu_a1 * 2 + 1];
	
	reg [20:0]cpu_ptr;
	reg idle;
	reg [3:0]cpu_oe_st;
	reg [3:0]delay;
	reg [3:0]state;
	reg mcu_a1;
	
	
	always @(posedge mcu.clk)
	begin
		
		cpu_oe_st					<= {cpu_oe_st[2:0], cpu_oe};
		
		if(mcu.ce & mcu.we != 0 & mcu.map.fpgio_sptr)
		begin
			cpu_ptr					<= mcu.dato;
		end
			else
		if(cpu_oe_st[2:0] == 'b110)
		begin
			cpu_ptr					<= cpu_ptr + 2;
		end
		
		
		if(!mcu_ce)
		begin
			idle						<= 0;
			mcu_ack					<= 0;
			delay						<= 0;
			state						<= 0;
			mcu_a1					<= 0;
		end
			else
		if(cpu_master & state != 0 & !mcu_ack)
		begin
			delay						<= idle ? 0 : `MEM_TIME - 1;
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
	
	
	wire cpu_ack;
	wire cpu_master;
	wire [15:0]cpu_dati_st;
	
	cpu_rdx cpu_rdx_inst(
	
		.clk(mcu.clk),
		.cpu(cpu),
		.cpu_oe_st(cpu_oe_st[0]),
		.mem_dato(mem_dato),
		
		.cpu_ack(cpu_ack),
		.cpu_master(cpu_master),
		.cpu_dati_st(cpu_dati_st)
	);
	
endmodule
