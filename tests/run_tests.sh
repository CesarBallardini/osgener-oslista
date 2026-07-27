#!/bin/bash
# ===================================================================
# ENGINE TEST SUITE - plan items 6.2 (behavior) and 6.4 (bounds).
# Runs the REAL binaries against generated fixtures and asserts
# outputs, SYSLIST/SYSPRINT content and return codes.
# Exit code: 0 = all PASS, 1 = any FAIL.
# ===================================================================
cd "$(dirname "$0")/.." || exit 1

GC_BIN="/c/ProgramData/chocolatey/lib/gnucobol/tools/bin"
if [ -d "$GC_BIN" ]; then PATH="$GC_BIN:$PATH"; fi

W="tests/work"
rm -rf "$W" && mkdir -p "$W"

resolve_bin () {
    if [ -x "bin/$1" ]; then echo "bin/$1"
    elif [ -x "bin/$1.exe" ]; then echo "bin/$1.exe"
    else echo "ERROR: bin/$1 missing - run 'make all' first" >&2; exit 1
    fi
}
GENER=$(resolve_bin OSGENER) || exit 1
LISTA=$(resolve_bin OSLISTA) || exit 1

PASS=0; FAIL=0
ok ()  { PASS=$((PASS+1)); echo "PASS  $1"; }
bad () { FAIL=$((FAIL+1)); echo "FAIL  $1 -- $2"; }

# run <binary> <tag> ; expects $W/<tag>.sysin and $W/<tag>.ut1
run () {
    SYSIN="$W/$2.sysin" SYSUT1="$W/$2.ut1" SYSUT2="$W/$2.out" \
    SYSUT4="$W/$2.u4" SYSUT5="$W/$2.u5" SYSUT6="$W/$2.ut6" \
    SYSPRINT="$W/$2.prt" SYSLIST="$W/$2.lst" \
    INTTAB="$W/$2.tab" "$1"
    RC=$?
}

# --- I1: ACUM division by zero -> warning, no abend ----------------
printf "ACUM1 /,Z,1,3\nCORTE F,ID='T',1\nIMCOR A1,Z5D0,10\n" > "$W/i1.sysin"
printf "000\n" > "$W/i1.ut1"
run "$LISTA" i1
if [ $RC -eq 0 ] && grep -q "DIVISION BY ZERO" "$W/i1.prt"
then ok "I1 div-zero warning, rc=0"
else bad "I1" "rc=$RC or warning missing"; fi

# --- I2: INCON FD calendar edges (days 00/32, months 00/13) --------
printf "INCON '0'/12,6,FD\n" > "$W/i2.sysin"
for d in 010100 320100 001200 311300 310000 311200; do
    printf '           %s\n' "$d"
done > "$W/i2.ut1"
run "$GENER" i2
V=$(grep -c "INCON FD VIOLATION" "$W/i2.lst")
N=$(wc -l < "$W/i2.out")
if [ "$V" = "4" ] && [ "$N" = "6" ]
then ok "I2 FD edges: 4 violations logged, 6 records kept"
else bad "I2" "violations=$V (want 4), records=$N (want 6)"; fi

# --- I3: CONV /INT interval lookup + miss -> last entry ------------
printf "CONV DD=INTTAB,1K,1,3,1/10,1,4/INT\n" > "$W/i3.sysin"
printf "100A\n200B\n300C\n" > "$W/i3.tab"
printf "050\n150\n250\n999\n" > "$W/i3.ut1"
run "$GENER" i3
R=$(cut -c10 "$W/i3.out" | tr -d '\n')
if [ "$R" = "ABCC" ]
then ok "I3 CONV /INT ceiling lookup + miss default (ABCC)"
else bad "I3" "got '$R' want 'ABCC'"; fi

# --- I4: GENER slot ordering by declared code priority -------------
printf "GENER 1,3/80,1/'0','1','2'\nFIELD 5,2,MOVE,1\nFIELD 85,2,MOVE,4\nFIELD 165,2,MOVE,7\n" > "$W/i4.sysin"
{ printf '%-79s2\n' "AAA C2"
  printf '%-79s0\n' "AAA C0"
  printf '%-79s1\n' "AAA C1"; } > "$W/i4.ut1"
run "$GENER" i4
if grep -q "C0 C1 C2" "$W/i4.out"
then ok "I4 GENER priority-slot ordering (arrival 2,0,1 -> 0,1,2)"
else bad "I4" "$(head -1 "$W/i4.out")"; fi

# --- I5: HEXA doubles length -----------------------------------------
printf "FIELD 1,3,HEXA,10\n" > "$W/i5.sysin"
printf "ABC\n" > "$W/i5.ut1"
run "$GENER" i5
if cut -c10-15 "$W/i5.out" | grep -q "414243"
then ok "I5 HEXA expansion (ABC -> 414243)"
else bad "I5" "$(head -1 "$W/i5.out")"; fi

