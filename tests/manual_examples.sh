#!/bin/bash
# ===================================================================
# MANUAL-EXAMPLE CONFORMANCE SUITE  (plan Phase 9 / item 9.2)
#
# One case per control-card example printed in the genuine SCD 1/84
# manual (osgener/docs/OSLSGEN.txt, translated in osgenls-manual.md).
# Case IDs are H<sheet>-<n>, matching the manual's "HOJA" numbering.
#
# Each case is fed to the REAL binary and classified:
#   PASS   expected to be accepted, and was
#   FAIL   expected to be accepted, but the card was rejected   <-- gate
#   XFAIL  expected to fail (known gap Mnn), and did
#   XPASS  expected to fail, but now passes -> reclassify in the plan
#
# Exit code: 0 unless a FAIL occurred.  XPASS is reported loudly but
# does not break the build; it means a gap was closed and the
# expectation table below plus plan Phase 9 must be updated.
#
# Cards are coded as the manual PRINTS them, except for the
# transcription slips catalogued in osgenls-manual.md Appendix A,
# which are coded in their corrected reading (the syntax the manual
# describes).  Corrections are marked "[fix]" in the case comment.
# ===================================================================
cd "$(dirname "$0")/.." || exit 1

GC_BIN="/c/ProgramData/chocolatey/lib/gnucobol/tools/bin"
if [ -d "$GC_BIN" ]; then PATH="$GC_BIN:$PATH"; fi

W="tests/work-manual"
rm -rf "$W" && mkdir -p "$W"

resolve_bin () {
    if [ -x "bin/$1" ]; then echo "bin/$1"
    elif [ -x "bin/$1.exe" ]; then echo "bin/$1.exe"
    else echo "ERROR: bin/$1 missing - run 'make all' first" >&2; exit 1
    fi
}
G=$(resolve_bin OSGENER) || exit 1
L=$(resolve_bin OSLISTA) || exit 1

# 300-byte input records so the manual's offsets are inside the buffer
printf '%-300s\n' "0123456789" > "$W/ut1"
printf '%-300s\n' "0123456789" > "$W/ut3"
printf '%-300s\n' "0123456789" > "$W/ut6"
printf '%-80s\n'  "AAA"        > "$W/tab"

PASS=0; FAIL=0; XFAIL=0; XPASS=0
FAILED_IDS=""; XPASSED_IDS=""

# mx <id> <bin> <expect: OK | Mnn> <prelude|""> <card>
mx () {
    local id="$1" bin="$2" want="$3" pre="$4" card="$5"
    local d="$W/$id"
    : > "$d.sysin"
    [ -n "$pre" ] && printf '%b\n' "$pre" >> "$d.sysin"
    printf '%s\n' "$card" >> "$d.sysin"

    SYSIN="$d.sysin" SYSUT1="$W/ut1" SYSUT3="$W/ut3" SYSUT6="$W/ut6" \
    SYSUT2="$d.out" SYSUT4="$d.u4" SYSUT5="$d.u5" \
    SYSPRINT="$d.prt" SYSLIST="$d.lst" \
    DDCARD="$W/tab" DDCINTA="$W/tab" DDCATD="$W/tab" \
    "$bin" >/dev/null 2>&1
    local rc=$?
    local err
    err=$(grep -m1 "CARD ERROR" "$d.prt" 2>/dev/null | sed 's/^ *\*\*\* //')

    if [ $rc -eq 0 ] && [ -z "$err" ]; then
        if [ "$want" = "OK" ]; then
            PASS=$((PASS+1)); printf 'PASS   %-7s %s\n' "$id" "$card"
        else
            XPASS=$((XPASS+1)); XPASSED_IDS="$XPASSED_IDS $id($want)"
            printf 'XPASS  %-7s %s   <-- gap %s appears CLOSED\n' \
                   "$id" "$card" "$want"
        fi
    else
        if [ "$want" = "OK" ]; then
            FAIL=$((FAIL+1)); FAILED_IDS="$FAILED_IDS $id"
            printf 'FAIL   %-7s %s\n           rc=%s %s\n' \
                   "$id" "$card" "$rc" "$err"
        else
            XFAIL=$((XFAIL+1))
            printf 'XFAIL  %-7s [%s] %s\n' "$id" "$want" "$card"
        fi
    fi
}

GEN3="GENER  1,3/80,1/'0','1','2'"
GEN2="GENER  1,3/80,2/'10','20','30','40','90','91','92','93','95'"

echo "=================================================================="
echo " OSLISTA - manual sheets 5 to 17"
echo "=================================================================="

