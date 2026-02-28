// Dual-port RAM with write-first behavior
module dual_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter RAM_DEPTH = 8
)(
    input wire clk,
    input wire rst,  // Reset port (port 8)
    
    // Port A (Read/Write)
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [DATA_WIDTH-1:0] data_in_a,
    output reg [DATA_WIDTH-1:0] data_out_a,
    input wire we_a,
    
    // Port B (Read only for display)
    input wire [ADDR_WIDTH-1:0] addr_b,
    output reg [DATA_WIDTH-1:0] data_out_b
);
    reg [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];
    
    integer i;
    
    // Port A - Write first, then read
    always @(posedge clk) begin
        if (rst) begin
            data_out_a <= 0;
            for (i = 0; i < RAM_DEPTH; i = i + 1) begin
                ram[i] <= 0;
            end
        end else begin
            if (we_a) begin
                ram[addr_a] <= data_in_a;
                data_out_a <= data_in_a;
            end else begin
                data_out_a <= ram[addr_a];
            end
        end
    end
    
    // Port B (for display/monitoring)
    always @(posedge clk) begin
        if (rst) begin
            data_out_b <= 0;
        end else begin
            data_out_b <= ram[addr_b];
        end
    end
endmodule

// Single-port RAM with write-first behavior
module single_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter RAM_DEPTH = 8
)(
    input wire clk,
    input wire rst,  // Reset port (port 6)
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    input wire we
);
    reg [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];
    
    integer i;
    
    // Write first, then read
    always @(posedge clk) begin
        if (rst) begin
            data_out <= 0;
            for (i = 0; i < RAM_DEPTH; i = i + 1) begin
                ram[i] <= 0;
            end
        end else begin
            if (we) begin
                ram[addr] <= data_in;
                data_out <= data_in;
            end else begin
                data_out <= ram[addr];
            end
        end
    end
endmodule