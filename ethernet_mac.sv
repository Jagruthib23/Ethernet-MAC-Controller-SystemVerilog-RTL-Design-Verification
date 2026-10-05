`timescale 1ns/1ps

module ethernet_mac (

    input  logic        clk,
    input  logic        rst,

    // =========================================
    // TX INTERFACE
    // =========================================

    input  logic        tx_start,

    input  logic [47:0] tx_dest_mac,
    input  logic [47:0] tx_src_mac,
    input  logic [15:0] tx_ethertype,

    input  logic [15:0] tx_payload_len,
    input  logic [7:0]  tx_data,
    input  logic        tx_data_valid,

    output logic        tx_data_ready,
    output logic [7:0]  tx_byte,
    output logic        tx_valid,
    output logic        tx_last,
    output logic        tx_busy,
    output logic        tx_done,

    // =========================================
    // RX INTERFACE
    // =========================================

    input  logic [7:0]  rx_byte,
    input  logic        rx_valid,
    input  logic        rx_last,

    input  logic [47:0] local_mac,

    output logic [47:0] rx_dest_mac,
    output logic [47:0] rx_src_mac,
    output logic [15:0] rx_ethertype,

    output logic [7:0]  rx_data,
    output logic        rx_data_valid,

    output logic        frame_valid,
    output logic        crc_error,
    output logic        mac_error,
    output logic        rx_done

);

    // =========================================
    // TRANSMITTER
    // =========================================

    mac_tx tx_inst (

        .clk(clk),
        .rst(rst),

        .tx_start(tx_start),

        .dest_mac(tx_dest_mac),
        .src_mac(tx_src_mac),
        .ethertype(tx_ethertype),

        .payload_len(tx_payload_len),
        .tx_data(tx_data),
        .tx_data_valid(tx_data_valid),

        .tx_data_ready(tx_data_ready),

        .tx_byte(tx_byte),
        .tx_valid(tx_valid),
        .tx_last(tx_last),

        .tx_busy(tx_busy),
        .tx_done(tx_done)

    );

    // =========================================
    // RECEIVER
    // =========================================

    mac_rx rx_inst (

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

endmodule