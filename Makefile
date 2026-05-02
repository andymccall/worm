# ---------------------------------------------------------------------------
# Worm - Master Makefile
# ---------------------------------------------------------------------------
# Three independent ASM codebases under src/<platform>/, one unified build
# front-end. Each platform has its own assembler/syntax; no code is shared
# between architectures (the X16/Neo trees are intentionally duplicated
# because cc65/ca65 and PCEAS/HuC don't share a syntax).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------
CA65       = ca65
LD65       = ld65
X16EMU     = x16emu
NEOEMU     = neo
NEO_HOME   = ~/development/tools/neo6502
PCEAS      = pceas
GEARGRAFX  = geargrafx

# HuC install root - derived from where pceas lives so this works regardless
# of where the user has unpacked HuC. Override on the command line if pceas
# isn't on PATH yet:  make HUC_HOME=/path/to/huc build-pce
HUC_HOME  ?= $(realpath $(dir $(shell command -v $(PCEAS) 2>/dev/null))/..)

# ---------------------------------------------------------------------------
# Directories
# ---------------------------------------------------------------------------
SRCDIR     = src
CFGDIR     = cfg
BUILDDIR   = build
RELEASEDIR = release

# ---------------------------------------------------------------------------
# Commander X16  (cc65 / ca65, 65C02)
# ---------------------------------------------------------------------------
X16_SRCS = $(wildcard $(SRCDIR)/x16/app/*.asm) \
           $(wildcard $(SRCDIR)/x16/engine/*.asm) \
           $(wildcard $(SRCDIR)/x16/system/*.asm)
X16_INCS = $(wildcard $(SRCDIR)/x16/app/*.inc) \
           $(wildcard $(SRCDIR)/x16/engine/*.inc) \
           $(wildcard $(SRCDIR)/x16/system/*.inc)
X16_OBJS = $(patsubst $(SRCDIR)/x16/%.asm,$(BUILDDIR)/x16/%.o,$(X16_SRCS))
X16_CFG  = $(CFGDIR)/x16.cfg
X16_OUT  = $(BUILDDIR)/x16/WORM.PRG

# ---------------------------------------------------------------------------
# Neo6502  (cc65 / ca65, 65C02)
# ---------------------------------------------------------------------------
NEO_SRCS = $(wildcard $(SRCDIR)/neo/app/*.asm) \
           $(wildcard $(SRCDIR)/neo/engine/*.asm) \
           $(wildcard $(SRCDIR)/neo/system/*.asm)
NEO_INCS = $(wildcard $(SRCDIR)/neo/app/*.inc) \
           $(wildcard $(SRCDIR)/neo/engine/*.inc) \
           $(wildcard $(SRCDIR)/neo/system/*.inc)
NEO_OBJS = $(patsubst $(SRCDIR)/neo/%.asm,$(BUILDDIR)/neo/%.o,$(NEO_SRCS))
NEO_CFG  = $(CFGDIR)/neo.cfg
NEO_RAW  = $(BUILDDIR)/neo/worm.bin
NEO_OUT  = $(BUILDDIR)/neo/worm.neo

# ---------------------------------------------------------------------------
# PC Engine / TurboGrafx-16  (PCEAS, HuC6280)
# ---------------------------------------------------------------------------
# PCEAS is the assembler shipped with HuC. The HuC6280 is a 65C02 derivative
# with banked memory and PCEAS-specific pseudo-ops, so it can't share the
# cc65/ca65 source tree. Currently a stub that boots, shows the WORM title,
# and prints "work in progress" - full gameplay port pending.
PCE_MAIN = $(SRCDIR)/pce/app/main.asm
PCE_OUT  = $(BUILDDIR)/pce/worm.pce
PCE_SYM  = $(BUILDDIR)/pce/worm.sym
PCE_LST  = $(BUILDDIR)/pce/worm.lst

# Project sources brought in by main.asm via include directives. PCEAS
# has no linker so the whole project assembles in a single pass; listing
# everything here as a Make-side dependency means edits trigger rebuilds.
PCE_SRCS = $(wildcard $(SRCDIR)/pce/app/*.asm) \
           $(wildcard $(SRCDIR)/pce/engine/*.asm) \
           $(wildcard $(SRCDIR)/pce/system/*.asm) \
           $(wildcard $(SRCDIR)/pce/system/*.inc)

# Search paths for PCEAS includes/incbins. PCEAS reads PCE_INCLUDE the same
# way Unix tools read PATH (':' on POSIX).
#
#   src/pce/system   project equates (platform.inc)
#   elmer/include    CORE(not TM) library (bare-startup, vdc, font, ...)
#   elmer/font       8x8 font .dat used by the title screen
#   hucc include     pceas.inc + pcengine.inc hardware equates
PCE_INCLUDE_DIRS = $(SRCDIR)/pce/app \
                   $(SRCDIR)/pce/engine \
                   $(SRCDIR)/pce/system \
                   $(HUC_HOME)/examples/asm/elmer/include \
                   $(HUC_HOME)/examples/asm/elmer/font \
                   $(HUC_HOME)/include/hucc
PCE_INCLUDE     := $(subst $(eval) ,:,$(PCE_INCLUDE_DIRS))

# --raw     : no ROM header (HuCARD doesn't need one)
# --newproc : .proc trampolines in MPR6 (frees MPR5 for game code)
# --strip   : strip unused .proc / .procgroup blocks
# -gA       : emit a PCEAS-format .SYM for ASM source-level debugging
# -m, -l 2  : show macro expansions in the .lst at detail level 2
# -S        : append segment usage + contents to stdout after assembly
PCEAS_FLAGS = --raw --newproc --strip -gA -m -l 2 -S

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: all build-x16 build-neo build-pce \
        run-x16 run-neo run-pce \
        release-x16 release-neo release-pce release-all \
        clean help

all: build-x16 build-neo build-pce

help:
	@echo "Targets:"
	@echo "  build-x16     Commander X16        -> $(X16_OUT)"
	@echo "  build-neo     Neo6502              -> $(NEO_OUT)"
	@echo "  build-pce     PC Engine / TG-16    -> $(PCE_OUT)"
	@echo "  all           build all three platforms"
	@echo "  run-<plat>    build then launch the platform's emulator"
	@echo "  release-<plat>  package the build artefact + manual + license"
	@echo "  release-all   package all three platforms"
	@echo "  clean         remove build/ and release/"

# ===========================================================================
# Commander X16
# ===========================================================================
build-x16: $(X16_OUT)

$(BUILDDIR)/x16/%.o: $(SRCDIR)/x16/%.asm $(X16_INCS)
	@mkdir -p $(dir $@)
	$(CA65) --cpu 65C02 -D __X16__ -I $(SRCDIR)/x16 -o $@ $<

$(X16_OUT): $(X16_OBJS) $(X16_CFG)
	@mkdir -p $(dir $@)
	$(LD65) -C $(X16_CFG) -o $@ $(X16_OBJS)

run-x16: build-x16
	$(X16EMU) -prg $(X16_OUT)

# ===========================================================================
# Neo6502
# ===========================================================================
build-neo: $(NEO_OUT)

$(BUILDDIR)/neo/%.o: $(SRCDIR)/neo/%.asm $(NEO_INCS)
	@mkdir -p $(dir $@)
	$(CA65) --cpu 65C02 -D __NEO__ -I $(SRCDIR)/neo -o $@ $<

$(NEO_RAW): $(NEO_OBJS) $(NEO_CFG)
	@mkdir -p $(dir $@)
	$(LD65) -C $(NEO_CFG) -o $@ $(NEO_OBJS)

$(NEO_OUT): $(NEO_RAW)
	python3 $(NEO_HOME)/exec.zip $(NEO_RAW)@800 run@800 -o"$(NEO_OUT)"

run-neo: build-neo
	@mkdir -p storage
	@cp $(NEO_OUT) storage/
	$(NEOEMU) $(NEO_OUT) cold
	@rm -rf storage
	@rm -f memory.dump

# ===========================================================================
# PC Engine
# ===========================================================================
build-pce: $(PCE_OUT)

# PCEAS writes the .pce wherever -o points, but always drops .sym + .lst
# next to the *input* .asm. Move them into $(BUILDDIR)/pce/ post-build so
# src/ stays clean and the .sym sits beside the .pce where Geargrafx
# auto-discovers it.
PCE_MAIN_STEM = $(basename $(notdir $(PCE_MAIN)))
PCE_SRC_SYM   = $(dir $(PCE_MAIN))$(PCE_MAIN_STEM).sym
PCE_SRC_LST   = $(dir $(PCE_MAIN))$(PCE_MAIN_STEM).lst

$(PCE_OUT): $(PCE_SRCS)
	@mkdir -p $(dir $@)
	PCE_INCLUDE="$(PCE_INCLUDE)" $(PCEAS) $(PCEAS_FLAGS) -o $@ $(PCE_MAIN)
	@[ -f $(PCE_SRC_SYM) ] && mv $(PCE_SRC_SYM) $(PCE_SYM) || true
	@[ -f $(PCE_SRC_LST) ] && mv $(PCE_SRC_LST) $(PCE_LST) || true

run-pce: build-pce
	$(GEARGRAFX) $(PCE_OUT) $(PCE_SYM)

# ===========================================================================
# Housekeeping
# ===========================================================================
clean:
	rm -rf $(BUILDDIR) $(RELEASEDIR)

# ===========================================================================
# Release packaging
# ===========================================================================
release-all: release-x16 release-neo release-pce

release-x16: build-x16
	@mkdir -p $(RELEASEDIR)/worm-x16
	cp $(X16_OUT) $(RELEASEDIR)/worm-x16/WORM.PRG
	cp docs/MANUAL.TXT $(RELEASEDIR)/worm-x16/MANUAL.TXT
	cp LICENSE.txt $(RELEASEDIR)/worm-x16/LICENSE.TXT
	cd $(RELEASEDIR) && zip -r worm-x16.zip worm-x16/
	rm -rf $(RELEASEDIR)/worm-x16

release-neo: build-neo
	@mkdir -p $(RELEASEDIR)/worm-neo
	cp $(NEO_OUT) $(RELEASEDIR)/worm-neo/worm.neo
	cp docs/MANUAL.TXT $(RELEASEDIR)/worm-neo/manual.txt
	cp LICENSE.txt $(RELEASEDIR)/worm-neo/license.txt
	cd $(RELEASEDIR) && zip -r worm-neo.zip worm-neo/
	rm -rf $(RELEASEDIR)/worm-neo

release-pce: build-pce
	@mkdir -p $(RELEASEDIR)/worm-pce
	cp $(PCE_OUT) $(RELEASEDIR)/worm-pce/worm.pce
	cp docs/MANUAL.TXT $(RELEASEDIR)/worm-pce/manual.txt
	cp LICENSE.txt $(RELEASEDIR)/worm-pce/license.txt
	cd $(RELEASEDIR) && zip -r worm-pce.zip worm-pce/
	rm -rf $(RELEASEDIR)/worm-pce
