`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Paraqum Technologies
// Engineer: H.A.D.N.M. Jayasinghe 
// 
// Create Date: 07/11/2019 08:48:46 AM
// Design Name: 
// Module Name: control
// Project Name: i2c_wrapper
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

module control
#(
    parameter mem_depth = 386
)(
    clk,
    reset,
    start_p,
    scl,
    alldone,
    sda
);

//---------------------------------------------------------------------------------------------------------------------
// IO
//---------------------------------------------------------------------------------------------------------------------

input           clk;
input           reset;
input           start_p = 0;
output  wire    scl;
output  wire    alldone;
inout   wire    sda;

//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------

reg     [3:0]   PS;
reg     [3:0]   NS;

reg             send_now =0;
reg             r_en = 0;
reg     [8:0]   addr = 0;  
reg     [15:0]  address = 0;
reg     [7:0]   data=0;
reg     [23:0]  counter;

wire    [15:0]  do_aram;
wire    [7:0]   do_dram;
wire            ready;
wire            idle;
wire            done;

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------

localparam
RESET               =   0,
IDLE                =   1,
START               =   2,
WAIT                =   3,
GET_ADDR_AND_DATA   =   4,
SEND                =   5,
SEND_DONE           =   6,
ALLDONE             =   7,
STALL               =   8;

//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------

i2c10bit i2cclockic
        (
        .clock(clk),
        .reset(reset),
        .address(address),
        .data(data),
        .start(send_now),
        .ready(ready),
        .idle(idle),
        .done(done),
        .scl(scl),
        .sda(sda) 
        );

/*address_ram aram_
        (
        .clk(clk), 
        .r_en(r_en), 
        .addr(addr), 
        .do(do_aram)
        ); 

data_ram dram_
        (
        .clk(clk), 
        .r_en(r_en), 
        .addr(addr), 
        .do(do_dram)
        );*/

rom_address aram (
          .clka(clk),       // input wire clka
          .ena(r_en),       // input wire ena
          .addra(addr),     // input wire [8 : 0] addra
          .douta(do_aram)   // output wire [15 : 0] douta
        );
        
rom_data dram (
          .clka(clk),       // input wire clka
          .ena(r_en),       // input wire ena
          .addra(addr),     // input wire [8 : 0] addra
          .douta(do_dram)   // output wire [7 : 0] douta
        );

assign alldone  = (PS===ALLDONE)? 1:0;
//fsm
always @(posedge clk)
    if (reset)
        PS<=RESET;
    else
        PS<=NS;
        
//next state        
always @(*)
    case (PS)
        RESET:begin
            NS=IDLE;
        end
        
        IDLE:begin                      //state where the start process signal is given. Writing to clockic starts here
            if (start_p)
                NS=START;
            else
                NS=IDLE;
        end
        
        START:begin                     //signals for reading from address and data memories are given
            NS=WAIT;
        end
        
        WAIT:begin
            if (counter==2)             //the fsm halts 3 clockcycles here to read from the block memory
                NS=GET_ADDR_AND_DATA;
            else
                NS=WAIT;
        end
        
        GET_ADDR_AND_DATA:begin         //address and data is sampled in this state. This sampled address and data
            if (addr===mem_depth)       //is given to the i2c state machine to send over the 12c line
                NS=ALLDONE;
            else
                NS=SEND;
        end
        
        SEND:begin                      //the start signal to begin the transmission the 12c state machine
            NS=SEND_DONE;
        end
        
        SEND_DONE:begin                 //checking the done signal. If done, go to next transmission
            if (done)begin              //else stay in this state until 'done' comes
                if (addr===2)
                    NS=STALL;           //stall after configuring preamble
                else                    
                    NS=START;
                
            end
            else
                NS=SEND_DONE;
        end
        
        STALL:begin
            if (counter==4800000)       //delay 300 msec. delay is worst case time for device to complete any calibration
                NS=START;               //that is running due to device state change previous to this script being processed.
            else
                NS=STALL; 
        end
        
        ALLDONE:begin                   //fsm comes to this stage when all the data in the memory has been sent over the i2c line
            NS=IDLE;
        end               
                
    endcase

always @(posedge clk)
    if (reset)
        addr<=0;
    else begin
        case (PS)
            RESET:begin
                r_en<=0;   
                addr<=0;
            end
    
            START:begin
                r_en<=1;
            end
            
            WAIT:begin
                if (counter ==2)
                    r_en<=0;
            end
            
            GET_ADDR_AND_DATA:begin
                address<=do_aram;
                data<=do_dram;
            end
            
            SEND:begin
                send_now<=1;
            end
            
            SEND_DONE:begin
                send_now<=0;
                if (done)begin
                    addr<=addr+1;
                end   
            end
        endcase
    end
    
//counter    
always@(posedge clk) begin
            if(reset) begin
                counter     <= 'b0;
            end else begin
                case(PS)
                    WAIT:     
                        if(counter==2) begin
                            counter <= 'b0;
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    STALL:     
                        if(counter==4800000) begin
                            counter <= 'b0;
                        end else begin
                            counter <= counter + 1'b1;
                        end
                endcase
            end
    end
       
endmodule
