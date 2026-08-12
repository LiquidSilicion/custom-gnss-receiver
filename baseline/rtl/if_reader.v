// Reads pre-recorded IF data from BRAM and feeds it to gnss_top
// Replaces test_pattern_gen with REAL GNSS signal data

module if_data_reader #(
    parameter MEM_DEPTH = 822600,  // 200ms × 4.113MHz ≈ 822,600 samples
    parameter ADC_WIDTH = 8
)(
    input  wire clk,
    input  wire rst_b,
    
    // Control from AXI (optional, for start/stop)
    input  wire enable,
    input  wire  restart,
    
    // Output to gnss_top
    output reg adc_clk,
    output reg [ADC_WIDTH-1:0]adc_data
);

    // ---- Generate 4.113 MHz ADC clock from 100 MHz ----
    // 100 MHz / 4.113 MHz ≈ 24.31
    // Use a fractional divider or just approximate
    // For simplicity: divide by 24 → 4.167 MHz (close enough for demo)
    reg [4:0] clk_div;
    
    always @(posedge clk) begin
        if (!rst_b) begin
            clk_div <= 5'd0;
            adc_clk <= 1'b0;
        end else begin
            if (clk_div >= 5'd23) begin  // 100/24 ≈ 4.17 MHz
                clk_div <= 5'd0;
                adc_clk <= ~adc_clk;
            end else begin
                clk_div <= clk_div + 1;
            end
        end
    end

    // ---- BRAM to hold IF data ----
    // 822,600 samples × 8 bits = 6.6 Mb
    // ZedBoard (xc7z020) has 4.9 Mb BRAM — NOT ENOUGH for full 200ms!
    
    // Solution: Use only first 10ms (41,130 samples) = 329 Kb
    // This fits easily and is enough for acquisition testing
    parameter USE_DEPTH = 41130;  // 10ms of data
    reg [ADC_WIDTH-1:0] if_mem [0:USE_DEPTH-1];
    
    initial begin
        $readmemh("if_data.mem", if_mem);
    end

    // ---- Replay the data ----
    reg [15:0] read_addr;
    reg [15:0] max_addr;
    
    initial max_addr = USE_DEPTH - 1;
    
    always @(posedge adc_clk) begin
        if (!rst_b) begin
            read_addr <= 16'd0;
            adc_data <= 8'd0;
        end else if (restart) begin
            read_addr <= 16'd0;
        end else if (enable) begin
            adc_data <= if_mem[read_addr];
            if (read_addr >= max_addr)
                read_addr <= 16'd0;  // Loop
            else
                read_addr <= read_addr + 1;
        end
    end

endmodule