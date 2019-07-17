`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: Paraqum Technologies
// Engineer: H.A.D.N.M. Jayasinghe 
// 
// Create Date: 07/11/2019 08:48:46 AM
// Design Name: 
// Module Name: 12c10bit
// Project Name: 12c_wrapper
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

module i2c10bit
    (
    clock,
    reset,
    address,
    data,
    start,
    ready,
    idle,
    done,
    scl,
    sda
    );

//---------------------------------------------------------------------------------------------------------------------
// IO
//---------------------------------------------------------------------------------------------------------------------

input           clock;
input           reset;
input [15:0]    address;
input [7:0]     data;
input           start;
output wire     ready;
output wire     idle;
output wire     done;
output wire     scl;
inout  wire     sda;

//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------

reg        wb_rst_i;     // synchronous active high reset
reg  [2:0] wb_adr_i;     // lower address bits
reg  [7:0] wb_dat_i;     // databus input
	
wire [7:0] wb_dat_o;     // databus output
	
reg        wb_we_i;      // write enable input
reg        wb_stb_i;     // stobe/core select signal
reg        wb_cyc_i;     // valid bus cycle input
	
wire       wb_ack_o;     // bus cycle acknowledge output
wire       wb_inta_o;    // interrupt request signal output
wire [7:0] sr_o;

reg  [4:0] PS    = 5'dx;
reg  [4:0] NS;

reg  [7:0] addrh;
reg  [7:0] addrl;
reg  [7:0] data_in;
reg  [2:0] counter;
reg        counter_done =0;
reg        status       =0; 
 
//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
   
localparam PRER_LO = 3'b000;
localparam PRER_HI = 3'b001;
localparam CTR     = 3'b010;
localparam RXR     = 3'b011;
localparam TXR     = 3'b011;
localparam CR      = 3'b100;
localparam SR      = 3'b100;

localparam SADR    = 7'b001_0000;

localparam RESET         = 5'd0;
localparam SEND_PREH     = 5'd1;
localparam SEND_PREL     = 5'd2;
localparam SEND_CTR      = 5'd3;
localparam IDLE          = 5'd4;
localparam START         = 5'd5;
localparam WR_SLADD      = 5'd6;
localparam SEND_SLADD    = 5'd7;
localparam CHK_SLADD1    = 5'd8;
localparam CHK_SLADD2    = 5'd9;
localparam WR_IADD       = 5'd27;
localparam SEND_IADD     = 5'd28;
localparam CHK_IADD1     = 5'd29;
localparam CHK_IADD2     = 5'd30;
localparam WR_ADDRH      = 5'd10;
localparam SEND_ADDRH    = 5'd11;
localparam CHK_ADDRH1    = 5'd12;
localparam CHK_ADDRH2    = 5'd13;
localparam REWR_SLADD    = 5'd14;
localparam RESEND_SLADD  = 5'd15;
localparam RECHK_SLADD1  = 5'd16;
localparam RECHK_SLADD2  = 5'd17;
localparam WR_ADDRL      = 5'd18;
localparam SEND_ADDRL    = 5'd19;
localparam CHK_ADDRL1    = 5'd20;
localparam CHK_ADDRL2    = 5'd21;
localparam WR_DATA       = 5'd22;
localparam SEND_DATA     = 5'd23;
localparam CHK_DATA1     = 5'd24;
localparam CHK_DATA2     = 5'd25;
localparam STOP          = 5'd26;

//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
    
i2c_master_top #(.ARST_LVL (0)) ic_top
            (
            .wb_clk_i(clock),
            .wb_rst_i(reset),
            .arst_i(1'b1),
            .wb_adr_i(wb_adr_i),
            .wb_dat_i(wb_dat_i),
            .wb_dat_o(wb_dat_o),
            .wb_we_i(wb_we_i),
            .wb_stb_i(wb_stb_i),
            .wb_cyc_i(wb_cyc_i),
            .wb_ack_o(wb_ack_o),
            .wb_inta_o(wb_inta_o),
            .scl(scl),
            .sda(sda),
            .sr_o(sr_o)
            );

assign idle     = (PS===IDLE)? 1:0;
assign ready    = (PS===IDLE)? 1:0;
assign done     = (PS===STOP)? 1:0;
            
//fsm
always @(posedge clock)
    if(reset)
        PS<=RESET;
    else
        PS<=NS;
        
//next-state
always @(*) 
    begin
        NS = PS;
        case(PS)
            RESET:                                          //reset state. all wishbone signals are set to zero
                begin
                    NS  =SEND_PREH;                                   
                end
                
            SEND_PREH:                                      //prescaler high byte is sent 
                begin
                    NS  =SEND_PREL;
                end
            
            SEND_PREL:                                      //prescaler low byte is sent 
                begin
                    NS=SEND_CTR;
                end

            SEND_CTR:                                       //control register is set. (12C core is enabled)
                begin
                    NS=IDLE;
                end            
            
            IDLE:                                           //idle state. fsm is in this state until a start signal comes
                begin                                       //to start i2c transmission.
                    if (start) begin
                        NS  =START;
                    end   
                    else
                        NS  =IDLE;                     
                end
            
            START:                                          //i2c transmission starts here. a 'status' bit is updated to  
                begin                                       //check whether the page number is same as the previous
                    if (status)                             //transmission. 
                        NS  =REWR_SLADD;
                    else
                        NS  =WR_SLADD;
                end

            WR_SLADD:                                       //writing the slave address to the transmit register
                begin
                    NS  =SEND_SLADD;
                end
            
            SEND_SLADD:                                     //writing to the command register to start byte transmission      
                begin
                    NS  =CHK_SLADD1;
                end

            CHK_SLADD1:                                     //delaying state machine three clock cycles until the status register  
                begin                                       //starts updating    
                    if (counter_done)
                        NS      =CHK_SLADD2;
                    else begin
                        NS      =CHK_SLADD1;
                    end
                end
      
            CHK_SLADD2:                                     //checking the status register - tip bit. fsm halts here until the tip
                begin                                       //bit becomes zero
                    if (wb_dat_o[1])
                        NS  =CHK_SLADD2;
                    else
                        NS  =WR_IADD;
                end          
            
            WR_IADD:                                        //writing the address 0x01
                begin
                    NS  =SEND_IADD;
                end
            
            SEND_IADD:                                      //writing to the command register to start byte transmission 
                begin
                    NS  =CHK_IADD1;
                end

            CHK_IADD1:                                      //delaying state machine 3 clock cycles until the status register 
                begin                                       //starts updating
                    if (counter_done)
                        NS      =CHK_IADD2;
                    else begin
                        NS      =CHK_IADD1;
                    end
                end
      
            CHK_IADD2:                                      //checking the status register - tip bit
                begin
                    if (wb_dat_o[1])
                        NS  =CHK_IADD2;
                    else
                        NS  =WR_ADDRH;
                end          
                        
            WR_ADDRH:                                       //writing the page number to the address 0x01 
            begin
                NS  =SEND_ADDRH;
            end
            
            SEND_ADDRH:                                     //writing to the command register to start byte transmission
                begin                                       //and the stop bit to end i2c cycle
                    NS  =CHK_ADDRH1;
                end
            
            CHK_ADDRH1:                                     //delaying fsm 3 clock cycles until the status register starts updating 
                begin
                    if (counter_done)
                        NS      =CHK_ADDRH2;
                    else begin
                        NS      =CHK_ADDRH1;
                    end
                end   
                        
            CHK_ADDRH2:                                     //checking the status register - tip bit
                begin
                    if (wb_dat_o[1])
                        NS  =CHK_ADDRH2;
                    else
                        NS  =REWR_SLADD;
                end
            
            REWR_SLADD:                                     //write the slave address again (data sending state) 
                begin
                    NS  =RESEND_SLADD;
                end
            
            RESEND_SLADD:                                   //writing to the command register to start byte transmission
                begin
                    NS  =RECHK_SLADD1;
                end

            RECHK_SLADD1:                                   //delaying fsm 3 clock cycles until the status register starts updating 
                begin
                    if (counter_done)
                        NS      =RECHK_SLADD2;
                    else begin
                        NS      =RECHK_SLADD1;
                    end
                end
      
            RECHK_SLADD2:                                   //checking the tip bit
                begin
                    if (wb_dat_o[1])
                        NS  =RECHK_SLADD2;
                    else
                        NS  =WR_ADDRL;
                end          
                             
            WR_ADDRL:                                       //writing the register address of the relevant page
                begin
                    NS  =SEND_ADDRL;
                end
            
            SEND_ADDRL:                                     //writing to the command register to start byte transmission 
                begin
                    NS  =CHK_ADDRL1;
                end
            
            CHK_ADDRL1:                                     //delaying fsm 3 clock cycles until the status register starts updating 
                begin
                    if (counter_done)
                        NS      =CHK_ADDRL2;
                    else begin
                        NS      =CHK_ADDRL1;
                    end
                end   
                        
            CHK_ADDRL2:                                     //checking the tip bit 
                begin
                    if (wb_dat_o[1])
                        NS  =CHK_ADDRL2;
                    else
                        NS  =WR_DATA;
                end
            
            WR_DATA:                                        //writing the data to the transmit register
                begin
                    NS  =SEND_DATA;
                end
            
            SEND_DATA:                                      //writing to the command register to start byte transmission  
                begin                                       //and the stop bit to end i2c cycle
                    NS  =CHK_DATA1;
                end
            
            CHK_DATA1:                                      //delaying fsm 3 clock cycles until the status register starts updating
                begin
                    if (counter_done)
                        NS      =CHK_DATA2;
                    else begin
                        NS      =CHK_DATA1;
                    end
                end   
                        
            CHK_DATA2:                                      //checking the tip bit and stay
                begin
                    if (wb_dat_o[1])
                        NS  =CHK_DATA2;
                    else
                        NS  =STOP;
                end
            
            STOP: 
                begin
                    NS  =IDLE;
                end
        endcase 
    end

//register write in each state. register writing is done according to the functions
//on each state mentioned above
always @(posedge clock)
    if(reset) begin
        wb_adr_i    <=3'b000;
        wb_dat_i    <=8'h00;
        addrh       <=8'h00;
        addrl       <=8'h00;
        data_in     <=8'h00;  
    end else
    begin
        case(PS)
            RESET: 
                begin
                    wb_adr_i    <=3'b000;
                    wb_dat_i    <=8'h00;                  
                end
            
            SEND_PREH: 
                begin
                    wb_adr_i    <= PRER_HI;
                    wb_dat_i    <= 8'h00;
                end
            
            SEND_PREL: 
                begin
                    wb_adr_i    <= PRER_LO;
                    wb_dat_i    <= 8'h3f;               
                end

            SEND_CTR: 
                begin
                    wb_adr_i    <= CTR;
                    wb_dat_i    <= 8'h80;
                end  
                          
            IDLE:
                begin
                    if (start) begin
                        if (addrh === address[15:8])
                            status<=1;
                        else
                            status<=0;
                            addrh   = address[15:8];
                    end
                end
                
            START: 
                begin
                    data_in <= data;
                    addrl   <= address[7:0];
                end

            WR_SLADD: 
                begin
                    wb_adr_i    <= TXR;
                    wb_dat_i    <= {SADR,1'b0};
                end
            
            SEND_SLADD,RESEND_SLADD: 
                begin
                    wb_adr_i    <= CR;
                    wb_dat_i    <= 8'h90;
                end
                
            WR_IADD: 
                begin
                    wb_adr_i    <= TXR;
                    wb_dat_i    <= 8'h01;
                end
            
            SEND_IADD,SEND_ADDRL: 
                begin
                    wb_adr_i    <= CR;
                    wb_dat_i    <= 8'h10;
                end
            
            CHK_SLADD2,CHK_IADD2,CHK_ADDRH2,RECHK_SLADD2,CHK_ADDRL2,CHK_DATA2:
                begin
                    wb_adr_i <= SR;
                    wb_dat_i <= {8{1'b0}};
                end          
                        
            WR_ADDRH: 
                begin
                    wb_adr_i    <= TXR;
                    wb_dat_i    <= addrh;
                end
            
            SEND_ADDRH,SEND_DATA: 
                begin
                    wb_adr_i    <= CR;
                    wb_dat_i    <= 8'h50;
                end
    
            REWR_SLADD: 
                begin
                    wb_adr_i    <= TXR;
                    wb_dat_i    <= {SADR,1'b0};
                    status      <=0;
                end

            WR_ADDRL: 
                begin
                    wb_adr_i    <= TXR;
                    wb_dat_i    <= addrl;
                end
                
            WR_DATA: 
                begin
                    wb_adr_i    <= TXR;
                    wb_dat_i    <= data_in;
                end
        endcase 
    end
    
//updating wishbone write enable, strobe signal and valid bus cycle inputs in each state   
always@(posedge clock) begin
        if(reset) begin
            wb_we_i     <=1'b0;
            wb_stb_i    <=1'b0;
            wb_cyc_i    <=1'b0;
        end else begin
            case(PS)
                SEND_PREH,SEND_PREL,SEND_CTR,WR_SLADD,SEND_SLADD,WR_IADD,SEND_IADD,REWR_SLADD,RESEND_SLADD,WR_ADDRH,SEND_ADDRH,WR_ADDRL,SEND_ADDRL,
                WR_DATA,SEND_DATA:
                    begin     
                        wb_we_i     <=1'b1;
                        wb_stb_i    <=1'b1;
                        wb_cyc_i    <=1'b1;
                    end
                IDLE,CHK_SLADD2,CHK_IADD2,CHK_ADDRH2,RECHK_SLADD2,CHK_ADDRL2,CHK_DATA2,CHK_SLADD1,CHK_IADD1,CHK_ADDRH1,RECHK_SLADD1,CHK_ADDRL1,CHK_DATA1:
                    begin
                        wb_cyc_i    <= 1'b1;
                        wb_stb_i    <= 1'b1;
                        wb_we_i     <= 1'b0;
                    end
            endcase
        end
end

//counter
always@(posedge clock) begin
        if(reset) begin
            counter     <= 'b0;
        end else begin
            case(PS)
                CHK_SLADD1,CHK_IADD1,CHK_ADDRH1,RECHK_SLADD1,CHK_ADDRL1,CHK_DATA1:     
                    if(counter_done) begin
                        counter <= 'b0;
                    end else begin
                        counter <= counter + 1'b1;
                    end
            endcase
        end
end
    
always@(*) begin
        counter_done = 'b0;
        case(PS)
            CHK_SLADD1,CHK_IADD1,CHK_ADDRH1,RECHK_SLADD1,CHK_ADDRL1,CHK_DATA1:    
                counter_done = (counter == 3'd2);
        endcase
end 
        
endmodule