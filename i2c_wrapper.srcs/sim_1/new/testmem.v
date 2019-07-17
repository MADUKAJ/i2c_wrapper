`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2019 10:38:22 PM
// Design Name: 
// Module Name: testmem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module testmem();

     reg        clk;
     reg        reset;
     reg        start_p;
     wire       scl;
     wire       alldone;
     wire       sda;
 
    parameter SADR    = 7'b001_0000; 
 
initial begin
     clk=0;
     forever begin
         clk=#31.25 ~clk; //32MHz
         end
     end
   
control #(386) control
    (
    .clk(clk),
    .reset(reset),
    .start_p(start_p),
    .scl(scl),
    .alldone(alldone),
    .sda(sda)
    );

i2c_slave_model #(SADR) i2c_slave 
    ( 
    .scl(scl), 
    .sda(sda) 
    );

pullup p1(scl);
pullup p2(sda);

initial begin
    
    repeat(5)@(posedge clk);
    reset=1;
    repeat(1)@(posedge clk);
    reset=0;
    repeat(3)@(posedge clk);
    start_p=1;
    repeat(1)@(posedge clk);
    start_p=0;
    
    /*#260000000;
    
    repeat(5)@(posedge clk);
    reset=1;
    repeat(1)@(posedge clk);
    reset=0;
    repeat(3)@(posedge clk);
    start_p=1;
    repeat(1)@(posedge clk);
    start_p=0;*/

    end
endmodule
