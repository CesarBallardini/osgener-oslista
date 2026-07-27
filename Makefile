# ===================================================================
# SCD 1/84 MODERNIZATION - OSGENER / OSLISTA
# TOOLCHAIN: GnuCOBOL 3.2 (cobc), mainframe personality (-std=mvs)
# D0.4/D0.6: single engine OSENGINE.CBL + thin dispatch stubs.
# ===================================================================

COBC        ?= cobc

# The suites are run as "bash tests/x.sh", never as "./tests/x.sh".
# This repository is developed on Windows, where core.fileMode is
# false, so git can never record the executable bit from the working
# tree and the scripts are committed mode 100644. A Linux checkout
# (GitHub Actions) then fails them with exit 126, Permission denied.
# Invoking the interpreter explicitly makes the bit irrelevant
# everywhere: host, container, and CI.
BASH        ?= bash

# --- Dialect selection (plan G9) -----------------------------------
# DIALECT=gnucobol (default) -> -std=mvs, DYNAMIC-assign copybooks
# DIALECT=rm                 -> -std=rm, RM variable-assign copybooks
# Dialect-bound code lives in copy/<DIALECT>/ and is pulled in with
# standard COPY statements via the compiler include path.
DIALECT     ?= gnucobol
ifeq ($(DIALECT),rm)
STD         ?= rm
else
STD         ?= mvs
endif
# -ffilename-mapping: DDNAME -> environment-variable resolution is
# part of this project's runtime contract (run_sim.sh, tests). The
# rm dialect config disables it (filename-mapping: no), so it is
# forced on explicitly for every dialect.
COBFLAGS    ?= -x -std=$(STD) -ffilename-mapping
COPYINC      = -I src/copy/$(DIALECT)

# Bare "make" lists the available targets; build with "make all"
.DEFAULT_GOAL := help
OUTPUT_DIR   = ./bin
SRC_MAIN     = src/OSENGINE.CBL
STUB_GEN     = src/stubs/OSGENER.CBL
STUB_LIS     = src/stubs/OSLISTA.CBL
UNIT_SRC     = tests/OSTESTS.CBL
SOURCES      = $(SRC_MAIN) $(STUB_GEN) $(STUB_LIS) $(UNIT_SRC)

# --- Host-specific toolchain location ------------------------------
# On Windows the Chocolatey GnuCOBOL needs its config directory and
# bundled gcc pointed out explicitly, and native make separates PATH
# entries with ';'. On Linux (including the Docker image) the packaged
# cobc finds its own config and gcc, and a ';'-joined PATH is not a
# valid PATH there, so none of this may leak in.
#
# Detect with OS=Windows_NT: it is exported by both cmd.exe and Git
# Bash. Do NOT use ComSpec - Git Bash exports it as COMSPEC and make
# is case-sensitive, so the block would be skipped and cobc would look
# for a bare "gcc" that is not on PATH.
#
# The second test keeps a Windows box that installed GnuCOBOL some
# other way from being forced onto the Chocolatey paths.
CHOCO_GC := C:/ProgramData/chocolatey/lib/gnucobol/tools
ifeq ($(OS),Windows_NT)
ifneq ($(wildcard $(CHOCO_GC)/bin/cobc.exe),)
export COB_CONFIG_DIR ?= $(CHOCO_GC)/config
export COB_CC ?= $(CHOCO_GC)/bin/gcc.exe
export PATH := $(CHOCO_GC)/bin;$(PATH)
endif
endif

all: setup osgener oslista
	@echo "=================================================="
	@echo " BUILD COMPLETE: $(OUTPUT_DIR)/OSGENER, OSLISTA"
	@echo "=================================================="

setup:
	@mkdir -p $(OUTPUT_DIR)

osgener: $(SRC_MAIN) $(STUB_GEN)
	@echo "Compiling OSGENER (stub + engine)..."
	$(COBC) $(COBFLAGS) $(COPYINC) -o $(OUTPUT_DIR)/OSGENER \
	    $(STUB_GEN) $(SRC_MAIN)

oslista: $(SRC_MAIN) $(STUB_LIS)
	@echo "Compiling OSLISTA (stub + engine)..."
	$(COBC) $(COBFLAGS) $(COPYINC) -o $(OUTPUT_DIR)/OSLISTA \
	    $(STUB_LIS) $(SRC_MAIN)

ostests: $(UNIT_SRC)
	@echo "Compiling unit test harness..."
	$(COBC) $(COBFLAGS) $(COPYINC) -o $(OUTPUT_DIR)/OSTESTS $(UNIT_SRC)

test: all ostests
	@echo "--- Unit tests ---"
	$(OUTPUT_DIR)/OSTESTS
	@echo "--- Integration simulation ---"
	$(BASH) tests/run_sim.sh
	@echo "--- Golden-file regression ---"
	$(BASH) tests/golden_check.sh
	@echo "--- Engine test suite (behavior/limits/negative) ---"
	$(BASH) tests/run_tests.sh
	@echo "--- Manual-example conformance (plan Phase 9) ---"
	$(BASH) tests/manual_examples.sh
	@echo "--- Real-mainframe regression (private job data) ---"
	$(BASH) tests/mainframe_check.sh

# Conformance suite alone: every control-card example printed in the
# genuine SCD 1/84 manual.
manual-tests: all
	$(BASH) tests/manual_examples.sh

# Replay a real production job against the outputs the
# genuine 1984 OSGENER produced. Skips cleanly if the data is absent.
mf-tests: all
	$(BASH) tests/mainframe_check.sh

