`timescale 1ns / 1ps

module test_10bit();

    reg        clk; 
	reg        reset;
	reg [15:0] address;
	reg [7:0]  data;
	reg        start;
	wire       ready;
	wire       idle;
	wire       done;
	wire       scl;
    wire       sda; 

    parameter SADR    = 7'b001_0000;


i2c10bit i2c10bit(.clock(clk),.reset(reset),.address(address),.data(data),.start(start),.ready(ready),.idle(idle),.done(done),.scl(scl),.sda(sda) );

i2c_slave_model #(SADR) i2c_slave ( .scl(scl), .sda(sda) );

initial begin
    clk=0;
    forever begin
        clk=#31.25 ~clk; //32MHz
        end
    end
    
pullup p1(scl);
pullup p2(sda);

initial begin
    repeat (1)@(posedge clk);
    reset <= 1'b1;
    repeat (1)@(posedge clk);
    reset <= 1'b0;
    repeat (5)@(posedge clk);
    address<= 16'h0101;
    data<=8'hbb;
    start<=1'b1;
    repeat (1)@(posedge clk);
    start<=1'b0;
    
    repeat (25000)@(posedge clk);
    address<= 16'h0102;
    data<=8'h11;
    start<=1'b1;
    repeat (1)@(posedge clk);
    start<=1'b0;
    
    repeat (12000)@(posedge clk);
    address<= 16'h0202;
    data<=8'h11;
    start<=1'b1;
    repeat (1)@(posedge clk);
    start<=1'b0;
    
    repeat (25000)@(posedge clk);
    address<= 16'h0203;
    data<=8'h11;
    start<=1'b1;
    repeat (1)@(posedge clk);
    start<=1'b0;
end

endmodule
