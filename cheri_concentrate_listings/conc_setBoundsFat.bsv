function SetBoundsReturn#(CapFat, CapAddrW) setBoundsFat(CapFat cap, Address lengthFull);
  CapFat ret = cap;
  // Find new exponent by finding the index of the most significant bit of the
  // length, or counting leading zeros in the high bits of the length, and
  // substracting them to the CapAddr width (taking away the bottom MW-1 bits:
  // trim (MW-1) bits from the bottom of length since any length with a
  // significance that small will yield an exponent of zero).
  CapAddr length = truncate(lengthFull);
  Bit#(TSub#(CapAddrW,TSub#(MW,1))) lengthMSBs = truncateLSB(length);
  Exp zeros = zeroExtend(countZerosMSB(lengthMSBs));
  // Adjust resetExp by one since it's scale reaches 1-bit greater than a
  // 64-bit length can express.
  Bool maxZero = (zeros==(resetExp-1));
  Bool intExp = !(maxZero && length[fromInteger(valueOf(TSub#(MW,2)))]==1'b0);
  // Do this without subtraction
  //fromInteger(valueof(TSub#(SizeOf#(Address),TSub#(MW,1)))) - zeros;
  Exp e = (resetExp-1) - zeros;
  // Derive new base bits by extracting MW bits from the capability address
  // starting at the new exponent's position.
  CapAddrPlus2 base = {2'b0, cap.address};
  Bit#(TAdd#(MW,1)) newBaseBits = truncate(base>>e);

  // Derive new top bits by extracting MW bits from the capability address +
  // requested length, starting at the new exponent's position, and rounding up
  // if significant bits are lost in the process.
  CapAddrPlus2 len = {2'b0, length};
  CapAddrPlus2 top = base + len;

  // Create a mask with all bits set below the MSB of length and then masking
  // all bits below the mantissa bits.
  CapAddrPlus2 lmask = smearMSBRight(len);
  // The shift amount required to put the most significant set bit of the len
  // just above the bottom HalfExpW bits that are taken by the exp.
  Integer shiftAmount = valueOf(TSub#(TSub#(MW,2),HalfExpW));

  // Calculate all values associated with E=e (e not rounding up)
  // Round up considering the stolen HalfExpW exponent bits if required
  Bit#(TAdd#(MW,1)) newTopBits = truncate(top>>e);
  // Check if non-zero bits were lost in the low bits of top, either in the 'e'
  // shifted out bits or in the HalfExpW bits stolen for the exponent
  // Shift by MW-1 to move MSB of mask just below the mantissa, then up
  // HalfExpW more to take in the bits that will be lost for the exponent when
  // it is non-zero.
  CapAddrPlus2 lmaskLor = lmask>>fromInteger(shiftAmount+1);
  CapAddrPlus2 lmaskLo  = lmask>>fromInteger(shiftAmount);
  // For the len, we're not actually losing significance since we're not
  // storing it, we just want to know if any low bits are non-zero so that we
  // will know if it will cause the total length to round up.
  Bool lostSignificantLen  = (len&lmaskLor)!=0 && intExp;
  Bool lostSignificantTop  = (top&lmaskLor)!=0 && intExp;
  // Check if non-zero bits were lost in the low bits of base, either in the
  // 'e' shifted out bits or in the HalfExpW bits stolen for the exponent
  Bool lostSignificantBase = (base&lmaskLor)!=0 && intExp;

  // Calculate all values associated with E=e+1 (e rounding up due to msb of L
  // increasing by 1) This value is just to avoid adding later.
  Bit#(MW) newTopBitsHigher = truncateLSB(newTopBits);
  // Check if non-zero bits were lost in the low bits of top, either in the 'e'
  // shifted out bits or in the HalfExpW bits stolen for the exponent Shift by
  // MW-1 to move MSB of mask just below the mantissa, then up HalfExpW more to
  // take in the bits that will be lost for the exponent when it is non-zero.
  Bool lostSignificantTopHigher  = (top&lmaskLo)!=0 && intExp;
  // Check if non-zero bits were lost in the low bits of base, either in the
  // 'e' shifted out bits or in the HalfExpW bits stolen for the exponent
  Bool lostSignificantBaseHigher = (base&lmaskLo)!=0 && intExp;
  // If either base or top lost significant bits and we wanted an exact
  // setBounds, void the return capability

  // We need to round up Exp if the msb of length will increase.
  // We can check how much the length will increase without looking at the
  // result of adding the length to the base.  We do this by adding the lower
  // bits of the length to the base and then comparing both halves (above and
  // below the mask) to zero.  Either side that is non-zero indicates an extra
  // "1" that will be added to the "mantissa" bits of the length, potentially
  // causing overflow.  Finally check how close the requested length is to
  // overflow, and test in relation to how much the length will increase.
  CapAddrPlus2 topLo = (lmaskLor & len) + (lmaskLor & base);
  CapAddrPlus2 mwLsbMask = lmaskLor ^ lmaskLo;
  // If the first bit of the mantissa of the top is not the sum of the
  // corrosponding bits of base and length, there was a carry in.
  Bool lengthCarryIn = (mwLsbMask & top) != ((mwLsbMask & base)^(mwLsbMask & len));
  Bool lengthRoundUp = lostSignificantTop;
  Bool lengthIsMax        = (len & (~lmaskLor)) == (lmask ^ lmaskLor);
  Bool lengthIsMaxLessOne = (len & (~lmaskLor)) == (lmask ^ lmaskLo);

  Bool lengthOverflow = False;
  if (lengthIsMax && (lengthCarryIn || lengthRoundUp)) lengthOverflow = True;
  if (lengthIsMaxLessOne && lengthCarryIn && lengthRoundUp) lengthOverflow = True;

  if(lengthOverflow && intExp) begin
    e = e+1;
    ret.bounds.topBits = lostSignificantTopHigher ? newTopBitsHigher + 'b1000
                                                  : newTopBitsHigher;
    ret.bounds.baseBits = truncateLSB(newBaseBits);
  end else begin
    ret.bounds.topBits = lostSignificantTop ? truncate(newTopBits + 'b1000)
                                            : truncate(newTopBits);
    ret.bounds.baseBits = truncate(newBaseBits);
  end
  Bool exact = !(lostSignificantBase || lostSignificantTop);

  ret.bounds.exp = e;
  // Update the addrBits fields
  ret.addrBits = ret.bounds.baseBits;
  // Derive new format from newly computed exponent value, and round top up if
  // necessary
  if (!intExp) begin // If we have an Exp of 0 and no implied MSB of L.
    ret.format = Exp0;
  end else begin
    ret.format = EmbeddedExp;
    Bit#(HalfExpW) botZeroes = 0;
    ret.bounds.baseBits = {truncateLSB(ret.bounds.baseBits), botZeroes};
    ret.bounds.topBits  = {truncateLSB(ret.bounds.topBits),  botZeroes};
  end

  // Begin calculate newLength in case this is a request just for a
  // representable length:
  CapAddrPlus2 newLength = {2'b0, length};
  CapAddrPlus2 baseMask = -1; // Override the result from the previous line if
                              // we represent everything.
  if (intExp) begin
    CapAddrPlus2 oneInLsb = (lmask ^ (lmask>>1)) >> shiftAmount;
    CapAddrPlus2 newLengthRounded = newLength + oneInLsb;
    newLength        = (newLength        & (~lmaskLor));
    newLengthRounded = (newLengthRounded & (~lmaskLor));
    if (lostSignificantLen) newLength = newLengthRounded;
    baseMask = (lengthIsMax && lostSignificantTop) ? ~lmaskLo : ~lmaskLor;
  end

  // Return derived capability
  return SetBoundsReturn { cap:    ret
                         , exact:  exact
                         , length: truncate(newLength)
                         , mask:   truncate(baseMask) };
endfunction
