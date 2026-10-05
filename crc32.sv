module crc32 (
    input  logic        clk,
    input  logic        rst,
    input  logic        init,
    input  logic        enable,
    input  logic [7:0]  data_in,
    output logic [31:0] crc_out
);

    logic [31:0] crc_reg;
    logic [31:0] crc_next;

    integer i;

    always_comb begin
        crc_next = crc_reg ^ {24'b0, data_in};

        for (i = 0; i < 8; i = i + 1) begin
            if (crc_next[0])
                crc_next = (crc_next >> 1) ^ 32'hEDB88320;
            else
                crc_next = crc_next >> 1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst)
            crc_reg <= 32'hFFFFFFFF;
        else if (init)
            crc_reg <= 32'hFFFFFFFF;
        else if (enable)
            crc_reg <= crc_next;
    end

    assign crc_out = ~crc_reg;

endmodule