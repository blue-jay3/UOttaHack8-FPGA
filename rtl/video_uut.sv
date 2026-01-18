/****************************************************************************
FILENAME     :  video_uut.sv
PROJECT      :  Hack-a-Thon 2026
TEAM         :  John Scales and Emma Ferrarotto
****************************************************************************/

module video_uut (
    input  wire         clk_i,
    input  wire         cen_i,
    input  wire         rst_i,
    input  wire         vid_sel_i,
    input  wire [23:0]  probe_color_i,
    input  wire [23:0]  probe_color2_i,
    input  wire [23:0]  probe_color3_i,
    input  wire [23:0]  probe_color4_i,
    input  wire [5:0] probe_framelength,
    input  wire [5:0] probe_amountspawn,
    input  wire [5:0] probe_spawnwaitclk,


    input  wire [15:0]  seed_i,

    input  wire [23:0]  vid_rgb_i,
    input  wire [1:0]   vh_blank_i,
    input  wire [2:0]   dvh_sync_i,
    output wire [2:0]   dvh_sync_o,
    output wire [23:0]  vid_rgb_o
);

    localparam CELL_SIZE = 20;
    localparam H_CELLS   = 96;
    localparam V_CELLS   = 54;
    localparam TOTAL     = H_CELLS * V_CELLS;

    localparam [23:0] BORDER_COLOR = 24'hFF_FF_FF;
    localparam [23:0] BLACK        = 24'h00_00_00;

    // for random init of cells
    //localparam [63:0] SEED = 64'hDEAD_BEEF_CAFE_BABE;

    reg [23:0] vid_rgb_d1;
    reg [2:0]  dvh_sync_d1;

    reg [11:0] x;
    reg [11:0] y;

    reg hblank_d, vblank_d;

    (* ram_style = "block" *) reg[3:0] cells_cur  [0:TOTAL-1];  //current 
    (* ram_style = "block" *) reg[3:0] cells_next [0:TOTAL-1];  //next 

    // for psuedo random init using Linear-feedback shift register
    reg [63:0] lfsr;
    reg [12:0] init_ptr; // inti cells one at a timee



    // detect the blanking
    always @(posedge clk_i) begin
        hblank_d <= vh_blank_i[0];
        vblank_d <= vh_blank_i[1];
    end

    wire hblank_start = vh_blank_i[0] & ~hblank_d;
    wire vblank_start = vh_blank_i[1] & ~vblank_d;

    // counter for x pixel
    always @(posedge clk_i) begin
        if (rst_i)
            x <= 0;
        else if (cen_i) begin
            if (hblank_start)
                x <= 0;
            else if (!vh_blank_i[0] && !vh_blank_i[1])
                x <= x + 1;
        end
    end

    // counter for y pixel
    always @(posedge clk_i) begin
        if (rst_i)
            y <= 0;
        else if (cen_i) begin
            if (vblank_start)
                y <= 0;
            else if (hblank_start && !vh_blank_i[1])
                y <= y + 1;
        end
    end

    // cell coord
    wire [6:0] cell_x = (x / CELL_SIZE < H_CELLS) ? x / CELL_SIZE : H_CELLS-1;
    wire [5:0] cell_y = (y / CELL_SIZE < V_CELLS) ? y / CELL_SIZE : V_CELLS-1;
    wire [12:0] cell_index = cell_y * H_CELLS + cell_x;

    // white border
    wire border;
    assign border =
           (x % CELL_SIZE == 0) ||
           (y % CELL_SIZE == 0);

    // conway game of life
    reg [12:0] life_ptr;
    reg        life_run;
    reg [5:0]  ctr;
    reg [5:0] spawnctr;

typedef enum logic [1:0] {
    IDLE,
    NEW_CLUSTER,
    DRAW
} state_t;

state_t state;


