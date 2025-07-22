


module ramdp_io(
	
	input  McuBus mcu,
	input  CpuBus cpu,
	
	output mcu_ack,
	output [31:0]mcu_dati,
	
	output [15:0]cpu_dati
);
	
	assign mcu_ack			= 1;
	assign cpu_dati		= cpu.addr[1] == 0 ? {cpu_dati_32[7:0], cpu_dati_32[15:8]} : {cpu_dati_32[23:16], cpu_dati_32[31:24]};
	
	wire mcu_ce	= mcu.ce & mcu.map.ramdp;
	
	wire [31:0]cpu_dati_32;
	wire [7:0]cpu_dati_lo;
	wire [7:0]cpu_dato_0	= cpu.dato[15:8];
	wire [7:0]cpu_dato_1	= cpu.dato[7:0];
	wire [3:0]cpu_we;
	
	assign cpu_we[0]		= cpu_we_ck & cpu.we_hi & cpu.addr[1] == 0;
	assign cpu_we[1]		= cpu_we_ck & cpu.we_lo & cpu.addr[1] == 0;
	assign cpu_we[2]		= cpu_we_ck & cpu.we_hi & cpu.addr[1] == 1;
	assign cpu_we[3]		= cpu_we_ck & cpu.we_lo & cpu.addr[1] == 1;
	
	wire cpu_we_ck			= cpu_we_st[2:0] == 'b011;
	wire cpu_we_act		= cpu.ce_lo & cpu.addr < 8192 & (cpu.we_lo | cpu.we_hi);
	
	reg [3:0]cpu_we_st;
	always @(posedge mcu.clk)
	begin
		cpu_we_st	<= {cpu_we_st[2:0], cpu_we_act};
	end
	
	
	ram_dp8 ram_dp_0(

		.clk_a(mcu.clk),
		.dati_a(mcu.dato[7:0]),
		.addr_a(mcu.addr[12:2]),
		.we_a(mcu_ce & mcu.we[0]),
		.dato_a(mcu_dati[7:0]),
		
		.clk_b(mcu.clk),
		.dati_b(cpu_dato_0),
		.addr_b(cpu.addr[12:2]),
		.we_b(cpu_we[0]),
		.dato_b(cpu_dati_32[7:0])
	);
	
	
	ram_dp8 ram_dp_1(

		.clk_a(mcu.clk),
		.dati_a(mcu.dato[15:8]),
		.addr_a(mcu.addr[12:2]),
		.we_a(mcu_ce & mcu.we[1]),
		.dato_a(mcu_dati[15:8]),
		
		.clk_b(mcu.clk),
		.dati_b(cpu_dato_1),
		.addr_b(cpu.addr[12:2]),
		.we_b(cpu_we[1]),
		.dato_b(cpu_dati_32[15:8])
	);
	
	
	ram_dp8 ram_dp_2(

		.clk_a(mcu.clk),
		.dati_a(mcu.dato[23:16]),
		.addr_a(mcu.addr[12:2]),
		.we_a(mcu_ce & mcu.we[2]),
		.dato_a(mcu_dati[23:16]),
		
		.clk_b(mcu.clk),
		.dati_b(cpu_dato_0),
		.addr_b(cpu.addr[12:2]),
		.we_b(cpu_we[2]),
		.dato_b(cpu_dati_32[23:16])
	);
	
	ram_dp8 ram_dp_3(

		.clk_a(mcu.clk),
		.dati_a(mcu.dato[31:24]),
		.addr_a(mcu.addr[12:2]),
		.we_a(mcu_ce & mcu.we[3]),
		.dato_a(mcu_dati[31:24]),
		
		.clk_b(mcu.clk),
		.dati_b(cpu_dato_1),
		.addr_b(cpu.addr[12:2]),
		.we_b(cpu_we[3]),
		.dato_b(cpu_dati_32[31:24])
	);
	
endmodule
