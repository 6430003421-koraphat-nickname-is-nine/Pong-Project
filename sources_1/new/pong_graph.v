`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Reference book: "FPGA Prototyping by Verilog Examples"
//                      "Xilinx Spartan-3 Version"
// Written by: Dr. Pong P. Chu
// Published by: Wiley, 2008
//
// Adapted for Basys 3 by David J. Marion aka FPGA Dude
//
//////////////////////////////////////////////////////////////////////////////////

module pong_graph(
    input clk,  
    input reset,    
    input [3:0] btn,        // btn[0] = up, btn[1] = down
    input gra_still,        // still graphics - newgame, game over states
    input video_on,
    input [9:0] x,
    input [9:0] y,
    output graph_on,
    output reg [1:0]hit, 
    output reg miss,   // ball hit or miss
    output reg [11:0] graph_rgb
    );
    
    // maximum x, y values in display area
    parameter X_MAX = 639;
    parameter Y_MAX = 479;
    
    // create 60Hz refresh tick
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0; // start of vsync(vertical retrace)
    
    
    // WALLS
    // LEFT wall boundaries
    parameter L_WALL_L = 32;    
    parameter L_WALL_R = 39;    // 8 pixels wide
    // TOP wall boundaries
    parameter T_WALL_T = 64;    
    parameter T_WALL_B = 71;    // 8 pixels wide
    // BOTTOM wall boundaries
    parameter B_WALL_T = 472;    
    parameter B_WALL_B = 479;    // 8 pixels wide
    
    
    
    // PADDLE
    // paddle horizontal boundaries
    parameter X_PAD_L = 599; // player2
    parameter X_PAD_R = X_PAD_L + 3;    // 4 pixels wide
    // paddle vertical boundary signals
    wire [9:0] y_pad_t, y_pad_b;
    parameter PAD_HEIGHT = 72;  // 72 pixels high
    // register to track top boundary and buffer
    reg [9:0] y_pad_reg = 204;      // Paddle starting position
    reg [9:0] y_pad_next;
    // paddle moving velocity when a button is pressed
    parameter PAD_VELOCITY = 3;     // change to speed up or slow down paddle movement
    
    parameter X1_PAD_L = 37; // player1
    parameter X1_PAD_R = X1_PAD_L + 3;    // 4 pixels wide
    // paddle vertical boundary signals
    wire [9:0] y1_pad_t, y1_pad_b;
    // 72 pixels high
    // register to track top boundary and buffer
    reg [9:0] y1_pad_reg = 204;      // Paddle starting position
    reg [9:0] y1_pad_next;
    
    
    
    // BALL
    // square rom boundaries
    parameter BALL_SIZE = 8;
    // ball horizontal boundary signals
    wire [9:0] x_ball_l, x_ball_r;
    // ball vertical boundary signals
    wire [9:0] y_ball_t, y_ball_b;
    // register to track top left position
    reg [9:0] y_ball_reg, x_ball_reg;
    // signals for register buffer
    wire [9:0] y_ball_next, x_ball_next;
    // registers to track ball speed and buffers
    reg [9:0] x_delta_reg, x_delta_next;
    reg [9:0] y_delta_reg, y_delta_next;
    // positive or negative ball velocity
    parameter BALL_VELOCITY_POS = 1;    // ball speed positive pixel direction(down, right)
    parameter BALL_VELOCITY_NEG = -1;   // ball speed negative pixel direction(up, left)
    // round ball from square image
    wire [2:0] rom_addr, rom_col;   // 3-bit rom address and rom column
    reg [7:0] rom_data;             // data at current rom address
    wire rom_bit;                   // signify when rom data is 1 or 0 for ball rgb control
    
    reg [1:0]direc = 0;
    //reg p1win , p2win = 0;
    reg [2:0] randomNum;//$urandom_range(0,8);  
    
    // Register Control paddle
    always @(posedge clk or posedge reset)
        if(reset) begin
            y_pad_reg <= 204;
            x_ball_reg <= 0;
            y_ball_reg <= 0;
            x_delta_reg <= 10'h002;
            y_delta_reg <= 10'h002;
            y1_pad_reg <= 204;
        end
        else begin
            y_pad_reg <= y_pad_next;
            y1_pad_reg <= y1_pad_next;
            x_ball_reg <= x_ball_next;
            y_ball_reg <= y_ball_next;
            x_delta_reg <= x_delta_next;
            y_delta_reg <= y_delta_next;
        end
    
    
    // ball rom
    always @*
        case(rom_addr)
            3'b000 :    rom_data = 8'b00111100; //   ****  
            3'b001 :    rom_data = 8'b01111110; //  ******
            3'b010 :    rom_data = 8'b11111111; // ********
            3'b011 :    rom_data = 8'b11111111; // ********
            3'b100 :    rom_data = 8'b11111111; // ********
            3'b101 :    rom_data = 8'b11111111; // ********
            3'b110 :    rom_data = 8'b01111110; //  ******
            3'b111 :    rom_data = 8'b00111100; //   ****
        endcase
    
    
    // OBJECT STATUS SIGNALS
    wire l_wall_on, t_wall_on, b_wall_on, pad_on, sq_ball_on, ball_on,pad1_on;
    wire [11:0] wall_rgb, pad_rgb, ball_rgb, bg_rgb,pad1_rgb;
    wire [11:0] wall_rgb2;
    
    // pixel within wall boundaries
    //assign l_wall_on = ((L_WALL_L <= x) && (x <= L_WALL_R)) ? 1 : 0;
    assign l_wall_on = 0;
    assign t_wall_on = ((T_WALL_T <= y) && (y <= T_WALL_B)) ? 1 : 0;
    assign b_wall_on = ((B_WALL_T <= y) && (y <= B_WALL_B)) ? 1 : 0;
    
    
    // assign object colors
    assign wall_rgb   = 12'hDDD;    // grey walls
    assign pad_rgb    = 12'h00F;    // blue paddle // player2
    assign ball_rgb   = 12'hFFF;    // black ball
    assign bg_rgb     = 12'h000;    // aqua background // 0FF
    assign pad1_rgb   = 12'hF00;    // player1
    
    assign wall_rgb2   = 12'hDDD;    // grey walls
    
    // paddle 
    assign y_pad_t = y_pad_reg;                             // paddle top position
    assign y_pad_b = y_pad_t + PAD_HEIGHT - 1;              // paddle bottom position
    assign pad_on = (X_PAD_L <= x) && (x <= X_PAD_R) &&     // pixel within paddle boundaries
                    (y_pad_t <= y) && (y <= y_pad_b);
    assign y1_pad_t = y1_pad_reg;                             // paddle top position
    assign y1_pad_b = y1_pad_t + PAD_HEIGHT - 1;              // paddle bottom position
    assign pad1_on = (X1_PAD_L <= x) && (x <= X1_PAD_R) &&     // pixel within paddle boundaries
                    (y1_pad_t <= y) && (y <= y1_pad_b);   
                    
    // Paddle Control
    always @* begin
        y_pad_next = y_pad_reg;     // no move
        y1_pad_next = y1_pad_reg;
        if(refresh_tick)
            if(btn[1] & (y_pad_b < (B_WALL_T - 1 - PAD_VELOCITY)))
                y_pad_next = y_pad_reg + PAD_VELOCITY;  // move down
            else if(btn[0] & (y_pad_t > (T_WALL_B - 1 - PAD_VELOCITY)))
                y_pad_next = y_pad_reg - PAD_VELOCITY;  // move up
            else if(btn[3] & (y1_pad_b < (B_WALL_T - 1 - PAD_VELOCITY)))
                y1_pad_next = y1_pad_reg + PAD_VELOCITY;  // move down
            else if(btn[2] & (y1_pad_t > (T_WALL_B - 1 - PAD_VELOCITY)))
                y1_pad_next = y1_pad_reg - PAD_VELOCITY;  // move up
    end
    
    
    // rom data square boundaries
    assign x_ball_l = x_ball_reg; // left side of ball
    assign y_ball_t = y_ball_reg; // top side of ball
    assign x_ball_r = x_ball_l + BALL_SIZE - 1; //right side of ball
    assign y_ball_b = y_ball_t + BALL_SIZE - 1; //bottom side of ball
    // pixel within rom square boundaries
    assign sq_ball_on = (x_ball_l <= x) && (x <= x_ball_r) &&
                        (y_ball_t <= y) && (y <= y_ball_b);
    // map current pixel location to rom addr/col
    assign rom_addr = y[2:0] - y_ball_t[2:0];   // 3-bit address
    assign rom_col = x[2:0] - x_ball_l[2:0];    // 3-bit column index
    assign rom_bit = rom_data[rom_col];         // 1-bit signal rom data by column
    // pixel within round ball
    assign ball_on = sq_ball_on & rom_bit;      // within square boundaries AND rom data bit == 1
 
  
    // new ball position
    assign x_ball_next = (gra_still) ? X_MAX / 2 :
                         (refresh_tick) ? x_ball_reg + x_delta_reg : x_ball_reg;
    assign y_ball_next = (gra_still) ? Y_MAX / 2 :
                         (refresh_tick) ? y_ball_reg + y_delta_reg : y_ball_reg;
    
    // change ball direction after collision
    always @* begin
        hit = 0;
        miss = 1'b0;
        x_delta_next = x_delta_reg;
        y_delta_next = y_delta_reg;
//        if(gra_still) begin
//       //direc = { x_ball_r > X_MAX,x_ball_l < 1};
//            if(direc == 0) begin
//                x_delta_next <= BALL_VELOCITY_NEG;
//                y_delta_next <= BALL_VELOCITY_POS;    
//            end
//            else if(direc == 2) begin //10
//                x_delta_next <= BALL_VELOCITY_NEG;
//                y_delta_next <= BALL_VELOCITY_NEG;             
//            end   
//            else if(direc == 1) begin// 01
//                x_delta_next <= BALL_VELOCITY_POS;
//                y_delta_next <= BALL_VELOCITY_NEG;
//            end     
//        end 
        if(gra_still) begin
            if(direc==0) begin
            x_delta_next <= BALL_VELOCITY_NEG;
            y_delta_next <= BALL_VELOCITY_POS;
//              randomNum = $urandom_range(0,8);
//              if(randomNum <= 4) begin
//                  x_delta_next = BALL_VELOCITY_NEG;
//                  y_delta_next = BALL_VELOCITY_POS;
//              end
//              else begin                 
//                  x_delta_next = BALL_VELOCITY_POS;
//                  y_delta_next = BALL_VELOCITY_POS;
//              end
            end
            else if(direc==2) begin
            x_delta_next <= BALL_VELOCITY_NEG;
            y_delta_next <= BALL_VELOCITY_NEG;
            end
            else if(direc==1) begin
            x_delta_next <= BALL_VELOCITY_POS;
            y_delta_next <= BALL_VELOCITY_NEG;
            end
        end 
        else if(y_ball_t < T_WALL_B)                   // reach top
            y_delta_next = BALL_VELOCITY_POS;   // move down
        
        else if(y_ball_b > (B_WALL_T))         // reach bottom wall
            y_delta_next = BALL_VELOCITY_NEG;   // move up
              
        //ball bounce back to the left
        else if((X_PAD_L <= x_ball_r) && (x_ball_r <= X_PAD_R) &&
                (y_pad_t <= y_ball_b) && (y_ball_t <= y_pad_b)) begin
                    x_delta_next = BALL_VELOCITY_NEG;
                    end
        //ball bounce back to the right
        else if((X1_PAD_L <= x_ball_l) && (x_ball_l <= X1_PAD_R) &&
                (y1_pad_t <= y_ball_b) && (y_ball_t <= y1_pad_b)) begin
                    x_delta_next = BALL_VELOCITY_POS;      
        end
        
        else if(x_ball_r > X_MAX) begin// ||(x_ball_l < 1)) begin //30
            miss = 1'b1;
            hit = 2'b10;
            direc = 2'b10;
        end
        else if(x_ball_l < 1) begin
            miss = 1'b1;
            hit = 2'b01;
            direc = 2'b01;
        end
        //            hit ={x_ball_r > X_MAX, x_ball_l < 1};
        //            direc ={ x_ball_r > X_MAX,x_ball_l < 1};
    end                    
    
    // output status signal for graphics 
    assign graph_on = l_wall_on | t_wall_on | b_wall_on | pad_on | ball_on|pad1_on;
    
    
    // rgb multiplexing circuit
    always @*
        if(~video_on)
            graph_rgb = 12'h000;      // no value, blank
        else
            if(l_wall_on | t_wall_on | b_wall_on) begin
                
                //graph_rgb = wall_rgb;     // wall color
                graph_rgb = 12'hF00;
                if(x[9:5] % 2 == 0 ) begin
                    graph_rgb = 12'hFFF;
                end
            end
            else if(pad_on)
                graph_rgb = pad_rgb; 
                 // paddle color
            else if(pad1_on)
                graph_rgb = pad1_rgb;      
            else if(ball_on)
                graph_rgb = ball_rgb;     // ball color
            else
                graph_rgb = bg_rgb;       // background
       
endmodule