logic [11:0] base_x, base_y;
logic [11:0] base_x1, base_y1;
logic [11:0] base_x2, base_y2;
logic [11:0] base_x3, base_y3;
logic [11:0] base_x4, base_y4;



    always @(posedge clk_i) begin
        if (rst_i||vid_sel_i) begin
            init_ptr <= 0;
            lfsr     <= seed_i;
            life_ptr <= 0;
            life_run <= 0;

        end else if (cen_i && init_ptr < TOTAL) begin     // init cells
            cells_cur[init_ptr]  <= lfsr[0];   // random bit with
            //cells_next[init_ptr] <= 1'b00;      // clear next gen
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            init_ptr <= init_ptr + 1;
        end else if (cen_i && init_ptr == TOTAL) begin //run sim
            // start update once per frame
            lfsr <= {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};

            if (vblank_start) begin
                ctr <= ctr +1;
                if(ctr == probe_framelength) begin
                     
                   

                            case(lfsr[3:2])
                                2'd0: begin base_x <= lfsr[11:4]; base_y <= 0; end
                                2'd1: begin base_x <= lfsr[11:4]; base_y <= V_CELLS-1; end
                                2'd2: begin base_x <= 0; base_y <= lfsr[15:8]; end
                                2'd3: begin base_x <= H_CELLS-1; base_y <= lfsr[15:8]; end
                            endcase

                            cells_cur[base_y*H_CELLS + base_x] <= 4'b0001;

                            if (lfsr[5:4]==0)
                                base_x1 <= base_x + 1;
                            else if (lfsr[5:4]==1)
                                base_y1 <= base_y + 1;
                            else if (lfsr[5:4]==2)
                                base_x1 <= base_x - 1;
                            else if (lfsr[5:4]==3)
                                base_y1 <= base_y - 1;

                            cells_cur[base_y1 *H_CELLS + base_x1] <= 4'b0001;

                            if (lfsr[7:6]==0)
                                base_x2 <= base_x1 + 1;
                            else if (lfsr[7:6]==1)
                                base_y2 <= base_y1 + 1;
                            else if (lfsr[7:6]==2)
                                base_x2 <= base_x1 - 1;
                            else if (lfsr[7:6]==3)
                                base_y2 <= base_y1 - 1;
                            cells_cur[base_y2 *H_CELLS + base_x2] <= 4'b0001;

                            if (lfsr[9:8]==0)
                                base_x3 <= base_x2 + 1;
                            else if (lfsr[9:8]==1)
                                base_y3 <= base_y2 + 1;
                            else if (lfsr[9:8]==2)
                                base_x3 <= base_x2 - 1;
                            else if (lfsr[9:8]==3)
                                base_y3 <= base_y2 - 1;
                            cells_cur[base_y3 *H_CELLS + base_x3] <= 4'b0001;

                            if (lfsr[11:10]==0)
                                base_x4 <= base_x3 + 1;
                            else if (lfsr[11:10]==1)
                                base_y4 <= base_y3 + 1;
                            else if (lfsr[11:10]==2)
                                base_x4 <= base_x3 - 1;
                            else if (lfsr[11:10]==3)
                                base_y4 <= base_y3 - 1;
                            cells_cur[base_y4*H_CELLS + base_x4] <= 4'b0001;



                    
                    life_run <= 1;
                    ctr <=0;
                end
            end


            if (life_run) begin
                    integer n;

                    n = count_neighbors(life_ptr);

                    // apply Game of Life rules
                    if (cells_cur[life_ptr] == 4'b0000) begin
                        if (n==2 )
                            cells_next[life_ptr] <= 4'b0001;
                        else
                            cells_next[life_ptr] <= 4'b0000;
                    end else if(cells_cur[life_ptr] == 4'b0001) begin
                        if (n==3 || n==4||n==5)
                            cells_next[life_ptr] <= 4'b0001;
                        else 
                            cells_next[life_ptr] <= 4'b0010;
                    end else if(cells_cur[life_ptr] == 4'b0010) begin
                            cells_next[life_ptr] <= 4'b0011;
                    end else if(cells_cur[life_ptr] == 4'b0011) begin
                            cells_next[life_ptr] <= 4'b0100;
                    end else
                        if (n==2)
                            cells_next[life_ptr] <= 4'b0001;
                        else
                            cells_next[life_ptr] <= cells_cur[life_ptr] + 1;

                    life_ptr <= life_ptr + 1;

                    // finished pass, commit
                    if (life_ptr == TOTAL-1) begin
                        life_ptr <= 0;
                        life_run <= 0;
                        // swap generations
                        for (integer j=0; j<TOTAL; j=j+1)
                            cells_cur[j] <= cells_next[j];
                    end

                
            end
        end
    end

    // video display
    always @(posedge clk_i) begin
        if (cen_i) begin

            if (cells_cur[cell_index]==4'b0001)
                vid_rgb_d1 <= probe_color_i;
            else if (cells_cur[cell_index]==4'b0010)
                vid_rgb_d1 <= probe_color2_i;
            else if (cells_cur[cell_index]==4'b0011)
                vid_rgb_d1 <= probe_color3_i;
            else if (cells_cur[cell_index] > 4'b0011) begin
                if (cells_cur[cell_index] == 4'b0100)
                    vid_rgb_d1 <= probe_color4_i;
            else    if (cells_cur[cell_index] == 4'b0101)
                    vid_rgb_d1 <= 24'hAF_02_04;
            else    if (cells_cur[cell_index] == 4'b0110)
                    vid_rgb_d1 <= 24'h9F_02_04;
            else    if (cells_cur[cell_index] == 4'b0111)
                    vid_rgb_d1 <= 24'h8F_02_03;
            else    if (cells_cur[cell_index] == 4'b1000)
                    vid_rgb_d1 <= 24'h7F_02_03;
            else    if (cells_cur[cell_index] == 4'b1001)
                    vid_rgb_d1 <= 24'h6F_02_03;
            else    if (cells_cur[cell_index] == 4'b1010)
                    vid_rgb_d1 <= 24'h60_01_02;
            else    if (cells_cur[cell_index] == 4'b1011)
                    vid_rgb_d1 <= 24'h50_01_02;
            else    if (cells_cur[cell_index] == 4'b1100)
                    vid_rgb_d1 <= 24'h40_01_02;
             else   if (cells_cur[cell_index] == 4'b1101)
                    vid_rgb_d1 <= 24'h30_01_01;
             else   if (cells_cur[cell_index] == 4'b1110)
                    vid_rgb_d1 <= 24'h20_01_01;
             else   if (cells_cur[cell_index] == 4'b1111)
                    vid_rgb_d1 <= 24'h10_01_01;


            end else
                vid_rgb_d1 <= BLACK;
            

            dvh_sync_d1 <= dvh_sync_i;
        end
    end

    // output stuff?
    assign dvh_sync_o = dvh_sync_d1;
    assign vid_rgb_o  = vid_rgb_d1;

    // function to count neighbors for conway
    function automatic [3:0] count_neighbors(input integer idx);
        integer cx, cy;
        integer nx, ny;
        integer nidx;
        integer dx, dy;
    begin
        cx = idx % H_CELLS;
        cy = idx / H_CELLS;
        count_neighbors = 0;

        for (dy = -1; dy <= 1; dy=dy+1) begin
            for (dx = -1; dx <= 1; dx=dx+1) begin
                if (dx != 0 || dy != 0) begin
                    nx = cx + dx;
                    ny = cy + dy;

                    if (nx>=0 && nx<H_CELLS && ny>=0 && ny<V_CELLS) begin
                        nidx = ny*H_CELLS + nx;
                        count_neighbors += (cells_cur[nidx]==4'b0001);
                    end
                end
            end
        end
    end
    endfunction


endmodule
