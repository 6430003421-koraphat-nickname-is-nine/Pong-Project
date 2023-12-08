`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2021 10:15:58 PM
// Design Name: 
// Module Name: uart_tx
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

module uart_tx(
    input clk,
    input [7:0] data_transmit,
    input ena,
    output reg sent,
    output reg [3:0] di
    );
    
    reg last_ena;
    reg sending = 0;
    reg [7:0] count;
    reg [7:0] temp;
    reg [15:0] cou=0;
    always@(posedge clk) begin
    temp=data_transmit;
        if (last_ena&!ena) begin
          case(temp)
                8'd73: di[0] = 1;// I
                8'd105: di[0] = 1;//i
                8'd75: di[1] = 1;// K
                8'd107: di[1] = 1;//k
                8'd87: di[2] = 1;// W
                8'd119: di[2] = 1;// w
                8'd83: di[3] = 1;// S
                8'd115: di[3] = 1;// s
                default:di=0;
            endcase
            end
        if(di!=0)
            begin
            if(cou<10000)
                cou=cou+1;
            else begin
             cou=0;
             di=0;
            end
            
         
        end
        last_ena <= ena;
        
      
        
        // sampling every 16 ticks
      
    end
endmodule