echo "--- sheet 5: PRINT ---"
mx H5-1  "$L" OK  "" "PRINT FL=X,FR=2000,SK=10,SP=1,SR=2"
mx H5-2  "$L" OK  "" "PRINT FL=C,SR=2"                          # [fix] SR02
mx H5-3  "$L" OK  "" "PRINT FR=9000"

echo "--- sheet 6: TIT ---"
mx H6-1  "$L" OK  "" "TIT1 FA10,S2,L40,'PRIMER TITULO EJEMPLO'"  # [fix] 140
mx H6-2  "$L" OK  "" "TIT2 'ESTE ES UN EJEMPLO DE UNA SEGUNDA LINEA DE TITULO'"
mx H6-3  "$L" OK  "" "TIT3 'ESTE TITULO CONTINUA EN OTRA FICHA
CONTINUACION TITULO 3'"
mx H6-4  "$L" OK  "" "TIT4 (32,5,,21),'LISTADO DE SUCURSAL XXXXX'"
mx H6-5  "$L" OK  "" "TIT5 S3,'**********************************************'"
# prose-only forms on sheet 6 (bare FN / FA default to column 91)
mx H6-6  "$L" OK  "" "TIT1 FN,'DATE AT DEFAULT COLUMN 91'"
mx H6-7  "$L" OK  "" "TIT1 FA,'DATE AT DEFAULT COLUMN 91'"

echo "--- sheet 7: CLAVE ---"
mx H7-1  "$L" OK  "" "CLAVE    1,8,1"
mx H7-2  "$L" OK  "" "CLAVE    10,5,24"
mx H7-3  "$L" OK  "" "CLAVE   13,2,18"
mx H7-4  "$L" OK  "" "CLAVE   174,20,22"

echo "--- sheet 8: RCIN / RCOUT ---"
mx H8-1  "$L" OK  "" "RCIN 9,NE,'c:2345'/24,GT,'888'"
mx H8-2  "$L" OK  "" "RCIN 27,,'9'.Y.20,,'5'.Y.180,GT,'68'.Y.LT,18000"  # [fix] 20,,5
mx H8-3  "$L" OK  "" "RCIN 17,NE,'7'/285,LT,'36'/47,,X'150F'.O.47,,X'150C'"
mx H8-4  "$L" OK  "" "RCIN   GT,4000.AND.LT,5000/GT,6000.Y.LT,10000"   # [fix] GT.4000
mx H8-5  "$L" OK  "" "RCOUT  LT,8000"
mx H8-6  "$L" OK  "" "RCOUT  475,LE,'4856'.OR.13,NE,'3'"
mx H8-7  "$L" OK  "CLAVE 1,8,1" "RCOUT S17,GT,'18'/17,GE,'70'.Y.22,,'9'"

echo "--- sheet 9: COND ---"
mx H9-1  "$L" OK  "" "COND1  4,,'10'.Y.28,LT,'260'/4,,'20'.Y.29,LT,'260'"
mx H9-2  "$L" OK  "" "COND7  18,GE,'1990'"
mx H9-3  "$L" OK  "" "COND6  GT,2500.Y.LT,5000"
mx H9-4  "$L" OK  "" "COND3  18,,X'14F0'/18,,X'14C0'"            # [fix] odd-length hex
mx H9-5  "$L" OK  "" "COND2  34,LT,'889'.Y.787,,'BANCO RURAL'.Y.810,,'SUC: CENTRO'"
mx H9-6  "$L" OK  "CLAVE 1,8,1" "COND1 S10,,'4'/70,,'A'/70,,'C'/70,,'D'/70,,'S'/70,,'7'/70,,'9'"

echo "--- sheet 10: ACUM ---"
mx H10-1 "$L" OK  "" "ACUM1  +,Z,18,8/*,2000/-,B,9,3//,6/+,P,5,4"
mx H10-2 "$L" OK  "" "ACUM2  +,Z,40,8/*,200/-,B,8,2/+,S,492,8/-,Z,150,3/*,8"  # [fix] *8
mx H10-3 "$L" OK  "" "ACUM32 -,Z,6,3/*,Z,18,2//,S,25,3"
mx H10-4 "$L" OK  "" "ACUM88  +,Z,188,6/+,Z,188,6/*,Z,188,6"
mx H10-5 "$L" OK  "" "ACUM35  +,Z,68,8//,48/*,2000/-,S,24,6/*,15"  # [fix] *15
mx H10-6 "$L" OK  "" "ACUM36  +,Z,400,9/+,50//100"

