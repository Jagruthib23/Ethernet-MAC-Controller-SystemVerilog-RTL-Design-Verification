`timescale 1ns/1ps

module crc32_tb;

    logic clk;
    logic rst;
    logic init;
    logic enable;
    logic [7:0] data_in;
    logic [31:0] crc_out;

    crc32 dut (
        .clk(clk),
        .rst(rst),
        .init(init),
        .enable(enable),
        .data_in(data_in),
        .crc_out(crc_out)
    );

    always #5 clk = ~clk;

    task send_byte(input logic [7:0] data);
        begin
            @(negedge clk);
            data_in = data;
            enable  = 1'b1;

            @(negedge clk);
            enable  = 1'b0;
        end
    endtask

    initial begin

        clk     = 0;
        rst     = 1;
        init    = 0;
        enable  = 0;
        data_in = 8'h00;

        #20;
        rst = 0;

        // Initialize CRC
        @(negedge clk);
        init = 1;

        @(negedge clk);
        init = 0;

        // "123456789"
        send_byte(8'h31);
        send_byte(8'h32);
        send_byte(8'h33);
        send_byte(8'h34);
        send_byte(8'h35);
        send_byte(8'h36);
        send_byte(8'h37);
        send_byte(8'h38);
        send_byte(8'h39);

        #20;

        $display("--------------------------------");
        $display("CRC TEST");
        $display("Input    = 123456789");
        $display("CRC      = %h", crc_out);
        $display("Expected = CBF43926");
        $display("--------------------------------");

        if (crc_out == 32'hCBF43926)
            $display("PASS: CRC is correct!");
        else
            $display("FAIL: CRC mismatch!");

        $finish;
    end

endmodule