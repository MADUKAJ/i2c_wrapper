`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2019 05:12:59 PM
// Design Name: 
// Module Name: address_ram
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


module data_ram(clk, r_en, addr, do);
 input        clk;
 input        r_en;
 input  [8:0] addr;
 output [7:0] do = 0;
 reg    [7:0] DRAM [511:0];
 reg    [7:0] do;
 
 initial begin
     $readmemh("C:/Vivado_Projects/i2c_wrapper/i2c_wrapper/srcs/data.txt", DRAM);
 end
  
 always @(posedge clk)
 begin
    if (r_en) begin
       do <= DRAM[addr];
    end
 end

endmodule

