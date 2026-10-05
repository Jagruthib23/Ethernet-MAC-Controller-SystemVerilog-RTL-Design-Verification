`timescale 1ns/1ps

module mac_rx_tb;

    logic clk;
    logic rst;

    logic [7:0] rx_byte;
    logic rx_valid;
    logic rx_last;

    logic [47:0] local_mac;

    logic [47:0] rx_dest_mac;
    logic [47:0] rx_src_mac;
    logic [15:0] rx_ethertype;

    logic [7:0] rx_data;
    logic rx_data_valid;

    logic frame_valid;
    logic crc_error;
    logic mac_error;
    logic rx_done;


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


    always #5 clk = ~clk;


    // --------------------------------------------------
    // Send one byte
    // --------------------------------------------------
    task send_byte;

        input [7:0] data;
        input       last;

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
    // Display received payload
    // --------------------------------------------------
    always @(posedge clk) begin

        if (rx_data_valid) begin

            $display(
                "TIME=%0t | RX PAYLOAD = %02h (%c)",
                $time,
                rx_data,
                rx_data
            );

        end

    end


    // --------------------------------------------------
    // Test
    // --------------------------------------------------
    initial begin

        $dumpfile("sim/mac_rx.vcd");
        $dumpvars(0, mac_rx_tb);

        clk = 0;
        rst = 1;

        rx_byte = 0;
        rx_valid = 0;
        rx_last = 0;

        // Destination MAC
        // Same as local MAC so MAC filtering passes
        local_mac = 48'h112233445566;


        // Reset
        #20;
        rst = 0;


        // --------------------------------------------------
        // PREAMBLE
        // --------------------------------------------------

        send_byte(8'hAA, 0);
        send_byte(8'hAA, 0);
        send_byte(8'hAA, 0);
        send_byte(8'hAA, 0);
        send_byte(8'hAA, 0);
        send_byte(8'hAA, 0);
        send_byte(8'hAA, 0);


        // --------------------------------------------------
        // SFD
        // --------------------------------------------------

        send_byte(8'hAB, 0);


        // --------------------------------------------------
        // DESTINATION MAC
        // 11:22:33:44:55:66
        // --------------------------------------------------

        send_byte(8'h11, 0);
        send_byte(8'h22, 0);
        send_byte(8'h33, 0);
        send_byte(8'h44, 0);
        send_byte(8'h55, 0);
        send_byte(8'h66, 0);


        // --------------------------------------------------
        // SOURCE MAC
        // AA:BB:CC:DD:EE:FF
        // --------------------------------------------------

        send_byte(8'hAA, 0);
        send_byte(8'hBB, 0);
        send_byte(8'hCC, 0);
        send_byte(8'hDD, 0);
        send_byte(8'hEE, 0);
        send_byte(8'hFF, 0);


        // --------------------------------------------------
        // ETHERTYPE = IPv4
        // --------------------------------------------------

        send_byte(8'h08, 0);
        send_byte(8'h00, 0);


        // --------------------------------------------------
        // PAYLOAD = HELLOWORLD
        // --------------------------------------------------

        send_byte(8'h48, 0); // H
        send_byte(8'h45, 0); // E
        send_byte(8'h4C, 0); // L
        send_byte(8'h4C, 0); // L
        send_byte(8'h4F, 0); // O
        send_byte(8'h57, 0); // W
        send_byte(8'h4F, 0); // O
        send_byte(8'h52, 0); // R
        send_byte(8'h4C, 0); // L
        send_byte(8'h44, 0); // D


        // --------------------------------------------------
        // Ethernet padding
        // 36 bytes
        // --------------------------------------------------

        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);

        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);

        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);

        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);
        send_byte(8'h00, 0);


        // --------------------------------------------------
        // FCS
        //
        // From our TX simulation:
        // EE BB A6 DA
        // --------------------------------------------------

        send_byte(8'hEE, 0);
        send_byte(8'hBB, 0);
        send_byte(8'hA6, 0);
        send_byte(8'hDA, 1);


        #50;


        // --------------------------------------------------
        // RESULTS
        // --------------------------------------------------

        $display("");
        $display("========================================");
        $display("          MAC RX TEST COMPLETE");
        $display("========================================");

        $display(
            "Destination MAC = %012h",
            rx_dest_mac
        );

        $display(
            "Source MAC      = %012h",
            rx_src_mac
        );

        $display(
            "EtherType       = %04h",
            rx_ethertype
        );

        $display(
            "Frame Valid     = %b",
            frame_valid
        );

        $display(
            "MAC Error       = %b",
            mac_error
        );

        $display(
            "CRC Error       = %b",
            crc_error
        );

        $display("========================================");


        $finish;

    end

endmodule