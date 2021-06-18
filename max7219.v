`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Richard Parsons
// Based on a works by George Smart
// 
// Module Name: max7219
// 
// Revision: 1.00
// Comments: Simple two-stage FSM to write to MAX7219.
//             'bit_fsm_counter' iterates over the number of bits sending data.
//             'ctrl_fsm_counter' iterates over the messages to send.
//             Tested working on Xilinx AC7A35T Arty with MAX6951 and 8 digits.
// 
//////////////////////////////////////////////////////////////////////////////////

module max7219
    (
    input clk,         // 66.6667 MHz positive edge
    input resetn,      // negative edge async reset
    input [31:0] i_data, // to display. 0xDEADBEEF will put DEADBEEF on the display
    input [7:0] dps,   // display 7:0 decimal points.
    output DI_nCS, //
    output DI_DTA, // 3 lines to display controller
    output DI_CKS  //
    );
    
    ////
    //// Slow Clock (div 8)
    ////   slow_clock must be less 26 MHz. See datasheet for timings. 
    ////
	 
	 reg [31:0]data;
    wire slow_clock;
    reg [2:0] clk_div;
    always @(posedge clk or negedge resetn) begin
        if (~resetn)
            clk_div <= 'b0;
        else
            clk_div <= clk_div + 1'b1;
    end
    assign slow_clock = clk_div[2];
    
    // named state machine states
    localparam s_IDLE = 2'h0;
    localparam s_SENDING = 2'h1;
    localparam s_DONE = 2'h2;
    wire update_data;
	 reg new_data_q;
	 reg new_data_p;

    wire [7:0]digit1;
    wire [7:0]digit2;
    wire [7:0]digit3;
    wire [7:0]digit4;
    wire [7:0]digit5;
    wire [7:0]digit6;
    wire [7:0]digit7;
    wire [7:0]digit8;
	 
	 reg [7:0]r_digit1;
    reg [7:0]r_digit2;
    reg [7:0]r_digit3;
    reg [7:0]r_digit4;
    reg [7:0]r_digit5;
    reg [7:0]r_digit6;
    reg [7:0]r_digit7;
    reg [7:0]r_digit8;
	 
	 


    bin_to_7seg d1(.i_Clk(clk),.i_Binary_Num(data[3:0]),.o_7seg(digit1));
	 bin_to_7seg d2(.i_Clk(clk),.i_Binary_Num(data[7:4]),.o_7seg(digit2));
	 bin_to_7seg d3(.i_Clk(clk),.i_Binary_Num(data[11:8]),.o_7seg(digit3));
	 bin_to_7seg d4(.i_Clk(clk),.i_Binary_Num(data[15:12]),.o_7seg(digit4));
				
	 bin_to_7seg d5(.i_Clk(clk),.i_Binary_Num(data[19:16]),.o_7seg(digit5));
	 bin_to_7seg d6(.i_Clk(clk),.i_Binary_Num(data[23:20]),.o_7seg(digit6));
	 bin_to_7seg d7(.i_Clk(clk),.i_Binary_Num(data[27:24]),.o_7seg(digit7));
	 bin_to_7seg d8(.i_Clk(clk),.i_Binary_Num(data[31:28]),.o_7seg(digit8));
				
    ////
    //// Bit FSM
    ////     Code toggles "update_data" when "reg_data" can be updated.
    ////     Use this 'clock' to run another FSM to setup the registers.
    ////
    reg [15:0] reg_data;        // data to write to the display
    reg [15:0] reg_data_t;         // holds the current data being sent while sending, when idle holds the last value sent
    reg [2:0] bit_fsm_state;  // holds states.
    reg [3:0] r_bitCounter; //which bit is being currently sent
    

    // update_data pulsed high for a single slow clock cycle when data has finished sending
    assign update_data = (bit_fsm_state == s_DONE) ? 1'b1 : 1'b0;

    // clock is clocking out data as long as we are not idle
    assign DI_CKS = (bit_fsm_state == s_SENDING) ? slow_clock: 1'b0;
    
    // CS is low as long as we are sending data
    assign DI_nCS = (bit_fsm_state == s_SENDING) ? 1'b0 : 1'b1;

    // if we are sending, send the data bit indicated by r_bitCounter, otherwise send 0
    assign DI_DTA = (bit_fsm_state == s_SENDING) ? reg_data_t[r_bitCounter]: 1'b0;


    always @(posedge clk) begin
	            //if (new_data_p != new_data_q)
					//  begin
                  r_digit1 = digit1;
					   r_digit2 = digit2;
					   r_digit3 = digit3;
					   r_digit4 = digit4;
					   r_digit5 = digit5;
					   r_digit6 = digit6;
					   r_digit7 = digit7;
					   r_digit8 = digit8;
					//	new_data_p = new_data_q;
               //end;						  
	 end;

    always @(negedge slow_clock or negedge resetn) begin
        if (~resetn) begin
            bit_fsm_state <= s_IDLE;
            reg_data_t <= 'b0;
        end else begin
        
            case (bit_fsm_state)
                s_IDLE: begin
                    // Prepare to send data
                    reg_data_t <= reg_data;
                    bit_fsm_state <= s_SENDING; 
                    r_bitCounter <= 4'd15;
                end

                s_SENDING: begin
                    if (r_bitCounter == 0) begin
                        bit_fsm_state <= s_DONE;
                        r_bitCounter <= 4'b0;
                    end else begin
                        bit_fsm_state <= s_SENDING;
                        r_bitCounter <= r_bitCounter - 1;
                    end
                end

                s_DONE: begin
                    // single iteration in this state to pulse update_data
                    bit_fsm_state <= s_IDLE;
                end

            endcase
        end
    end
    
    ////
    //// Control FSM
    ////
    reg [3:0] ctrl_fsm_counter = 0; // holds states
    always @(posedge update_data or negedge resetn) begin
        if (~resetn)
            ctrl_fsm_counter <= 'b0; // from reset, send everything.
          else begin
            if (ctrl_fsm_counter >= 11) // once we've got to the end, go back to 4. Just update digits.
				begin
                   ctrl_fsm_counter <= 'h4;
					    data = i_data;
				end else
			 	    begin
                  ctrl_fsm_counter <= ctrl_fsm_counter + 1'b1;
			  		 end
        end
       
        case (ctrl_fsm_counter)
            // control registers updated
            0 :  reg_data <= {8'h0C, 8'h01}; // Config Reg:     basic on    (addr: 0x0C, data: 0x01)
            1 :  reg_data <= {8'h0A, 8'h00}; // Brightness Reg: 1/2 bright (addr: 0x0A, data: 0x08)
            2 :  reg_data <= {8'h0B, 8'h07}; // Scan Reg:       8 digits    (addr: 0x0B, data: 0x07)
            3 :  reg_data <= {8'hFF, 8'h00}; // No Decode
            // digits registers updated            
            4 :  reg_data <= {8'h01, r_digit1};
            5 :  reg_data <= {8'h02, r_digit2};
            6 :  reg_data <= {8'h03, r_digit3};
            7 :  reg_data <= {8'h04, r_digit4};
            8 :  reg_data <= {8'h05, r_digit5};
            9 :  reg_data <= {8'h06, r_digit6};
            10 : reg_data <= {8'h07, r_digit7};
            11 : reg_data <= {8'h08, r_digit8};
        endcase
    end
endmodule

module bin_to_7seg 
  (
   input       i_Clk,
   input  [3:0]i_Binary_Num,
   output [7:0]o_7seg
   );
 
  reg [6:0]    r_Hex_Encoding = 7'h00;
   
  // Purpose: Creates a case statement for all possible input binary numbers.
  // Drives r_Hex_Encoding appropriately for each input combination.
  always @(posedge i_Clk)
    begin
      case (i_Binary_Num)
        4'b0000 : r_Hex_Encoding <= 7'h7E;
        4'b0001 : r_Hex_Encoding <= 7'h30;
        4'b0010 : r_Hex_Encoding <= 7'h6D;
        4'b0011 : r_Hex_Encoding <= 7'h79;
        4'b0100 : r_Hex_Encoding <= 7'h33;          
        4'b0101 : r_Hex_Encoding <= 7'h5B;
        4'b0110 : r_Hex_Encoding <= 7'h5F;
        4'b0111 : r_Hex_Encoding <= 7'h70;
        4'b1000 : r_Hex_Encoding <= 7'h7F;
        4'b1001 : r_Hex_Encoding <= 7'h7B;
        4'b1010 : r_Hex_Encoding <= 7'h77;
        4'b1011 : r_Hex_Encoding <= 7'h1F;
        4'b1100 : r_Hex_Encoding <= 7'h4E;
        4'b1101 : r_Hex_Encoding <= 7'h3D;
        4'b1110 : r_Hex_Encoding <= 7'h4F;
        4'b1111 : r_Hex_Encoding <= 7'h47;
      endcase
    end // always @ (posedge i_Clk)
 
  // r_Hex_Encoding[7] is unused
  assign o_7seg = r_Hex_Encoding;
 
endmodule // Binary_To_7Segment