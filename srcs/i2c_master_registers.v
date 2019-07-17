//-------------------------------------------------------------------------
//  >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
//-------------------------------------------------------------------------
/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE revB.2 compliant I2C Master controller Top-level  ////
////                                                             ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/projects/i2c/    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
//  Copyright (c) 2008 by Lattice Semiconductor Corporation      
// 
//-------------------------------------------------------------------------                           
// Disclaimer:
//
//   This VHDL or Verilog source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Lattice Semiconductor provides no warranty
//   regarding the use or functionality of this code.
//-------------------------------------------------------------------------
//
//    Lattice Semiconductor Corporation
//    5555 NE Moore Court
//    Hillsboro, OR 97124
//    U.S.A
//
//    TEL: 1-800-Lattice (USA and Canada)
//    503-268-8001 (other locations)
//
//    web: http://www.latticesemi.com/
//    email: techsupport@latticesemi.com
// 
//-------------------------------------------------------------------------
// Name:  i2c_master_registers.v   
// 
// Description: This module contains the registers used in the i2c core
//   
//-------------------------------------------------------------------------
// Code Revision History :
//-------------------------------------------------------------------------
// Ver: | Author	|Mod. Date	|Changes Made:
// V2.0 | cm		|12/2008    |Init ver - move the logic from top module
//-------------------------------------------------------------------------

//`include "..\testbench\timescale.v"

`timescale 1ns / 10ps


module i2c_master_registers (wb_clk_i, rst_i, wb_rst_i,wb_dat_i,wb_adr_i,
                  wb_wacc, i2c_al, i2c_busy, 
                  done,irxack,
		  prer,                  
		  ctr, 
                  txr, 
                  cr,  
                  sr);
           
input wb_clk_i;     
input rst_i;        
input wb_rst_i;
input [7:0] wb_dat_i;
input [2:0] wb_adr_i;
input wb_wacc;       //wishbone write access
input i2c_al;    
input i2c_busy;
input  done, irxack;
output  [15:0] prer; // clock prescale register  
output  [ 7:0] ctr;  // control register         
output  [ 7:0] txr;  // transmit register                
output  [ 7:0] cr;   // command register         
output  [ 7:0] sr;   // status register          

reg  [15:0] prer; // clock prescale register                 
reg  [ 7:0] ctr;  // control register                    
reg  [ 7:0] txr;  // transmit register        
//wire [ 7:0] rxr;  // receive register         
reg  [ 7:0] cr;   // command register         
wire [ 7:0] sr;   // status register   

// generate prescale regisres, control registers, and transmit register                                                         
always @(posedge wb_clk_i or negedge rst_i)   
  if (!rst_i)                                             
    begin                                                 
        prer <= #1 16'hffff;                              
        ctr  <= #1  8'h0;                                 
        txr  <= #1  8'h0;                                 
    end                                                   
  else if (wb_rst_i)                                      
    begin                                                 
        prer <= #1 16'hffff;                              
        ctr  <= #1  8'h0;                                 
        txr  <= #1  8'h0;                                 
    end                                                   
  else                                                    
    if (wb_wacc)                                          
      case (wb_adr_i) // synopsis parallel_case           
         3'b000 : prer [ 7:0] <= #1 wb_dat_i;             
         3'b001 : prer [15:8] <= #1 wb_dat_i;             
         3'b010 : ctr         <= #1 wb_dat_i;             
         3'b011 : txr         <= #1 wb_dat_i;             
         default: ;                                       
      endcase                                             
                                                          
// generate command register (special case)                             
always @(posedge wb_clk_i or negedge rst_i )    
  if (~rst_i)                                             
    cr <= #1 8'h0;                                        
  else if (wb_rst_i)                                      
    cr <= #1 8'h0;                                        
  else if (wb_wacc)                                       
    begin                                                 
        //if (core_en & (wb_adr_i == 3'b100) ) 
        if (ctr[7] & (wb_adr_i == 3'b100) )              
          cr <= #1 wb_dat_i;                              
    end                                                   
  else                                                    
    begin                                                 
        if (done | i2c_al)                                
          cr[7:4] <= #1 4'h0;           // clear command b
                                        // or when aribitr
        cr[2:1] <= #1 2'b0;             // reserved bits  
        cr[0]   <= #1 2'b0;             // clear IRQ_ACK b
    end                                                   
    
reg  al;          // status register arbitration lost bit              
reg  rxack;       // received aknowledge from slave
reg  tip;         // transfer in progress
reg  irq_flag;    // interrupt pending flag           
                                                          
                                                          
// generate status register block + interrupt request signal  
// each output will be assigned to corresponding sr register locations on top level                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
always @(posedge wb_clk_i or negedge rst_i ) 
  if (!rst_i)                                                                                                                                                                                                                                                                                                                                                                                                                              
    begin                                                                                                                                                                                                                                                                                                                                                                                                                                  
        al       <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                                               
        rxack    <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                                               
        tip      <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                                               
        irq_flag <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                  
    end                                                                                                                                                                                                                                                                                                                                                                                                       
  else if (wb_rst_i)                                                                                                                                                                                                                                                                                                                                                                                          
    begin                                                                                                                                                                                                                                                                                                                                                                                                     
        al       <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                  
        rxack    <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                  
        tip      <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                  
        irq_flag <= #1 1'b0;                                                                                                                                                                                                                                                                                                                                                                                  
    end                                                                                                                                                                                                                                                                                                                                                                                                       
  else                                                                                                                                                                                                                                                                                                                                                                                                        
    begin                                                                                                                                                                                                                                                                                                                                                                                                     
        //al       <= #1 i2c_al | (al & ~sta);   
        al       <= #1 i2c_al | (al & ~cr[7]);                                                                                                                                                                                                                                                                                                                                                                 
        rxack    <= #1 irxack;                                                                                                                                                                                                                                                                                                                                                                                
        //tip      <= #1 (rd | wr);
        tip      <= #1 (cr[5] | cr[4]);                                                                                                                                                                                                                                                                                                                                                                              
        //irq_flag <= #1 (done | i2c_al | irq_flag) & ~iack;     
        irq_flag <= #1 (done | i2c_al | irq_flag) & ~cr[0];  // interrupt request flag is always generated                                                                                                                                                                                                                                                                                                
    end
        
// assign status register bits               
assign sr[7]   = rxack;               
assign sr[6]   = i2c_busy;            
assign sr[5]   = al;                  
assign sr[4:2] = 3'h0; // reserved    
assign sr[1]   = tip;                 
assign sr[0]   = irq_flag;  

endmodule         
