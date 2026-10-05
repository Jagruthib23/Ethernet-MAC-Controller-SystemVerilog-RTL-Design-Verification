module mac_tx (
    input  logic        clk,
    input  logic        rst,

    // Start a new Ethernet frame
    input  logic        tx_start,

    // Frame information
    input  logic [47:0] dest_mac,
    input  logic [47:0] src_mac,
    input  logic [15:0] ethertype,

    // Payload information
    input  logic [15:0] payload_len,
    input  logic [7:0]  tx_data,
    input  logic        tx_data_valid,
    output logic        tx_data_ready,

    // Ethernet byte stream output
    output logic [7:0]  tx_byte,
    output logic        tx_valid,
    output logic        tx_last,

    // Status
    output logic        tx_busy,
    output logic        tx_done
);

    // ------------------------------------------------------------
    // FSM states
    // ------------------------------------------------------------

    typedef enum logic [3:0] {
        IDLE,
        PREAMBLE,
        SFD,
        DEST,
        SRC,
        TYPE,
        PAYLOAD,
        PAD,
        FCS
    } state_t;

    state_t state;

    // ------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------

    logic [47:0] dest_mac_reg;
    logic [47:0] src_mac_reg;
    logic [15:0] ethertype_reg;

    logic [15:0] payload_len_reg;
    logic [15:0] payload_count;
    logic [15:0] pad_count;

    logic [2:0]  preamble_count;
    logic [2:0]  mac_count;
    logic [1:0]  type_count;
    logic [1:0]  fcs_count;

    logic [31:0] crc_value;

    // CRC control
    logic        crc_init;
    logic        crc_enable;

    // ------------------------------------------------------------
    // CRC-32 module
    // ------------------------------------------------------------

    crc32 crc_inst (
        .clk     (clk),
        .rst     (rst),
        .init    (crc_init),
        .enable  (crc_enable),
        .data_in (tx_byte),
        .crc_out (crc_value)
    );

    // ------------------------------------------------------------
    // CRC control
    //
    // CRC is calculated over:
    // Destination MAC
    // Source MAC
    // EtherType
    // Payload
    // Padding
    //
    // NOT over preamble or SFD.
    // ------------------------------------------------------------

    always_comb begin
        crc_init   = 1'b0;
        crc_enable = 1'b0;

        case (state)

            DEST,
            SRC,
            TYPE,
            PAYLOAD,
            PAD: begin
                crc_enable = tx_valid;
            end

            default: begin
                crc_enable = 1'b0;
            end

        endcase

        // Initialize CRC when frame starts
        if (state == PREAMBLE && preamble_count == 3'd0)
            crc_init = 1'b1;
    end

    // ------------------------------------------------------------
    // TX output logic
    // ------------------------------------------------------------

    always_comb begin

        tx_byte        = 8'h00;
        tx_valid       = 1'b0;
        tx_last        = 1'b0;
        tx_data_ready  = 1'b0;

        case (state)

            // ----------------------------------------------------
            // PREAMBLE
            // ----------------------------------------------------

            PREAMBLE: begin
                tx_byte  = 8'hAA;
                tx_valid = 1'b1;
            end

            // ----------------------------------------------------
            // Start Frame Delimiter
            // ----------------------------------------------------

            SFD: begin
                tx_byte  = 8'hAB;
                tx_valid = 1'b1;
            end

            // ----------------------------------------------------
            // Destination MAC
            // ----------------------------------------------------

            DEST: begin
                tx_valid = 1'b1;

                case (mac_count)
                    3'd0: tx_byte = dest_mac_reg[47:40];
                    3'd1: tx_byte = dest_mac_reg[39:32];
                    3'd2: tx_byte = dest_mac_reg[31:24];
                    3'd3: tx_byte = dest_mac_reg[23:16];
                    3'd4: tx_byte = dest_mac_reg[15:8];
                    3'd5: tx_byte = dest_mac_reg[7:0];
                    default: tx_byte = 8'h00;
                endcase
            end

            // ----------------------------------------------------
            // Source MAC
            // ----------------------------------------------------

            SRC: begin
                tx_valid = 1'b1;

                case (mac_count)
                    3'd0: tx_byte = src_mac_reg[47:40];
                    3'd1: tx_byte = src_mac_reg[39:32];
                    3'd2: tx_byte = src_mac_reg[31:24];
                    3'd3: tx_byte = src_mac_reg[23:16];
                    3'd4: tx_byte = src_mac_reg[15:8];
                    3'd5: tx_byte = src_mac_reg[7:0];
                    default: tx_byte = 8'h00;
                endcase
            end

            // ----------------------------------------------------
            // EtherType
            // ----------------------------------------------------

            TYPE: begin
                tx_valid = 1'b1;

                case (type_count)
                    2'd0: tx_byte = ethertype_reg[15:8];
                    2'd1: tx_byte = ethertype_reg[7:0];
                    default: tx_byte = 8'h00;
                endcase
            end

            // ----------------------------------------------------
            // Payload
            // ----------------------------------------------------

            PAYLOAD: begin
                tx_data_ready = 1'b1;

                if (tx_data_valid) begin
                    tx_byte  = tx_data;
                    tx_valid = 1'b1;
                end
            end

            // ----------------------------------------------------
            // Padding
            // ----------------------------------------------------

            PAD: begin
                tx_byte  = 8'h00;
                tx_valid = 1'b1;
            end

            // ----------------------------------------------------
            // FCS
            //
            // Ethernet transmits CRC least-significant byte first.
            // ----------------------------------------------------

            FCS: begin
                tx_valid = 1'b1;

                case (fcs_count)
                    2'd0: tx_byte = crc_value[7:0];
                    2'd1: tx_byte = crc_value[15:8];
                    2'd2: tx_byte = crc_value[23:16];
                    2'd3: begin
                        tx_byte = crc_value[31:24];
                        tx_last = 1'b1;
                    end
                    default: tx_byte = 8'h00;
                endcase
            end

            default: begin
                tx_byte = 8'h00;
            end

        endcase
    end

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            state          <= IDLE;

            dest_mac_reg   <= 48'h0;
            src_mac_reg    <= 48'h0;
            ethertype_reg  <= 16'h0;

            payload_len_reg <= 16'h0;
            payload_count   <= 16'h0;
            pad_count       <= 16'h0;

            preamble_count <= 3'd0;
            mac_count      <= 3'd0;
            type_count     <= 2'd0;
            fcs_count      <= 2'd0;

            tx_busy        <= 1'b0;
            tx_done        <= 1'b0;

        end
        else begin

            // Default
            tx_done <= 1'b0;

            case (state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                IDLE: begin

                    tx_busy <= 1'b0;

                    if (tx_start) begin

                        dest_mac_reg  <= dest_mac;
                        src_mac_reg   <= src_mac;
                        ethertype_reg <= ethertype;

                        payload_len_reg <= payload_len;

                        payload_count <= 16'd0;
                        pad_count     <= 16'd0;

                        preamble_count <= 3'd0;
                        mac_count      <= 3'd0;
                        type_count     <= 2'd0;
                        fcs_count      <= 2'd0;

                        tx_busy <= 1'b1;

                        state <= PREAMBLE;

                    end
                end

                // ------------------------------------------------
                // PREAMBLE
                // ------------------------------------------------

                PREAMBLE: begin

                    if (preamble_count == 3'd6) begin
                        preamble_count <= 3'd0;
                        state <= SFD;
                    end
                    else begin
                        preamble_count <= preamble_count + 1'b1;
                    end

                end

                // ------------------------------------------------
                // SFD
                // ------------------------------------------------

                SFD: begin
                    mac_count <= 3'd0;
                    state <= DEST;
                end

                // ------------------------------------------------
                // DESTINATION MAC
                // ------------------------------------------------

                DEST: begin

                    if (mac_count == 3'd5) begin
                        mac_count <= 3'd0;
                        state <= SRC;
                    end
                    else begin
                        mac_count <= mac_count + 1'b1;
                    end

                end

                // ------------------------------------------------
                // SOURCE MAC
                // ------------------------------------------------

                SRC: begin

                    if (mac_count == 3'd5) begin
                        mac_count  <= 3'd0;
                        type_count <= 2'd0;
                        state <= TYPE;
                    end
                    else begin
                        mac_count <= mac_count + 1'b1;
                    end

                end

                // ------------------------------------------------
                // ETHERTYPE
                // ------------------------------------------------

                TYPE: begin

                    if (type_count == 2'd1) begin

                        payload_count <= 16'd0;

                        // If payload is already at least 46 bytes,
                        // receive it directly.
                        if (payload_len_reg >= 16'd46) begin
                            state <= PAYLOAD;
                        end

                        // Otherwise receive payload first and
                        // then add padding.
                        else begin
                            state <= PAYLOAD;
                        end

                    end
                    else begin
                        type_count <= type_count + 1'b1;
                    end

                end

                // ------------------------------------------------
                // PAYLOAD
                // ------------------------------------------------

                PAYLOAD: begin

                    if (tx_data_valid && tx_data_ready) begin

                        payload_count <= payload_count + 1'b1;

                        if (payload_count + 1 >= payload_len_reg) begin

                            // Payload complete

                            if (payload_len_reg < 16'd46) begin

                                pad_count <= 16'd0;
                                state <= PAD;

                            end
                            else begin

                                fcs_count <= 2'd0;
                                state <= FCS;

                            end

                        end

                    end

                end

                // ------------------------------------------------
                // PADDING
                // ------------------------------------------------

                PAD: begin

                    if (pad_count == (16'd45 - payload_len_reg)) begin

                        fcs_count <= 2'd0;
                        state <= FCS;

                    end
                    else begin
                        pad_count <= pad_count + 1'b1;
                    end

                end

                // ------------------------------------------------
                // FCS
                // ------------------------------------------------

                FCS: begin

                    if (fcs_count == 2'd3) begin

                        state <= IDLE;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;

                    end
                    else begin
                        fcs_count <= fcs_count + 1'b1;
                    end

                end

                default: begin
                    state <= IDLE;
                end

            endcase

        end
    end

endmodule