// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete o_rx_dv will be
// driven high for one clock cycle.
// 
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 12 MHz Clock, 115200 baud UART
// (12000000)/(115200) = 104.16
  
module uart_rx 
  #(parameter CLKS_PER_BIT = 104)
  (
   input        i_Clock,
   input        i_Rx_Serial,
	output  reg outsingle,
   output reg [31:0] o_Rx_Byte,
	output reg square_wave, 
  output reg pin1,
  output  reg pin2
   );
    
  parameter s_IDLE         = 3'b000;
  parameter s_RX_START_BIT = 3'b001;
  parameter s_RX_DATA_BITS = 3'b010;
  parameter s_RX_STOP_BIT  = 3'b011;
  parameter s_CLEANUP      = 3'b100;
   
  
  reg [7:0] first_8bit;
  reg [7:0] second_8bit;
  reg [7:0] third_8bit;
  reg [7:0] fourth_8bit;
  reg [7:0] data_check = 8'h00;
  
  reg           r_Rx_Data_R = 1'b1;
  reg           r_Rx_Data   = 1'b1;
   
  reg [31:0]     r_Clock_Count = 0;
  reg [3:0]     r_Bit_Index   = 0; //8 bits total
  reg [31:0]     r_Rx_Byte     = 0;
  //reg           r_Rx_DV       = 0;
  reg [2:0]     r_SM_Main     = 0;
  
  //assign outsingle = o_Rx_Byte[7];
   
reg [60:0] distZ = 61'hFFFFFFFFFFFFFFF;
reg [23:0] counter = 0;
reg toggle = 1;
wire [23:0] store;
wire [61:0] distA;
reg [61:0] distB =0;
reg stop =0;

reg [15:0] rpm = 0;

//assign o_Rx_Byte[31:24] = fourth_8bit;
//assign o_Rx_Byte[23:16] = third_8bit;
//assign o_Rx_Byte[15:8] = second_8bit;
//assign o_Rx_Byte[7:0] = first_8bit;

assign distA =40*distZ;
assign store = (18 * 100000)/ rpm;

always@(posedge i_Clock)
begin

 r_Rx_Data_R = i_Rx_Serial;
 r_Rx_Data   = r_Rx_Data_R;

o_Rx_Byte[31:24] = fourth_8bit;
o_Rx_Byte[23:16] = third_8bit;
o_Rx_Byte[15:8] = second_8bit;
o_Rx_Byte[7:0] = first_8bit;

 rpm = o_Rx_Byte[31:16];
// distZ = o_Rx_Byte[15:0];
 

if (stop==0)
begin
counter <= counter + 1;
if (counter == store )
begin
toggle=~ toggle;
counter<=0;
if (o_Rx_Byte[31] == 0)
begin
pin1 = 0;
pin2 = 1;
end
else
begin
pin1 = 1;
pin2 = 0;
end


if (toggle==0)
begin
distB <= distB +1;
end
end
if (distB ==distA)
begin
stop = 1;
end
else
begin
square_wave <= toggle;
end
end
end

  always @(posedge i_Clock)
    begin
       

			
      case (r_SM_Main)
        s_IDLE :
          begin
     
            r_Clock_Count <= 0;
            r_Bit_Index   <= 0;
             
            if (r_Rx_Data == 1'b0)          // Start bit detected
              r_SM_Main <= s_RX_START_BIT;
            else
              r_SM_Main <= s_IDLE;
          end
         
        // Check middle of start bit to make sure it's still low
        s_RX_START_BIT :
          begin
            if (r_Clock_Count == (CLKS_PER_BIT-1)/2)
              begin
                if (r_Rx_Data == 1'b0)
                  begin
                    r_Clock_Count <= 0;  // reset counter, found the middle
                    r_SM_Main     <= s_RX_DATA_BITS;
                  end
                else
                  r_SM_Main <= s_IDLE;
              end
            else
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_RX_START_BIT;
              end
          end // case: s_RX_START_BIT
         
         
        // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
        s_RX_DATA_BITS :
          begin
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_RX_DATA_BITS;
              end
            else
              begin
                r_Clock_Count          <= 0;
                r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
                 
                // Check if we have received all bits
                if (r_Bit_Index < 8)
                  begin
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_SM_Main   <= s_RX_DATA_BITS;
                  end
                else
                  begin
						 if (data_check == 8'h03)
						 begin
						 fourth_8bit <= r_Rx_Byte;
						 data_check <= 8'h00;
						 
						 end
						 
						 if (data_check == 8'h02)
						 begin
						 third_8bit <= r_Rx_Byte;
						 data_check <= 8'h03;
						 end
						 
						 if (data_check == 8'h01)
						 begin
						 second_8bit <= r_Rx_Byte;
						 data_check <= 8'h02;
						 end
						 
						 if (data_check == 8'h00)
						 begin
						 first_8bit <= r_Rx_Byte;
						 data_check <= 8'h01;
						 end
						 
//						 else
//						 begin
//						  first_8bit <= r_Rx_Byte;
//						  data_check <= 8'h01;
//						  end
						  
                    r_Bit_Index <= 0;
                    r_SM_Main   <= s_RX_STOP_BIT;
                  end
              
				  end
				 
          end // case: s_RX_DATA_BITS
     
     
        // Receive Stop bit.  Stop bit = 1
        s_RX_STOP_BIT :
          begin
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_RX_STOP_BIT;
              end
            else
              begin
              
                r_Clock_Count <= 0;
                r_SM_Main     <= s_CLEANUP;
              end
          end // case: s_RX_STOP_BIT
     
         
        // Stay here 1 clock
        s_CLEANUP :
          begin
            r_SM_Main <= s_IDLE;
         
          end
         
         
        default :
          r_SM_Main <= s_IDLE;         
      endcase
    end   
	 
//assign o_Rx_Byte = r_Rx_Byte;
   
endmodule


