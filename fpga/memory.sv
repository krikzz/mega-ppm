

module ram_dp8(

	input clk_a,
	input [7:0]dati_a,
	input [15:0]addr_a,
	input we_a,
	output reg [7:0]dato_a,
	
	input clk_b,
	input [7:0]dati_b,
	input [15:0]addr_b,
	input we_b,
	output reg [7:0]dato_b
);

	
	reg [7:0]ram[65536];
	
	always @(posedge clk_a)
	begin
	
		dato_a 			<= we_a ? dati_a : ram[addr_a];
		
		if(we_a)
		begin
			ram[addr_a] <= dati_a;
		end
	end
	
	always @(posedge clk_b)
	begin
	
		dato_b 			<= we_b ? dati_b : ram[addr_b];
		
		if(we_b)
		begin
			ram[addr_b] <= dati_b;
		end
	end
	
endmodule


module ram_dp16(

	input clk_a,
	input [15:0]dati_a,
	input [15:0]addr_a,
	input we_a,
	output reg [15:0]dato_a,
	
	input clk_b,
	input [15:0]dati_b,
	input [15:0]addr_b,
	input we_b,
	output reg [15:0]dato_b
);

	
	reg [15:0]ram[65536];
	
	always @(posedge clk_a)
	begin
	
		dato_a 			<= we_a ? dati_a : ram[addr_a];
		
		if(we_a)
		begin
			ram[addr_a] <= dati_a;
		end
	end
	
	always @(posedge clk_b)
	begin
	
		dato_b 			<= we_b ? dati_b : ram[addr_b];
		
		if(we_b)
		begin
			ram[addr_b] <= dati_b;
		end
	end
	
endmodule