# --- I6: ZxDy edit mask ---------------------------------------------
printf "FIELD 18,6,Z6D2,10\n" > "$W/i6.sysin"
printf '%-17s012345\n' "" > "$W/i6.ut1"
run "$GENER" i6
if grep -q "123,45" "$W/i6.out"
then ok "I6 Z6D2 edit mask (012345 -> 123,45)"
else bad "I6" "$(head -1 "$W/i6.out")"; fi

# --- I7: negative packed value through ACUM + IMCOR ----------------
# bytes X'413D' ("A=") = packed -413
printf "ACUM1 +,P,1,2\nCORTE F,ID='T',1\nIMCOR A1,Z5D0,10\n" > "$W/i7.sysin"
printf 'A=\n' > "$W/i7.ut1"
run "$LISTA" i7
if grep -q -- "-413" "$W/i7.out"
then ok "I7 negative packed decode (X'413D' -> -413)"
else bad "I7" "$(grep T "$W/i7.out")"; fi

# --- I8: UNPK digits (v1: digits only, sign dropped) ---------------
printf "FIELD 1,2,UNPK,10\n" > "$W/i8.sysin"
printf 'A=\n' > "$W/i8.ut1"
run "$GENER" i8
if cut -c10-12 "$W/i8.out" | grep -q "413"
then ok "I8 UNPK nibble expansion (X'413D' -> 413)"
else bad "I8" "$(head -1 "$W/i8.out")"; fi

# === PHASE-8 GAP TESTS (G1..G8) ====================================

# --- I9 (G2): INCON relational rule flags out-of-range field -------
# Field at 1-3 must be >= '500'; '499' fails, '500' passes.
printf "INCON '0'/1,GE,'500'\n" > "$W/i9.sysin"
printf "499\n500\n" > "$W/i9.ut1"
run "$GENER" i9
V=$(grep -c "INCON R  VIOLATION" "$W/i9.lst")
if [ "$V" = "1" ]
then ok "I9 (G2) INCON relational: 1 of 2 flagged"
else bad "I9" "violations=$V want 1"; fi

# --- I10 (G4): zoned overpunch negative sign ('J' = -1 units) ------
# ACUM sums a 2-byte zoned field "0J" = -01.
printf "ACUM1 +,Z,1,2\nCORTE F,ID='T',1\nIMCOR A1,Z5D0,10\n" > "$W/i10.sysin"
printf '0J\n' > "$W/i10.ut1"
run "$LISTA" i10
if grep -q -- "-1" "$W/i10.out"
then ok "I10 (G4) zoned overpunch negative (0J -> -1)"
else bad "I10" "$(grep T "$W/i10.out")"; fi

# --- I11 (G4): binary two's-complement negative --------------------
# bytes X'FFFF' = -1 as signed 2-byte binary, summed via ACUM B.
printf "ACUM1 +,B,1,2\nCORTE F,ID='T',1\nIMCOR A1,Z6D0,20\n" > "$W/i11.sysin"
printf '\xff\xff\n' > "$W/i11.ut1"
run "$LISTA" i11
if grep -q -- "-1" "$W/i11.out"
then ok "I11 (G4) binary two's-complement (X'FFFF' -> -1)"
else bad "I11" "$(grep T "$W/i11.out")"; fi

# --- I12 (G5): ACUM numeric literal operand ------------------------
printf "ACUM1 +,L,100\nACUM1 +,L,2.5\nCORTE F,ID='T',1\nIMCOR A1,Z6D2,20\n" > "$W/i12.sysin"
printf "X\n" > "$W/i12.ut1"
run "$LISTA" i12
if grep -q "102,50" "$W/i12.out"
then ok "I12 (G5) ACUM literals (100 + 2.5 = 102,50)"
else bad "I12" "$(grep T "$W/i12.out")"; fi

# --- I13 (G5): ACUM implied-decimal alignment (Z2) -----------------
# field "12345" read as Z2 = 123.45
printf "ACUM1 +,Z2,1,5\nCORTE F,ID='T',1\nIMCOR A1,Z6D2,20\n" > "$W/i13.sysin"
printf "12345\n" > "$W/i13.ut1"
run "$LISTA" i13
if grep -q "123,45" "$W/i13.out"
then ok "I13 (G5) implied decimals (Z2: 12345 -> 123,45)"
else bad "I13" "$(grep T "$W/i13.out")"; fi

# --- I14 (G7): duplicate GENER code dropped, first kept ------------
printf "GENER 1,3/80,1/'0','1'\nFIELD 5,1,MOVE,1\n" > "$W/i14.sysin"
{ printf '%-79s0\n' "AAA A"
  printf '%-79s0\n' "AAA B"
  printf '%-79s1\n' "AAA C"; } > "$W/i14.ut1"
