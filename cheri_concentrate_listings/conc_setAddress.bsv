function VnD#(CapFat) setAddress(CapFat cap, CapAddr address, TempFields tf);
  CapFat ret = setCapPointer(cap, address);
  Exp e = cap.bounds.exp;
  // Calculate what the difference in the upper bits of the new and original addresses must be if
  // the new address is within representable bounds.
  Bool newAddrHi  = truncateLSB(ret.addrBits) < tf.repBoundTopBits;
  Bit#(TSub#(CapAddrW,MW)) deltaAddrHi = signExtend({1'b0,pack(newAddrHi)} - {1'b0,pack(tf.addrHi)}) << e;
  // Calculate the actual difference between the upper bits of the new address and the original address.
  Bit#(TSub#(CapAddrW,MW)) mask = -1 << e;
  Bit#(TSub#(CapAddrW,MW)) deltaAddrUpper = (truncateLSB(address)&mask) - (truncateLSB(cap.address)&mask);
  Bool inRepBounds = deltaAddrHi == deltaAddrUpper;
  if (!inRepBounds) ret.isCapability = False;
  return VnD {v: inRepBounds, d: ret};
endfunction
