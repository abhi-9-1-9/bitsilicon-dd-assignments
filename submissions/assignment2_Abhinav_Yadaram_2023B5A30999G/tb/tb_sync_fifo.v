`timescale 1ns / 1ps

module tb_sync_fifo;

    
    parameter DATA_WIDTH = 8;
    parameter DEPTH = 16;
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // DUT Signals
    reg clk;
    reg rst_n;
    reg wr_en;
    reg [DATA_WIDTH-1:0] wr_data;
    wire wr_full;
    reg rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire rd_empty;
    wire [ADDR_WIDTH:0] count;

    
    sync_fifo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .wr_full(wr_full),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_empty(rd_empty),
        .count(count)
    );

    // generating the required clock signals
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end

    // golden model variables 
    reg [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
    integer model_wr_ptr = 0;
    integer model_rd_ptr = 0;
    integer model_count = 0;
    reg [DATA_WIDTH-1:0] model_rd_data = 0;

    
    reg model_valid_write;
    reg model_valid_read;

    // coverage counters 
    integer cov_full = 0;
    integer cov_empty = 0;
    integer cov_wrap = 0;
    integer cov_simul = 0;
    integer cov_overflow = 0;
    integer cov_underflow = 0;

    integer cycle = 0;

    // cycle counter
    always @(posedge clk) cycle <= cycle + 1;

      // golden model update
    always @(posedge clk) begin
        if (!rst_n) begin
            model_wr_ptr = 0;
            model_rd_ptr = 0;
            model_count = 0;
            model_rd_data = 0;
        end else begin
            
            model_valid_write = wr_en && (model_count < DEPTH); 
            model_valid_read  = rd_en && (model_count > 0); 

            if (model_valid_write) begin
                model_mem[model_wr_ptr] = wr_data; 
                model_wr_ptr = (model_wr_ptr == DEPTH - 1) ? 0 : model_wr_ptr + 1;
            end

            if (model_valid_read) begin
                model_rd_data = model_mem[model_rd_ptr]; 
                model_rd_ptr = (model_rd_ptr == DEPTH - 1) ? 0 : model_rd_ptr + 1; 
            end

            if (model_valid_write && !model_valid_read)
                model_count = model_count + 1; 
            else if (!model_valid_write && model_valid_read)
                model_count = model_count - 1; 
                
            // Update Coverage
            if (model_count == DEPTH) cov_full = cov_full + 1;
            if (model_count == 0) cov_empty = cov_empty + 1;
            if (wr_en && (model_count == DEPTH)) cov_overflow = cov_overflow + 1;
            if (rd_en && (model_count == 0)) cov_underflow = cov_underflow + 1;
            if (model_valid_write && model_valid_read) cov_simul = cov_simul + 1;
            if (model_wr_ptr == 0 && model_valid_write) cov_wrap = cov_wrap + 1;
        end
    end

    // scoreboard 
    always @(posedge clk) begin
        #1; // for executing strictly after both DUT and Model update states 
        if (rst_n) begin
            if (dut.rd_data !== model_rd_data) begin 
                $display("ERROR at cycle %0d", cycle); 
                $display("Data Mismatch: Expected=%0h, Got=%0h", model_rd_data, dut.rd_data);
                $finish; 
            end
            if (count !== model_count) begin 
                $display("ERROR at cycle %0d", cycle);
                $display("Count Mismatch: Expected=%0d, Got=%0d", model_count, count); 
                $finish;
            end
            if (rd_empty !== (model_count == 0)) begin 
                $display("ERROR at cycle %0d", cycle);
                $display("Empty Flag Mismatch: Expected=%0b, Got=%0b", (model_count == 0), rd_empty);
                $finish;
            end
            if (wr_full !== (model_count == DEPTH)) begin 
                $display("ERROR at cycle %0d", cycle);
                $display("Full Flag Mismatch: Expected=%0b, Got=%0b", (model_count == DEPTH), wr_full);
                $finish;
            end
        end
    end

    // Stimulus & Directed Tests 
    initial begin
        // Initialize Inputs
        rst_n = 0; wr_en = 0; rd_en = 0; wr_data = 0;
        #25; 
        
        // 1. Reset Test 
        rst_n = 1;
        #10;
        $display("PASS: Reset Test Completed.");

        // 2. Single Write / Read Test 
        wr_en = 1; wr_data = 8'hAA; #10;
        wr_en = 0; #10;
        rd_en = 1; #10;
        rd_en = 0; #10;
        $display("PASS: Single Write/Read Completed.");

        // 3. Fill Test 
        wr_en = 1;
        repeat(DEPTH) begin
            wr_data = $random;
            #10;
        end
        wr_en = 0; #10;
        $display("PASS: Fill Test Completed.");

        // 4. Overflow Attempt Test 
        wr_en = 1; wr_data = 8'hFF; #20; 
        wr_en = 0; #10;
        $display("PASS: Overflow Attempt Completed.");

        // 5. Drain Test 
        rd_en = 1;
        repeat(DEPTH) #10;
        rd_en = 0; #10;
        $display("PASS: Drain Test Completed.");

        // 6. Underflow Attempt Test 
        rd_en = 1; #20;
        rd_en = 0; #10;
        $display("PASS: Underflow Attempt Completed.");

        // 7. Simultaneous Read/Write Test 
        wr_en = 1; wr_data = 8'h11; #10;
        wr_data = 8'h22; #10;
        // Now read and write simultaneously
        rd_en = 1; wr_data = 8'h33; #30;
        wr_en = 0; rd_en = 0; #10;
        $display("PASS: Simultaneous Read/Write Completed.");

        // 8. Pointer Wrap-Around Test 
        // Empty the FIFO first
        rd_en = 1; repeat(5) #10; rd_en = 0;
        
        // Push until wrap
        wr_en = 1;
        repeat(DEPTH + 2) begin
            wr_data = $random;
            if (model_count == DEPTH) wr_en = 0; // stop pushing if full
            #10;
        end
        wr_en = 0;
        $display("PASS: Pointer Wrap-Around Completed.");

        // Coverage Summary Report 
        $display("\n--- Coverage Summary ---");
        $display("cov_full      : %0d", cov_full);
        $display("cov_empty     : %0d", cov_empty);
        $display("cov_wrap      : %0d", cov_wrap);
        $display("cov_simul     : %0d", cov_simul);
        $display("cov_overflow  : %0d", cov_overflow);
        $display("cov_underflow : %0d", cov_underflow);
        
        if (cov_full && cov_empty && cov_wrap && cov_simul && cov_overflow && cov_underflow)
            $display("SUCCESS: All coverage metrics met!");
        else
            $display("WARNING: Missing coverage events.");
            
        $display("All Tests Completed Successfully.");
        $finish; 
    end

endmodule