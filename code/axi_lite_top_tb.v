module axi_lite_master_tb #(
    parameter DATA_WD = 8,
    parameter ADDR_WD = 8,
    parameter KEEP_WD = (ADDR_WD + DATA_WD) >> 3
) ( );
reg                          clk;
reg                          rst_n;
reg                          tvalid;
wire [ADDR_WD+DATA_WD-1 : 0] tdata;
wire [1:0]                   tkeep;
wire                         tready;

initial begin
    clk = 0;
    forever
    #5 clk = ~clk;
end

initial begin
    rst_n = 0;
    #100
    rst_n = 1;
    #10000
    $finish;
end

initial begin
    $dumpfile("test.vcd");
    $dumpvars;
end

wire tfire;
assign tfire = tvalid && tready;

localparam RANDOM_FIRE = 0;
reg [DATA_WD : 0] data_cnt;

generate if (RANDOM_FIRE) begin
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_cnt <= 'b0;
        end
        else if (tfire) begin
            data_cnt <= data_cnt + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tvalid <= 1'b0;
        end
        else if (!tvalid || tready) begin
            tvalid <= $random;
        end
    end

assign tdata = {data_cnt[DATA_WD-1 : 0] , data_cnt[DATA_WD-1 : 0]};
assign tkeep = data_cnt[DATA_WD] ? 2'b10 : 2'b11 ;
end
else begin
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_cnt <= 'b0;
        end
        else if (tfire) begin
            data_cnt <= data_cnt + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tvalid <= 1'b0;
        end
        else if (!tvalid || tready) begin //has't pending
            tvalid <= 1'b1;
        end
    end

assign tdata = {data_cnt[DATA_WD-1 : 0] , data_cnt[DATA_WD-1 : 0]};
assign tkeep = data_cnt[DATA_WD] ? 2'b10 : 2'b11 ;    // assign tkeep =  (data_cnt[DATA_WD] && 2'b10) || (data_cnt[DATA_WD] && 2'b11)
end
endgenerate

axi_lite_master # (.DATA_WD(DATA_WD),
                .ADDR_WD(ADDR_WD),
                .KEEP_WD(KEEP_WD)    
) u_axi_lite_master ( 
                   .clk(clk),
                   .rst_n(rst_n),
                   .tvalid(tvalid),
                   .tdata(tdata),
                   .tkeep(tkeep),
                   .tready(tready)
);

endmodule