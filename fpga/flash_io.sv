

module flash_io(

	input  McuBus mcu,
	input  CpuBus cpu,
	
	output mcu_ack,
	output [31:0]mcu_dati,
	output [15:0]cpu_dati,
	
	output MemBus mem,
	input  [15:0]mem_dato
);
		
	assign mem.dati	= mcu_a1 == 0 ? mcu.dato[15:0] : mcu.dato[31:16];
	
	assign mem.addr	= cpu_master ? cpu.addr : mcu.addr | (mcu_a1 << 1);
	assign mem.oe		= cpu_master ? cpu_oe : mcu_oe & !mcu_ack;
	//assign mem.we[0]	= cpu_master ? 0 : mcu_we[1];
	//assign mem.we[1]	= cpu_master ? 0 : mcu_we[0];
	
	assign cpu_dati	= cpu_ack ? cpu_dati_st : mem_dato;
	
	wire cpu_oe			= cpu.map.flash & cpu.oe;
	wire mcu_ce			= mcu.map.flash & mcu.ce;
	wire mcu_oe			= !idle & mcu_ce & mcu.oe;
	
	wire [1:0]mcu_we;
	assign mcu_we[0]	= !idle & mcu_ce & mcu.we[mcu_a1 * 2 + 0];
	assign mcu_we[1]	= !idle & mcu_ce & mcu.we[mcu_a1 * 2 + 1];
	
	reg idle;
	reg cpu_oe_st;
	reg [3:0]delay;
	reg [3:0]state;
	reg mcu_a1;
	
	
	always @(posedge mcu.clk)
	begin
		
		cpu_oe_st					<= cpu_oe;
		
		
		if(!mcu_ce)
		begin
			mcu_ack					<= 0;
			delay						<= 0;
			state						<= 0;
			mcu_a1					<= 0;
		end
			else
		if(cpu_master & state != 0 & !mcu_ack)
		begin
			delay						<= `MEM_TIME - 1;
		end
			else
		if(delay)
		begin
			delay						<= delay - 1;
		end
			else
		case(state)
			0:begin
				delay					<= `MEM_TIME - 1;
				mcu_a1				<= 0;
				state					<= state + 1;
			end
			1:begin
				delay					<= `MEM_TIME - 1;
				mcu_dati[15:0]		<= mem_dato[15:0];
				mcu_a1				<= 1;
				state					<= state + 1;
			end
			2:begin
				mcu_dati[31:16]	<= mem_dato[15:0];
				mcu_ack				<= 1;
				state					<= state + 1;
			end
			3:begin
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
		.cpu_oe_st(cpu_oe_st),
		.mem_dato(mem_dato),
		
		.cpu_ack(cpu_ack),
		.cpu_master(cpu_master),
		.cpu_dati_st(cpu_dati_st)
	);
	
endmodule


module cpu_rdx(
	
	input  clk,
	input  CpuBus cpu,
	input  cpu_oe_st,
	input [15:0]mem_dato,
	
	output cpu_ack,
	output cpu_master,
	output [15:0]cpu_dati_st
);

	
	assign cpu_master	= cpu_oe_st & !cpu_ack;
	
	reg [3:0]delay;
	reg [23:0]cpu_addr[2];
	
	always @(posedge clk)
	begin
		
		cpu_addr[0]		<= cpu.addr;
		cpu_addr[1]		<= cpu_addr[0];
		
		if(!cpu_ack)
		begin
			cpu_dati_st	<= mem_dato;
		end
		
		if(!cpu_oe_st | cpu_addr[1] != cpu_addr[0])
		begin
			cpu_ack		<= 0;
			delay			<= `MEM_TIME;// - 1;
		end
			else
		if(delay)
		begin
			delay			<= delay - 1;
		end
			else
		begin
			cpu_ack		<= 1;
		end
		
	end
	
endmodule
