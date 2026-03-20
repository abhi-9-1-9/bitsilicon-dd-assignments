`timescale 1ns / 1ps

module sync_fifo_top #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 16
)(
    input  wire clk,
    input  wire rst_n,         
    input  wire wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire wr_full,
    input  wire rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire rd_empty,
    output wire [$clog2(DEPTH):0] count
);

    // address width
    localparam ADDR_WIDTH = $clog2(DEPTH);

  
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   occ_count;

    // assigning outputs
    assign count = occ_count;
    assign rd_empty = (occ_count == 0);
    assign wr_full  = (occ_count == DEPTH);

  // conditions for validity
    wire valid_write = wr_en && !wr_full;
    wire valid_read  = rd_en && !rd_empty;

    // 1) synchronous logic
    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            occ_count <= 0;
            rd_data   <= 0;
        end else begin
            //  memory writes
            if (valid_write) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= (wr_ptr == DEPTH - 1) ? 0 : wr_ptr + 1;
            end

            //  memory reads
            if (valid_read) begin
                rd_data <= mem[rd_ptr];
                rd_ptr <= (rd_ptr == DEPTH - 1) ? 0 : rd_ptr + 1;
            end

            // update occupancy counter
            if (valid_write && !valid_read) begin
                occ_count <= occ_count + 1;
            end else if (!valid_write && valid_read) begin
                occ_count <= occ_count - 1;
            end
            
        end
    end

endmodule