# --- Container ------------------------------------------------------
# The image never contains the confidential job data (.dockerignore
# keeps it out of the build context). It is bind-mounted read-only at
# run time, but only when it is actually present, so the very same
# command works on a machine that does not have it - there the
# mainframe suite simply reports SKIP.
DOCKER_IMAGE ?= osgener-oslista
DOCKER_PRIVATE = $(if $(wildcard private/*/mf-steps.sh),\
                   -v "$(CURDIR)/private:/src/private:ro",)

docker-build:
	docker build -t $(DOCKER_IMAGE) .

docker-test: docker-build
	docker run --rm $(DOCKER_PRIVATE) $(DOCKER_IMAGE)

# Drop into the image for poking around (data mounted if present).
docker-shell: docker-build
	docker run --rm -it $(DOCKER_PRIVATE) $(DOCKER_IMAGE) bash

# Lint policy: zero warnings expected.
#  -Wno-terminator      : the code uses an explicit scope terminator
#                         on EVERY statement that has one in MVS
#                         COBOL / COBOL-85 (END-IF, END-PERFORM,
#                         END-EVALUATE, END-READ, END-ADD,
#                         END-COMPUTE, END-WRITE, END-STRING,
#                         END-SUBTRACT, END-MULTIPLY, END-DIVIDE,
#                         END-CALL). The only statements left
#                         unterminated are DISPLAYs: END-DISPLAY is
#                         a MF/GnuCOBOL extension REJECTED by
#                         -std=mvs-strict and -std=cobol85, so
#                         those remain period/context-delimited.
#  -Wno-possible-truncate: advisory only - numeric MOVE truncation
#                         behaves identically on IBM MVS COBOL
#                         (TRUNC(STD) modeled by binary-truncate).
#                         Deliberate nibble/digit staging triggers
#                         it; oversized card operands are rejected
#                         semantically by 1600-VALIDATE-CONFIG.
#                         Run "make lint-extra" to review these
#                         classes when adding new code.
# -Werror makes this a real gate: cobc exits 0 even when it prints
# warnings, so without it "0 warnings" was a convention nobody could
# enforce - least of all CI. The two suppressed classes are excluded
# above, so anything that still warns is genuinely new.
lint:
	@echo "Linting (cobc syntax-only, all warnings, mvs dialect)..."
	$(COBC) $(COPYINC) -fsyntax-only -std=mvs -Wall -Wextra -Werror \
	    -Wno-terminator -Wno-possible-truncate \
	    $(SOURCES)

lint-extra:
	@echo "Advisory pass: suppressed warning classes (no gate)..."
	-$(COBC) $(COPYINC) -fsyntax-only -std=mvs -Wall -Wextra \
	    $(SOURCES) \
	    2>&1 | grep -cE "terminator|possible-truncate" || true

lint-strict:
	@echo "Portability audit: strict MVS, portable copybooks..."
	$(COBC) -I src/copy/rm -fsyntax-only -std=mvs-strict $(SRC_MAIN)

# Verify every dialect profile of GnuCOBOL compiles the source (G9).
# The two strict rows prove genuine MVS COBOL / RM/COBOL-85
# conformance using the portable (copy/rm) SELECT variant; the
# gnucobol copybook keeps its documented DYNAMIC extension and is
# checked under the non-strict mvs profile it is built with.
# cobc exits non-zero on errors, so any failure fails this target.
check-dialects:
	@echo "== 1/4 MVS profile (-std=mvs, copy/gnucobol)"
	$(COBC) -I src/copy/gnucobol -fsyntax-only -std=mvs $(SOURCES)
	@echo "== 2/4 RM profile (-std=rm, copy/rm)"
	$(COBC) -I src/copy/rm -fsyntax-only -std=rm $(SOURCES)
	@echo "== 3/4 STRICT MVS conformance (-std=mvs-strict, copy/rm)"
	$(COBC) -I src/copy/rm -fsyntax-only -std=mvs-strict $(SOURCES)
	@echo "== 4/4 STRICT RM/COBOL-85 conformance (-std=rm-strict)"
	$(COBC) -I src/copy/rm -fsyntax-only -std=rm-strict $(SOURCES)
	@echo "=================================================="
	@echo " ALL DIALECT PROFILES COMPILE CLEAN"
	@echo "=================================================="

clean:
	@echo "Cleaning build and simulation outputs..."
	rm -rf $(OUTPUT_DIR) ./datasets ./logs
	@echo "Clean."

help:
	@echo "Available targets:"
	@echo "  make all         : build bin/OSGENER and bin/OSLISTA"
	@echo "  make ostests     : build the unit test harness"
	@echo "  make test        : build all + unit tests + simulation"
	@echo "  make manual-tests: manual-example conformance suite"
	@echo "  make mf-tests    : replay the real mainframe job (needs private data)"
	@echo "  make docker-build: build the Debian test image"
	@echo "  make docker-test : run the suites in the container"
	@echo "                     (mounts private/ read-only if present)"
	@echo "  make docker-shell: interactive shell inside the image"
	@echo "  make lint        : cobc syntax-only pass, all warnings"
	@echo "  make lint-extra  : count suppressed advisory warnings"
	@echo "  make lint-strict : audit against -std=mvs-strict"
	@echo "  make check-dialects : compile under all 4 dialect"
	@echo "                        profiles (mvs/rm + strict)"
	@echo "  make clean       : remove bin/, datasets/, logs/"
	@echo "  make help        : this list (default target)"

.PHONY: all setup osgener oslista ostests test manual-tests mf-tests \
        docker-build docker-test docker-shell \
        lint lint-extra lint-strict check-dialects clean help
