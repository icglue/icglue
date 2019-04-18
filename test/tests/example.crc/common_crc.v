// ------------------------------------------------------------
// Author            :   neumaerker
// E-Mail            :   felix.neumaerker@tu-dresden.de
//
// Notes             :   CRC-Logic Module.
//                       Polynom representation is in normalform,
//                       this means the highest degree is omitted
//                       and bit-position matches degree.
//
//                       The DATA_W specifies the datainput width,
//                       which is related to the unroll-depth.
//                       E.g. CRC-8
//                       (https://en.wikipedia.org/wiki/Polynomial_representations_of_cyclic_redundancy_checks)
//                         r(x)    = x^8 + x^7 + x^6 + x^4 + x^2 + 1
//                         CRC_W   = 8;
//                         POLYNOM = 8'b11010101; // 8'hd5
//
// ------------------------------------------------------------

module common_crc (
        crc_i,
        data_i,
        crc_o
    );

    parameter DATA_W   = 8;
    parameter CRC_W    = 8;
    parameter POLYNOM  = 8'hd5;
    parameter FEED_LSB = 0; // Start with the LSB and go upto MSB

    input  [DATA_W-1:0] data_i;
    input   [CRC_W-1:0] crc_i;
    output  [CRC_W-1:0] crc_o;

    wire  [CRC_W-1:0] tap[DATA_W:0];
    wire [DATA_W-1:0] feedback;

    assign tap[0] = crc_i;

    genvar i_unroll;
    genvar i_order;
    generate for (i_unroll = 0; i_unroll < DATA_W; i_unroll = i_unroll + 1) begin: gen_unroll
        assign feedback[i_unroll] = tap[i_unroll][CRC_W-1] ^ (FEED_LSB ? data_i[i_unroll] : data_i[DATA_W-1-i_unroll]);
        assign tap[i_unroll+1][0] = feedback[i_unroll];

        for (i_order = 1; i_order < CRC_W; i_order = i_order + 1) begin: gen_crc_step
            if (POLYNOM[i_order] == 1'b1) begin: gen_bit_set
                assign tap[i_unroll+1][i_order] = tap[i_unroll][i_order-1] ^ feedback[i_unroll];
            end else begin: gen_bit_skip
                assign tap[i_unroll+1][i_order] = tap[i_unroll][i_order-1];
            end
        end

    end
    endgenerate

    assign crc_o = tap[DATA_W];

endmodule