run "$GENER" i14
D=$(grep -c "DUPLICATE CARD CODE" "$W/i14.lst")
F=$(cut -c1 "$W/i14.out")
if [ "$D" = "1" ] && [ "$F" = "A" ]
then ok "I14 (G7) duplicate code dropped, first kept, logged"
else bad "I14" "dups=$D first=$F"; fi

# --- I15 (G3): CARRO WC1 forces a page eject (form feed emitted) ---
printf "PRINT SP=1\nTIT1  L5,'HDR'\nCARRO WC1\nFIELD 1,3,MOVE,1\n" > "$W/i15.sysin"
printf "AAA\nBBB\nCCC\n" > "$W/i15.ut1"
run "$LISTA" i15
# form-feed byte (0x0C) present => at least one channel-1 eject
if grep -q $'\x0c' "$W/i15.out"
then ok "I15 (G3/G8) CARRO WC1 emits form-feed page eject"
else bad "I15" "no form feed in output"; fi

# --- I16 (G1): TIT field map renders page-lead record --------------
printf "TIT1  L5,'ACCT',(1,3,MOVE,20)\nFIELD 1,3,MOVE,1\n" > "$W/i16.sysin"
printf "XYZ\nXYZ\n" > "$W/i16.ut1"
run "$LISTA" i16
# title line carries both the literal 'ACCT' and the mapped 'XYZ'
if grep -q "ACCT" "$W/i16.out" && \
   awk '/ACCT/{print substr($0,20,3)}' "$W/i16.out" | grep -q "XYZ"
then ok "I16 (G1) TIT field map renders page-lead record"
else bad "I16" "$(grep ACCT "$W/i16.out" | head -1)"; fi

# --- I17..I21 (M3): logical connectors + the run/OR-of-ANDs model ---
# Fixture: col 1 = A/B, col 2 = 1/2, one record per combination.
mk_ab () { printf "A1\nA2\nB1\nB2\n" > "$W/$1.ut1"; }

# I17: .Y. glued to its operands is an AND (used to tokenize as
# ".Y.20" and be rejected outright).
printf "RCIN 1,EQ,'A'.Y.2,EQ,'1'\n" > "$W/i17.sysin"; mk_ab i17
run "$GENER" i17
R=$(tr -d '\n\r ' < "$W/i17.out")
if [ $RC -eq 0 ] && [ "$R" = "A1" ]
then ok "I17 (M3) glued .Y. is AND (A1 only)"
else bad "I17" "rc=$RC got '$R' want 'A1'"; fi

# I18: .O. glued is an OR.
printf "RCIN 1,EQ,'B'.O.2,EQ,'2'\n" > "$W/i18.sysin"; mk_ab i18
run "$GENER" i18
R=$(tr -d '\n\r ' < "$W/i18.out")
if [ $RC -eq 0 ] && [ "$R" = "A2B1B2" ]
then ok "I18 (M3) glued .O. is OR (A2,B1,B2)"
else bad "I18" "rc=$RC got '$R' want 'A2B1B2'"; fi

# I19: sum of products - "/" separates two AND-runs (manual sheet 8
# example RCIN GT,4000.AND.LT,5000/GT,6000.Y.LT,10000). The old flat
# model ANDed all four conditions and would return nothing.
printf "RCIN 1,EQ,'A'.Y.2,EQ,'1'/1,EQ,'B'.Y.2,EQ,'1'\n" > "$W/i19.sysin"
mk_ab i19
run "$GENER" i19
R=$(tr -d '\n\r ' < "$W/i19.out")
if [ $RC -eq 0 ] && [ "$R" = "A1B1" ]
then ok "I19 (M3) OR-of-ANDs across '/' (A1,B1)"
else bad "I19" "rc=$RC got '$R' want 'A1B1'"; fi

# I20: the family may change across "/" (run 1 bare, run 2 an AND).
printf "RCIN 1,EQ,'A'/1,EQ,'B'.Y.2,EQ,'1'\n" > "$W/i20.sysin"; mk_ab i20
run "$GENER" i20
R=$(tr -d '\n\r ' < "$W/i20.out")
if [ $RC -eq 0 ] && [ "$R" = "A1A2B1" ]
then ok "I20 (M3) family switch across '/' (A1,A2,B1)"
else bad "I20" "rc=$RC got '$R' want 'A1A2B1'"; fi

# I21: CONDx takes a whole condition group. This used to parse only
# the first condition and drop the rest of the card in silence, so
# the flag never fired for 'B'.
printf "COND1 1,EQ,'A'/1,EQ,'B'\nFIELD 1,2,MOVE,1\nFIELD1 'X',CL,5,1\n" \
    > "$W/i21.sysin"
