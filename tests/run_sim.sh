#!/bin/bash
# ===================================================================
# END-TO-END SIMULATION - OSGENER + OSLISTA (GnuCOBOL BUILD)
# FIXTURE REDESIGNED PER PLAN D0.7 (2026-07-23):
#  - SYSUT1 SORTED BY PESQ KEY (COLS 1-5); SYSUT6 SORTED TOO
#  - RCIN ACCEPTS ARG+BRA (OR GROUP) SO THE CODIG TEST IS REACHABLE
#  - INCON OFFSETS MATCH THE DATA (DATE 12-17, BAD BYTE AT 13)
#  - OSLISTA WRITES TO ITS OWN SYSUT2 FILE (NO CLOBBER)
# ===================================================================

# Paths are repo-root relative, so anchor there however we are called
cd "$(dirname "$0")/.." || exit 1

BIN_DIR="./bin"
DATA_DIR="./datasets"
LOG_DIR="./logs"

# GnuCOBOL runtime DLLs (chocolatey layout) if not already on PATH
GC_BIN="/c/ProgramData/chocolatey/lib/gnucobol/tools/bin"
if [ -d "$GC_BIN" ]; then PATH="$GC_BIN:$PATH"; fi

mkdir -p "$DATA_DIR" "$LOG_DIR"

echo "=================================================="
echo "1. Generating test datasets..."

# SYSUT1: layout 1-3 geo, 4-7 branch, 8-11 year, 12-17 date DDMMAA,
# 18-23 amount, 80 card-type code. Sorted by cols 1-5.
# ARG0395 carries corrupt date 1A5991 (day '1A'); BRA0290 lacks the
# type-1 card so CODIG '1',OBL,'2' must orphan the batch to SYSUT5.
cat << 'EOF' > "$DATA_DIR/sysut1.dat"
ARG01941994110512150050                                                        0
ARG01941994110512050025                                                        1
ARG01941994110512010000                                                        2
ARG039519951A5991040000                                                        0
BRA02901990110512020000                                                        0
BRA02901990110512035000                                                        2
URD04961996110512005000                                                        1
EOF

# SYSUT6: lookup keys (cols 1-5 of SYSUT1). Sorted. URD absent.
cat << 'EOF' > "$DATA_DIR/sysut6.dat"
ARG01
ARG03
BRA02
EOF

# SYSUT3: secondary file for the CLAVE match, keyed on cols 1-7 of
# SYSUT1 and sorted by it. Cols 8-10 carry a region code that the
# S-prefixed FIELD group copies out, so the golden files defend both
# CLAVE pairing and S-prefixed input offsets (M6).
cat << 'EOF' > "$DATA_DIR/sysut3.dat"
ARG0194SUR
ARG0395NOR
BRA0290SUD
URD0496ORI
EOF

# CONV external table: key cols 1-3, function cols 10-19.
# Last row is the mandated miss-default entry.
cat << 'EOF' > "$DATA_DIR/convtab.dat"
ARG      ARGENTINA
BRA      BRAZIL
ZZZ      UNKNOWN
EOF

# OSGENER control cards.
# Deliberately written with MULTI-GROUP cards and the manual features
# the 2026-07-27 parity pass added, so the golden baselines defend
# them: several "/"-separated FIELD groups on one card (M27), an
# omitted comparison operator (M1), an omitted conv code (M9), a
# plain 'literal',so group with no CL (M8), the record counter AN
# (M20), a validation conversion (M29), a condition-gated CONVx over
# an INLINE SYSIN table (M11/M12), an S-prefixed SYSUT3 input offset
# (M6) and an .O. INCON alternation (M17).
cat << 'EOF' > "$DATA_DIR/sysin_gener.dat"
PESQIN 1,5,1
CLAVE  1,7,1
RCIN  1,3,EQ,'ARG'/1,3,EQ,'BRA'
COND1 8,4,GE,'1990'
COND2 1,,'ARG'
GENER 1,7/80,1/'0','1','2','3'
CODIG '1',OBL,'2'
INCON '0'/12,6,FD/13,1,ND
INCON '0'/1,,'ARG'.O.1,,'BRA'
FIELD 1,3,MOVE,1/18,6,MOVE,10/98,6,MOVE,20/18,6,zDVy,30
FIELD 'X',CL,52,3/'TAG',56
FIELD1 8,4,,60
FIELD2 S8,3,MOVE,70
FIELD 18,6,NO,80
FIELD AN,Z,90,4
CONV DD=CONVTAB,4K,1,3,1/40,10,10
CONV2 1,3,1/100,6,9
ARG     ARGENT
BRA     BRASIL
        OTHER
