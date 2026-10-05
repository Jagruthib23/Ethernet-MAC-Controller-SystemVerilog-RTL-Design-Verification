`timescale 1ns/1ps

module mac_rx_mac_error_tb;

    logic clk;
    logic rst;

    logic [7:0] rx_byte;
    logic       rx_valid;
    logic       rx_last;

    logic [47:0] local_mac;

    logic [47:0] rx_dest_mac;
    logic [47:0] rx_src_mac;
    logic [15:0] rx_ethertype;

    logic [7:0] rx_data;
    logic       rx_data_valid;

    logic frame_valid;
    logic crc_error;
    logic mac_error;
    logic rx_done;

    // --------------------------------------------------
    // DUT
    // --------------------------------------------------

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

    // --------------------------------------------------
    // CLOCK
    // --------------------------------------------------

    always #5 clk = ~clk;

    // --------------------------------------------------
    // SEND ONE BYTE
    // --------------------------------------------------

    task send_byte(input logic [7:0] data, input logic last);
        begin
            @(negedge clk);

            rx_byte  = data;
            rx_valid = 1'b1;
            rx_last  = last;

            @(negedge clk);

            rx_valid = 1'b0;
            rx_last  = 1'b0;
        end
    endtask

    // --------------------------------------------------
    // SEND NORMAL BYTE
    // --------------------------------------------------

    task send_normal_byte(input logic [7:0] data);
        begin
            send_byte(data, 1'b0);
        end
    endtask

    // --------------------------------------------------
    // TEST
    // --------------------------------------------------

    initial begin

        clk = 0;
        rst = 1;

        rx_byte  = 8'h00;
        rx_valid = 1'b0;
        rx_last  = 1'b0;

        // Receiver's MAC address
        local_mac = 48'h112233445566;

        // Reset
        #20;
        rst = 0;

        // --------------------------------------------------
        // PREAMBLE
        // --------------------------------------------------

        send_normal_byte(8'hAA);
        send_normal_byte(8'hAA);
        send_normal_byte(8'hAA);
        send_normal_byte(8'hAA);
        send_normal_byte(8'hAA);
        send_normal_byte(8'hAA);
        send_normal_byte(8'hAA);

        // --------------------------------------------------
        // SFD
        // --------------------------------------------------

        send_normal_byte(8'hAB);

        // --------------------------------------------------
        // WRONG DESTINATION MAC
        //
        // Local MAC:
        // 11 22 33 44 55 66
        //
        // Received MAC:
        // 12 34 56 78 9A BC
        // --------------------------------------------------

        send_normal_byte(8'h12);
        send_normal_byte(8'h34);
        send_normal_byte(8'h56);
        send_normal_byte(8'h78);
        send_normal_byte(8'h9A);
        send_normal_byte(8'hBC);

        // --------------------------------------------------
        // SOURCE MAC
        // --------------------------------------------------

        send_normal_byte(8'hAA);
        send_normal_byte(8'hBB);
        send_normal_byte(8'hCC);
        send_normal_byte(8'hDD);
        send_normal_byte(8'hEE);
        send_normal_byte(8'hFF);

        // --------------------------------------------------
        // ETHERTYPE = 0800
        // --------------------------------------------------

        send_normal_byte(8'h08);
        send_normal_byte(8'h00);

        // --------------------------------------------------
        // PAYLOAD = HELLOWORLD
        // --------------------------------------------------

        send_normal_byte(8'h48); // H
        send_normal_byte(8'h45); // E
        send_normal_byte(8'h4C); // L
        send_normal_byte(8'h4C); // L
        send_normal_byte(8'h4F); // O
        send_normal_byte(8'h57); // W
        send_normal_byte(8'h4F); // O
        send_normal_byte(8'h52); // R
        send_normal_byte(8'h4C); // L
        send_normal_byte(8'h44); // D

        // --------------------------------------------------
        // 36 BYTES PADDING
        // --------------------------------------------------

        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);

        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);

        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);

        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);
        send_normal_byte(8'h00);

        // --------------------------------------------------
        // CORRECT FCS FOR THIS FRAME
        //
        // FCS = B1 BA B9 5D
        // --------------------------------------------------

        send_normal_byte(8'hB1);
        send_normal_byte(8'hBA);
        send_normal_byte(8'hB9);
        send_byte(8'h5D, 1'b1);

        // Give DUT time to finish
        #30;

        // --------------------------------------------------
        // RESULTS
        // --------------------------------------------------

        $display("");
        $display("========================================");
        $display("       MAC RX MAC ERROR TEST");
        $display("========================================");

        $display("Destination MAC = %h", rx_dest_mac);
        $display("Source MAC      = %h", rx_src_mac);
        $display("EtherType       = %h", rx_ethertype);

        $display("----------------------------------------");

        $display("Frame Valid     = %b", frame_valid);
        $display("MAC Error       = %b", mac_error);
        $display("CRC Error       = %b", crc_error);

        $display("========================================");

        // --------------------------------------------------
        // CHECK
        // --------------------------------------------------

        if ((mac_error == 1'b1) &&
            (crc_error == 1'b0) &&
            (frame_valid == 1'b0))
        begin
            $display("PASS: Wrong destination MAC detected correctly!");
        end
        else
        begin
            $display("FAIL: MAC error detection is incorrect!");
        end

        $display("========================================");

        $finish;

    end

endmodule