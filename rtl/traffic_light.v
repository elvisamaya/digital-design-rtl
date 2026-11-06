// traffic_light.v
// Two-road intersection controller (North-South / East-West) with a
// pedestrian button. Moore FSM: outputs depend only on the current state.
//
//   NS_GREEN -> NS_YELLOW -> ALL_RED -> EW_GREEN -> EW_YELLOW -> ALL_RED
//        ^                                                          |
//        +------------- (WALK, only if a request is pending) <------+
//
// Durations are in clock cycles; in hardware, drive `clk` with a slow
// enable/tick or scale the parameters up.
`timescale 1ns/1ps
`default_nettype none

module traffic_light #(
    parameter integer GREEN_T  = 20,
    parameter integer YELLOW_T = 4,
    parameter integer ALLRED_T = 2,
    parameter integer WALK_T   = 10
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ped_req,    // pedestrian button (one-cycle pulse or level)
    output reg  [2:0] ns,         // {red, yellow, green}
    output reg  [2:0] ew,         // {red, yellow, green}
    output reg        walk
);
    localparam [2:0] S_NS_G  = 3'd0,
                     S_NS_Y  = 3'd1,
                     S_RED_A = 3'd2,   // all red, before EW green
                     S_EW_G  = 3'd3,
                     S_EW_Y  = 3'd4,
                     S_RED_B = 3'd5,   // all red, before NS green / walk
                     S_WALK  = 3'd6;

    // Timer reload values, sized to the 16-bit timer
    localparam integer GI = GREEN_T - 1, YI = YELLOW_T - 1, AI = ALLRED_T - 1, WI = WALK_T - 1;
    localparam [15:0] G_LD = GI[15:0], Y_LD = YI[15:0], A_LD = AI[15:0], W_LD = WI[15:0];

    localparam [2:0] RED = 3'b100, YELLOW = 3'b010, GREEN = 3'b001;

    reg [2:0]  state;
    reg [15:0] timer;
    reg        ped_pending;

    // State register + timer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_NS_G;
            timer       <= G_LD;
            ped_pending <= 1'b0;
        end else begin
            if (ped_req) ped_pending <= 1'b1;

            if (timer != 0) begin
                timer <= timer - 16'd1;
            end else begin
                case (state)
                    S_NS_G:  begin state <= S_NS_Y;  timer <= Y_LD; end
                    S_NS_Y:  begin state <= S_RED_A; timer <= A_LD; end
                    S_RED_A: begin state <= S_EW_G;  timer <= G_LD; end
                    S_EW_G:  begin state <= S_EW_Y;  timer <= Y_LD; end
                    S_EW_Y:  begin state <= S_RED_B; timer <= A_LD; end
                    S_RED_B: begin
                        if (ped_pending || ped_req) begin
                            state       <= S_WALK;
                            timer       <= W_LD;
                            ped_pending <= 1'b0;
                        end else begin
                            state <= S_NS_G;
                            timer <= G_LD;
                        end
                    end
                    S_WALK:  begin state <= S_NS_G;  timer <= G_LD; end
                    default: begin state <= S_NS_G;  timer <= G_LD; end
                endcase
            end
        end
    end

    // Output decode (Moore)
    always @(*) begin
        ns   = RED;
        ew   = RED;
        walk = 1'b0;
        case (state)
            S_NS_G: ns   = GREEN;
            S_NS_Y: ns   = YELLOW;
            S_EW_G: ew   = GREEN;
            S_EW_Y: ew   = YELLOW;
            S_WALK: walk = 1'b1;
            default: ;
        endcase
    end
endmodule

`default_nettype wire
