function VnD#(CapFat) incOffsetFat( CapFat cap
                                  , CapAddr pointer
                                  , CapAddr offset // this is the increment in inc offset, and the offset in set offset
                                  , TempFields tf
                                  , Bool setOffset);
// NOTE:
// The 'offset' argument is the "increment" value when setOffset is false, and
// the actual "offset" value when setOffset is true.
//
// For this function to work correctly, we must have
// 'offset' = 'pointer'-'cap.address'.
// In the most critical case we have both available and picking one or the
// other is less efficient than passing both.  If the 'setOffset' flag is set,
// this function will ignore the 'pointer' argument and use 'offset' to set the
// offset of 'cap' by adding it to the capability base. If the 'setOffset' flag
// is not set, this function will increment the offset of 'cap' by replacing
// the 'cap.address' field with the 'pointer' argument (with the assumption
// that the 'pointer' argument is indeed equal to 'cap.address'+'offset'.  The
// 'cap.addrBits' field is also updated accordingly.
  CapFat ret = cap;
  Exp e = cap.bounds.exp;
  // Updating the address of a capability requires checking that the new
  // address is still within representable bounds. For capabilities with big
  // representable regions (with exponents >= resetExp-2), there is no
  // representability issue.
  // For the other capabilities, the check consists of two steps:
  // - A "inRange" test
  // - A "inLimits" test

  // The inRange test
  // ----------------
  // Conceptually, the inRange test checks the magnitude of 'offset' is less
  // then the representable region's size S. This ensures that the inLimits
  // test result is meaningful. The test succeeds if the absolute value of
  // 'offset' is less than S, that is -S < 'offset' < S. This test reduces to a
  // check that there are no significant bits in the high bits of 'offset',
  // that is they are all ones or all zeros.
  CapAddr offsetAddr = offset;
  Bit#(TSub#(CapAddrW,MW)) signBits       = signExtend(offset[valueOf(TSub#(CapAddrW,1))]);
  Bit#(TSub#(CapAddrW,MW)) highOffsetBits = truncateLSB(offsetAddr);
  Bit#(TSub#(CapAddrW,MW)) highBitsfilter = -1 << e;
  highOffsetBits = (highOffsetBits ^ signBits) & highBitsfilter;
  Bool inRange = (highOffsetBits == 0);

  // The inLimits test
  // -----------------
  // Conceptually, the inLimits test ensures that neither the of the edges of
  // the representable region have been crossed with the new address. In
  // essence, it compares the distance 'offsetBits' added (on MW bits) with the
  // distance 'toBounds' to the edge of the representable space (on MW bits).
  // - For a positive or null increment
  //   inLimits = offsetBits < toBounds - 1
  // - For a negative increment:
  //   inLimits = (offsetBits >= toBounds) and ('we were not already on the
  //   bottom edge') (when already on the bottom edge of the representable
  //   space, the relevant bits of the address and those of the representable
  //   edge are the same, leading to a false positive on the i >= toBounds
  //   comparison)

  // The sign of the increment
  Bool posInc = msb(offsetAddr) == 1'b0;

  // The offsetBits value corresponds to the appropriate slice of the
  // 'offsetAddr' argument
  Bit#(MW) offsetBits  = truncate(offsetAddr >> e);

  // The toBounds value is given by substracting the address of the capability
  // from the address of the edge of the representable region (on MW bits) when
  // the 'setOffset' flag is not set. When it is set, it is given by
  // substracting the base address of the capability from the edge of the
  // representable region (on MW bits).  This value is both the distance to the
  // representable top and the distance to the representable bottom (when
  // appended to a one for negative sign), a convenience of the two's
  // complement representation.

  // NOTE: When the setOffset flag is set, toBounds should be the distance from
  // the base to the representable edge. This can be computed efficiently, and
  // without relying on the temporary fields, as follows: equivalent to
  // (repBoundBits - cap.bounds.baseBits):
  Bit#(MW) toBounds_A   = {3'b111,0} - {3'b000,truncate(cap.bounds.baseBits)};
  // equivalent to (repBoundBits - cap.bounds.baseBits - 1):
  Bit#(MW) toBoundsM1_A = {3'b110,~truncate(cap.bounds.baseBits)};
  /*
  XXX not sure if we still care about that
  if (toBoundsM1_A != (toBounds_A-1)) $display("error %x", toBounds_A[15:13]);
  */
  // When the setOffset flag is not set, we need to use the temporary fields
  // with the upper bits of the representable bounds
  Bit#(MW) repBoundBits = {tf.repBoundTopBits,0};
  Bit#(MW) toBounds_B   = repBoundBits - cap.addrBits;
  Bit#(MW) toBoundsM1_B = repBoundBits + ~cap.addrBits;
  // Select the appropriate toBounds value
  Bit#(MW) toBounds   = setOffset ? toBounds_A   : toBounds_B;
  Bit#(MW) toBoundsM1 = setOffset ? toBoundsM1_A : toBoundsM1_B;
  Bool addrAtRepBound = !setOffset && (repBoundBits == cap.addrBits);

  // Implement the inLimit test
  Bool inLimits = False;
  if (posInc) begin
    // For a positive or null increment
    // SetOffset is offsetting against base, which has 0 in the lower bits, so
    // we don't need to be conservative.
    inLimits = setOffset ? offsetBits <= toBoundsM1
                         : offsetBits <  toBoundsM1;
  end else begin
    // For a negative increment
    inLimits = (offsetBits >= toBounds) && !addrAtRepBound;
  end

  // Complete representable bounds check
  // -----------------------------------
  Bool inBounds = (inRange && inLimits) || (e >= (resetExp - 2));

  // Updating the return capability
  // ------------------------------
  if (setOffset) begin
    // Get the base and add the offsetAddr. This could be slow, but seems to
    // pass timing.
    ret.address = getBotFat(cap,tf) + offsetAddr;
    // Work out the slice of the address we are interested in using MW-bit
    // arithmetics.
    Bit#(MW) newAddrBits = cap.bounds.baseBits + offsetBits;
    // Ensure the bits of the address slice past the top of the address space
    // are zero
    Bit#(2) mask = (e == resetExp) ? 2'b00 : (e == resetExp-1) ? 2'b01 : 2'b11;
    ret.addrBits = {mask, ~0} & newAddrBits;
  end else begin
    // In the incOffset case, the 'pointer' argument already contains the new
    // address
    ret.address  = pointer;
    ret.addrBits = truncate(ret.address >> e);
  end
  // Nullify the capability if the representable bounds check has failed
  if (!inBounds) ret.isCapability = False;

  // return updated / invalid capability
  return VnD {v: inBounds, d: ret};
endfunction
