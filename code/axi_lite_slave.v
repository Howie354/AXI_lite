module axi_lite_slave #(
    parameter ADDR_WD = 8,
    parameter DATA_WD = 8 
)(
    input                  a_clk,
    input                  a_resetn,

    input                  awvalid,
    input [ADDR_WD-1 : 0]  awaddr,
    output                 awready,

    input                  wvalid,
    input [DATA_WD-1 : 0]  wdata,
    output                 wready,

    input                  bready,
    output [1 : 0]         bresp,
    output                 bvalid,
 
    input                  arvalid,
    input [ADDR_WD-1 : 0]  araddr,
    output                 arready,

    input                  rready,
    output                 rvalid,
    output                 rresp,
    output [DATA_WD-1 : 0] rdata
);

    localparam DEPTH = 1 << ADDR_WD;               //变位数为个数
    reg [DATA_WD-1 : 0] mem [DEPTH-1 : 0];

    // handshake 4 cases:
    // valid && ready        fire
    // valid && !ready       wait/pending
    // ！valid && ready      ready/available
    // ！valid && !ready         
    
    // handshake data changable next beat:
    // fire || !valid  =====> (valid && ready) || !valid =====> ready || !valid                 non-block/non-wait
    wire awfire = awvalid && awready;
    wire wfire = wvalid && wready;
    wire bfire = bvalid && bready;
    wire arfire = arvalid && arready;
    wire rfire = rvalid && rready;

    wire has_write_resp_wait = bvalid || !bready;   //写反馈通道被阻塞
    assign awready = (!has_write_resp_wait || awvalid_r);   //写地址信号已经fire而写数据信号还未fire，所以awready需要拉低
    assign wready = (!has_write_resp_wait || wvalid_r);     //写数据信号已经fire而写地址信号还未fire，所以wready需要拉低

    wire has_read_resp_wait = rvalid && !rready; //读反馈通道被阻塞
    assign arready = !has_read_resp_wait;

    reg                 awvalid_r;
    reg                 wvalid_r;
    reg [ADDR_WD-1 : 0] awaddr_r;
    reg [DATA_WD-1 : 0] wdata_r;
    reg                 bvalid_r;
    reg                 rvalid_r;
    reg [DATA_WD-1 : 0] rdata_r;

    assign bvalid = bvalid_r;
    assign rvalid = rvalid_r;
    assign rdata = rdata_r;
    
    always @(posedge a_clk or negedge a_resetn) begin     //对写的部分的控制信号赋值
        if(!a_resetn) begin
            awvalid_r <= 1'b0;
            wvalid_r <= 1'b0;
            awaddr_r <= 'b0;
            wdata_r <= 'b0;
            bvalid_r <= 1'b0;
        end
        else begin
            if(awfire) begin
                awvalid_r <= 1'b1;
                awaddr_r <= awaddr;
            end
            if(wfire) begin
                wvalid_r <= 1'b1;
                wdata_r <= wdata;
            end
            if(bfire) begin
                bvalid_r <= 1'b0;
            end
            else if(awfire && wfire) begin
                mem[awaddr_r] <= wdata;
                awvalid_r <= 1'b0;
                wvalid_r <= 1'b0;
                bvalid_r <= 1'b1;
            end
            else if(awfire && wvalid_r) begin
                mem[awaddr] <= wdata_r;
                awvalid_r <= 1'b0;
                wvalid_r <= 1'b0;
                bvalid_r <= 1'b1;
            end
            else if(awaddr_r && wfire) begin
                mem[awaddr_r] <= wdata;
                awvalid_r <= 1'b0;
                wvalid_r <= 1'b0;
                bvalid_r <= 1'b1;
            end
        end
    end

    always @(posedge a_clk or negedge a_resetn) begin    //对读的部分的控制信号赋值
        if(!a_resetn) begin
            rvalid_r <= 1'b0;
            rdata_r <= 'b0;
        end
        else begin
            if(arfire) begin
                rvalid_r <= 1'b1;
                rdata_r <= mem[araddr];
            end
            if(rfire) begin
                rvalid_r <= 1'b0;
            end
        end
    end

endmodule