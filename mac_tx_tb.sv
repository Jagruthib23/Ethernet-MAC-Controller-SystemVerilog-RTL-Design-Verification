`timescale 1ns/1ps

module mac_tx_tb;

    logic clk;
    logic rst;

    logic        tx_start;

    logic [47:0] dest_mac;
    logic [47:0] src_mac;
    logic [15:0] ethertype;

    logic [15:0] payload_len;
    logic [7:0]  tx_data;
    logic        tx_data_valid;
    logic        tx_data_ready;

    logic [7:0]  tx_byte;
    logic        tx_valid;
    logic        tx_last;

    logic        tx_busy;
    logic        tx_done;


    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    mac_tx dut (

        .clk            (clk),
        .rst            (rst),

        .tx_start       (tx_start),

        .dest_mac       (dest_mac),
        .src_mac        (src_mac),
        .ethertype      (ethertype),

        .payload_len    (payload_len),
        .tx_data        (tx_data),
        .tx_data_valid  (tx_data_valid),
        .tx_data_ready  (tx_data_ready),

        .tx_byte        (tx_byte),
        .tx_valid       (tx_valid),
        .tx_last        (tx_last),

        .tx_busy        (tx_busy),
        .tx_done        (tx_done)
    );


    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------

    always #5 clk = ~clk;


    // ------------------------------------------------------------
    // Payload
    // ------------------------------------------------------------

    logic [7:0] payload [0:9];

    integer payload_index;


    // ------------------------------------------------------------
    // Drive payload
    // ------------------------------------------------------------

    always @(negedge clk) begin

        if (tx_data_ready && payload_index < payload_len) begin

            tx_data       <= payload[payload_index];
            tx_data_valid <= 1'b1;

        end
        else begin

            tx_data_valid <= 1'b0;

        end

    end


    // ------------------------------------------------------------
    // Payload index
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (rst) begin
            payload_index <= 0;
        end
        else begin

            if (tx_data_ready && tx_data_valid) begin
                payload_index <= payload_index + 1;
            end

        end

    end


    // ------------------------------------------------------------
    // Monitor Ethernet frame
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (tx_valid) begin

            $display(
                "TIME=%0t | BYTE=%02h | LAST=%b",
                $time,
                tx_byte,
                tx_last
            );

        end

    end


    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------

    initial begin

        $dumpfile("sim/mac_tx.vcd");
        $dumpvars(0, mac_tx_tb);


        // Initial values

        clk = 0;
        rst = 1;

        tx_start = 0;

        dest_mac = 48'h112233445566;
        src_mac  = 48'hAABBCCDDEEFF;

        ethertype = 16'h0800;

        payload_len = 16'd10;

        tx_data = 8'h00;
        tx_data_valid = 0;

        payload_index = 0;


        // Payload = "HELLOWORLD"

        payload[0] = 8'h48; // H
        payload[1] = 8'h45; // E
        payload[2] = 8'h4C; // L
        payload[3] = 8'h4C; // L
        payload[4] = 8'h4F; // O
        payload[5] = 8'h57; // W
        payload[6] = 8'h4F; // O
        payload[7] = 8'h52; // R
        payload[8] = 8'h4C; // L
        payload[9] = 8'h44; // D


        // Reset

        #20;
        rst = 0;


        // Start frame

        @(negedge clk);

        tx_start = 1;

        @(negedge clk);

        tx_start = 0;


        // Wait until frame finishes

        wait(tx_done);


        #20;

        $display("");
        $display("========================================");
        $display("       MAC TX TEST COMPLETE");
        $display("========================================");
        $display("Destination MAC : 11:22:33:44:55:66");
        $display("Source MAC      : AA:BB:CC:DD:EE:FF");
        $display("EtherType       : 0800");
        $display("Payload         : HELLOWORLD");
        $display("Payload Length  : 10 bytes");
        $display("Expected Padding: 36 bytes");
        $display("========================================");


        #20;

        $finish;

    end

endmodule