echo "--- sheet 12: FIELD (OSLISTA) ---"
mx H12-1 "$L" OK   "" "FIELD EC=12/18,2,M,4/20,4,,10/24,6,U,20/30,5,P7D1,38"
mx H12-2 "$L" OK  "" "FIELD 36,4,M,48/42,8,,O8/58,7,Z9D2,70/'TIPO DE TAREA',88"
mx H12-3 "$L" OK  "ACUM5 +,Z,1,3" "FIELD 70,10,Z7D0,104/80,30,,S1/204,12,M,S42/A5,Z9D2,69"
mx H12-4 "$L" OK  "CLAVE 1,8,1" "FIELD S2,5,,S90/8,10,P8D2,S70/270,80,,T1/S90,100,,X10"
mx H12-5 "$L" OK  "" "FIELD 22,2,,20/'/',22/24,2,,23/'/',25/26,2,,26"

echo "--- sheet 14: CONV (OSLISTA) ---"
mx H14-1 "$L" OK  "" "CONV  22,1,10/23,9,20"
mx H14-2 "$L" OK  "" "CONV2  18,3,1/18,3,10/INT"
mx H14-3 "$L" OK  "" "CONV   10,1,5/11,09,8"
mx H14-4 "$L" OK  "" "CONV3  DD=DDCARD/132,10,12/T100,10,1"
mx H14-5 "$L" OK  "" "CONV5  TIT3/10K/80,8,1/S24,20,10"

echo "--- sheet 15: CORTE ---"
mx H15-1 "$L" OK  "" "CORTE F/10,18,2,ID='CUENTA',1,I,8/2,4,2,ID='CAJA',1,I,8"
mx H15-2 "$L" OK  "" "CORTE 196,5,ID='TOTAL PARCIAL',1"
mx H15-3 "$L" OK  "" "CORTE 352,1,3,ID='CODIGO',1,I,8/52,3"
mx H15-4 "$L" OK  "" "CORTE 1,2/4,8/62,5"
mx H15-5 "$L" OK  "" "CORTE CT,1000"

echo "--- sheet 16: IMCOR ---"
mx H16-1 "$L" OK "CORTE F,ID='T',1\nACUM9 +,Z,1,3" \
    "IMCOR CANT,1/10,9,Z7D2,12/36,3,P3D0,30/A9,P9D0,118"
mx H16-2 "$L" OK "CORTE F,ID='T',1" "IMCOR 136,4,PBD1,42/264,2,B5D0,54"  # [fix] B5,D0
mx H16-3 "$L" OK "CORTE F,ID='T',1" "IMCOR 84,11,ZBD0,68/98,7,ZDD2,90"

echo "--- sheet 17: CARRO ---"
mx H17-1 "$L" OK  "" "CARRO W2A,,W3A,W1A"
mx H17-2 "$L" OK  "" "CARRO W2A,WC2,W1A,WCA,WC1"
mx H17-3 "$L" OK  "" "CARRO SC1,W1A,W2A,W1A,WC3,W1A,W1A"

echo "=================================================================="
echo " OSGENER - manual sheets 24 to 35"
echo "=================================================================="

echo "--- sheet 24: PESQIN / PESQOUT ---"
mx H24-1 "$G" OK  "" "PESQIN    1,9,1"
mx H24-2 "$G" OK  "" "PESQIN    12,3,21"
mx H24-3 "$G" OK  "" "PESQOUT   100,4,18"
mx H24-4 "$G" OK  "" "PESQOUT   10,20,5"

echo "--- sheet 26: COPY ---"
mx H26-1 "$G" OK  "" "COPY   FR=10,LR=100,FR=1500,LR=3800,SK=58/FR=8000,LR=9000"
mx H26-2 "$G" OK  "" "COPY   LR=200"
mx H26-3 "$G" OK  "" "COPY   FR=1521,LR=1830"
mx H26-4 "$G" OK  "" "COPY   SK=1000"

echo "--- sheet 27: GENER ---"
mx H27-1 "$G" OK  "" "GENER  1,10/80,1/'0','1','2','3'"
mx H27-2 "$G" OK  "" "GENER  76,5/74,2/'10','20','80','90','91','92','97'"
mx H27-3 "$G" OK  "" "GENER  1,5/77,3/'000','111'"

