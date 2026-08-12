// gnss_axi_wrapper.v
// AXI4-Lite bridge for gnss_top on ZedBoard

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

    reg         host_cs, host_rd, host_wr;
    reg  [13:0] host_addr;
    reg  [31:0] host_d4wt;
    wire [31:0] host_d4rd;

    // ---- WRITE ----
    localparam W_IDLE=0, W_DATA=1, W_RESP=2;
    reg [1:0] w_state;
    reg [15:0] w_addr;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            w_state<=W_IDLE; host_cs<=0; host_wr<=0; host_rd<=0;
            s_axi_awready<=0; s_axi_wready<=0; s_axi_bvalid<=0;
        end else begin
            case(w_state)
            W_IDLE: begin
                s_axi_awready<=1; s_axi_wready<=0; s_axi_bvalid<=0;
                host_cs<=0; host_wr<=0;
                if(s_axi_awvalid && s_axi_awready) begin
                    w_addr<=s_axi_awaddr; s_axi_awready<=0; w_state<=W_DATA;
                end
            end
            W_DATA: begin
                s_axi_wready<=1;
                if(s_axi_wvalid && s_axi_wready) begin
                    host_cs<=1; host_wr<=1;
                    host_addr<=w_addr[15:2]; host_d4wt<=s_axi_wdata;
                    s_axi_wready<=0; w_state<=W_RESP;
                end
            end
            W_RESP: begin
                host_cs<=0; host_wr<=0; s_axi_bvalid<=1; s_axi_bresp<=0;
                if(s_axi_bready) begin s_axi_bvalid<=0; w_state<=W_IDLE; end
            end
            endcase
        end
    end

    // ---- READ ----
    localparam R_IDLE=0, R_WAIT=1, R_RESP=2;
    reg [1:0] r_state;
    reg [31:0] rdata_hold;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            r_state<=R_IDLE; s_axi_arready<=0; s_axi_rvalid<=0;
            s_axi_rdata<=0; s_axi_rresp<=0;
        end else begin
            case(r_state)
            R_IDLE: begin
                s_axi_arready<=1; s_axi_rvalid<=0;
                if(s_axi_arvalid && s_axi_arready) begin
                    host_cs<=1; host_rd<=1;
                    host_addr<=s_axi_araddr[15:2];
                    s_axi_arready<=0; r_state<=R_WAIT;
                end
            end
            R_WAIT: begin
                host_cs<=0; host_rd<=0;
                rdata_hold<=host_d4rd; r_state<=R_RESP;
            end
            R_RESP: begin
                s_axi_rdata<=rdata_hold; s_axi_rvalid<=1; s_axi_rresp<=0;
                if(s_axi_rready) begin s_axi_rvalid<=0; r_state<=R_IDLE; end
            end
            endcase
        end
    end

    // ---- gnss_top instance ----
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