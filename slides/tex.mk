help:
	@echo "\n --- Rendering slides"
	@echo "slides             : Renders slides to PDF (basic compilation)"
	@echo "slides-nomargin    : Renders 4:3 slides with -nomargin.pdf suffix"
	@echo "\n --- Cleaning up"
	@echo "texclean           : Deletes all LaTeX build artifacts (.log, .aux, .nav, .synctex, ...)"
	@echo "clean              : Runs texclean and deletes all rendered slides"
	@echo "\n --- Copying to /slides-pdf/ (!! Linked from course website !!)"
	@echo "release            : Runs texclean, renders slides and literature, copies to /slides-pdf/, and texclean again"
	@echo "copy               : Copies PDF files to /slides-pdf/"
	@echo "\n --- Utilities"
	@echo "pax                : Runs pdfannotextractor.pl (pax) to store hyperlinks etc. in .pax files for later use"
	@echo "literature         : Generates chapter-literature-CHAPTERNAME.pdf from references.bib"

# ============================================================================
# VARIABLES
# ============================================================================

# TeXLive version configuration: use 2024 as default, can be overruled with TLYEAR env var
# See also
# - Source repo with description: https://gitlab.com/islandoftex/images/texlive
# - Registry: https://gitlab.com/islandoftex/images/texlive/container_registry/573747
TLYEAR ?= 2024

# Get current working directory name and lecture root path
CWD := $(notdir $(CURDIR))
LECTURE := $(shell cd ../.. && pwd)

# Configure latexmk command based on DOCKER environment variable
ifeq ($(DOCKER),true)
LATEXMK = docker run -i --rm --user $$(id -u) --name latex \
  -v "$(LECTURE)":/usr/src/app:z \
  -w "/usr/src/app/slides/$(CWD)" \
  registry.gitlab.com/islandoftex/images/texlive:TL$(TLYEAR)-historic \
  latexmk
else
LATEXMK = latexmk
endif

# Slide .tex files, relative paths
SLIDE_TEX_FILES = $(shell find . -maxdepth 1 -iname "slides*.tex")
# Substitute file extension tex -> pdf for output pdf filenames
SLIDE_PDF_FILES = $(SLIDE_TEX_FILES:%.tex=%.pdf)
# Substitute file extension tex -> pax for annotation files
SLIDE_PAX_FILES = $(SLIDE_TEX_FILES:%.tex=%.pax)
# output pdf filenames for slides without margin (old 4:3 layout)
SLIDE_NOMARGIN_PDFS = $(SLIDE_TEX_FILES:%.tex=%-nomargin.pdf)

# fls files contain the full filesystem paths of all included files, used for unused figure detection script
SLIDE_FLS_FILES = $(SLIDE_TEX_FILES:%.tex=%.fls)

# Generate literature list from references.bib, appending the current chapter name to the file name
CHAPTER_NAME := $(notdir $(CURDIR))
LITERATURE_PDF := chapter-literature-$(CHAPTER_NAME).pdf

.PHONY: slides slides-nomargin release copy texclean clean help pax literature

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Docker availability check function
define check_docker
	@if [ "$(DOCKER)" = "true" ]; then \
		if ! command -v docker >/dev/null 2>&1; then \
			echo "Error: Docker is not installed. Please install Docker to use DOCKER=true mode."; \
			exit 1; \
		fi; \
		if ! docker info >/dev/null 2>&1; then \
			echo "Error: Docker daemon is not running. Please:"; \
			echo "  a) Check if Docker is installed"; \
			echo "  b) Start the Docker daemon/service"; \
			exit 1; \
		fi; \
	fi
endef

# Check if latex-math directory exists in the expected location
define check_latex_math
	@if [ ! -d "../../latex-math" ]; then \
		echo "Cannot find 'latex-math' in root directory"; \
		exit 1; \
	fi
endef

# ============================================================================
# TARGETS
# ============================================================================

# Basic slide compilation
slides: $(SLIDE_FLS_FILES)
slides-nomargin: $(SLIDE_NOMARGIN_PDFS)