echo "--- sheet 28: INCON ---"
mx H28-1 "$G" OK  "$GEN3" "INCON '090'/1,9,N/1,GT,'00001000'/1,LT,'12001891'"
mx H28-2 "$G" OK  "$GEN3" "INCON '090'/9,6,AB/9,,'71'/20,22,AB/50,,'4'.O.50,,'5'.O.50,,'7'"   # [fix] BA
mx H28-3 "$G" OK  "$GEN3\nCLAVE 1,8,1" "INCON '091'/12,4,ND/12,LT,'66'/S2,7,FD/66,GT,'880'"
mx H28-4 "$G" OK  "$GEN3" "INCON '092'/46,8,N/64,6,AN/60,5,ND/60,GT,'00000'"                  # [fix] NO
mx H28-5 "$G" OK  "$GEN3" "INCON '092'/18,,'1'.O.18,,'3'.O.18,,'S'.O.18,,'6'.O.18,,'9'"
mx H28-6 "$G" OK  "$GEN3" "INCON '092'/33,26,AN/24,LT,'18'.O.24,GT,'62'"
# the remaining documented codig values (sheet 28 table, no printed example)
mx H28-7 "$G" OK  "$GEN3" "INCON '092'/33,26,A"
mx H28-8 "$G" OK  "$GEN3" "INCON '092'/33,26,ANB"
mx H28-9 "$G" OK  "$GEN3" "INCON '092'/33,7,FA"

echo "--- sheet 29: CODIG ---"
mx H29-1 "$G" OK  "$GEN2" "CODIG  '10',OBL"
mx H29-2 "$G" OK  "$GEN2" "CODIG  '20',OBL,'30'"
mx H29-3 "$G" OK  "$GEN2" "CODIG  '30',OBL,'40'"
mx H29-4 "$G" OK  "$GEN2" "CODIG  '91',OBL,'92','93','91','95'"
mx H29-5 "$G" OK  "$GEN2" "CODIG  '90',OBL"

echo "--- sheet 30: TIT (OSGENER SYSLIST heading) ---"
mx H30-1 "$G" OK  "$GEN3" "TIT L18,'  ERRORES  EN  ARMADO  DEL  ARCHIVO  MAESTRO  '"  # [fix] 18
mx H30-2 "$G" OK  "$GEN3" "TIT  ' LISTADO   DE   INCONSISTENCIAS   '"

echo "--- sheet 33: FIELD (OSGENER) ---"
mx H33-1 "$G" OK  "" "FIELD   1,80,,1/81,8,ZP,89,5/84,8,ZB,81,4/102,7,ZZ,100,10/200,70,,51"   # [fix] 1;80
mx H33-2 "$G" OK  "ACUM8 +,Z,1,3" "FIELD   '0',CL,1,320/10,5,PZ,1,3/A8,Z,4,5/'222',13/'333',S10"
mx H33-3 "$G" OK  "ACUM3 +,Z,1,3" "FIELD1  '333',18/A3,P,15,3/10,9,ZP,25,5/20,8,,30/72,2,BP,39,3"
mx H33-4 "$G" OK  "ACUM2 +,Z,1,3" "FIELD2  '444',18/A2,P,15,3/10,9,ZP,25,5/20,5,,30/38,2,BZ,45,5"
mx H33-5 "$G" OK  "ACUM4 +,Z,1,3\nACUM5 +,Z,1,3" "FIELD3  A4,B,12,4/A5,Z,48,10/'10101010',68/18,24,AB,18/43,5,,S22"
mx H33-6 "$G" OK  "CLAVE 1,8,1" "FIELD    S44,8,ZS,281,3/1062,5,SZ,304,8/1,4,ZDVZ,1,5/10,3,NO,10"  # [fix] ZD/Z
# prose-only form on sheet 32: AN = written-record counter
mx H33-7 "$G" OK  "" "FIELD   AN,Z,10,6"

echo "--- sheet 35: CONV (OSGENER) ---"
mx H35-1 "$G" OK  "" "CONV  22,1,10/23,4,20"
mx H35-2 "$G" OK  "" "CONV2  35,3,1/18,3,10/INT"                 # [fix] 3.1
mx H35-3 "$G" OK  "" "CONV5  DD=DDCINTA/5K/80,4,1/S85,18,5"
mx H35-4 "$G" OK  "" "CONV   10,1,5/11,09,8"
mx H35-5 "$G" OK  "" "CONV3  DD=DDCATD/132,10,12/100,10,9"

echo
echo "=================================================================="
printf ' manual examples: %d PASS  %d FAIL  %d XFAIL (known gaps)  %d XPASS\n' \
       "$PASS" "$FAIL" "$XFAIL" "$XPASS"
echo "=================================================================="
if [ -n "$XPASSED_IDS" ]; then
    echo " XPASS:$XPASSED_IDS"
    echo " -> a documented gap now works. Reclassify the case to OK and"
    echo "    mark the gap done in docs/plan.md."
fi
if [ "$FAIL" -ne 0 ]; then
    echo " FAILED:$FAILED_IDS"
    exit 1
fi
exit 0
