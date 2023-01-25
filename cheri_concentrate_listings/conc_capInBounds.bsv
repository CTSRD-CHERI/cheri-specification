function Bool capInBounds(CapFat cap, TempFields tf, Bool inclusive);
  // Check that the pointer of a capability is currently within the bounds
  // of the capability
  Bool ptrVStop = inclusive ? cap.addrBits <= cap.bounds.topBits
                            : cap.addrBits <  cap.bounds.topBits;
  // Top is ok if the pointer and top are in the same alignment region
  // and the pointer is less than the top.  If they are not in the same
  // alignment region, it's ok if the top is in Hi and the bottom in Low.
  Bool topOk  = (tf.topHi  == tf.addrHi) ? ptrVStop : tf.topHi;
  Bool baseOk = (tf.baseHi == tf.addrHi) ? cap.addrBits >= cap.bounds.baseBits
                                         : tf.addrHi;
  return topOk && baseOk;
endfunction
