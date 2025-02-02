// Project F: Hardware Sprites - Sprite v2
// (C)2021 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module sprite_v2 #(
    parameter WIDTH=8,            // graphic width in pixels
    parameter HEIGHT=8,           // graphic height in pixels
    parameter SCALE_X=1,          // sprite width scale-factor
    parameter SCALE_Y=1,          // sprite height scale-factor
    parameter SPR_FILE="",        // file to load sprite graphic from
    parameter CORDW=16,           // screen coordinate width in bits
    parameter DEPTH=WIDTH*HEIGHT  // depth of memory array holding graphic
    ) (
    input  wire logic clk,               // clock
    input  wire logic rst,               // reset
    input  wire logic start,             // start control
    input  wire logic signed [CORDW-1:0] sx,    // horizontal screen position
    input  wire logic signed [CORDW-1:0] sprx,  // horizontal sprite position
    output      logic pix                // pixel colour to draw
    );

    // sprite graphic ROM
    logic [$clog2(DEPTH)-1:0] spr_rom_addr;  // pixel position
    logic spr_rom_data;  // pixel colour
    rom_async #(
        .WIDTH(1),  // 1 bit per pixel
        .DEPTH(DEPTH),
        .INIT_F(SPR_FILE)
    ) spr_rom (
        .addr(spr_rom_addr),
        .data(spr_rom_data)
    );

    // position within sprite
    logic [$clog2(WIDTH)-1:0]  ox;
    logic [$clog2(HEIGHT)-1:0] oy;

    // scale counters
    logic [$clog2(SCALE_X)-1:0] cnt_x;
    logic [$clog2(SCALE_Y)-1:0] cnt_y;

    enum {
        IDLE,       // awaiting start signal
        START,      // prepare for new sprite drawing
        AWAIT_POS,  // await horizontal position
        DRAW,       // draw pixel
        NEXT_LINE   // prepare for next sprite line
    } state, state_next;

    always_ff @(posedge clk) begin
        state <= state_next;  // advance to next state

        case (state)
            START: begin
                oy <= 0;
                cnt_y <= 0;
                spr_rom_addr <= 0;
            end
            AWAIT_POS: begin
                ox <= 0;
                cnt_x <= 0;
            end
            DRAW: begin
                if (SCALE_X <= 1 || cnt_x == SCALE_X-1) begin
                    ox <= ox + 1;
                    cnt_x <= 0;
                    spr_rom_addr <= spr_rom_addr + 1;
                end else begin
                    cnt_x <= cnt_x + 1;
                end
            end
            NEXT_LINE: begin
                if (SCALE_Y <= 1 || cnt_y == SCALE_Y-1) begin
                    oy <= oy + 1;
                    cnt_y <= 0;
                end else begin
                    cnt_y <= cnt_y + 1;
                    spr_rom_addr <= spr_rom_addr - WIDTH;  // restart line
                end
            end
        endcase

        if (rst) begin
            state <= IDLE;
            ox <= 0;
            oy <= 0;
            cnt_x <= 0;
            cnt_y <= 0;
            spr_rom_addr <= 0;
        end
    end

    // output current pixel colour when drawing
    always_comb pix = (state == DRAW) ? spr_rom_data : 0;

    // create status signals
    logic last_pixel, last_line;
    always_comb begin
        /* verilator lint_off WIDTH */
        last_pixel = (ox == WIDTH-1  && cnt_x == SCALE_X-1);
        last_line  = (oy == HEIGHT-1 && cnt_y == SCALE_Y-1);
        /* verilator lint_on WIDTH */
    end

    // determine next state
    always_comb begin
        case (state)
            IDLE:       state_next = start ? START : IDLE;
            START:      state_next = AWAIT_POS;
            AWAIT_POS:  state_next = (sx == sprx-1) ? DRAW : AWAIT_POS;
            DRAW:       state_next = !last_pixel ? DRAW :
                                    (!last_line ? NEXT_LINE : IDLE);
            NEXT_LINE:  state_next = AWAIT_POS;
            default:    state_next = IDLE;
        endcase
    end
endmodule
