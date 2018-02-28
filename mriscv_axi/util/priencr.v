module priencr #(parameter width = 64)
  (
   input [width-1:0] decode,
   output [log2(width)-1:0] encode,
   output valid
   );

  function [31:0] log2;
    input reg [31:0] value;
    begin
      value = value-1;
      for (log2=0; value>0; log2=log2+1)
	value = value>>1;
    end
  endfunction

  generate
    if (width == 2)
      begin
	assign valid = |decode;
	assign encode = decode[1];
      end
    else if (width & (width-1))
      priencr #(1<<log2(width)) priencr ({1<<log2(width) {1'b0}} | decode,
                                         encode,valid);
    else
      begin
	wire [log2(width)-2:0] encode_low;
	wire [log2(width)-2:0] encode_high;
	wire valid_low, valid_high;
	priencr #(width>>1) low(decode[(width>>1)-1:0],encode_low,valid_low);
	priencr #(width>>1) high(decode[width-1:width>>1],encode_high,valid_high);
	assign valid = valid_low | valid_high;
	assign encode = valid_high ? {1'b1,encode_high} : {1'b0,encode_low};
      end
  endgenerate
endmodule