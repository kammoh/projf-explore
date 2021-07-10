// Project F Library - Draw Line
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module draw_line #(parameter CORDW=16) (  // signed coordinate width
    input  wire logic clk,             // clock
    input  wire logic rst,             // reset
    input  wire logic start,           // start line drawing
    input  wire logic oe,              // output enable
    input  wire logic signed [CORDW-1:0] x0, y0,  // point 0
    input  wire logic signed [CORDW-1:0] x1, y1,  // point 1
    output      logic signed [CORDW-1:0] x,  y,   // drawing position
    output      logic drawing,         // line is drawing
    output      logic complete,        // line complete (remains high)
    output      logic done             // line done (high for one tick)
    );

    // line properties
    logic swap;   // swap points to ensure y1 >= y0
    logic right;  // drawing direction
    logic signed [CORDW-1:0] xa, ya;  // start point
    logic signed [CORDW-1:0] xb, yb;  // end point
    logic signed [CORDW-1:0] x_end, y_end;  // register end point
    always_comb begin
        swap = (y0 > y1);  // swap points if y0 is below y1
        xa = swap ? x1 : x0;
        xb = swap ? x0 : x1;
        ya = swap ? y1 : y0;
        yb = swap ? y0 : y1;
    end

    // error values
    logic signed [CORDW:0] err;  // a bit wider as signed
    logic signed [CORDW:0] dx, dy;
    logic movx, movy;  // horizontal/vertical move required
    always_comb begin
        movx = (2*err >= dy);
        movy = (2*err <= dx);
    end

    logic in_progress = 0;  // calculation in progress (but only output if oe)
    always_comb begin
        drawing = 0;
        if (in_progress && oe) drawing = 1;
    end

    enum {IDLE, INIT_0, INIT_1, DRAW} state;
    always_ff @(posedge clk) begin
        case (state)
            DRAW: begin
                if (oe) begin
                    if (x == x_end && y == y_end) begin
                        state <= IDLE;
                        in_progress <= 0;
                        complete <= 1;
                        done <= 1;
                    end else begin
                        if (movx) begin
                            x <= right ? x + 1 : x - 1;
                            err <= err + dy;
                        end
                        if (movy) begin
                            y <= y + 1;  // always down
                            err <= err + dx;
                        end
                        if (movx && movy) begin
                            x <= right ? x + 1 : x - 1;
                            y <= y + 1;
                            err <= err + dy + dx;
                        end
                    end
                end
            end
            INIT_0: begin
                state <= INIT_1;
                dx <= right ? xb - xa : xa - xb;  // dx = abs(xb - xa)
                dy <= ya - yb;  // dy = -abs(yb - ya)
            end
            INIT_1: begin
                state <= DRAW;
                err <= dx + dy;
                x <= xa;
                y <= ya;
                x_end <= xb;
                y_end <= yb;
                in_progress <= 1;
            end
            default: begin  // IDLE
                done <= 0;
                if (start) begin
                    state <= INIT_0;
                    right <= (xa < xb);  // draw right to left?
                    complete <= 0;
                end
            end
        endcase

        if (rst) begin
            state <= IDLE;
            in_progress <= 0;
            complete <= 0;
            done <= 0;
        end
    end
endmodule