printf "A1\nB1\nC1\n" > "$W/i21.ut1"
run "$GENER" i21
R=$(cut -c5 "$W/i21.out" | tr -d '\n ')
if [ $RC -eq 0 ] && [ "$R" = "XX" ]
then ok "I21 (M3) CONDx group: flag set for both A and B, not C"
else bad "I21" "rc=$RC col5='$R' want 'XX'"; fi

# I21b: CONDx AND-group. 3510-SET-COND-FLAGS used to OR every
# condition of the card regardless of its connectors, so this card
# flagged all four records instead of A1 alone.
printf "COND1 1,EQ,'A'.Y.2,EQ,'1'\nFIELD 1,2,MOVE,1\nFIELD1 'X',CL,5,1\n" \
    > "$W/i21b.sysin"; mk_ab i21b
run "$GENER" i21b
R=$(cut -c5 "$W/i21b.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "X" ]
then ok "I21b (M3) CONDx AND-group folds (A1 only)"
else bad "I21b" "rc=$RC col5='$R' want 'X'"; fi

# --- I22..I24 (M1): an omitted comparison operator assumes EQ ------
# I22: RCIN with an empty operator field behaves exactly like EQ.
printf "RCIN 1,,'A'\n" > "$W/i22.sysin"; mk_ab i22
run "$GENER" i22
R=$(tr -d '\n\r ' < "$W/i22.out")
if [ $RC -eq 0 ] && [ "$R" = "A1A2" ]
then ok "I22 (M1) RCIN omitted operator = EQ"
else bad "I22" "rc=$RC got '$R' want 'A1A2'"; fi

# I23: same for CONDx, and the explicit form must still agree.
printf "COND1 2,,'1'\nFIELD 1,2,MOVE,1\nFIELD1 'X',CL,5,1\n" \
    > "$W/i23.sysin"; mk_ab i23
run "$GENER" i23
R=$(cut -c5 "$W/i23.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "XX" ]
then ok "I23 (M1) CONDx omitted operator = EQ (A1,B1 flagged)"
else bad "I23" "rc=$RC col5='$R' want 'XX'"; fi

# I24: INCON relational form with the operator omitted. Record 2
# fails the implied "col 1 EQ 'A'" and is the only one reported.
printf "GENER 1,1/2,1/'1'\nINCON '1'/1,,'A'\n" > "$W/i24.sysin"
printf "A1\nB1\n" > "$W/i24.ut1"
run "$GENER" i24
V=$(grep -c "INCON" "$W/i24.lst")
if [ $RC -eq 0 ] && [ "$V" = "1" ]
then ok "I24 (M1) INCON omitted operator = EQ (1 violation)"
else bad "I24" "rc=$RC violations=$V want 1"; fi

# --- I25..I27 (M2): count-only conditions "op,cuenta" --------------
mk_six () { printf "r1\nr2\nr3\nr4\nr5\nr6\n" > "$W/$1.ut1"; }

# I25: an AND-run of two count conditions selects a record window
# (manual sheet 8: RCIN GT,4000.AND.LT,5000).
printf "RCIN GT,2.Y.LT,5\n" > "$W/i25.sysin"; mk_six i25
run "$GENER" i25
R=$(tr -d '\n\r ' < "$W/i25.out")
if [ $RC -eq 0 ] && [ "$R" = "r3r4" ]
then ok "I25 (M2) count window GT,2 .Y. LT,5 -> r3,r4"
else bad "I25" "rc=$RC got '$R' want 'r3r4'"; fi

# I26: RCOUT LT,3 (manual sheet 8 example 5) skips the first two.
printf "RCOUT LT,3\n" > "$W/i26.sysin"; mk_six i26
run "$GENER" i26
R=$(tr -d '\n\r ' < "$W/i26.out")
if [ $RC -eq 0 ] && [ "$R" = "r3r4r5r6" ]
then ok "I26 (M2) RCOUT LT,3 skips records 1-2"
else bad "I26" "rc=$RC got '$R' want 'r3r4r5r6'"; fi

# I27: count and field conditions mix inside one AND-run, and the
# count form works on CONDx too (manual sheet 9: COND6 GT,..,LT,..).
printf "COND1 1,EQ,'r'.Y.GE,5\nFIELD 1,2,MOVE,1\nFIELD1 'X',CL,5,1\n" \
    > "$W/i27.sysin"; mk_six i27
run "$GENER" i27
R=$(cut -c5 "$W/i27.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "XX" ]
then ok "I27 (M2) count+field in one AND-run on CONDx (r5,r6)"
else bad "I27" "rc=$RC col5='$R' want 'XX'"; fi

# --- I28..I30 (M17): INCON connectors; "/" is AND, ".O." alternates -
# Records: col 1 is the value under test.
mk_incon () { printf "1x\n3x\n7x\nZx\n" > "$W/$1.ut1"; }

# I28: an .O. alternation (manual sheet 28: field must be one of a
# set). Only the record matching none of the alternatives is a
# violation -- a failing alternative is NOT itself an inconsistency.
printf "GENER 1,1/2,1/'x'\nINCON 'x'/1,,'1'.O.1,,'3'.O.1,,'7'\n" \
    > "$W/i28.sysin"; mk_incon i28
run "$GENER" i28
V=$(grep -c "INCON" "$W/i28.lst")
if [ $RC -eq 0 ] && [ "$V" = "1" ]
then ok "I28 (M17) .O. alternation: 1 violation (Z only)"
else bad "I28" "rc=$RC violations=$V want 1"; fi

# I29: "/" separates independent checks (sheet 28: "el separador /
# equivale a .Y."), so each failure is reported on its own. Here
# every record fails at least one of the two checks.
printf "GENER 1,1/2,1/'x'\nINCON 'x'/1,,'1'/1,,'3'\n" \
    > "$W/i29.sysin"; mk_incon i29
run "$GENER" i29
V=$(grep -c "INCON" "$W/i29.lst")
if [ $RC -eq 0 ] && [ "$V" = "6" ]
then ok "I29 (M17) '/' is AND: 6 independent violations"
else bad "I29" "rc=$RC violations=$V want 6"; fi

# I30 (D0.9): a correcting type code may not be an .O. alternative --
# the manual gives no semantics for correcting a losing alternative.
printf "GENER 1,1/2,1/'x'\nINCON 'x'/1,1,ND.O.1,,'3'\n" \
    > "$W/i30.sysin"; mk_incon i30
run "$GENER" i30
if [ $RC -eq 12 ] && \
   grep -q "ONLY RELATIONAL INCON RULES MAY BE .O." "$W/i30.prt"
then ok "I30 (D0.9) corrector rejected as .O. alternative"
else bad "I30" "rc=$RC"; fi

# --- I31 (M26): offsets past the old 800-byte buffer ---------------
# The manual addresses column 810 (sheet 9) and 1062 (sheet 33); the
# input record used to be X(800), so both were rejected outright.
# one group per card on purpose: multi-group cards are gap M27.
printf "FIELD 1062,5,MOVE,1\nFIELD 810,3,MOVE,10\n" > "$W/i31.sysin"
{ printf '%1061s' "" | tr ' ' '.'; printf 'FARIN'; } > "$W/i31.ut1"
# patch columns 810-812 of that same record
awk '{ printf "%s%s%s\n", substr($0,1,809), "T10", substr($0,813) }' \
    "$W/i31.ut1" > "$W/i31.tmp" && mv "$W/i31.tmp" "$W/i31.ut1"
run "$GENER" i31
R=$(cut -c1-5,10-12 "$W/i31.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "FARINT10" ]
then ok "I31 (M26) reads columns 810 and 1062 (was X(800))"
else bad "I31" "rc=$RC got '$R' want 'FARINT10'"; fi

# --- I32..I34 (M27): every "/"-separated group must be honoured ----
# I32: two FIELD groups on one card. Only the first used to apply,
# with no diagnostic for the discarded remainder.
printf "FIELD 1,3,M,1/4,3,M,10\n" > "$W/i32.sysin"
printf "AAABBB\n" > "$W/i32.ut1"
run "$GENER" i32
R=$(cut -c1-3,10-12 "$W/i32.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "AAABBB" ]
then ok "I32 (M27) both FIELD groups applied"
else bad "I32" "rc=$RC got '$R' want 'AAABBB'"; fi

# I33: five groups, mixing a literal-fill group with field groups,
# to prove the group loop tracks boundaries through the CL form's
# optional trailing width (manual sheet 33 example 2).
printf "FIELD '0',CL,1,4/1,3,M,10/'Z',CL,20,2/4,3,M,30\n" \
    > "$W/i33.sysin"
printf "AAABBB\n" > "$W/i33.ut1"
run "$GENER" i33
R=$(cut -c1-4,10-12,20-21,30-32 "$W/i33.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "0000AAAZZBBB" ]
then ok "I33 (M27) 4 mixed groups incl. CL widths"
else bad "I33" "rc=$RC got '$R' want '0000AAAZZBBB'"; fi

# I34 (M27/M15): two CORTE levels on one card, each with its own
# ID='..'. The options loop used to run to end of card and eat the
# second level; 1255 hands out the ID literals in card order.
printf "CORTE 1,1,ID='OUTER',1/2,1,ID='INNER',1\nIMCOR CANT,40\n" \
    > "$W/i34.sysin"
printf "A1\nA2\nB1\n" > "$W/i34.ut1"
run "$LISTA" i34
if [ $RC -eq 0 ] && grep -q "OUTER" "$W/i34.out" \
   && grep -q "INNER" "$W/i34.out"
then ok "I34 (M27/M15) both CORTE levels and both ID literals"
else bad "I34" "rc=$RC $(grep -c . "$W/i34.out") lines"; fi

# --- I35 (M9): an omitted conversion code means MOVE --------------
printf "FIELD 1,3,,1/4,3,MOVE,10\n" > "$W/i35.sysin"
printf "AAABBB\n" > "$W/i35.ut1"
run "$GENER" i35
R=$(cut -c1-3,10-12 "$W/i35.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "AAABBB" ]
then ok "I35 (M9) empty conv behaves as MOVE"
else bad "I35" "rc=$RC got '$R' want 'AAABBB'"; fi

# --- I36..I38 (M4): ACUM numeric literal operands "op,num" ---------
# acum_case <tag> <acum card> ; input is the single record "150"
acum_case () {
    printf "%s\nCORTE F,ID='T',1\nIMCOR A1,Z7D2,20\n" "$2" \
        > "$W/$1.sysin"
    printf "150\n" > "$W/$1.ut1"
    run "$LISTA" "$1"
    ACR=$(sed 's/\r//' "$W/$1.out" | grep '^T' | tr -s ' ')
}

# I36: the manual's two-token form (sheet 10) - no "L" marker.
acum_case i36 "ACUM1 +,Z,1,3/*,3"
if [ $RC -eq 0 ] && [ "$ACR" = "T 450,00" ]
then ok "I36 (M4) literal multiply 150*3"
else bad "I36" "rc=$RC got '$ACR' want 'T 450,00'"; fi

# I37: division by a literal. 3525-RUN-ONE-ACUM divided by DN-VAL,
# which the literal branch never sets, so this used to divide by the
# PREVIOUS field operand (150/150=1) instead of by 3.
acum_case i37 "ACUM1 +,Z,1,3//,3"
if [ $RC -eq 0 ] && [ "$ACR" = "T 50,00" ]
then ok "I37 (M4) literal divide 150/3"
else bad "I37" "rc=$RC got '$ACR' want 'T 50,00'"; fi

# I38: manual sheet 10 example ACUM36 - "$ Ley 18188" conversion,
# a field then two literal operations chained.
acum_case i38 "ACUM1 +,Z,1,3/+,50//,100"
if [ $RC -eq 0 ] && [ "$ACR" = "T 2,00" ]
then ok "I38 (M4) chained literals (150+50)/100"
else bad "I38" "rc=$RC got '$ACR' want 'T 2,00'"; fi

# --- I39..I41 (M11/M12): inline SYSIN CONV tables + CONVx ----------
# I39: manual sheet 14 example 1 verbatim - sex decode with the
# table included in SYSIN (no DD=). The blank-argument last row is
# the fall-through entry.
{ echo "CONV  22,1,10/23,9,20"
  printf '%9s1%9sMASCULINO\n' "" ""
  printf '%9s2%9sFEMENINO\n' "" ""
  printf '%19sERROR\n' ""
} > "$W/i39.sysin"
{ printf '%-21s1\n' ""; printf '%-21s2\n' ""; printf '%-21s9\n' ""; } \
    > "$W/i39.ut1"
run "$GENER" i39
R=$(sed 's/\r//' "$W/i39.out" | cut -c23-31 | tr -d ' \n')
if [ $RC -eq 0 ] && [ "$R" = "MASCULINOFEMENINOERROR" ]
then ok "I39 (M11) inline SYSIN CONV table + fall-through row"
else bad "I39" "rc=$RC got '$R'"; fi

# I40: manual sheet 14 example 2 verbatim - /INT interval table,
# inline, gated on CONV2 (M12). 005->000 020->001 030->003, and the
# 999 miss falls through to the last entry 005.
{ echo "COND2 18,GE,'0'"
  echo "CONV2  18,3,1/18,3,10/INT"
  printf '010%6s000%7sDE  0  A  10\n' "" ""
  printf '020%6s001%7sDE  11 A  20\n' "" ""
  printf '025%6s002%7sDE  21 A  25\n' "" ""
  printf '050%6s003%7sDE  26 A  50\n' "" ""
  printf '080%6s004%7sDE  51 A  80\n' "" ""
  printf '200%6s005%9s+ DE 80\n' "" ""
} > "$W/i40.sysin"
for v in 005 020 030 999; do printf '%-17s%s\n' "" "$v"; done \
    > "$W/i40.ut1"
run "$GENER" i40
R=$(sed 's/\r//' "$W/i40.out" | cut -c18-20 | tr -d ' \n')
if [ $RC -eq 0 ] && [ "$R" = "000001003005" ]
then ok "I40 (M11/M12) inline /INT table gated on CONV2"
else bad "I40" "rc=$RC got '$R' want '000001003005'"; fi

# I41: the same CONVx with its condition FALSE must not convert.
sed "s/^COND2 18,GE,'0'/COND2 18,EQ,'ZZZ'/" "$W/i40.sysin" \
    > "$W/i41.sysin"
cp "$W/i40.ut1" "$W/i41.ut1"
run "$GENER" i41
R=$(sed 's/\r//' "$W/i41.out" | cut -c18-20 | tr -d ' \n')
if [ $RC -eq 0 ] && [ "$R" = "005020030999" ]
then ok "I41 (M12) CONVx suppressed when its flag is off"
else bad "I41" "rc=$RC got '$R' want unconverted input"; fi

# --- I42..I49: the remaining manual gaps ---------------------------
# I42 (M6): S-prefixed INPUT offset reads SYSUT3, not SYSUT1.
printf "CLAVE 1,3,1\nFIELD 1,3,M,1/S4,3,M,10\n" > "$W/i42.sysin"
printf "KEYAAA\n" > "$W/i42.ut1"
printf "KEYZZZ\n" > "$W/i42.ut3"
SYSIN="$W/i42.sysin" SYSUT1="$W/i42.ut1" SYSUT3="$W/i42.ut3" \
SYSUT2="$W/i42.out" SYSPRINT="$W/i42.prt" \
SYSUT4="$W/i42.u4" SYSUT5="$W/i42.u5" SYSLIST="$W/i42.lst" \
"$GENER" >/dev/null 2>&1
RC=$?
R=$(cut -c1-3,10-12 "$W/i42.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "KEYZZZ" ]
then ok "I42 (M6) S-prefixed input offset reads SYSUT3"
else bad "I42" "rc=$RC got '$R' want 'KEYZZZ'"; fi

# I43 (M7): print lines 5-9 via the Q/X/P/O/N prefixes.
printf "FIELD 1,1,M,1/1,1,M,S1/1,1,M,T1/1,1,M,C1/1,1,M,Q1\n" \
    > "$W/i43.sysin"
printf "FIELD 1,1,M,X1/1,1,M,P1/1,1,M,O1/1,1,M,N1\n" \
    >> "$W/i43.sysin"
printf "Z\n" > "$W/i43.ut1"
run "$LISTA" i43
N=$(grep -c '^Z' "$W/i43.out")
if [ $RC -eq 0 ] && [ "$N" = "9" ]
then ok "I43 (M7) all nine print lines emitted"
else bad "I43" "rc=$RC lines=$N want 9"; fi

# I44 (M29): AN / AB / NO replace out-of-class bytes.
printf "FIELD 1,4,AN,1/1,4,AB,10/1,4,NO,20\n" > "$W/i44.sysin"
# classes are uppercase-only, as in the INCON correctors
printf 'A1%%Z\n' > "$W/i44.ut1"
run "$GENER" i44
A=$(cut -c1-4 "$W/i44.out"); B=$(cut -c10-13 "$W/i44.out")
C=$(cut -c20-23 "$W/i44.out")
if [ $RC -eq 0 ] && [ "$A" = "A1 Z" ] && [ "$B" = "A  Z" ] \
   && [ "$C" = "0100" ]
then ok "I44 (M29) AN/AB/NO class corrections"
else bad "I44" "rc=$RC AN='$A' AB='$B' NO='$C'"; fi

# I45 (M20): AN is the written-record counter, not accumulator N.
printf "FIELD 1,1,M,1/AN,Z,10,3\n" > "$W/i45.sysin"
printf "A\nB\nC\n" > "$W/i45.ut1"
run "$GENER" i45
R=$(cut -c10-12 "$W/i45.out" | tr -d '\n\r ')
if [ $RC -eq 0 ] && [ "$R" = "000001002" ]
then ok "I45 (M20) AN emits the written-record counter"
else bad "I45" "rc=$RC got '$R' want '000001002'"; fi

# I46 (M16): CORTE I,s02 echoes the breaking field, and no longer
# corrupts the ID position it used to overwrite.
printf "CORTE 1,1,ID='GRP',1,I,20\nIMCOR CANT,40\n" > "$W/i46.sysin"
printf "A1\nA2\nB1\n" > "$W/i46.ut1"
run "$LISTA" i46
if [ $RC -eq 0 ] && grep -q "^GRP" "$W/i46.out" \
   && awk '/^GRP/{print substr($0,20,1)}' "$W/i46.out" | grep -q "A"
then ok "I46 (M16) CORTE I,s02 echoes the breaking field"
else bad "I46" "rc=$RC $(grep '^GRP' "$W/i46.out" | head -1)"; fi

# I47 (M25): the heading carries -PAGINA even with no TIT card.
printf "FIELD 1,1,M,1\n" > "$W/i47.sysin"
printf "A\n" > "$W/i47.ut1"
run "$LISTA" i47
if [ $RC -eq 0 ] && grep -q -- "-PAGINA 00001" "$W/i47.out"
then ok "I47 (M25) page legend printed without a TIT card"
else bad "I47" "rc=$RC no -PAGINA line"; fi

# I48 (M24): a TIT literal opened on one card, closed on the next.
printf "TIT1 'FIRST PART \nSECOND PART'\nFIELD 1,1,M,1\n" \
    > "$W/i48.sysin"
printf "A\n" > "$W/i48.ut1"
run "$LISTA" i48
# the literal legitimately absorbs the blanks out to column 80 of
# the first card, so assert both halves land on one title line
if [ $RC -eq 0 ] && \
   grep "FIRST PART" "$W/i48.out" | grep -q "SECOND PART"
then ok "I48 (M24) TIT literal continued on the next card"
else bad "I48" "rc=$RC $(head -1 "$W/i48.out")"; fi

# I49 (M21): sheet-11 input caps are enforced (HEXA 64).
neg_pre () { printf "%s\n" "$2" > "$W/$1.sysin"; printf "A\n" \
    > "$W/$1.ut1"; run "$LISTA" "$1"; }
neg_pre i49 "FIELD 1,65,HEXA,1"
if [ $RC -eq 12 ] && grep -q "HEXA INPUT LIMIT IS 64" "$W/i49.prt"
then ok "I49 (M21) HEXA input length cap enforced"
else bad "I49" "rc=$RC"; fi

# --- L1..L4: table limits produce clean card errors (rc=12) --------
limit_test () {
    local tag=$1 bin=$2 msg=$3
    printf "AAA\n" > "$W/$tag.ut1"
    run "$bin" "$tag"
    if [ $RC -eq 12 ] && grep -q "$msg" "$W/$tag.prt"
    then ok "$4"
    else bad "$4" "rc=$RC, message '$msg' $(grep -c "$msg" "$W/$tag.prt") hits"; fi
}
for i in $(seq 151); do echo "RCIN 1,3,EQ,'AAA'"; done > "$W/l1.sysin"
limit_test l1 "$GENER" "CONDITION TABLE FULL (150)" "L1 151st condition rejected"
for i in $(seq 126); do echo "FIELD 1,3,MOVE,1"; done > "$W/l2.sysin"
limit_test l2 "$GENER" "FIELD TABLE FULL (125)" "L2 126th FIELD rejected"
{ echo "CORTE F,ID='T',1"
  for i in $(seq 10); do echo "CORTE 1,2,1"; done; } > "$W/l3.sysin"
limit_test l3 "$LISTA" "CORTE LEVEL LIMIT (10) EXCEEDED" "L3 11th CORTE rejected"
for i in $(seq 21); do echo "CONV DD=T,1K,1,3,1/40,10,10"; done > "$W/l4.sysin"
limit_test l4 "$GENER" "CONV TABLE LIMIT (20) EXCEEDED" "L4 21st CONV rejected"

# --- N1..N9: negative parse paths ----------------------------------
neg_test () {
    local tag=$1 bin=$2 card=$3 msg=$4 name=$5
    printf "%s\n" "$card" > "$W/$tag.sysin"
    printf "AAA\n" > "$W/$tag.ut1"
    run "$bin" "$tag"
    if [ $RC -eq 12 ] && grep -q "$msg" "$W/$tag.prt"
    then ok "$name"
    else bad "$name" "rc=$RC"; fi
}
neg_test n1 "$GENER" "RCIN 1,3,EQ,X'ABC'" \
    "HEX LITERAL MUST HAVE EVEN LENGTH" "N1 odd hex literal"
neg_test n2 "$GENER" "RCIN 1,4,EQ,X'aB2z'" \
    "INVALID HEX DIGIT" "N2 invalid hex digit"
neg_test n3 "$GENER" "FIELD 1234567,3,MOVE,1" \
    "NUMERIC OPERAND EXCEEDS 6 DIGITS" "N3 oversized numeric operand"
neg_test n4 "$LISTA" "PRINT FR=" \
    "KEYWORD WITHOUT VALUE" "N4 valueless keyword"
neg_test n5 "$GENER" "CONV DD=T,1,50,251/1,10,250" \
    "CONV TABLE OFFSETS EXCEED 256-BYTE ROW" "N5 CONV geometry"
neg_test n6 "$GENER" " FIELD 1,3,MOVE,1" \
    "OP-CODE MUST START IN COLUMN 1" "N6 column-1 rule"
neg_test n7 "$GENER" "FIELD 1,3,MOVE,T10" \
    "PREFIX NOT VALID IN OSGENER" "N7 T-prefix in OSGENER"
neg_test n8 "$GENER" "RCIN 1,3,EQ,'A' .AND. 4,3,EQ,'B' .OR. 7,3,EQ,'C'" \
    "MIXED .AND./.OR." "N8 mixed AND/OR families"
neg_test n9 "$GENER" "FIELD 32755,10,MOVE,1" \
    "FIELD INPUT OUTSIDE RECORD BUFFER" "N9 bounds validator"

echo "=================================================="
echo "RESULT: $PASS passed, $FAIL failed"
echo "=================================================="
[ $FAIL -eq 0 ]
