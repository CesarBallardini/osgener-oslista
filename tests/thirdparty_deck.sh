#!/bin/bash
# ===================================================================
# THIRD-PARTY DECK SUITE
# A field-selection deck written by somebody else, for somebody
# else's machine, and checked against an oracle we did not write.
#
# Source (public JCL practice repository):
#   https://github.com/Nazgonzalezz/JCL-practica
#   file: "cambiar OSGENER por un SORT"
#
# The exercise replaces an OSGENER step with an IBM SORT step, so the
# file carries BOTH the OSGENER control deck and the DFSORT OUTREC
# that must produce the same record.  That OUTREC is an independent
# specification of the answer: it states, group by group, which byte
# lands where and how wide each packed->zoned conversion has to be
#
#     5:199,2,PD,TO=ZD,LENGTH=3      <-  SELEC 199,2,PZ,5,3
#    26:4,3,PD,TO=ZD,LENGTH=5        <-  SELEC 4,3,PZ,26,5
#
# so it independently confirms the digit-width convention this engine
# implements (a packed field of n bytes carries 2n-1 digits), the
# left-zero padding, and the exact output offsets.  The deck is the
# whole point: no example in the manual chains seven selections into
# one delimited output record.
#
# Two provenance facts, deliberately not papered over:
#
#  - The deck's op-code is SELEC, and its DDs are SYSUT / SYSLST, not
#    SYSUT1 / SYSUT2 / SYSPRINT.  It is another installation's OSGENER,
#    not the SCD 1/84 one, so the cards are replayed with the op-code
#    this engine documents (FIELD) and T8 pins that SELEC itself is
#    diagnosed rather than silently ignored.
#  - The operand grammar is character-for-character the SCD FIELD
#    grammar of manual sheet 32 - Si,long1,conv,So,long for a field
#    group, 'literal',So for a literal group, groups separated by "/",
#    with PZ among the XY conversion codes - so every group of the
#    deck translates verbatim.  An unrelated site using the identical
#    grammar is corroboration of the manual's reading.
#
# Exit code: 0 = all PASS, 1 = any FAIL.
# ===================================================================
cd "$(dirname "$0")/.." || exit 1

GC_BIN="/c/ProgramData/chocolatey/lib/gnucobol/tools/bin"
if [ -d "$GC_BIN" ]; then PATH="$GC_BIN:$PATH"; fi

W="tests/work-3p"
rm -rf "$W" && mkdir -p "$W"

resolve_bin () {
    if [ -x "bin/$1" ]; then echo "bin/$1"
    elif [ -x "bin/$1.exe" ]; then echo "bin/$1.exe"
    else echo "ERROR: bin/$1 missing - run 'make all' first" >&2; exit 1
    fi
}
GENER=$(resolve_bin OSGENER) || exit 1

PASS=0; FAIL=0
ok ()  { PASS=$((PASS+1)); echo "PASS  $1"; }
bad () { FAIL=$((FAIL+1)); echo "FAIL  $1 -- $2"; }

# run <tag>; expects $W/<tag>.sysin, uses the shared fixture
run () {
    SYSIN="$W/$1.sysin" SYSUT1="$W/deck.ut1" SYSUT2="$W/$1.out" \
    SYSPRINT="$W/$1.prt" SYSLIST="$W/$1.lst" "$GENER" >/dev/null 2>&1
    RC=$?
}
# got <tag> : the output, CR stripped (LINE SEQUENTIAL on Windows)
got () { tr -d '\r' < "$W/$1.out" 2>/dev/null; }

# -------------------------------------------------------------------
# FIXTURE
# The deck reads a 230-byte record and touches seven places in it.
# Packed fields are built from printable bytes so the fixture stays a
# text file: X'41' X'53' X'4C' is "ASL" and unpacks to +41534, exactly
# as X'41' X'3C' is "A<" and unpacks to +413.  Filler is "." so that
# any byte that leaked from an unselected column would be obvious.
# -------------------------------------------------------------------
fill () { local s; s=$(printf "%$1s" ""); echo "${s// /.}"; }
F192=$(fill 192); F16=$(fill 16); F4=$(fill 4)

# mkrec <3 chars @1> <3 packed bytes @4> <2 @199> <2 @217> <2 @219>
#       <4 chars @221> <2 @225>
mkrec () {
    printf '%s' "$1"; printf "$2";  printf '%s' "$F192"
    printf "$3";      printf '%s' "$F16"
    printf "$4";      printf "$5";  printf '%s' "$6"; printf "$7"
    printf '%s\n' "$F4"
}
{
  mkrec ABC '\x41\x53\x4c' '\x41\x3c' '\x42\x3c' '\x43\x3c' WXYZ '\x44\x3c'
  mkrec DEF '\x50\x60\x7c' '\x50\x3c' '\x51\x3c' '\x52\x3c' MNOP '\x53\x3c'
  mkrec GHI '\x62\x73\x2c' '\x60\x3c' '\x61\x3c' '\x62\x3c' QRST '\x63\x3c'
} > "$W/deck.ut1"

# What the DFSORT OUTREC of the same exercise specifies, byte for byte
cat > "$W/expected" <<'EOF'
ABC;413;423;433;WXYZ;443;41534
DEF;503;513;523;MNOP;533;50607
GHI;603;613;623;QRST;633;62732
EOF

echo "=================================================================="
echo " third-party deck - github.com/Nazgonzalezz/JCL-practica"
echo "=================================================================="

