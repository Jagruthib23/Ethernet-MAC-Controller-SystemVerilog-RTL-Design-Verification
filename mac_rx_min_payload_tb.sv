`timescale 1ns/1ps

module mac_rx_min_payload_tb;

    logic clk;
    logic rst;

    logic [7:0] rx_byte;
    logic rx_valid;
    logic rx_last;

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

    // ---------------------------------------------------------
    // DUT
    // ---------------------------------------------------------
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

    // ---------------------------------------------------------
    // Clock
    // ---------------------------------------------------------
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // CRC function
    // Ethernet CRC-32 reflected implementation
    // ---------------------------------------------------------
    function automatic [31:0] crc32_byte;
        input [31:0] crc;
        input [7:0] data;

        reg [31:0] c;
        integer i;

        begin
            c = crc ^ {24'h000000, data};

            for (i = 0; i < 8; i = i + 1) begin
                if (c[0])
                    c = (c >> 1) ^ 32'hEDB88320;
                else
                    c = c >> 1;
            end

            crc32_byte = c;
        end
    endfunction

    // ---------------------------------------------------------
    // Send one byte
    // ---------------------------------------------------------
    task send_byte;
        input [7:0] data;
        input       last;

        begin
            @(negedge clk);

            rx_byte  = data;
            rx_valid = 1;
            rx_last  = last;

            @(negedge clk);

            rx_valid = 0;
            rx_last  = 0;
        end
    endtask

    // ---------------------------------------------------------
    // Test variables
    // ---------------------------------------------------------
    reg [31:0] crc;
    reg [31:0] final_crc;
    reg [31:0] fcs;

    integer i;

    // ---------------------------------------------------------
    // Test
    // ---------------------------------------------------------
    initial begin

        clk = 0;
        rst = 1;

        rx_byte  = 0;
        rx_valid = 0;
        rx_last  = 0;

        local_mac = 48'h112233445566;

        // Reset
        #20;
        rst = 0;

        // Start CRC
        crc = 32'hFFFFFFFF;

        $display("");
        $display("========================================");
        $display("   MINIMUM PAYLOAD RX TEST");
        $display("========================================");
        $display("Payload length = 46 bytes");
        $display("");

        // -----------------------------------------------------
        // PREAMBLE - 7 bytes AA
        // -----------------------------------------------------
        for (i = 0; i < 7; i = i + 1)
            send_byte(8'hAA, 0);

        // -----------------------------------------------------
        // SFD
        // -----------------------------------------------------
        send_byte(8'hAB, 0);

        // -----------------------------------------------------
        // DESTINATION MAC
        // 11:22:33:44:55:66
        // -----------------------------------------------------
        send_byte(8'h11, 0);
        crc = crc32_byte(crc, 8'h11);

        send_byte(8'h22, 0);
        crc = crc32_byte(crc, 8'h22);

        send_byte(8'h33, 0);
        crc = crc32_byte(crc, 8'h33);

        send_byte(8'h44, 0);
        crc = crc32_byte(crc, 8'h44);

        send_byte(8'h55, 0);
        crc = crc32_byte(crc, 8'h55);

        send_byte(8'h66, 0);
        crc = crc32_byte(crc, 8'h66);

        // -----------------------------------------------------
        // SOURCE MAC
        // AA:BB:CC:DD:EE:FF
        // -----------------------------------------------------
        send_byte(8'hAA, 0);
        crc = crc32_byte(crc, 8'hAA);

        send_byte(8'hBB, 0);
        crc = crc32_byte(crc, 8'hBB);

        send_byte(8'hCC, 0);
        crc = crc32_byte(crc, 8'hCC);

        send_byte(8'hDD, 0);
        crc = crc32_byte(crc, 8'hDD);

        send_byte(8'hEE, 0);
        crc = crc32_byte(crc, 8'hEE);

        send_byte(8'hFF, 0);
        crc = crc32_byte(crc, 8'hFF);

        // -----------------------------------------------------
        // EtherType = 0800
        // -----------------------------------------------------
        send_byte(8'h08, 0);
        crc = crc32_byte(crc, 8'h08);

        send_byte(8'h00, 0);
        crc = crc32_byte(crc, 8'h00);

        // -----------------------------------------------------
        // 46-BYTE PAYLOAD
        // Pattern:
        // 01 02 03 ... 2E
        // -----------------------------------------------------
        for (i = 1; i <= 46; i = i + 1) begin
            send_byte(i[7:0], 0);
            crc = crc32_byte(crc, i[7:0]);
        end

        // -----------------------------------------------------
        // Calculate Ethernet FCS
        // -----------------------------------------------------
        final_crc = ~crc;
        fcs = final_crc;

        $display("Calculated FCS = %08h", fcs);

        // Ethernet sends FCS LSB first
        send_byte(fcs[7:0],  0);
        send_byte(fcs[15:8],  0);
        send_byte(fcs[23:16], 0);
        send_byte(fcs[31:24], 1);

        // Give DUT time to finish
        #30;

        // -----------------------------------------------------
        // RESULTS
        // -----------------------------------------------------
        $display("");
        $display("========================================");
        $display("          TEST RESULTS");
        $display("========================================");

        $display("Destination MAC = %012h", rx_dest_mac);
        $display("Source MAC      = %012h", rx_src_mac);
        $display("EtherType       = %04h", rx_ethertype);
        $display("Frame Valid     = %b", frame_valid);
        $display("MAC Error       = %b", mac_error);
        $display("CRC Error       = %b", crc_error);

        if (frame_valid &&
            !mac_error &&
            !crc_error &&
            rx_dest_mac == 48'h112233445566 &&
            rx_src_mac  == 48'hAABBCCDDEEFF &&
            rx_ethertype == 16'h0800) begin

            $display("");
            $display("========================================");
            $display("       PASS: 46-BYTE PAYLOAD");
            $display("========================================");

        end else begin

            $display("");
            $display("========================================");
            $display("       FAIL: 46-BYTE PAYLOAD");
            $display("========================================");

        end

        #20;
        $finish;

    end

endmodule