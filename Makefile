TARGET=cheri-architecture.pdf
TARGET_TR=cheri-architecture-tr.pdf
PREVEOUS=../branches/20150624-cheri-architecture-1-13

SAIL_LATEX_RISCV_DIR=sail_latex_riscv

SOURCES=$(wildcard *.tex insn-riscv/*.tex insn-x86-64/*.tex $(SAIL_LATEX_RISCV_DIR)/*.tex cheri_concentrate_listings/*.bsv cheri_concentrate_listings/*.tex) cheri.bib LICENSE LICENSE-sail-cheri-riscv LICENSE-sail-riscv
DIFFDIR=diff
DIFFTEX=$(SOURCES:%=${DIFFDIR}/%)
DIFFPARAM=--type=UNDERLINE --packages=amsmath,hyperref --math-markup=1

TIKZFIGURES=fig-representable-regions.pdf fig-sentry-plt.pdf fig-type-token.pdf
FIGSOURCES=						\
	20200816-cheri-timeline.pdf			\
	fig-cheri-high-level.pdf			\
	fig-pointer-provenance.pdf			\
	fig-cheri-high-level.pdf			\
	$(TIKZFIGURES)

V?=0
ifeq ($(V),0)
INTERACTION=batchmode
TEXLOGANALYSER_FLAGS=-w
else
INTERACTION=nonstopmode
# Also include page numbers to make it easier to find what caused the warning
TEXLOGANALYSER_FLAGS=-w -n
endif

LATEXMK_COMMON_FLAGS=-bibtex -pdf
PDFLATEX_FLAGS=-file-line-error -halt-on-error -interaction=$(INTERACTION)

.PHONY: all
all: ${TARGET}

# The texloganalyser tool can be used to find all warning messages in the latex
# logfile which is useful when using interaction=batchmode. There is also
# a python package pydflatex that does the same thing (but with colours).
# Howver, texloganalyser is included by default in some TeX distributions so
# prefer that one.
# TODO: fix the broken sail hyperrefs so we don't have to filter the out.
${TARGET} ${TARGET_TR}: ${SOURCES} ${FIGSOURCES}
	latexmk $(LATEXMK_COMMON_FLAGS) $(@:.pdf=.tex) $(PDFLATEX_FLAGS); ret=$$?; \
	    if command -v texloganalyser >/dev/null 2>/dev/null; then \
	        texloganalyser $(TEXLOGANALYSER_FLAGS) build/$(@:.pdf=.log); \
	    fi; exit $$ret

$(TIKZFIGURES): %.pdf: %.tex Makefile
	latexmk $(LATEXMK_COMMON_FLAGS) $(PDFLATEX_FLAGS) $<

.PHONY: figures
figures: $(TIKZFIGURES)

.PHONY: quick
quick:
	pdflatex cheri-architecture.tex $(PDFLATEX_FLAGS)
	@(echo "pdflatex only run once so build may be incomplete")

.PHONY: diff
diff: ${PREVEOUS} diffdir ${DIFFDIR}/${TARGET}

${PREVEOUS}:
	@((echo "ERROR: the preveous version directory (" ${PREVEOUS} ") does not exist." ; echo "Set the PREVEOUS variable in the Makefile.") && false)

.PHONY: diffdir
diffdir:
	@(test -d ${DIFFDIR} || mkdir ${DIFFDIR})
	@(test -d ${DIFFDIR}/cheri_concentrate_listings || mkdir ${DIFFDIR}/cheri_concentrate_listings)
	@(test -d ${DIFFDIR}/insn-riscv || mkdir ${DIFFDIR}/insn-riscv)
	@(test -d ${DIFFDIR}/insn-x86-64 || mkdir ${DIFFDIR}/insn-x86-64)
	@(test -d ${DIFFDIR}/sail_latex_riscv || mkdir ${DIFFDIR}/sail_latex_riscv)

${DIFFDIR}/$(TARGET): $(DIFFTEX)
	cp LICENSE* Makefile ${DIFFDIR}/
	cp ${FIGSOURCES} ${DIFFDIR}/
	cp sail_latex_riscv/*.sail ${DIFFDIR}/sail_latex_riscv
	cp cheri_concentrate_listings/*.bsv ${DIFFDIR}/cheri_concentrate_listings
	make -C ${DIFFDIR}
	@(echo "diff of between "${PREVEOUS}" and this version is now in "${DIFFDIR}"/"${TARGET})

${DIFFDIR}/preamble.tex: preamble.tex
	cp preamble.tex ${DIFFDIR}

${DIFFDIR}/def-riscv-insns-macros.tex: def-riscv-insns-macros.tex
	cp def-riscv-insns-macros.tex ${DIFFDIR}

${DIFFDIR}/sail_latex_riscv/%.tex: sail_latex_riscv/%.tex
	cp $< ${DIFFDIR}/sail_latex_riscv

${DIFFDIR}/%.tex: %.tex
	@(echo '\DIFaddbegin' > ${DIFFDIR}/diffbegin)
	@(echo '\DIFaddend' > ${DIFFDIR}/diffend)
	(if [ -f ${PREVEOUS}/$*.tex ]; then latexdiff ${DIFFPARAM} ${PREVEOUS}/$*.tex $*.tex > ${DIFFDIR}/$*.tex; else cat ${DIFFDIR}/diffbegin $*.tex ${DIFFDIR}/diffend > ${DIFFDIR}/$*.tex; fi)

${DIFFDIR}/%.bib: %.bib
	cp $*.bib ${DIFFDIR}/


# The sed commands require GNU sed
ifeq ($(shell uname -s),Linux)
SED?=sed
else
SED?=gsed
endif

# Work around `find: fts_read: Invalid argument` on macOS
ifeq ($(shell uname -s),Darwin)
FIND?=gfind
else
FIND?=find
endif

$(SAIL_LATEX_RISCV_DIR): %:
	mkdir -p $@

sail-cheri-riscv:
	git clone --recurse-submodules https://github.com/CTSRD-CHERI/sail-cheri-riscv

SAIL_CHERI_RISCV_DIR?=sail-cheri-riscv
sail-cheri-riscv-latex: $(SAIL_CHERI_RISCV_DIR) | $(SAIL_LATEX_RISCV_DIR)
	rm -rf $(SAIL_CHERI_RISCV_DIR)/$(SAIL_LATEX_RISCV_DIR)
	$(MAKE) -C $(SAIL_CHERI_RISCV_DIR) latex
	chmod -R +w $(SAIL_LATEX_RISCV_DIR)
	rm -rf $(SAIL_LATEX_RISCV_DIR)
	cp -r $(SAIL_CHERI_RISCV_DIR)/$(SAIL_LATEX_RISCV_DIR) $(SAIL_LATEX_RISCV_DIR)
	$(FIND) $(SAIL_LATEX_RISCV_DIR) -type f -name 'fcl*zexecute*.tex' -exec $(SED) -i -e '1d; 2{/^{$$/d}; $$d; s/^  //;' {} +
	touch $(SAIL_LATEX_RISCV_DIR)/0GENERATED_FILES_DO_NOT_EDIT
	touch $(SAIL_LATEX_RISCV_DIR)/zGENERATED_FILES_DO_NOT_EDIT
	$(FIND) $(SAIL_LATEX_RISCV_DIR) -type f -exec chmod -w {} +


update-sail-defs-riscv: $(SAIL_CHERI_RISCV_DIR)
	git -C $(SAIL_CHERI_RISCV_DIR) pull --rebase
	git -C $(SAIL_CHERI_RISCV_DIR) submodule update --init --recursive
	$(MAKE) sail-cheri-riscv-latex

update-sail-defs: update-sail-defs-riscv

update-concentrate-defs:
	$(MAKE) -C cheri_concentrate_listings

.PHONY: clean update-sail-defs sail-cheri-riscv-latex update-sail-defs-riscv update-concentrate-defs
clean:
	latexmk -C $(LATEXMK_COMMON_FLAGS) cheri-architecture.tex
	latexmk -C $(LATEXMK_COMMON_FLAGS) fig-*.tex
	rm -f $(TARGET) $(TIKZFIGURES)
	rm -rf $(DIFFDIR)

cheri-sorted.bib: cheri.bib bib-sorting.conf
	biber --tool $< --sortcase=false --strip-comments --sortdebug --isbn13 --isbn-normalise --fixinits \
	    --output_indent=4 --output_fieldcase=lower --sortlocale=en_GB \
	    --configfile=bib-sorting.conf --validate-config --output-file=$@


.PHONY: check-bibliography check-bibliography-strict
check-bibliography:
	# For more detailed output add --debug
	biber --tool cheri.bib

check-bibliography-strict:
	biber --tool --validate-datamodel cheri.bib | grep -v "Missing mandatory field 'editor'" | grep -v "is not an integer"
