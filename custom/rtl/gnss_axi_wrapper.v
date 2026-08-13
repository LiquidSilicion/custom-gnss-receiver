// gnss_axi_wrapper.v
// AXI4-Lite bridge for gnss_top on ZedBoard (FIXED)

module gnss_axi_wrapper
(
    // AXI4-Lite Slave
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    
    input  wire [15:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    
    input  wire [15:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,
    
    // ADC interface
    input  wire        adc_clk,
    input  wire [7:0]  adc_data,
    
    // PPS outputs
    output wire        pps_pulse1,
    output wire        pps_pulse2,
    output wire        pps_pulse3,
    output wire        pps_irq,
    output wire        irq
);

    // ==========================================
    // INTERNAL SIGNALS (Separated to avoid Multiple Drivers)
    // ==========================================
    
    // Signals dedicated to the WRITE path
    reg         wr_host_cs, wr_host_wr;
    reg  [13:0] wr_host_addr;
    reg  [31:0] wr_host_d4wt;

    // Signals dedicated to the READ path
    reg         rd_host_cs, rd_host_rd;
    reg  [13:0] rd_host_addr;

    // Final combined signals that go to gnss_top
    wire        host_cs, host_rd, host_wr;
    wire [13:0] host_addr;
    wire [31:0] host_d4wt;
    wire [31:0] host_d4rd;

    // Combine Read and Write paths using simple logic gates
    assign host_cs   = wr_host_cs | rd_host_cs;       // Active if EITHER is active
    assign host_wr   = wr_host_wr;                    // Only Write path can write
    assign host_rd   = rd_host_rd;                    // Only Read path can read
    assign host_addr = wr_host_cs ? wr_host_addr : rd_host_addr; // Mux address
    assign host_d4wt = wr_host_d4wt;                  // Data only comes from Write path

    // ==========================================
    // WRITE STATE MACHINE
    // ==========================================
    localparam W_IDLE=0, W_DATA=1, W_RESP=2;
    reg [1:0] w_state;
    reg [15:0] w_addr;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            w_state      <= W_IDLE;
            wr_host_cs   <= 1'b0;
            wr_host_wr   <= 1'b0;
            wr_host_addr <= 14'd0;
            wr_host_d4wt <= 32'd0;
            s_axi_awready<= 1'b1;
            s_axi_wready <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            case(w_state)
            W_IDLE: begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b0;
                s_axi_bvalid  <= 1'b0;
                wr_host_cs    <= 1'b0;
                wr_host_wr    <= 1'b0;
                if(s_axi_awvalid && s_axi_awready) begin
                    w_addr        <= s_axi_awaddr;
                    s_axi_awready <= 1'b0;
                    w_state       <= W_DATA;
                end
            end
            W_DATA: begin
                s_axi_wready <= 1'b1;
                if(s_axi_wvalid && s_axi_wready) begin
                    wr_host_cs   <= 1'b1;
                    wr_host_wr   <= 1'b1;
                    wr_host_addr <= w_addr[15:2]; // Convert byte addr to DWORD
                    wr_host_d4wt <= s_axi_wdata;
                    s_axi_wready <= 1'b0;
                    w_state      <= W_RESP;
                end
            end
            W_RESP: begin
                wr_host_cs   <= 1'b0;
                wr_host_wr   <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
                if(s_axi_bready && s_axi_bvalid) begin
                    s_axi_bvalid <= 1'b0;
                    w_state      <= W_IDLE;
                end
            end
            endcase
        end
    end

    // ==========================================
    // READ STATE MACHINE
    // ==========================================
    localparam R_IDLE=0, R_WAIT=1, R_RESP=2;
    reg [1:0] r_state;
    reg [31:0] rdata_hold;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            r_state       <= R_IDLE;
            rd_host_cs    <= 1'b0;
            rd_host_rd    <= 1'b0;
            rd_host_addr  <= 14'd0;
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
            s_axi_rresp   <= 2'b00;
            rdata_hold    <= 32'd0;
        end else begin
            case(r_state)
            R_IDLE: begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b0;
                rd_host_cs    <= 1'b0;
                rd_host_rd    <= 1'b0;
                if(s_axi_arvalid && s_axi_arready) begin
                    rd_host_cs    <= 1'b1;
                    rd_host_rd    <= 1'b1;
                    rd_host_addr  <= s_axi_araddr[15:2]; // Convert byte addr to DWORD
                    s_axi_arready <= 1'b0;
                    r_state       <= R_WAIT;
                end
            end
            R_WAIT: begin
                rd_host_cs   <= 1'b0;
                rd_host_rd   <= 1'b0;
                rdata_hold   <= host_d4rd; // Capture gnss_top output
                r_state      <= R_RESP;
            end
            R_RESP: begin
                s_axi_rdata  <= rdata_hold;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00; // OKAY
                if(s_axi_rready && s_axi_rvalid) begin
                    s_axi_rvalid <= 1'b0;
                    r_state      <= R_IDLE;
                end
            end
            endcase
        end
    end

    // ==========================================
    // gnss_top instance
    // ==========================================
    gnss_top u_gnss_top (
        .clk        (s_axi_aclk),
        .rst_b      (s_axi_aresetn),
        .adc_clk    (adc_clk),
        .adc_data   (adc_data),
        .host_cs    (host_cs),
        .host_rd    (host_rd),
        .host_wr    (host_wr),
        .host_addr  (host_addr),
        .host_d4wt  (host_d4wt),
        .host_d4rd  (host_d4rd),
        .event_mark (1'b0),
        .pps_pulse1 (pps_pulse1),
        .pps_pulse2 (pps_pulse2),
        .pps_pulse3 (pps_pulse3),
        .pps_irq    (pps_irq),
        .irq        (irq)
    );

endmodule