# --- T1: the deck itself, one FIELD card per original SELEC card ---
# SELEC      1,3,,1/';',4        SELEC      219,2,PZ,13,3/';',16
# SELEC      199,2,PZ,5,3/';',8  SELEC      221,4,,17/';',21
# SELEC      217,2,PZ,9,3/';',12 SELEC      225,2,PZ,22,3/';',25
#                                SELEC      4,3,PZ,26,5
cat > "$W/t1.sysin" <<'EOF'
FIELD 1,3,,1/';',4
FIELD 199,2,PZ,5,3/';',8
FIELD 217,2,PZ,9,3/';',12
FIELD 219,2,PZ,13,3/';',16
FIELD 221,4,,17/';',21
FIELD 225,2,PZ,22,3/';',25
FIELD 4,3,PZ,26,5
EOF
run t1
if [ $RC -eq 0 ] && got t1 | diff -q - "$W/expected" > /dev/null
then ok "T1 whole deck == the DFSORT OUTREC it was replaced by"
else bad "T1" "rc=$RC; $(got t1 | diff - "$W/expected" | head -4)"; fi

# --- T2: same seven groups, three continuation cards ---------------
# A card whose operands end in "/" continues on the next card
# (manual sheet 32, the FIELD1/FIELD2 examples).  Same 30 bytes.
cat > "$W/t2.sysin" <<'EOF'
FIELD 1,3,,1/';',4/199,2,PZ,5,3/';',8/217,2,PZ,9,3/';',12/
FIELD 219,2,PZ,13,3/';',16/221,4,,17/';',21/225,2,PZ,22,3/
FIELD ';',25/4,3,PZ,26,5
EOF
run t2
if [ $RC -eq 0 ] && got t2 | diff -q - "$W/expected" > /dev/null
then ok "T2 continuation form == card-per-selection form"
else bad "T2" "rc=$RC; $(got t2 | diff - "$W/expected" | head -4)"; fi

# --- T3: the same cards in reverse order ---------------------------
# The manual says selections happen in card order; the deck's targets
# are disjoint, so the record must come out identical either way.
# (A regression guard for M27-style "only the first group parsed":
#  that defect would drop a DIFFERENT group here than in T1.)
cat > "$W/t3.sysin" <<'EOF'
FIELD 4,3,PZ,26,5
FIELD 225,2,PZ,22,3/';',25
FIELD 221,4,,17/';',21
FIELD 219,2,PZ,13,3/';',16
FIELD 217,2,PZ,9,3/';',12
FIELD 199,2,PZ,5,3/';',8
FIELD 1,3,,1/';',4
EOF
run t3
if [ $RC -eq 0 ] && got t3 | diff -q - "$W/expected" > /dev/null
then ok "T3 disjoint targets are card-order independent"
else bad "T3" "rc=$RC; $(got t3 | diff - "$W/expected" | head -4)"; fi

# --- T4: the output record is built, not copied --------------------
# SORT's OUTREC constructs a new record; so must FIELD.  With only
# the deck's first card, nothing but its four bytes may appear - no
# tail of the 230-byte input.
printf "FIELD 1,3,,1/';',4\n" > "$W/t4.sysin"
run t4
if [ $RC -eq 0 ] && [ "$(got t4 | head -1)" = "ABC;" ]
then ok "T4 unselected columns do not leak into the output"
else bad "T4" "rc=$RC; got '$(got t4 | head -1)'"; fi

# --- T5: PZ width, 2-byte source ("LENGTH=3" in the OUTREC) --------
printf "FIELD 199,2,PZ,1,3\n" > "$W/t5.sysin"
run t5
if [ $RC -eq 0 ] && [ "$(got t5)" = "413
503
603" ]
then ok "T5 PZ 2 packed bytes -> exactly 3 zoned digits"
else bad "T5" "rc=$RC; got '$(got t5 | tr '\n' ' ')'"; fi

# --- T6: PZ width, 3-byte source ("LENGTH=5" in the OUTREC) --------
printf "FIELD 4,3,PZ,1,5\n" > "$W/t6.sysin"
run t6
if [ $RC -eq 0 ] && [ "$(got t6)" = "41534
50607
62732" ]
then ok "T6 PZ 3 packed bytes -> exactly 5 zoned digits"
else bad "T6" "rc=$RC; got '$(got t6 | tr '\n' ' ')'"; fi

# --- T7: declared output wider than the digits -> left zero fill ---
# DFSORT pads a TO=ZD result on the left; the deck never needs it,
# but the width convention T5/T6 pin is only half the contract.
printf "FIELD 199,2,PZ,1,6\n" > "$W/t7.sysin"
run t7
if [ $RC -eq 0 ] && [ "$(got t7 | head -1)" = "000413" ]
then ok "T7 short value left-padded to the declared length"
else bad "T7" "rc=$RC; got '$(got t7 | head -1)'"; fi

# --- T8: SELEC is not this utility's op-code -----------------------
# The deck comes from a sibling implementation.  An op-code this
# engine does not implement must be REPORTED, never ignored: a
# silently dropped card would copy records through unchanged.
printf "SELEC 1,3,,1/';',4\n" > "$W/t8.sysin"
run t8
if [ $RC -ne 0 ] && grep -q "UNKNOWN OP-CODE: SELEC" "$W/t8.prt"
then ok "T8 foreign op-code SELEC diagnosed, not ignored"
else bad "T8" "rc=$RC (want non-zero) and no UNKNOWN OP-CODE line"; fi

# --- T9: every record of the file goes through ---------------------
if grep -q "RECORDS READ:    000000003" "$W/t1.prt" &&
   grep -q "RECORDS WRITTEN: 000000003" "$W/t1.prt"
then ok "T9 3 read / 3 written on the deck run"
else bad "T9" "$(grep RECORDS "$W/t1.prt" | tr '\n' ' ')"; fi

echo "=================================================="
echo "RESULT: $PASS passed, $FAIL failed"
echo "=================================================="
[ $FAIL -eq 0 ]
