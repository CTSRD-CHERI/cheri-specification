.PHONY: all
all: conc_version.tex \
     conc_getTopFat.bsv \
     conc_capInBounds.bsv \
     conc_incOffsetFat.bsv \
     conc_setAddress.bsv \
     conc_setBoundsFat.bsv

cheri-cap-lib:
	git clone https://github.com/CTSRD-CHERI/cheri-cap-lib

cheri-cap-lib/CHERICC_Fat.bsv: cheri-cap-lib

conc_version.tex: cheri-cap-lib
	echo "\\url{https://github.com/CTSRD-CHERI/cheri-cap-lib/tree/$(shell git -C $< rev-parse --short HEAD)}" > $@

conc_%.bsv: cheri-cap-lib/CHERICC_Fat.bsv
	sed -n "/^function.*$*/,/^endfunction/p" $^ > $@

.PHONY: clean
clean:
	rm -rf *.bsv conc_version.tex
