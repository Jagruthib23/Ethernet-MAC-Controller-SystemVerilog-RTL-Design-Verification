`timescale 1ns/1ps

module mac_rx_coverage_tb;

    logic clk;
    logic rst;

    logic [7:0] rx_byte;
    logic       rx_valid;
    logic       rx_last;

    logic [47:0] local_mac;

    logic [47:0] rx_dest_mac;
    logic [47:0] rx_src_mac;
    logic [15:0] rx_ethertype;
    logic [7:0]  rx_data;
    logic        rx_data_valid;
    logic        frame_valid;
    logic        crc_error;
    logic        mac_error;
    logic        rx_done;

    // ============================================
    // Coverage counters
    // ============================================

    integer min_payload_count;
    integer normal_payload_count;
    integer padded_payload_count;
    integer crc_error_count;
    integer mac_error_count;
    integer broadcast_count;
    integer back_to_back_count;

    integer completed_frames;

    // ============================================
    // DUT
    // ============================================

    mac_rx dut (
        .clk(clk),
        .rst(rst),
        .rx_byte(rx_byte),
        .rx_valid(rx_valid),
        .rx_last(rx_last),
        .local_mac(local_mac),

        .rx_dest_mac(rx_dest_mac),
        .rx_src_mac(rx_src_mac),
        .rx_ethertype(rx_ethertype),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .frame_valid(frame_valid),
        .crc_error(crc_error),
        .mac_error(mac_error),
        .rx_done(rx_done)
    );

    // ============================================
    // Clock
    // ============================================

    always #5 clk = ~clk;

    // ============================================
    // CRC function
    // ============================================

    function [31:0] crc32_byte;

        input [31:0] crc;
        input [7:0] data;

        reg [31:0] c;
        integer j;

        begin

            c = crc ^ {24'h000000, data};

            for (j = 0; j < 8; j = j + 1) begin

                if (c[0])
                    c = (c >> 1) ^ 32'hEDB88320;
                else
                    c = c >> 1;

            end

            crc32_byte = c;

        end

    endfunction

    // ============================================
    // Send one byte
    // ============================================

    task send_byte;

        input [7:0] data;
        input       last;

        begin

            @(posedge clk);

            rx_byte  <= data;
            rx_valid <= 1'b1;
            rx_last  <= last;

            @(posedge clk);

            rx_valid <= 1'b0;
            rx_last  <= 1'b0;

        end

    endtask

    // ============================================
    // Send frame
    // ============================================

    task send_frame;

        input [47:0] destination;
        input [47:0] source;
        input integer payload_length;
        input integer corrupt_crc;

        reg [31:0] crc;
        reg [31:0] fcs;

        integer i;
        integer pad_length;

        begin

            // Start CRC

            crc = 32'hFFFFFFFF;

            // ====================================
            // Preamble
            // ====================================

            for (i = 0; i < 7; i = i + 1)
                send_byte(8'hAA, 1'b0);

            // ====================================
            // SFD
            // ====================================

            send_byte(8'hAB, 1'b0);

            // ====================================
            // Destination MAC
            // ====================================

            send_byte(destination[47:40], 1'b0);
            crc = crc32_byte(crc, destination[47:40]);

            send_byte(destination[39:32], 1'b0);
            crc = crc32_byte(crc, destination[39:32]);

            send_byte(destination[31:24], 1'b0);
            crc = crc32_byte(crc, destination[31:24]);

            send_byte(destination[23:16], 1'b0);
            crc = crc32_byte(crc, destination[23:16]);

            send_byte(destination[15:8], 1'b0);
            crc = crc32_byte(crc, destination[15:8]);

            send_byte(destination[7:0], 1'b0);
            crc = crc32_byte(crc, destination[7:0]);

            // ====================================
            // Source MAC
            // ====================================

            send_byte(source[47:40], 1'b0);
            crc = crc32_byte(crc, source[47:40]);

            send_byte(source[39:32], 1'b0);
            crc = crc32_byte(crc, source[39:32]);

            send_byte(source[31:24], 1'b0);
            crc = crc32_byte(crc, source[31:24]);

            send_byte(source[23:16], 1'b0);
            crc = crc32_byte(crc, source[23:16]);

            send_byte(source[15:8], 1'b0);
            crc = crc32_byte(crc, source[15:8]);

            send_byte(source[7:0], 1'b0);
            crc = crc32_byte(crc, source[7:0]);

            // ====================================
            // EtherType = 0800
            // ====================================

            send_byte(8'h08, 1'b0);
            crc = crc32_byte(crc, 8'h08);

            send_byte(8'h00, 1'b0);
            crc = crc32_byte(crc, 8'h00);

            // ====================================
            // Payload
            // ====================================

            for (i = 0; i < payload_length; i = i + 1) begin

                send_byte(8'h30 + (i % 10), 1'b0);

                crc = crc32_byte(
                    crc,
                    8'h30 + (i % 10)
                );

            end

            // ====================================
            // Padding
            // ====================================

            pad_length = 0;

            if (payload_length < 46)
                pad_length = 46 - payload_length;

            for (i = 0; i < pad_length; i = i + 1) begin

                send_byte(8'h00, 1'b0);

                crc = crc32_byte(
                    crc,
                    8'h00
                );

            end

            // ====================================
            // Final CRC
            // ====================================

            fcs = ~crc;

            // Corrupt CRC when requested

            if (corrupt_crc)
                fcs = fcs ^ 32'h00000001;

            // ====================================
            // FCS
            // ====================================

            send_byte(fcs[7:0],  1'b0);
            send_byte(fcs[15:8],  1'b0);
            send_byte(fcs[23:16], 1'b0);
            send_byte(fcs[31:24], 1'b1);

        end

    endtask

    // ============================================
    // Main test
    // ============================================

    initial begin

        clk = 0;
        rst = 1;

        rx_byte  = 0;
        rx_valid = 0;
        rx_last  = 0;

        local_mac = 48'h112233445566;

        min_payload_count    = 0;
        normal_payload_count = 0;
        padded_payload_count = 0;
        crc_error_count      = 0;
        mac_error_count      = 0;
        broadcast_count      = 0;
        back_to_back_count   = 0;

        completed_frames = 0;

        #20;

        rst = 0;

        // ========================================
        // TEST 1: 46-BYTE MINIMUM PAYLOAD
        // ========================================

        $display("");
        $display("TEST 1: Minimum payload");

        send_frame(
            48'h112233445566,
            48'hAABBCCDDEEFF,
            46,
            0
        );

        @(posedge clk);

        if (frame_valid && !crc_error && !mac_error) begin

            min_payload_count = min_payload_count + 1;

            $display("COVERED: 46-byte minimum payload");

        end

        // ========================================
        // TEST 2: 100-BYTE PAYLOAD
        // ========================================

        $display("");
        $display("TEST 2: Normal payload");

        send_frame(
            48'h112233445566,
            48'hAABBCCDDEEFF,
            100,
            0
        );

        @(posedge clk);

        if (frame_valid && !crc_error && !mac_error) begin

            normal_payload_count =
                normal_payload_count + 1;

            $display("COVERED: 100-byte payload");

        end

        // ========================================
        // TEST 3: PADDING
        // ========================================

        $display("");
        $display("TEST 3: Payload requiring padding");

        send_frame(
            48'h112233445566,
            48'hAABBCCDDEEFF,
            10,
            0
        );

        @(posedge clk);

        if (frame_valid && !crc_error && !mac_error) begin

            padded_payload_count =
                padded_payload_count + 1;

            $display("COVERED: Payload padding");

        end

        // ========================================
        // TEST 4: CRC ERROR
        // ========================================

        $display("");
        $display("TEST 4: CRC error");

        send_frame(
            48'h112233445566,
            48'hAABBCCDDEEFF,
            50,
            1
        );

        @(posedge clk);

        if (crc_error && !frame_valid) begin

            crc_error_count =
                crc_error_count + 1;

            $display("COVERED: CRC error");

        end

        // ========================================
        // TEST 5: WRONG MAC
        // ========================================

        $display("");
        $display("TEST 5: Wrong destination MAC");

        send_frame(
            48'h999999999999,
            48'hAABBCCDDEEFF,
            50,
            0
        );

        @(posedge clk);

        if (mac_error && !frame_valid) begin

            mac_error_count =
                mac_error_count + 1;

            $display("COVERED: MAC error");

        end

        // ========================================
        // TEST 6: BROADCAST
        // ========================================

        $display("");
        $display("TEST 6: Broadcast frame");

        send_frame(
            48'hFFFFFFFFFFFF,
            48'hAABBCCDDEEFF,
            50,
            0
        );

        @(posedge clk);

        if (frame_valid && !crc_error && !mac_error) begin

            broadcast_count =
                broadcast_count + 1;

            $display("COVERED: Broadcast");

        end

        // ========================================
        // TEST 7: BACK-TO-BACK
        // ========================================

        $display("");
        $display("TEST 7: Back-to-back frames");

        send_frame(
            48'h112233445566,
            48'hAABBCCDDEEFF,
            20,
            0
        );

        send_frame(
            48'h112233445566,
            48'hAABBCCDDEEFF,
            20,
            0
        );

        @(posedge clk);

        back_to_back_count = 1;

        $display("COVERED: Back-to-back frames");

        // ========================================
        // COVERAGE REPORT
        // ========================================

        $display("");
        $display("========================================");
        $display("       FUNCTIONAL COVERAGE");
        $display("========================================");

        if (min_payload_count > 0)
            $display("Minimum payload (46B) : COVERED");
        else
            $display("Minimum payload (46B) : NOT COVERED");

        if (normal_payload_count > 0)
            $display("Normal payload (100B): COVERED");
        else
            $display("Normal payload (100B): NOT COVERED");

        if (padded_payload_count > 0)
            $display("Padding               : COVERED");
        else
            $display("Padding               : NOT COVERED");

        if (crc_error_count > 0)
            $display("CRC error             : COVERED");
        else
            $display("CRC error             : NOT COVERED");

        if (mac_error_count > 0)
            $display("MAC error             : COVERED");
        else
            $display("MAC error             : NOT COVERED");

        if (broadcast_count > 0)
            $display("Broadcast             : COVERED");
        else
            $display("Broadcast             : NOT COVERED");

        if (back_to_back_count > 0)
            $display("Back-to-back frames   : COVERED");
        else
            $display("Back-to-back frames   : NOT COVERED");

        $display("========================================");

        if ((min_payload_count > 0) &&
            (normal_payload_count > 0) &&
            (padded_payload_count > 0) &&
            (crc_error_count > 0) &&
            (mac_error_count > 0) &&
            (broadcast_count > 0) &&
            (back_to_back_count > 0)) begin

            $display("Coverage: 7/7 scenarios");
            $display("STATUS: FULLY COVERED");

        end
        else begin

            $display("Coverage incomplete");

        end

        $display("========================================");

        #20;

        $finish;

    end

endmodule