EOF

# OSLISTA control cards (independent listing over the same input).
# Also multi-group, and covering the OSLISTA-side parity features:
# a TIT literal continued on the next card (M24), a title field map
# with an omitted conv (M23), an ACUM numeric literal in the manual's
# two-token form (M4), extra print lines beyond line 2 (M7), the
# CORTE "I,so2" breaking-field echo (M16), and two break levels
# declared on one card each carrying its own ID= (M15/M27).
cat << 'EOF' > "$DATA_DIR/sysin_lista.dat"
PRINT FL=XC,SP=1,SR=2
TIT1  L10,'SCD - GEOGRAPHIC CONTROL REPORT',FA70,(1,3,,60)
TIT2  L10,'CONTINUED HEADING
SECOND CARD'
ACUM1 +,Z2,18,6/*,2
FIELD 1,3,MOVE,1/18,6,MOVE,10
FIELD 1,3,MOVE,T5/8,4,MOVE,Q5
CORTE F,ID='GRAND TOTAL',H/1,3,1,ID='PROVINCE: ',5,I,20
IMCOR CANT,30/A1,Z9D2,50
EOF

echo "Datasets ready in $DATA_DIR/."
echo "=================================================="

# --- DDNAME -> file mapping via environment (GnuCOBOL native) ---
export SYSUT1="$DATA_DIR/sysut1.dat"
export SYSUT3="$DATA_DIR/sysut3.dat"
export SYSUT6="$DATA_DIR/sysut6.dat"
export CONVTAB="$DATA_DIR/convtab.dat"
export SYSUT4="$DATA_DIR/sysut4.dat"
export SYSUT5="$DATA_DIR/sysut5_rejects.dat"
export SYSLIST="$LOG_DIR/syslist.log"

run_bin () {
    # resolve OSGENER vs OSGENER.exe
    if [ -x "$BIN_DIR/$1" ]; then "$BIN_DIR/$1"
    elif [ -x "$BIN_DIR/$1.exe" ]; then "$BIN_DIR/$1.exe"
    else
        echo "ERROR: $BIN_DIR/$1 not found. Run 'make all' first."
        exit 1
    fi
}

echo "2. Running OSGENER..."
export SYSIN="$DATA_DIR/sysin_gener.dat"
export SYSUT2="$DATA_DIR/sysut2.dat"
export SYSPRINT="$LOG_DIR/sysprint_gener.log"
run_bin OSGENER
echo ">> OSGENER done (rc=$?)."

echo "=================================================="

echo "3. Running OSLISTA..."
export SYSIN="$DATA_DIR/sysin_lista.dat"
export SYSUT2="$DATA_DIR/sysut2_lista.dat"
export SYSPRINT="$LOG_DIR/sysprint_lista.log"
run_bin OSLISTA
echo ">> OSLISTA done (rc=$?)."

echo "=================================================="
echo "Outputs:"
echo "  $DATA_DIR/sysut2.dat           - OSGENER main output"
echo "  $DATA_DIR/sysut5_rejects.dat  - CODIG orphan batches"
echo "  $DATA_DIR/sysut2_lista.dat     - OSLISTA listing"
echo "  $LOG_DIR/syslist.log           - inconsistency report"
echo "  $LOG_DIR/sysprint_*.log        - operation logs"
echo "=================================================="
