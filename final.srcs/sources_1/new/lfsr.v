`timescale 1ns / 1ps

// LFSR Random Number Generator
// Generates random values in range 1-99
module lfsr_rng #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 3,
    parameter MAX_ARRAY_SIZE = 8
)(
    input wire clk,
    input wire rst,
    input wire [7:0] seed_in,
    input wire generate_enable,      // Start generating random array
    input wire [ADDR_WIDTH:0] array_length,  // How many numbers to generate
    output reg [DATA_WIDTH-1:0] random_value,
    output reg [ADDR_WIDTH-1:0] write_addr,
    output reg write_enable,
    output reg generation_done
);

    // LFSR state register (8-bit for maximal-length sequence)
    reg [7:0] lfsr_state;
    
    // Counter for array generation
    reg [ADDR_WIDTH:0] count;
    
    // FSM states
    localparam IDLE = 2'd0;
    localparam GENERATING = 2'd1;
    localparam SCALE = 2'd2;
    localparam DONE = 2'd3;
    
    reg [1:0] state;
    reg [7:0] raw_value;
    
    // Maximal-length LFSR with taps at positions 8, 6, 5, 4
    // Polynomial: x^8 + x^6 + x^5 + x^4 + 1
    wire feedback;
    assign feedback = lfsr_state[7] ^ lfsr_state[5] ^ lfsr_state[4] ^ lfsr_state[3];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lfsr_state <= 8'b10101010;  // Non-zero seed (avoid all-zeros)
            random_value <= 0;
            write_addr <= 0;
            write_enable <= 0;
            generation_done <= 0;
            count <= 0;
            state <= IDLE;
            raw_value <= 0;
        end else begin
            case (state)
                IDLE: begin
                    write_enable <= 0;
                    generation_done <= 0;
                    count <= 0;
                    write_addr <= 0;
                    
                    if (generate_enable) begin
                         // Load the new seed when generation starts!
                        // We check for 0 just in case, as 0 is an invalid LFSR state.
                        lfsr_state <= (seed_in == 8'd0) ? 8'b10101010 : seed_in;
                        state <= GENERATING;
                    end
                end
                
                GENERATING: begin
                    // Shift LFSR to generate next value
                    lfsr_state <= {lfsr_state[6:0], feedback};
                    raw_value <= {lfsr_state[6:0], feedback};
                    state <= SCALE;
                end
                
                SCALE: begin
                    // Scale the 8-bit value (0-255) to range 1-99
                    // Method: (raw_value % 99) + 1
                    // For hardware efficiency, we use: if value > 99, subtract 99 until in range
                    
                    if (raw_value == 0) begin
                        random_value <= 8'd1;  // Avoid zero
                    end else if (raw_value <= 99) begin
                        random_value <= raw_value;
                    end else if (raw_value <= 198) begin
                        random_value <= raw_value - 99;
                    end else begin
                        random_value <= raw_value - 198;
                    end
                    
                    write_addr <= count[ADDR_WIDTH-1:0];
                    write_enable <= 1;
                    count <= count + 1;
                    
                    if (count >= array_length - 1) begin
                        state <= DONE;
                    end else begin
                        state <= GENERATING;
                    end
                end
                
                DONE: begin
                    write_enable <= 0;
                    generation_done <= 1;
                    
                    if (!generate_enable) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule