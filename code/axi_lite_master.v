module axi_lite_master #(
    parameter ADDR_WD = 8,
    parameter DATA_WD = 8,
    parameter KEEP_WD = (ADDR_WD + DATA_WD) >> 3
) (
    input                              clk,
    input                              rst_n,

    input                              tvalid,
    input  [ADDR_WD + DATA_WD - 1 : 0] tdata,
    input  [KEEP_WD - 1 : 0]           tkeep,
    output                             tready,

    output                             awvalid,
    output [ADDR_WD - 1 : 0]           awaddr,
    input                              awready,

    output                             wvalid,
    output [DATA_WD - 1 : 0]           wdata,
    input                              wready,

    input                              bvalid,
    input  [1 : 0]                     bresp,
    output                             bready,

    output                             arvalid,
    output [ADDR_WD - 1 : 0]           araddr,
    input                              arready,

    input                              rvalid,
    input  [DATA_WD - 1 : 0]           rdata,
    input  [1 : 0]                     rresp,
    output                             rready
);

    wire cmd = & tkeep;
    wire tvalid4w = tvalid && cmd;
    wire tvalid4r = tvalid && !cmd;
    wire tready4w;
    wire tready4r;

    wire [ADDR_WD - 1 : 0] taddr4w = tdata [ADDR_WD + DATA_WD - 1 -: ADDR_WD];  //注意这种用法时-和:之间不能加空格
    wire [ADDR_WD - 1 : 0] taddr4r = tdata [ADDR_WD + DATA_WD - 1 -: ADDR_WD];
    wire [DATA_WD - 1 : 0] tdata4w = tdata [DATA_WD - 1 : 0];

    assign tready = (tready4w && cmd) || (tready4r && !cmd);

    axi_lite_master_write #(
        .DATA_WD(DATA_WD),
        .ADDR_WD(ADDR_WD)
    )   write_master(
        .clk(clk),
        .rst_n(rst_n),
        .tvalid(tvalid4w),
        .taddr(taddr4w),
        .tdata(tdata4w),
        .tready(tready4w),
        .awvalid(awvalid),
        .awaddr(taddr4w),
        .awready(awready),
        .wvalid(wvalid),
        .wdata(wdata),
        .wready(wready),
        .bvalid(bvalid),
        .bresp(bresp),
        .bready(bready)
    );

    axi_lite_master_read #(
        .DATA_WD(DATA_WD),
        .ADDR_WD(ADDR_WD)
    )   read_master(
        .clk(clk),
        .rst_n(rst_n),
        .tvalid(tvalid4r),
        .taddr(taddr4r),
        .tready(tready4r),
        .arvalid(arvalid),
        .araddr(araddr),
        .arready(arready),
        .rvalid(rvalid),
        .rdata(rdata),
        .rresp(rresp),
        .rready(rready)
    );

    axi_lite_slave #(
        .ADDR_WD(ADDR_WD),
        .DATA_WD(DATA_WD)
    ) u_axi_lite_slave(
        .a_clk(clk),
        .a_resetn(rst_n),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .awready(awready),
        .wvalid(wvalid),
        .wdata(wdata),
        .wready(wready),
        .bready(bready),
        .bresp(bresp),
        .bvalid(bvalid),
        .arvalid(arvalid),
        .araddr(araddr),
        .arready(arready),
        .rready(rready),
        .rvalid(rvalid),
        .rresp(rresp),
        .rdata(rdata)
    );
    
endmodule

module axi_lite_master_read #(
    parameter DATA_WD = 8,
    parameter ADDR_WD = 8
) (
    input                    clk,
    input                    rst_n,

    input                    tvalid,
    input [ADDR_WD - 1 : 0]  taddr,
    output                   tready,

    output                   arvalid,
    output [ADDR_WD - 1 : 0] araddr,
    input                    arready,

    input                    rvalid,
    input [1 : 0]            rresp,
    input [DATA_WD - 1 : 0]  rdata,
    output                   rready
);
    
    wire tfire = tvalid && tready;
    wire arfire = arvalid && arready;
    wire rfire = rvalid && rready;

 // reg                   tready_r; 不需要，是给tb的反馈?
    reg                   arvalid_r;
    reg [ADDR_WD - 1 : 0] araddr_r;
    reg                   rready_r;

    assign arvalid = arvalid_r;
    assign araddr = araddr_r;
    assign rready = rready_r;

    wire has_resp_pending = rvalid && !rready;
    assign tready = !has_resp_pending;
    // reg                   tfire_r;
    // reg                   arfire_r;
    // reg                   rfire_r;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            arvalid_r <= 1'b0;
            araddr_r <= 'b0;
            rready_r <= 1'b0;
        end
        else begin
            if(arfire) begin
                arvalid_r <= 1'b0;
            end
            if(rfire) begin
                rready_r <= 1'b0;
            end
            if(arfire) begin
                rready_r <= 1'b1; //注意将arfire拆开，因为rready_r置1要放在后面以便实现连续传输
            end
            if(tfire) begin
                arvalid_r <= 1'b1;
                araddr_r <= taddr;
            end
        end
    end

endmodule

module axi_lite_master_write #(
    parameter DATA_WD = 8,
    parameter ADDR_WD = 8
) (
    input                    clk,
    input                    rst_n,

    input                    tvalid,
    input [ADDR_WD - 1 : 0]  taddr,
    input [DATA_WD - 1 : 0]  tdata,
    output                   tready,

    output                   awvalid,
    output [ADDR_WD - 1 : 0] awaddr,
    input                    awready,

    output                   wvalid,
    output [DATA_WD - 1 : 0] wdata,
    input                    wready,

    input                    bvalid,
    input [1 : 0]            bresp,
    output                   bready
);
    
    wire tfire = tvalid && tready;
    wire awfire = awvalid && awready;
    wire wfire = wvalid && wready;
    wire bfire = bvalid && bready;

    reg                   awvalid_r;
    reg [ADDR_WD - 1 : 0] awaddr_r;
    reg                   awfire_r;
    
    reg                   wvalid_r;
    reg [DATA_WD - 1 : 0] wdata_r;
    reg                   wfire_r;

    reg                   bready_r;

    assign awvalid = awvalid_r;
    assign awaddr = awaddr_r;
    assign wvalid = wvalid_r;
    assign wdata = wdata_r;
    assign bready = bready_r;

    assign awfire = awfire_r; //因为存在读地址先到或者读数据先到的情况，所以需要寄存器保存先到的数据
    assign wfire = wfire_r;

    wire has_write_resp_pending = bvalid && !bready;
    assign tready = !has_write_resp_pending;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            awfire_r <= 1'b0;
            wfire_r <= 1'b0;

            awvalid_r <= 1'b0;
            awaddr_r <= 'b0;
            wvalid_r <= 1'b0;
            wdata_r <= 'b0;
            bready_r <= 1'b0;
        end
        else begin
            if(awfire) begin
                awvalid_r <= 1'b0;
                awfire_r <= 1'b1;
            end
            if(wfire) begin
                wvalid_r <= 1'b0;
                wfire_r <= 1'b1;
            end
            if(bfire) begin
                bready_r <= 1'b0;
                awfire_r <= 1'b0;
                wfire_r <= 1'b0;
            end
            if(tfire) begin
                awvalid_r <= 1'b1;
                wvalid_r <= 1'b1;
                awaddr_r <= taddr;
                wdata_r <= tdata;
            end
            if(awfire && wfire) begin
                bready_r <= 1'b1;
            end
            else if(awfire && wfire_r) begin
                bready_r <= 1'b1;
            end
            else if(awfire_r && wfire) begin
                bready_r <= 1'b1;
            end
        end
    end

endmodule