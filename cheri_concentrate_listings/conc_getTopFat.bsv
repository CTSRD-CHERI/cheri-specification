function CapAddrPlus1 getTopFat(CapFat cap, TempFields tf);
  // First, construct a full length value with the top bits and the
  // correction bits above, and shift that value to the appropriate spot.
  CapAddrPlus1 addTop = signExtend({pack(tf.topCorrection), cap.bounds.topBits}) << cap.bounds.exp;
  // Build a mask on the high bits of a full length value to extract the high
  // bits of the address.
  Bit#(TSub#(TAdd#(CapAddrW,1),MW)) mask = ~0 << cap.bounds.exp;
  // Extract the high bits of the address (and append the implied zeros at the
  // bottom), and add with the previously prepared value.
  CapAddrPlus1 ret = {truncateLSB({1'b0,cap.address})&mask,0} + addTop;
  // If the bottom and top are more than an address space away from eachother,
  // invert the 64th/32nd bit of Top.  This corrects for errors that happen
  // when the representable space wraps the address space.
  Bit#(2) topTip = truncateLSB(ret);
  // Calculate the msb of the base.
  // First assume that only the address and correction are involved...
  Bit#(TSub#(CapAddrW,MW)) bot = truncateLSB(cap.address) + (signExtend(pack(tf.baseCorrection)) << cap.bounds.exp);
  Bit#(2) botTip = {1'b0, msb(bot)};
  // If the bit we're interested in are actually coming from baseBits, select
  // the correct one from there.
  // exp == (resetExp - 1) doesn't matter since we will not flip unless
  // exp < resetExp-1.
  if (cap.bounds.exp == (resetExp - 2)) botTip = {1'b0, cap.bounds.baseBits[valueOf(MW)-1]};
  // Do the final check.
  // If exp >= resetExp - 1, the bits we're looking at are coming directly from
  // topBits and baseBits, are not being inferred, and therefore do not need
  // correction. If we are below this range, check that the difference between
  // the resulting top and bottom is less than one address space.  If not, flip
  // the msb of the top.
  if (cap.bounds.exp<(resetExp-1) && (topTip - botTip) > 1)
    ret[valueOf(CapAddrW)] = ~ret[valueOf(CapAddrW)];
  return ret;
endfunction
