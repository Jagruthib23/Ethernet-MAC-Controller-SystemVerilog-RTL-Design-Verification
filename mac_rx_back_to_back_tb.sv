`timescale 1ns/1ps

module mac_rx_back_to_back_tb;

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

    integer completed_frames;

    reg previous_rx_done;

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
    // CLOCK
    // ============================================

    always #5 clk = ~clk;

    // ============================================
    // ASSERTIONS
    // ============================================

    always @(posedge clk) begin

        if (rst) begin

            previous_rx_done <= 1'b0;

        end
        else begin

            // rx_done should only be a one-cycle pulse

            if (previous_rx_done && rx_done) begin

                $display("ASSERTION FAILED: rx_done stayed HIGH");
                $finish;

            end

            // A valid frame cannot have CRC error

            if (frame_valid && crc_error) begin

                $display(
                    "ASSERTION FAILED: frame_valid with CRC error"
                );

                $finish;

            end

            // A valid frame cannot have MAC error

            if (frame_valid && mac_error) begin

                $display(
                    "ASSERTION FAILED: frame_valid with MAC error"
                );

                $finish;

            end

            previous_rx_done <= rx_done;

        end

    end

    // ============================================
    // CRC FUNCTION
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
    // SEND ONE BYTE
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
    // FRAME 1
    // Payload = HELLO
    // ============================================

    task send_frame1;

        reg [31:0] crc;
        reg [31:0] fcs;

        integer i;

        begin

            crc = 32'hFFFFFFFF;

            // Preamble

            for (i = 0; i < 7; i = i + 1)
                send_byte(8'hAA, 1'b0);

            // SFD

            send_byte(8'hAB, 1'b0);

            // Destination MAC

            send_byte(8'h11, 1'b0);
            crc = crc32_byte(crc, 8'h11);

            send_byte(8'h22, 1'b0);
            crc = crc32_byte(crc, 8'h22);

            send_byte(8'h33, 1'b0);
            crc = crc32_byte(crc, 8'h33);

            send_byte(8'h44, 1'b0);
            crc = crc32_byte(crc, 8'h44);

            send_byte(8'h55, 1'b0);
            crc = crc32_byte(crc, 8'h55);

            send_byte(8'h66, 1'b0);
            crc = crc32_byte(crc, 8'h66);

            // Source MAC

            send_byte(8'hAA, 1'b0);
            crc = crc32_byte(crc, 8'hAA);

            send_byte(8'hBB, 1'b0);
            crc = crc32_byte(crc, 8'hBB);

            send_byte(8'hCC, 1'b0);
            crc = crc32_byte(crc, 8'hCC);

            send_byte(8'hDD, 1'b0);
            crc = crc32_byte(crc, 8'hDD);

            send_byte(8'hEE, 1'b0);
            crc = crc32_byte(crc, 8'hEE);

            send_byte(8'hFF, 1'b0);
            crc = crc32_byte(crc, 8'hFF);

            // EtherType 0800

            send_byte(8'h08, 1'b0);
            crc = crc32_byte(crc, 8'h08);

            send_byte(8'h00, 1'b0);
            crc = crc32_byte(crc, 8'h00);

            // Payload HELLO

            send_byte(8'h48, 1'b0);
            crc = crc32_byte(crc, 8'h48);

            send_byte(8'h45, 1'b0);
            crc = crc32_byte(crc, 8'h45);

            send_byte(8'h4C, 1'b0);
            crc = crc32_byte(crc, 8'h4C);

            send_byte(8'h4C, 1'b0);
            crc = crc32_byte(crc, 8'h4C);

            send_byte(8'h4F, 1'b0);
            crc = crc32_byte(crc, 8'h4F);

            // Padding: 41 bytes

            for (i = 0; i < 41; i = i + 1) begin

                send_byte(8'h00, 1'b0);

                crc = crc32_byte(crc, 8'h00);

            end

            // FCS

            fcs = ~crc;

            send_byte(fcs[7:0],   1'b0);
            send_byte(fcs[15:8],  1'b0);
            send_byte(fcs[23:16], 1'b0);
            send_byte(fcs[31:24], 1'b1);

            $display("Frame 1 FCS = %08h", fcs);

        end

    endtask

    // ============================================
    // FRAME 2
    // Payload = WORLD
    // ============================================

    task send_frame2;

        reg [31:0] crc;
        reg [31:0] fcs;

        integer i;

        begin

            crc = 32'hFFFFFFFF;

            // Preamble

            for (i = 0; i < 7; i = i + 1)
                send_byte(8'hAA, 1'b0);

            // SFD

            send_byte(8'hAB, 1'b0);

            // Destination MAC

            send_byte(8'h11, 1'b0);
            crc = crc32_byte(crc, 8'h11);

            send_byte(8'h22, 1'b0);
            crc = crc32_byte(crc, 8'h22);

            send_byte(8'h33, 1'b0);
            crc = crc32_byte(crc, 8'h33);

            send_byte(8'h44, 1'b0);
            crc = crc32_byte(crc, 8'h44);

            send_byte(8'h55, 1'b0);
            crc = crc32_byte(crc, 8'h55);

            send_byte(8'h66, 1'b0);
            crc = crc32_byte(crc, 8'h66);

            // Source MAC

            send_byte(8'hAA, 1'b0);
            crc = crc32_byte(crc, 8'hAA);

            send_byte(8'hBB, 1'b0);
            crc = crc32_byte(crc, 8'hBB);

            send_byte(8'hCC, 1'b0);
            crc = crc32_byte(crc, 8'hCC);

            send_byte(8'hDD, 1'b0);
            crc = crc32_byte(crc, 8'hDD);

            send_byte(8'hEE, 1'b0);
            crc = crc32_byte(crc, 8'hEE);

            send_byte(8'hFF, 1'b0);
            crc = crc32_byte(crc, 8'hFF);

            // EtherType

            send_byte(8'h08, 1'b0);
            crc = crc32_byte(crc, 8'h08);

            send_byte(8'h00, 1'b0);
            crc = crc32_byte(crc, 8'h00);

            // Payload WORLD

            send_byte(8'h57, 1'b0);
            crc = crc32_byte(crc, 8'h57);

            send_byte(8'h4F, 1'b0);
            crc = crc32_byte(crc, 8'h4F);

            send_byte(8'h52, 1'b0);
            crc = crc32_byte(crc, 8'h52);

            send_byte(8'h4C, 1'b0);
            crc = crc32_byte(crc, 8'h4C);

            send_byte(8'h44, 1'b0);
            crc = crc32_byte(crc, 8'h44);

            // Padding

            for (i = 0; i < 41; i = i + 1) begin

                send_byte(8'h00, 1'b0);

                crc = crc32_byte(crc, 8'h00);

            end

            // FCS

            fcs = ~crc;

            send_byte(fcs[7:0],   1'b0);
            send_byte(fcs[15:8],  1'b0);
            send_byte(fcs[23:16], 1'b0);
            send_byte(fcs[31:24], 1'b1);

            $display("Frame 2 FCS = %08h", fcs);

        end

    endtask

    // ============================================
    // MAIN TEST
    // ============================================

    initial begin

        // ----------------------------------------
        // ENABLE GTKWAVE
        // ----------------------------------------

        $dumpfile("sim/mac_rx_back_to_back.vcd");
        $dumpvars(0, mac_rx_back_to_back_tb);

        // ----------------------------------------
        // INITIAL VALUES
        // ----------------------------------------

        clk = 0;

        rst = 1;

        rx_byte  = 8'h00;
        rx_valid = 1'b0;
        rx_last  = 1'b0;

        local_mac = 48'h112233445566;

        completed_frames = 0;

        previous_rx_done = 1'b0;

        // ----------------------------------------
        // RESET
        // ----------------------------------------

        #20;

        rst = 0;

        // ----------------------------------------
        // TEST INFORMATION
        // ----------------------------------------

        $display("");
        $display("========================================");
        $display("      BACK-TO-BACK FRAME TEST");
        $display("========================================");

        $display("Frame 1 payload = HELLO");
        $display("Frame 2 payload = WORLD");

        $display("");
        $display("Assertions enabled");

        // ----------------------------------------
        // FRAME 1
        // ----------------------------------------

        $display("");
        $display("Sending FRAME 1...");

        send_frame1;

        // Wait for RX completion

        @(posedge clk);

        if (rx_done)
            completed_frames = completed_frames + 1;

        // ----------------------------------------
        // FRAME 2
        // ----------------------------------------

        $display("Sending FRAME 2...");

        send_frame2;

        @(posedge clk);

        if (rx_done)
            completed_frames = completed_frames + 1;

        // ----------------------------------------
        // RESULTS
        // ----------------------------------------

        $display("");
        $display("========================================");
        $display("          TEST RESULTS");
        $display("========================================");

        $display("Completed frames = %0d", completed_frames);

        $display("Frame Valid      = %b", frame_valid);
        $display("MAC Error        = %b", mac_error);
        $display("CRC Error        = %b", crc_error);

        $display("Destination MAC  = %012h", rx_dest_mac);
        $display("Source MAC       = %012h", rx_src_mac);
        $display("EtherType        = %04h", rx_ethertype);

        $display("");

        if ((completed_frames == 2) &&
            frame_valid &&
            !mac_error &&
            !crc_error) begin

            $display("========================================");
            $display("     PASS: BACK-TO-BACK FRAMES");
            $display("     ALL ASSERTIONS PASSED");
            $display("========================================");

        end
        else begin

            $display("========================================");
            $display("     FAIL: BACK-TO-BACK TEST");
            $display("========================================");

        end

        #20;

        $finish;

    end

endmodule