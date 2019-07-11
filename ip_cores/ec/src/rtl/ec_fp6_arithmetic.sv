/*
  This provides the interface to perform
  Fp^6 point logic (adding, subtracting, multiplication), over a Fp2 tower.
  Fq6 is constructed as Fq2(v) / (v3 - ξ) where ξ = u + 1


  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

module ec_fe6_arithmetic
#(
  parameter type FE2_TYPE,
  parameter type FE6_TYPE,
  parameter CTL_BIT = 8        // From this bit 2 bits are used for internal control, 2 bits for resource sharing
)(
  input i_clk, i_rst,
  // Interface to FE2_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe2_if,
  if_axi_stream.sink   i_mul_fe2_if,
  // Interface to FE2_TYPE adder (mod P)
  if_axi_stream.source o_add_fe2_if,
  if_axi_stream.sink   i_add_fe2_if,
  // Interface to FE2_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe2_if,
  if_axi_stream.sink   i_sub_fe2_if,
  // Interface to FE6_TYPE multiplier (mod P)
  if_axi_stream.source o_mul_fe6_if,
  if_axi_stream.sink   i_mul_fe6_if,
  // Interface to FE6_TYPE adder (mod P)
  if_axi_stream.source o_add_fe6_if,
  if_axi_stream.sink   i_add_fe6_if,
  // Interface to FE6_TYPE subtractor (mod P)
  if_axi_stream.source o_sub_fe6_if,
  if_axi_stream.sink   i_sub_fe6_if
);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BIT+4))   add_if_fe2_i [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BIT+4)) add_if_fe2_o [1:0] (i_clk);

if_axi_stream #(.DAT_BITS($bits(FE_TYPE)), .CTL_BITS(CTL_BIT+4))   sub_if_fe2_i [1:0] (i_clk);
if_axi_stream #(.DAT_BITS(2*$bits(FE_TYPE)), .CTL_BITS(CTL_BIT+4)) sub_if_fe2_o [1:0] (i_clk);


// Point addtions are simple additions on each of the Fp2 elements
logic [1:0] add_cnt;
always_comb begin
  i_add_fe6_if.rdy = (add_cnt == 2) && (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy));
  add_if_fe2_i[0].rdy = ~o_add_fe6_if.val || (o_add_fe6_if.val && o_add_fe6_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_add_fe6_if.reset_source();
    add_cnt <= 0;
    add_if_fe2_o[0].reset_source();
  end else begin

    if (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy) add_if_fe2_o[0].val <= 0;
    if (o_add_fe6_if.val && o_add_fe6_if.rdy) o_add_fe6_if.val <= 0;

    // One process to parse inputs and send them to the adder
    case(add_cnt)
      0: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                                   i_add_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)]},
                                   i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[CTL_BIT] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 1;
        end
      end
      1: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_add_fe6_if.dat[$bits(FE6_TYPE)+$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[CTL_BIT] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 2;
        end
      end
      2: begin
        if (~add_if_fe2_o[0].val || (add_if_fe2_o[0].val && add_if_fe2_o[0].rdy)) begin
          add_if_fe2_o[0].copy_if({i_add_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_add_fe6_if.dat[$bits(FE6_TYPE)+2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_add_fe6_if.val, 1, 1, i_add_fe6_if.err, i_add_fe6_if.mod, i_add_fe6_if.ctl);
          add_if_fe2_o[0].ctl[CTL_BIT] <= add_cnt;
          if (i_add_fe6_if.val) add_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_add_fe6_if.val || (o_add_fe6_if.val && o_add_fe6_if.rdy)) begin
      o_add_fe6_if.ctl <= add_if_fe2_i[0].ctl;
      if (add_if_fe2_i[0].ctl[CTL_BIT] == 0) begin
        if (add_if_fe2_i[0].val)
          o_add_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
      end else if (add_if_fe2_i[0].ctl[CTL_BIT] == 1) begin
        if (add_if_fe2_i[0].val)
          o_add_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
      end else begin
        o_add_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= add_if_fe2_i[0].dat;
        o_add_fe6_if.val <= add_if_fe2_i[0].val;
      end
    end
  end
end

// Point subtractions are simple subtractions on each of the Fp2 elements
logic [1:0] sub_cnt;
always_comb begin
  i_sub_fe6_if.rdy = (sub_cnt == 2) && (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy));
  sub_if_fe2_i[0].rdy = ~o_sub_fe6_if.val || (o_sub_fe6_if.val && o_sub_fe6_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    o_sub_fe6_if.reset_source();
    sub_cnt <= 0;
    sub_if_fe2_o[0].reset_source();
  end else begin

    if (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy) sub_if_fe2_o[0].val <= 0;
    if (o_sub_fe6_if.val && o_sub_fe6_if.rdy) o_sub_fe6_if.val <= 0;

    // One process to parse inputs and send them to the adder
    case(sub_cnt)
      0: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[0 +: $bits(FE2_TYPE)],
                                   i_sub_fe6_if.dat[$bits(FE6_TYPE) +: $bits(FE2_TYPE)]},
                                   i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[CTL_BIT] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 1;
        end
      end
      1: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_sub_fe6_if.dat[$bits(FE6_TYPE)+$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[CTL_BIT] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 2;
        end
      end
      2: begin
        if (~sub_if_fe2_o[0].val || (sub_if_fe2_o[0].val && sub_if_fe2_o[0].rdy)) begin
          sub_if_fe2_o[0].copy_if({i_sub_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)],
                                i_sub_fe6_if.dat[$bits(FE6_TYPE)+2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)]},
                                i_sub_fe6_if.val, 1, 1, i_sub_fe6_if.err, i_sub_fe6_if.mod, i_sub_fe6_if.ctl);
          sub_if_fe2_o[0].ctl[CTL_BIT] <= sub_cnt;
          if (i_sub_fe6_if.val) sub_cnt <= 0;
        end
      end
    endcase

    // One process to assign outputs
    if (~o_sub_fe6_if.val || (o_sub_fe6_if.val && o_sub_fe6_if.rdy)) begin
      o_sub_fe6_if.ctl <= sub_if_fe2_i[0].ctl;
      if (sub_if_fe2_i[0].ctl[CTL_BIT] == 0) begin
        if (sub_if_fe2_i[0].val)
          o_sub_fe6_if.dat[0 +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
      end else if (sub_if_fe2_i[0].ctl[CTL_BIT] == 1) begin
        if (sub_if_fe2_i[0].val)
          o_sub_fe6_if.dat[$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
      end else begin
        o_sub_fe6_if.dat[2*$bits(FE2_TYPE) +: $bits(FE2_TYPE)] <= sub_if_fe2_i[0].dat;
        o_sub_fe6_if.val <= sub_if_fe2_i[0].val;
      end
    end
  end
end

// Multiplications are calculated using the formula in bls12_381.pkg::fe6_mul()
logic [2:0] mul_cnt;
logic [1:0] add_sub_val;
always_comb begin
  i_mul_fe2_if.rdy = (fp_mode_mul || mul_state == MUL3) && (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy));

  i_mul_fe_if.rdy = fp_mode_mul ? ~o_mul_fe2_if.val ||  (o_mul_fe2_if.val && o_mul_fe2_if.rdy) :
                  (i_mul_fe_if.ctl[CTL_BIT +: 2] == 0 || i_mul_fe_if.ctl[CTL_BIT +: 2] == 1) ?
                  (~sub_if_fe_o[1].val || (sub_if_fe_o[1].val && sub_if_fe_o[1].rdy)) :
                  (~add_if_fe_o[1].val || (add_if_fe_o[1].val && add_if_fe_o[1].rdy));

  o_mul_fe2_if.val = &add_sub_val;
  sub_if_fe_i[1].rdy = ~add_sub_val[1] || (o_mul_fe2_if.val && o_mul_fe2_if.rdy);
  add_if_fe_i[1].rdy = ~add_sub_val[0] || (o_mul_fe2_if.val && o_mul_fe2_if.rdy);
end

always_ff @ (posedge i_clk) begin
  if (i_rst) begin
    add_sub_val <= 0;
    o_mul_fe2_if.sop <= 1;
    o_mul_fe2_if.eop <= 1;
    o_mul_fe2_if.err <= 0;
    o_mul_fe2_if.ctl <= 0;
    o_mul_fe2_if.dat <= 0;
    o_mul_fe2_if.mod <= 0;
    mul_state <= MUL0;
    o_mul_fe_if.reset_source();
    sub_if_fe_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    add_if_fe_o[1].copy_if(0, 0, 1, 1, 0, 0, 0);
    fp_mode_mul <= 0;
  end else begin

    fp_mode_mul <= i_fp_mode;

    if (o_mul_fe2_if.val && o_mul_fe2_if.rdy) begin
      add_sub_val <= 0;
    end
    if (o_mul_fe_if.val && o_mul_fe_if.rdy) o_mul_fe_if.val <= 0;
    if (sub_if_fe_o[1].val && sub_if_fe_o[1].rdy) sub_if_fe_o[1].val <= 0;
    if (add_if_fe_o[1].val && add_if_fe_o[1].rdy) add_if_fe_o[1].val <= 0;

    // One process to parse inputs and send them to the multiplier
    if (~o_mul_fe_if.val || (o_mul_fe_if.val && o_mul_fe_if.rdy)) begin
      case (mul_state)
        MUL0: begin
          o_mul_fe_if.copy_if({i_mul_fe2_if.dat[0 +: $bits(FE_TYPE)],
                            i_mul_fe2_if.dat[$bits(FE2_TYPE)  +: $bits(FE_TYPE)]},
                            i_mul_fe2_if.val, 1, 1, i_mul_fe2_if.err, i_mul_fe2_if.mod, i_mul_fe2_if.ctl);
          o_mul_fe_if.ctl[CTL_BIT +: 2] <= 0;
          if (i_mul_fe2_if.val && ~fp_mode_mul) mul_state <= MUL1;
        end
        MUL1: begin
          o_mul_fe_if.copy_if({i_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                            i_mul_fe2_if.dat[$bits(FE2_TYPE) + $bits(FE_TYPE) +: $bits(FE_TYPE)]},
                            i_mul_fe2_if.val, 1, 1, i_mul_fe2_if.err, i_mul_fe2_if.mod, i_mul_fe2_if.ctl);
          o_mul_fe_if.ctl[CTL_BIT +: 2] <= 1;
          if (i_mul_fe2_if.val) mul_state <= MUL2;
        end
        MUL2: begin
          o_mul_fe_if.copy_if({i_mul_fe2_if.dat[0 +: $bits(FE_TYPE)],
                            i_mul_fe2_if.dat[$bits(FE2_TYPE) + $bits(FE_TYPE) +: $bits(FE_TYPE)]},
                            i_mul_fe2_if.val, 1, 1, i_mul_fe2_if.err, i_mul_fe2_if.mod, i_mul_fe2_if.ctl);
          o_mul_fe_if.ctl[CTL_BIT +: 2] <= 2;
          if (i_mul_fe2_if.val) mul_state <= MUL3;
        end
        MUL3: begin
          o_mul_fe_if.copy_if({i_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)],
                            i_mul_fe2_if.dat[$bits(FE2_TYPE)  +: $bits(FE_TYPE)]},
                            i_mul_fe2_if.val, 1, 1, i_mul_fe2_if.err, i_mul_fe2_if.mod, i_mul_fe2_if.ctl);
          o_mul_fe_if.ctl[CTL_BIT +: 2] <= 3;
          if (i_mul_fe2_if.val) mul_state <= MUL0;
        end
      endcase
    end

    // Process multiplications and do subtraction
    if (~fp_mode_mul && (~sub_if_fe_o[1].val || (sub_if_fe_o[1].val && sub_if_fe_o[1].rdy))) begin
      if (i_mul_fe_if.ctl[CTL_BIT +: 2] == 0) begin
        if (i_mul_fe_if.val) sub_if_fe_o[1].dat[0 +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
      end
      if (i_mul_fe_if.ctl[CTL_BIT +: 2] == 1) begin
        sub_if_fe_o[1].val <= i_mul_fe_if.val;
        sub_if_fe_o[1].dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
      end
      sub_if_fe_o[1].ctl <= i_mul_fe_if.ctl;
    end

    // Process multiplications and do addition
    if (~fp_mode_mul && (~add_if_fe_o[1].val || (add_if_fe_o[1].val && add_if_fe_o[1].rdy))) begin
      if (i_mul_fe_if.ctl[CTL_BIT +: 2] == 2) begin
        if (i_mul_fe_if.val) add_if_fe_o[1].dat[0 +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
      end
      if (i_mul_fe_if.ctl[CTL_BIT +: 2] == 3) begin
        add_if_fe_o[1].val <= i_mul_fe_if.val;
        add_if_fe_o[1].dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
      end
      add_if_fe_o[1].ctl <= i_mul_fe_if.ctl;
    end

    // One process to assign output
    // If we are in fp_mode
    if (fp_mode_mul) begin
      if (~add_sub_val[0] || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
        o_mul_fe2_if.dat[0 +: $bits(FE_TYPE)] <= i_mul_fe_if.dat;
        o_mul_fe2_if.ctl <= i_mul_fe_if.ctl;
        add_sub_val <= {2{i_mul_fe_if.val}};
      end
    end else begin
      if (~add_sub_val[0] || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
        o_mul_fe2_if.ctl <= add_if_fe_i[1].ctl;
        o_mul_fe2_if.dat[$bits(FE_TYPE) +: $bits(FE_TYPE)] <= add_if_fe_i[1].dat;
        add_sub_val[0] <= add_if_fe_i[1].val;
      end

      if (~add_sub_val[1] || (o_mul_fe2_if.val && o_mul_fe2_if.rdy)) begin
          o_mul_fe2_if.dat[0 +: $bits(FE_TYPE)] <= sub_if_fe_i[1].dat;
          add_sub_val[1] <= sub_if_fe_i[1].val;
      end
    end
  end
end

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BIT+4         ),
  .OVR_WRT_BIT  ( CTL_BIT+2         ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_sub (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( sub_if_fe_o[1:0] ),
  .o_res ( o_sub_fe_if ),
  .i_res ( i_sub_fe_if ),
  .o_axi ( sub_if_fe_i[1:0] )
);

resource_share # (
  .NUM_IN       ( 2                 ),
  .DAT_BITS     ( 2*$bits(FE2_TYPE) ),
  .CTL_BITS     ( CTL_BIT+4         ),
  .OVR_WRT_BIT  ( CTL_BIT+2         ),
  .PIPELINE_IN  ( 0                 ),
  .PIPELINE_OUT ( 0                 )
)
resource_share_add (
  .i_clk ( i_clk ),
  .i_rst ( i_rst ),
  .i_axi ( add_if_fe2_o[1:0] ),
  .o_res ( o_add_fe2_if      ),
  .i_res ( i_add_fe2_if      ),
  .o_axi ( add_if_fe2_i[1:0] )
);

endmodule