release:
	$(call check_latex_math)
	$(MAKE) texclean
	$(MAKE) $(SLIDE_PDF_FILES)
	$(MAKE) pax
	$(MAKE) literature
	$(MAKE) copy
	$(MAKE) texclean

# Conditionally remove or create empty nospeakermargin.tex file to decide which layout to use
# See /style/lmu-lecture.sty -- it's a whole thing but does the job.
$(SLIDE_PDF_FILES): %.pdf: %.tex
	$(call check_docker)
	-rm nospeakermargin.tex
	@echo render $<;
	$(LATEXMK) -halt-on-error -pdf $<

$(SLIDE_NOMARGIN_PDFS): %-nomargin.pdf: %.tex
	$(call check_docker)
	touch nospeakermargin.tex
	$(LATEXMK) -halt-on-error -pdf -jobname=%A-nomargin $<

$(SLIDE_FLS_FILES): %.fls: %.tex
	$(call check_docker)
	-rm nospeakermargin.tex
	$(LATEXMK) -halt-on-error -pdf -g $<

copy:
	@echo "Copying PDFs and PAX files to slides-pdf/..."
	@rsync -u *.pdf ../../slides-pdf/ 2>/dev/null || cp *.pdf ../../slides-pdf/
	@rsync -u *.pax ../../slides-pdf/ 2>/dev/null || true

# Extract pdf annotations, i.e. hyperlinks, for later reinsertion
# When combining multiple PDFs into one (for slides/all/)
# https://ctan.org/tex-archive/macros/latex/contrib/pax?lang=en
# Depending on installation linked script in PATH does not have file extension
pax:
	@if command -v pdfannotextractor.pl &> /dev/null; then\
		echo "Found pdfannotextractor.pl - extracting annotations...";\
		pdfannotextractor.pl *.pdf 2>/dev/null || echo "Warning: Some PDFs may not have been processed";\
	elif command -v pdfannotextractor &> /dev/null; then\
		echo "Found pdfannotextractor - extracting annotations...";\
		pdfannotextractor *.pdf 2>/dev/null || echo "Warning: Some PDFs may not have been processed";\
	else\
		echo "Note: pdfannotextractor not found!";\
		echo "Please install 'pax' package using: tlmgr install pax";\
		echo "This is required to preserve clickable URLs and annotations in slides-pdf/"
	fi

texclean:
	-rm -rf *.out
	-rm -rf *.dvi
	-rm -rf *.log
	-rm -rf *.aux
	-rm -rf *.bbl
	-rm -rf *.bbl-SAVE-ERROR
	-rm -rf *.blg
	-rm -rf *.ind
	-rm -rf *.idx
	-rm -rf *.ilg
	-rm -rf *.lof
	-rm -rf *.lot
	-rm -rf *.toc
	-rm -rf *.nav
	-rm -rf *.snm
	-rm -rf *.vrb
	-rm -rf *.fls
	-rm -rf *.pax
	-rm -rf *.bbl
	-rm -rf *.bcf-SAVE-ERROR
	-rm -rf *.bcf
	-rm -rf *.run.xml
	-rm -rf *.fdb_latexmk
	-rm -rf *.synctex.gz
	-rm -rf *-concordance.tex
	-rm -rf nospeakermargin.tex

clean: texclean
	-rm -f $(SLIDE_PDF_FILES) $(SLIDE_NOMARGIN_PDFS) $(SLIDE_PAX_FILES) $(LITERATURE_PDF)

literature: $(LITERATURE_PDF)

$(LITERATURE_PDF): references.bib
	$(call check_docker)
	@echo "Compiling literature list for chapter $(CHAPTER_NAME)..."
	$(LATEXMK) -pdf -halt-on-error -jobname=chapter-literature-$(CHAPTER_NAME) ../../style/chapter-literature-template.tex
	@echo "Literature list generated: $(LITERATURE_PDF)"
	@echo "Cleaning up detritus..."
	$(LATEXMK) -c -jobname=chapter-literature-$(CHAPTER_NAME) ../../style/chapter-literature-template.tex 2>/dev/null
