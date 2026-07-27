# Test Output

* run it with:

```bash
make test
```

* output:

```text
Compiling OSGENER (stub + engine)...
cobc -x -std=mvs -ffilename-mapping -I src/copy/gnucobol -o ./bin/OSGENER \
    src/stubs/OSGENER.CBL src/OSENGINE.CBL
Compiling OSLISTA (stub + engine)...
cobc -x -std=mvs -ffilename-mapping -I src/copy/gnucobol -o ./bin/OSLISTA \
    src/stubs/OSLISTA.CBL src/OSENGINE.CBL
==================================================
 BUILD COMPLETE: ./bin/OSGENER, OSLISTA
==================================================
Compiling unit test harness...
cobc -x -std=mvs -ffilename-mapping -I src/copy/gnucobol -o ./bin/OSTESTS tests/OSTESTS.CBL
--- Unit tests ---
./bin/OSTESTS
==================================================
SCD ENGINE - AUTOMATED UNIT TEST SUITE ACTIVE     
==================================================
TC-01 (zDVy Mod-10 Checksum)  : PASSED    
TC-02 (UNPK Mainframe COMP-3) : PASSED    
TC-03 (INCON ND Active Clean) : PASSED    
TC-04 (CODIG Relational Chk)  : PASSED    
TC-05 (COND Indicator Route)  : PASSED    
==================================================
END OF TEST SUITE EXECUTION                       
==================================================
--- Integration simulation ---
bash tests/run_sim.sh
==================================================
1. Generating test datasets...
Datasets ready in ./datasets/.
==================================================
2. Running OSGENER...
>> OSGENER done (rc=0).
==================================================
3. Running OSLISTA...
>> OSLISTA done (rc=0).
==================================================
Outputs:
  ./datasets/sysut2.dat           - OSGENER main output
  ./datasets/sysut5_rejects.dat  - CODIG orphan batches
  ./datasets/sysut2_lista.dat     - OSLISTA listing
  ./logs/syslist.log           - inconsistency report
  ./logs/sysprint_*.log        - operation logs
==================================================
--- Golden-file regression ---
bash tests/golden_check.sh
PASS  golden: sysut2.dat
PASS  golden: sysut5_rejects.dat
PASS  golden: sysut2_lista.dat
PASS  golden: syslist.log
--- Engine test suite (behavior/limits/negative) ---
bash tests/run_tests.sh
PASS  I1 div-zero warning, rc=0
PASS  I2 FD edges: 4 violations logged, 6 records kept
PASS  I3 CONV /INT ceiling lookup + miss default (ABCC)
PASS  I4 GENER priority-slot ordering (arrival 2,0,1 -> 0,1,2)
PASS  I5 HEXA expansion (ABC -> 414243)
PASS  I6 Z6D2 edit mask (012345 -> 123,45)
PASS  I7 negative packed decode (X'413D' -> -413)
PASS  I8 UNPK nibble expansion (X'413D' -> 413)
PASS  I9 (G2) INCON relational: 1 of 2 flagged
PASS  I10 (G4) zoned overpunch negative (0J -> -1)
PASS  I11 (G4) binary two's-complement (X'FFFF' -> -1)
PASS  I12 (G5) ACUM literals (100 + 2.5 = 102,50)
PASS  I13 (G5) implied decimals (Z2: 12345 -> 123,45)
PASS  I14 (G7) duplicate code dropped, first kept, logged
PASS  I15 (G3/G8) CARRO WC1 emits form-feed page eject
PASS  I16 (G1) TIT field map renders page-lead record
PASS  I17 (M3) glued .Y. is AND (A1 only)
PASS  I18 (M3) glued .O. is OR (A2,B1,B2)
PASS  I19 (M3) OR-of-ANDs across '/' (A1,B1)
PASS  I20 (M3) family switch across '/' (A1,A2,B1)
PASS  I21 (M3) CONDx group: flag set for both A and B, not C
PASS  I21b (M3) CONDx AND-group folds (A1 only)
PASS  I22 (M1) RCIN omitted operator = EQ
PASS  I23 (M1) CONDx omitted operator = EQ (A1,B1 flagged)
PASS  I24 (M1) INCON omitted operator = EQ (1 violation)
PASS  I25 (M2) count window GT,2 .Y. LT,5 -> r3,r4
PASS  I26 (M2) RCOUT LT,3 skips records 1-2
PASS  I27 (M2) count+field in one AND-run on CONDx (r5,r6)
PASS  I28 (M17) .O. alternation: 1 violation (Z only)
PASS  I29 (M17) '/' is AND: 6 independent violations
PASS  I30 (D0.9) corrector rejected as .O. alternative
PASS  I31 (M26) reads columns 810 and 1062 (was X(800))
PASS  I32 (M27) both FIELD groups applied
PASS  I33 (M27) 4 mixed groups incl. CL widths
PASS  I34 (M27/M15) both CORTE levels and both ID literals
PASS  I35 (M9) empty conv behaves as MOVE
PASS  I36 (M4) literal multiply 150*3
PASS  I37 (M4) literal divide 150/3
PASS  I38 (M4) chained literals (150+50)/100
PASS  I39 (M11) inline SYSIN CONV table + fall-through row
PASS  I40 (M11/M12) inline /INT table gated on CONV2
PASS  I41 (M12) CONVx suppressed when its flag is off
PASS  I42 (M6) S-prefixed input offset reads SYSUT3
PASS  I43 (M7) all nine print lines emitted
PASS  I44 (M29) AN/AB/NO class corrections
PASS  I45 (M20) AN emits the written-record counter
PASS  I46 (M16) CORTE I,s02 echoes the breaking field
PASS  I47 (M25) page legend printed without a TIT card
PASS  I48 (M24) TIT literal continued on the next card
PASS  I49 (M21) HEXA input length cap enforced
PASS  L1 151st condition rejected
PASS  L2 126th FIELD rejected
PASS  L3 11th CORTE rejected
PASS  L4 21st CONV rejected
PASS  N1 odd hex literal
PASS  N2 invalid hex digit
PASS  N3 oversized numeric operand
PASS  N4 valueless keyword
PASS  N5 CONV geometry
PASS  N6 column-1 rule
PASS  N7 T-prefix in OSGENER
PASS  N8 mixed AND/OR families
PASS  N9 bounds validator
==================================================
RESULT: 63 passed, 0 failed
==================================================
--- Manual-example conformance (plan Phase 9) ---
bash tests/manual_examples.sh
==================================================================
 OSLISTA - manual sheets 5 to 17
==================================================================
--- sheet 5: PRINT ---
PASS   H5-1    PRINT FL=X,FR=2000,SK=10,SP=1,SR=2
PASS   H5-2    PRINT FL=C,SR=2
PASS   H5-3    PRINT FR=9000
--- sheet 6: TIT ---
PASS   H6-1    TIT1 FA10,S2,L40,'PRIMER TITULO EJEMPLO'
PASS   H6-2    TIT2 'ESTE ES UN EJEMPLO DE UNA SEGUNDA LINEA DE TITULO'
PASS   H6-3    TIT3 'ESTE TITULO CONTINUA EN OTRA FICHA
CONTINUACION TITULO 3'
PASS   H6-4    TIT4 (32,5,,21),'LISTADO DE SUCURSAL XXXXX'
PASS   H6-5    TIT5 S3,'**********************************************'
PASS   H6-6    TIT1 FN,'DATE AT DEFAULT COLUMN 91'
PASS   H6-7    TIT1 FA,'DATE AT DEFAULT COLUMN 91'
--- sheet 7: CLAVE ---
PASS   H7-1    CLAVE    1,8,1
PASS   H7-2    CLAVE    10,5,24
PASS   H7-3    CLAVE   13,2,18
PASS   H7-4    CLAVE   174,20,22
--- sheet 8: RCIN / RCOUT ---
PASS   H8-1    RCIN 9,NE,'c:2345'/24,GT,'888'
PASS   H8-2    RCIN 27,,'9'.Y.20,,'5'.Y.180,GT,'68'.Y.LT,18000
PASS   H8-3    RCIN 17,NE,'7'/285,LT,'36'/47,,X'150F'.O.47,,X'150C'
PASS   H8-4    RCIN   GT,4000.AND.LT,5000/GT,6000.Y.LT,10000
PASS   H8-5    RCOUT  LT,8000
PASS   H8-6    RCOUT  475,LE,'4856'.OR.13,NE,'3'
PASS   H8-7    RCOUT S17,GT,'18'/17,GE,'70'.Y.22,,'9'
--- sheet 9: COND ---
PASS   H9-1    COND1  4,,'10'.Y.28,LT,'260'/4,,'20'.Y.29,LT,'260'
PASS   H9-2    COND7  18,GE,'1990'
PASS   H9-3    COND6  GT,2500.Y.LT,5000
PASS   H9-4    COND3  18,,X'14F0'/18,,X'14C0'
PASS   H9-5    COND2  34,LT,'889'.Y.787,,'BANCO RURAL'.Y.810,,'SUC: CENTRO'
PASS   H9-6    COND1 S10,,'4'/70,,'A'/70,,'C'/70,,'D'/70,,'S'/70,,'7'/70,,'9'
--- sheet 10: ACUM ---
PASS   H10-1   ACUM1  +,Z,18,8/*,2000/-,B,9,3//,6/+,P,5,4
PASS   H10-2   ACUM2  +,Z,40,8/*,200/-,B,8,2/+,S,492,8/-,Z,150,3/*,8
PASS   H10-3   ACUM32 -,Z,6,3/*,Z,18,2//,S,25,3
PASS   H10-4   ACUM88  +,Z,188,6/+,Z,188,6/*,Z,188,6
PASS   H10-5   ACUM35  +,Z,68,8//,48/*,2000/-,S,24,6/*,15
PASS   H10-6   ACUM36  +,Z,400,9/+,50//100
--- sheet 12: FIELD (OSLISTA) ---
PASS   H12-1   FIELD EC=12/18,2,M,4/20,4,,10/24,6,U,20/30,5,P7D1,38
PASS   H12-2   FIELD 36,4,M,48/42,8,,O8/58,7,Z9D2,70/'TIPO DE TAREA',88
PASS   H12-3   FIELD 70,10,Z7D0,104/80,30,,S1/204,12,M,S42/A5,Z9D2,69
PASS   H12-4   FIELD S2,5,,S90/8,10,P8D2,S70/270,80,,T1/S90,100,,X10
PASS   H12-5   FIELD 22,2,,20/'/',22/24,2,,23/'/',25/26,2,,26
--- sheet 14: CONV (OSLISTA) ---
PASS   H14-1   CONV  22,1,10/23,9,20
PASS   H14-2   CONV2  18,3,1/18,3,10/INT
PASS   H14-3   CONV   10,1,5/11,09,8
PASS   H14-4   CONV3  DD=DDCARD/132,10,12/T100,10,1
PASS   H14-5   CONV5  TIT3/10K/80,8,1/S24,20,10
--- sheet 15: CORTE ---
PASS   H15-1   CORTE F/10,18,2,ID='CUENTA',1,I,8/2,4,2,ID='CAJA',1,I,8
PASS   H15-2   CORTE 196,5,ID='TOTAL PARCIAL',1
PASS   H15-3   CORTE 352,1,3,ID='CODIGO',1,I,8/52,3
PASS   H15-4   CORTE 1,2/4,8/62,5
PASS   H15-5   CORTE CT,1000
--- sheet 16: IMCOR ---
PASS   H16-1   IMCOR CANT,1/10,9,Z7D2,12/36,3,P3D0,30/A9,P9D0,118
PASS   H16-2   IMCOR 136,4,PBD1,42/264,2,B5D0,54
PASS   H16-3   IMCOR 84,11,ZBD0,68/98,7,ZDD2,90
--- sheet 17: CARRO ---
PASS   H17-1   CARRO W2A,,W3A,W1A
PASS   H17-2   CARRO W2A,WC2,W1A,WCA,WC1
PASS   H17-3   CARRO SC1,W1A,W2A,W1A,WC3,W1A,W1A
==================================================================
 OSGENER - manual sheets 24 to 35
==================================================================
--- sheet 24: PESQIN / PESQOUT ---
PASS   H24-1   PESQIN    1,9,1
PASS   H24-2   PESQIN    12,3,21
PASS   H24-3   PESQOUT   100,4,18
PASS   H24-4   PESQOUT   10,20,5
--- sheet 26: COPY ---
PASS   H26-1   COPY   FR=10,LR=100,FR=1500,LR=3800,SK=58/FR=8000,LR=9000
PASS   H26-2   COPY   LR=200
PASS   H26-3   COPY   FR=1521,LR=1830
PASS   H26-4   COPY   SK=1000
--- sheet 27: GENER ---
PASS   H27-1   GENER  1,10/80,1/'0','1','2','3'
PASS   H27-2   GENER  76,5/74,2/'10','20','80','90','91','92','97'
PASS   H27-3   GENER  1,5/77,3/'000','111'
--- sheet 28: INCON ---
PASS   H28-1   INCON '090'/1,9,N/1,GT,'00001000'/1,LT,'12001891'
PASS   H28-2   INCON '090'/9,6,AB/9,,'71'/20,22,AB/50,,'4'.O.50,,'5'.O.50,,'7'
PASS   H28-3   INCON '091'/12,4,ND/12,LT,'66'/S2,7,FD/66,GT,'880'
PASS   H28-4   INCON '092'/46,8,N/64,6,AN/60,5,ND/60,GT,'00000'
PASS   H28-5   INCON '092'/18,,'1'.O.18,,'3'.O.18,,'S'.O.18,,'6'.O.18,,'9'
PASS   H28-6   INCON '092'/33,26,AN/24,LT,'18'.O.24,GT,'62'
PASS   H28-7   INCON '092'/33,26,A
PASS   H28-8   INCON '092'/33,26,ANB
PASS   H28-9   INCON '092'/33,7,FA
--- sheet 29: CODIG ---
PASS   H29-1   CODIG  '10',OBL
PASS   H29-2   CODIG  '20',OBL,'30'
PASS   H29-3   CODIG  '30',OBL,'40'
PASS   H29-4   CODIG  '91',OBL,'92','93','91','95'
PASS   H29-5   CODIG  '90',OBL
--- sheet 30: TIT (OSGENER SYSLIST heading) ---
PASS   H30-1   TIT L18,'  ERRORES  EN  ARMADO  DEL  ARCHIVO  MAESTRO  '
PASS   H30-2   TIT  ' LISTADO   DE   INCONSISTENCIAS   '
--- sheet 33: FIELD (OSGENER) ---
PASS   H33-1   FIELD   1,80,,1/81,8,ZP,89,5/84,8,ZB,81,4/102,7,ZZ,100,10/200,70,,51
PASS   H33-2   FIELD   '0',CL,1,320/10,5,PZ,1,3/A8,Z,4,5/'222',13/'333',S10
PASS   H33-3   FIELD1  '333',18/A3,P,15,3/10,9,ZP,25,5/20,8,,30/72,2,BP,39,3
PASS   H33-4   FIELD2  '444',18/A2,P,15,3/10,9,ZP,25,5/20,5,,30/38,2,BZ,45,5
PASS   H33-5   FIELD3  A4,B,12,4/A5,Z,48,10/'10101010',68/18,24,AB,18/43,5,,S22
PASS   H33-6   FIELD    S44,8,ZS,281,3/1062,5,SZ,304,8/1,4,ZDVZ,1,5/10,3,NO,10
PASS   H33-7   FIELD   AN,Z,10,6
--- sheet 35: CONV (OSGENER) ---
PASS   H35-1   CONV  22,1,10/23,4,20
PASS   H35-2   CONV2  35,3,1/18,3,10/INT
PASS   H35-3   CONV5  DD=DDCINTA/5K/80,4,1/S85,18,5
PASS   H35-4   CONV   10,1,5/11,09,8
PASS   H35-5   CONV3  DD=DDCATD/132,10,12/100,10,9

==================================================================
 manual examples: 93 PASS  0 FAIL  0 XFAIL (known gaps)  0 XPASS
==================================================================
--- Real-mainframe regression (private job data) ---
bash tests/mainframe_check.sh
==================================================================
 Real-mainframe regression
==================================================================
PASS  STEP03   16943 records match the mainframe  (NUL records excluded)
PASS  STEP05   17004 records match the mainframe  (NUL records excluded)
PASS  STEP21   15561 records match the mainframe
PASS  STEP23    5706 records match the mainframe
PASS  STEP27    1360 records match the mainframe
PASS  STEP33    7023 records match the mainframe
PASS  STEP35       1 records match the mainframe
PASS  STEP37    7024 records match the mainframe
NOTE  1 further step skipped: its expected output was not captured
==================================================================
 mainframe steps: 8 PASS  0 FAIL
==================================================================
```
