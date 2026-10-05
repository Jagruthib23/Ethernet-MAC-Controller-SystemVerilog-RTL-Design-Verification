module mac_rx (
    input  logic clk,
    input  logic rst,
    input  logic [7:0] rx_byte,
    input  logic rx_valid,
    input  logic rx_last,
    input  logic [47:0] local_mac,

    output logic [47:0] rx_dest_mac,
    output logic [47:0] rx_src_mac,
    output logic [15:0] rx_ethertype,
    output logic [7:0] rx_data,
    output logic rx_data_valid,
    output logic frame_valid,
    output logic crc_error,
    output logic mac_error,
    output logic rx_done
);

    typedef enum logic [2:0] {
        IDLE,
        PREAMBLE,
        SFD,
        DEST,
        SRC,
        TYPE,
        DATA
    } state_t;

    state_t state;

    logic [2:0] preamble_count;
    logic [2:0] mac_count;
    logic type_count;

    logic [47:0] dest_mac_reg;
    logic [47:0] src_mac_reg;
    logic [15:0] ethertype_reg;

    logic [31:0] crc_reg;

    logic [7:0] buf0;
    logic [7:0] buf1;
    logic [7:0] buf2;
    logic [7:0] buf3;

    logic [2:0] buffer_count;

    integer i;

    // ---------------------------------------------------------
    // CRC-32 calculation for one byte
    // ---------------------------------------------------------
    function automatic [31:0] crc32_byte;
        input [31:0] crc;
        input [7:0] data;

        reg [31:0] c;

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
    // Combinational CRC/FCS values
    //
    // These replace the old final_crc and expected_fcs
    // sequential registers. They do not change the behavior.
    // ---------------------------------------------------------
    logic [31:0] calculated_crc;
    logic [31:0] calculated_fcs;

    always_comb begin
        calculated_crc = crc32_byte(crc_reg, buf0);
        calculated_fcs = ~calculated_crc;
    end

    // ---------------------------------------------------------
    // Outputs
    // ---------------------------------------------------------

    assign rx_dest_mac = dest_mac_reg;
    assign rx_src_mac = src_mac_reg;
    assign rx_ethertype = ethertype_reg;

    // ---------------------------------------------------------
    // Main RX FSM
    // ---------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            state <= IDLE;

            preamble_count <= 0;
            mac_count <= 0;
            type_count <= 0;

            dest_mac_reg <= 0;
            src_mac_reg <= 0;
            ethertype_reg <= 0;

            crc_reg <= 32'hFFFFFFFF;

            buf0 <= 0;
            buf1 <= 0;
            buf2 <= 0;
            buf3 <= 0;

            buffer_count <= 0;

            rx_data <= 0;
            rx_data_valid <= 0;

            frame_valid <= 0;
            crc_error <= 0;
            mac_error <= 0;
            rx_done <= 0;

        end else begin

            // Default one-cycle pulses
            rx_data_valid <= 0;
            rx_done <= 0;

            // =================================================
            // IDLE
            // =================================================

            if (state == IDLE) begin

                if (rx_valid && rx_byte == 8'hAA) begin

                    preamble_count <= 1;
                    state <= PREAMBLE;

                    crc_error <= 0;
                    mac_error <= 0;
                    frame_valid <= 0;

                end

            // =================================================
            // PREAMBLE
            // =================================================

            end else if (state == PREAMBLE) begin

                if (rx_valid) begin

                    if (rx_byte == 8'hAA) begin

                        if (preamble_count == 6)
                            state <= SFD;
                        else
                            preamble_count <= preamble_count + 1;

                    end else begin

                        state <= IDLE;
                        preamble_count <= 0;

                    end

                end

            // =================================================
            // SFD
            // =================================================

            end else if (state == SFD) begin

                if (rx_valid) begin

                    if (rx_byte == 8'hAB) begin

                        mac_count <= 0;
                        crc_reg <= 32'hFFFFFFFF;

                        state <= DEST;

                    end else begin

                        state <= IDLE;

                    end

                end

            // =================================================
            // DESTINATION MAC
            // =================================================

            end else if (state == DEST) begin

                if (rx_valid) begin

                    case (mac_count)

                        0:
                            dest_mac_reg[47:40] <= rx_byte;

                        1:
                            dest_mac_reg[39:32] <= rx_byte;

                        2:
                            dest_mac_reg[31:24] <= rx_byte;

                        3:
                            dest_mac_reg[23:16] <= rx_byte;

                        4:
                            dest_mac_reg[15:8] <= rx_byte;

                        5: begin

                            dest_mac_reg[7:0] <= rx_byte;

                            mac_count <= 0;
                            state <= SRC;

                        end

                        default: begin

                            mac_count <= 0;
                            state <= IDLE;

                        end

                    endcase

                    crc_reg <= crc32_byte(crc_reg, rx_byte);

                    if (mac_count != 5)
                        mac_count <= mac_count + 1;

                end

            // =================================================
            // SOURCE MAC
            // =================================================

            end else if (state == SRC) begin

                if (rx_valid) begin

                    case (mac_count)

                        0:
                            src_mac_reg[47:40] <= rx_byte;

                        1:
                            src_mac_reg[39:32] <= rx_byte;

                        2:
                            src_mac_reg[31:24] <= rx_byte;

                        3:
                            src_mac_reg[23:16] <= rx_byte;

                        4:
                            src_mac_reg[15:8] <= rx_byte;

                        5: begin

                            src_mac_reg[7:0] <= rx_byte;

                            mac_count <= 0;
                            type_count <= 0;

                            state <= TYPE;

                        end

                        default: begin

                            mac_count <= 0;
                            state <= IDLE;

                        end

                    endcase

                    crc_reg <= crc32_byte(crc_reg, rx_byte);

                    if (mac_count != 5)
                        mac_count <= mac_count + 1;

                end

            // =================================================
            // ETHERTYPE
            // =================================================

            end else if (state == TYPE) begin

                if (rx_valid) begin

                    if (type_count == 0) begin

                        ethertype_reg[15:8] <= rx_byte;
                        type_count <= 1;

                    end else begin

                        ethertype_reg[7:0] <= rx_byte;

                        buffer_count <= 0;

                        buf0 <= 0;
                        buf1 <= 0;
                        buf2 <= 0;
                        buf3 <= 0;

                        state <= DATA;

                    end

                    crc_reg <= crc32_byte(crc_reg, rx_byte);

                end

            // =================================================
            // PAYLOAD + FCS
            // =================================================

            end else if (state == DATA) begin

                if (rx_valid) begin

                    // Shift the four-byte buffer
                    buf0 <= buf1;
                    buf1 <= buf2;
                    buf2 <= buf3;
                    buf3 <= rx_byte;

                    if (buffer_count < 4) begin

                        buffer_count <= buffer_count + 1;

                    end else begin

                        // -------------------------------------------------
                        // buf0 is now the oldest byte.
                        // When rx_last arrives:
                        //
                        // buf0 = last payload byte
                        // buf1 = FCS byte 0
                        // buf2 = FCS byte 1
                        // buf3 = FCS byte 2
                        // rx_byte = FCS byte 3
                        // -------------------------------------------------

                        if (rx_last) begin

                            rx_data <= buf0;
                            rx_data_valid <= 1;

                            // -----------------------------
                            // CRC CHECK
                            // -----------------------------

                            if ((buf1 == calculated_fcs[7:0]) &&
                                (buf2 == calculated_fcs[15:8]) &&
                                (buf3 == calculated_fcs[23:16]) &&
                                (rx_byte == calculated_fcs[31:24])) begin

                                crc_error <= 0;

                            end else begin

                                crc_error <= 1;

                            end

                            // -----------------------------
                            // MAC ADDRESS CHECK
                            // -----------------------------

                            if ((dest_mac_reg == local_mac) ||
                                (dest_mac_reg == 48'hFFFFFFFFFFFF)) begin

                                mac_error <= 0;

                            end else begin

                                mac_error <= 1;

                            end

                            // -----------------------------
                            // FRAME VALID
                            // -----------------------------

                            if ((buf1 == calculated_fcs[7:0]) &&
                                (buf2 == calculated_fcs[15:8]) &&
                                (buf3 == calculated_fcs[23:16]) &&
                                (rx_byte == calculated_fcs[31:24]) &&
                                ((dest_mac_reg == local_mac) ||
                                 (dest_mac_reg == 48'hFFFFFFFFFFFF))) begin

                                frame_valid <= 1;

                            end else begin

                                frame_valid <= 0;

                            end

                            rx_done <= 1;

                            state <= IDLE;

                        end else begin

                            // Normal payload byte
                            rx_data <= buf0;
                            rx_data_valid <= 1;

                            crc_reg <= calculated_crc;

                        end

                    end

                end

            end else begin

                state <= IDLE;

            end

        end

    end

endmodule