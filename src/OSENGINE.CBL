      *================================================================
      * OSENGINE.CBL - UNIFIED SCD 1/84 UTILITY ENGINE
      * PERSONALITIES: OSGENER (FILE GENERATION) / OSLISTA (LISTINGS)
      * TARGET: GNUCOBOL -std=mvs (MAINFRAME PERSONALITY), COBOL-85
      * CALLED AS SUBPROGRAM BY STUBS WITH MODE PIC X(7)
      * SPEC: docs/manual/OSLSGEN.txt - THE GENUINE SCD 1/84 MANUAL
      * DECISIONS: PLAN 2026-07-23 D0.1-D0.7 (SEE PLAN FILE)
      *================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. OSENGINE.
      *
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT SYSIN-F   ASSIGN TO "SYSIN"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-SYSIN.
           SELECT SYSUT1-F  ASSIGN TO "SYSUT1"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-UT1.
           SELECT OPTIONAL SYSUT3-F  ASSIGN TO "SYSUT3"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-UT3.
           SELECT OPTIONAL SYSUT6-F  ASSIGN TO "SYSUT6"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-UT6.
           SELECT SYSUT2-F  ASSIGN TO "SYSUT2"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-UT2.
           SELECT SYSUT4-F  ASSIGN TO "SYSUT4"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-UT4.
           SELECT SYSUT5-F  ASSIGN TO "SYSUT5"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-UT5.
           SELECT SYSPRINT-F ASSIGN TO "SYSPRINT"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-PRT.
           SELECT SYSLIST-F ASSIGN TO "SYSLIST"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-LST.
      *    G9: THE CONV-TABLE SELECT IS DIALECT-BOUND (DYNAMIC VS
      *    NATIVE VARIABLE ASSIGN) - RESOLVED VIA COPYBOOK FROM
      *    copy/<DIALECT>/ SELECTED BY THE COMPILER INCLUDE PATH
           COPY SELCONV.
      *
       DATA DIVISION.
       FILE SECTION.
       FD  SYSIN-F.
       01  SYSIN-REC            PIC X(80).
       FD  SYSUT1-F.
       01  SYSUT1-REC           PIC X(32760).
       FD  SYSUT3-F.
       01  SYSUT3-REC           PIC X(32760).
       FD  SYSUT6-F.
       01  SYSUT6-REC           PIC X(80).
       FD  SYSUT2-F.
       01  SYSUT2-REC           PIC X(32760).
       FD  SYSUT4-F.
       01  SYSUT4-REC           PIC X(32760).
       FD  SYSUT5-F.
       01  SYSUT5-REC           PIC X(80).
       FD  SYSPRINT-F.
       01  SYSPRINT-REC         PIC X(132).
       FD  SYSLIST-F.
       01  SYSLIST-REC          PIC X(132).
       FD  CONVTAB-F.
       01  CONVTAB-REC          PIC X(256).
      *
       WORKING-STORAGE SECTION.
      *----------------------------------------------------------------
      * GLOBAL STATE AND FILE STATUS
      *----------------------------------------------------------------
       01  WS-MODE              PIC X(7)  VALUE SPACES.
           88  MODE-OSGENER               VALUE "OSGENER".
           88  MODE-OSLISTA               VALUE "OSLISTA".
       01  WS-FILE-STATUS.
           05  FS-SYSIN         PIC XX    VALUE "00".
           05  FS-UT1           PIC XX    VALUE "00".
           05  FS-UT3           PIC XX    VALUE "00".
           05  FS-UT6           PIC XX    VALUE "00".
           05  FS-UT2           PIC XX    VALUE "00".
           05  FS-UT4           PIC XX    VALUE "00".
           05  FS-UT5           PIC XX    VALUE "00".
           05  FS-PRT           PIC XX    VALUE "00".
           05  FS-LST           PIC XX    VALUE "00".
           05  FS-CNV           PIC XX    VALUE "00".
       01  WS-SWITCHES.
           05  SW-EOF-SYSIN     PIC X     VALUE "N".
           05  SW-EOF-UT1       PIC X     VALUE "N".
           05  SW-EOF-UT3       PIC X     VALUE "N".
           05  SW-EOF-UT6       PIC X     VALUE "N".
           05  SW-PARSE-ERR     PIC X     VALUE "N".
           05  SW-UT3-OPEN      PIC X     VALUE "N".
           05  SW-UT6-OPEN      PIC X     VALUE "N".
           05  SW-UT3-HAVE      PIC X     VALUE "N".
           05  SW-UT6-HAVE      PIC X     VALUE "N".
           05  SW-SEC-MATCH     PIC X     VALUE "N".
           05  SW-REC-OK        PIC X     VALUE "N".
           05  SW-BLK-CORRUPT   PIC X     VALUE "N".
           05  SW-PAGE-TOP      PIC X     VALUE "Y".
       01  WS-CONV-DDNAME       PIC X(64) VALUE SPACES.
       01  WS-COUNTERS.
           05  REC-NO           PIC 9(9)  VALUE 0.
           05  OUT-CNT          PIC 9(9)  VALUE 0.
           05  OUT4-CNT         PIC 9(9)  VALUE 0.
           05  ORPHAN-CNT       PIC 9(9)  VALUE 0.
           05  PROC-CNT         PIC 9(9)  VALUE 0.
           05  AUDIT-CNT        PIC 9(2)  VALUE 0.
           05  LN-CNT           PIC 9(3)  VALUE 99.
           05  PAGE-NO          PIC 9(5)  VALUE 0.
       01  WS-RC                PIC 9(2)  VALUE 0.
      *----------------------------------------------------------------
      * SYSIN CARD PARSING WORK AREA
      *----------------------------------------------------------------
       01  WS-CARD              PIC X(80).
       01  WS-OPCODE            PIC X(8)  VALUE SPACES.
       01  WS-OPRND             PIC X(80) VALUE SPACES.
       01  WS-COND-IDX          PIC 9     VALUE 0.
       01  WS-SCAN.
           05  SC-PTR           PIC 9(3)  VALUE 1.
           05  SC-TOKEN         PIC X(132) VALUE SPACES.
           05  SC-TLEN          PIC 9(3)  VALUE 0.
           05  SC-TYPE          PIC X     VALUE SPACE.
      *        W=WORD  L=QUOTED LITERAL  X=HEX LITERAL  E=END(EMPTY)
      *        C=LOGICAL CONNECTOR .AND./.Y./.OR./.O.  (M3)
           05  SC-DELIM         PIC X     VALUE SPACE.
      *        DELIMITER THAT ENDED TOKEN: , / OR SPACE(END)
           05  SC-CLEN          PIC 9(2)  VALUE 0.
      *        SCANNER-LOCAL LENGTH FOR 1535 (I/J/K/L ARE HELD ACROSS
      *        1500-GET-TOKEN CALLS BY SOME CALLERS - DO NOT REUSE)
       01  WS-ERRMSG            PIC X(80) VALUE SPACES.
      *----------------------------------------------------------------
      * CONDITION TABLE: RCIN / RCOUT / CONDX  (MAX 150)
      *----------------------------------------------------------------
       01  COND-CNT             PIC 9(3)  VALUE 0.
       01  COND-TAB.
           05  COND-ENT OCCURS 150.
               10  CT-KIND      PIC X.
      *            I=RCIN  O=RCOUT  C=CONDX
               10  CT-FLAG      PIC 9.
               10  CT-FILE      PIC X.
      *            1=SYSUT1/BLOCK  3=SYSUT3  N=RECORD-COUNT FORM (M2)
               10  CT-CNT       PIC 9(6).
      *            M2: "OP,CUENTA" COMPARAND - COMPARED WITH REC-NO
               10  CT-OFF       PIC 9(5).
               10  CT-LEN       PIC 9(3).
               10  CT-OP        PIC XX.
               10  CT-LIT       PIC X(80).
               10  CT-CONN      PIC X.
      *            A=.AND. NEXT   O=.OR. NEXT   SPACE=GROUP END
               10  CT-GROUP     PIC 9(3).
       01  WS-GROUP-NO          PIC 9(3)  VALUE 0.
      *----------------------------------------------------------------
      * ACCUMULATORS AND ACUM OPERATION TABLE (9 REGS, MAX 90 OPS)
      *----------------------------------------------------------------
       01  ACUM-REGS.
           05  ACUM-REG OCCURS 9 PIC S9(12)V9(6) COMP-3 VALUE 0.
       01  ACUM-CNT             PIC 9(3)  VALUE 0.
       01  ACUM-TAB.
           05  ACUM-ENT OCCURS 90.
               10  AT-ACUM      PIC 9.
               10  AT-FLAG      PIC 9.
               10  AT-OP        PIC X.
               10  AT-FMT       PIC X.
      *            P=PACKED SIGNED  Z=ZONED  S=PACKED UNSIGNED  B=BIN
               10  AT-FILE      PIC X.
               10  AT-OFF       PIC 9(5).
               10  AT-LEN       PIC 9(3).
      *            G5: SOURCE KIND AND IMPLIED-DECIMAL ALIGNMENT
               10  AT-SRCK      PIC X.
      *            F=INPUT FIELD  L=NUMERIC LITERAL
               10  AT-DEC       PIC 9(2).
               10  AT-LIT       PIC S9(12)V9(6) VALUE 0.
      *----------------------------------------------------------------
      * FIELD OPERATION TABLE (MAX 125)
      *----------------------------------------------------------------
       01  FIELD-CNT            PIC 9(3)  VALUE 0.
       01  FIELD-TAB.
           05  FIELD-ENT OCCURS 125.
               10  FT-FLAG      PIC 9.
               10  FT-SRC       PIC X.
      *            F=INPUT FIELD  A=ACCUMULATOR  L=LITERAL(CL)
               10  FT-FILE      PIC X.
      *            M6: "1"=SYSUT1/BLOCK  "3"=SYSUT3 (S-PREFIX)
               10  FT-OFF       PIC 9(5).
               10  FT-LEN       PIC 9(3).
               10  FT-ACUM      PIC 9.
               10  FT-LIT       PIC X(40).
               10  FT-LLEN      PIC 9(2).
               10  FT-CONV      PIC X(2).
      *            MV UN HX ZD PD DV CL XY
               10  FT-INFMT     PIC X.
               10  FT-OUTFMT    PIC X.
               10  FT-DIGITS    PIC 9(2).
               10  FT-DEC       PIC 9(2).
      *            G6: CARD-SPECIFIED XY OUTPUT LENGTH (0 = DERIVE)
               10  FT-OUTLEN    PIC 9(3).
               10  FT-OUT       PIC 9(4).
               10  FT-DEST      PIC X.
      *            M=SYSUT2/LINE1  S=SYSUT4  2,3,4=EXTRA PRINT LINES
      *----------------------------------------------------------------
      * CONV EXTERNAL TABLES (MAX 20 TABLES X 500 ENTRIES)
      *----------------------------------------------------------------
       01  CONV-CNT             PIC 9(2)  VALUE 0.
       01  CONV-TAB.
           05  CONV-ENT OCCURS 20.
               10  CV-DD        PIC X(8).
               10  CV-INFILE    PIC X.
               10  CV-DEST      PIC X.
               10  CV-TIT       PIC 9.
               10  CV-INOFF     PIC 9(5).
               10  CV-INLEN     PIC 9(3).
               10  CV-ARGOFF    PIC 9(4).
               10  CV-OUTOFF    PIC 9(4).
               10  CV-OUTLEN    PIC 9(3).
               10  CV-FUNOFF    PIC 9(4).
               10  CV-INT       PIC X.
               10  CV-N         PIC 9(4).
               10  CV-FLAG      PIC 9.
               10  CV-INLINE    PIC X.
      *            M11: "Y" = TABLE ROWS FOLLOW THE CARD IN SYSIN
      *            (SHEETS 13/34: "UN ARCHIVO SECUENCIAL INCLUIDO EN
      *            SYSIN O CON DD ESPECIAL"), SO DD= IS OPTIONAL.
       01  WS-INLINE-CV         PIC 9(2)  VALUE 0.
      *    CONV ENTRY CURRENTLY COLLECTING INLINE ROWS, 0 = NONE
       01  SW-IS-OPCODE         PIC X     VALUE "N".
       01  CONV-DATA.
           05  CONV-ROWS OCCURS 20.
               10  CVE-ENT OCCURS 500.
                   15  CVE-ARG  PIC X(40).
                   15  CVE-FUN  PIC X(40).
      *----------------------------------------------------------------
      * CORTE CONTROL-BREAK LEVELS (MAX 10) + IMCOR MAPS
      *----------------------------------------------------------------
       01  CORTE-CNT            PIC 9(2)  VALUE 0.
       01  CORTE-TAB.
           05  CORTE-ENT OCCURS 10.
               10  CO-TYPE      PIC X.
      *            F=EOF LEVEL  K=KEY  C=COUNT(CT)
               10  CO-OFF       PIC 9(5).
               10  CO-LEN       PIC 9(3).
               10  CO-SK        PIC X.
               10  CO-SILENT    PIC X.
               10  CO-ID        PIC X(40).
               10  CO-IDLEN     PIC 9(2).
               10  CO-SO1       PIC 9(3).
               10  CO-SO2       PIC 9(3).
               10  CO-PRTKEY    PIC X.
      *            M16: "I,s02" - ECHO THE BREAKING FIELD AT s02
               10  CO-CT       PIC 9(6).
               10  CO-PREV      PIC X(80).
               10  CO-COUNT     PIC 9(9).
       01  IMCOR-CNTS.
           05  IM-CNT OCCURS 10 PIC 9(2) VALUE 0.
       01  IMCOR-TAB.
           05  IMCOR-LVL OCCURS 10.
               10  IMCOR-ENT OCCURS 10.
                   15  IM-KIND  PIC X.
      *                C=CANT  F=FIELD  A=ACUM
                   15  IM-SO    PIC 9(3).
                   15  IM-OFF   PIC 9(5).
                   15  IM-LEN   PIC 9(3).
                   15  IM-ACUM  PIC 9.
                   15  IM-DIGITS PIC 9(2).
                   15  IM-DEC   PIC 9(2).
       01  WS-LAST-CORTE        PIC 9(2)  VALUE 0.
      *----------------------------------------------------------------
      * GENER BLOCK (800 BYTES = 10 X 80), CODIG, INCON
      *----------------------------------------------------------------
       01  GENER-CFG.
           05  G-ACTIVE         PIC X     VALUE "N".
           05  G-KOFF           PIC 9(5)  VALUE 0.
           05  G-KLEN           PIC 9(3)  VALUE 0.
           05  G-COFF           PIC 9(5)  VALUE 0.
           05  G-CLEN           PIC 9(3)  VALUE 0.
           05  G-NCODES         PIC 9(2)  VALUE 0.
           05  G-CODE-ENT OCCURS 10.
               10  G-CODE       PIC X(8).
           05  G-CURKEY         PIC X(80) VALUE SPACES.
           05  G-HAVE           PIC X     VALUE "N".
       01  G-BLOCK.
           05  G-SLOT OCCURS 10 PIC X(80).
       01  G-SLOT-USED.
           05  G-USED OCCURS 10 PIC X    VALUE "N".
       01  CODIG-CNT            PIC 9(2)  VALUE 0.
       01  CODIG-TAB.
           05  CODIG-ENT OCCURS 10.
               10  CD-TARGET    PIC X(8).
               10  CD-NTRIG     PIC 9(2).
               10  CD-TRIG-ENT OCCURS 10.
                   15  CD-TRIG  PIC X(8).
       01  INCON-CNT            PIC 9(2)  VALUE 0.
       01  INCON-TAB.
           05  INCON-ENT OCCURS 50.
               10  IC-CODE      PIC X(8).
               10  IC-FILE      PIC X.
               10  IC-OFF       PIC 9(4).
               10  IC-LEN       PIC 9(3).
               10  IC-TYPE      PIC XX.
      *            N  ND A  AB AN NB(=ANB) FD FA
      *            G2: RELATIONAL RULE FORM "SI,OP,'LIT'"
               10  IC-RELOP     PIC XX.
      *            BLANK = TYPE CHECK; ELSE EQ/NE/LT/GT/LE/GE/NL/NH
               10  IC-LIT       PIC X(40).
               10  IC-LLEN      PIC 9(3).
               10  IC-LABEL     PIC X(8).
               10  IC-GROUP     PIC 9(3).
      *            M17: RULES SHARING A GROUP ARE .O. ALTERNATIVES -
      *            THE GROUP IS VIOLATED ONLY IF ALL OF THEM ARE.
      *            "/" AND .Y./.AND. OPEN A NEW GROUP (SHEET 28:
      *            "EL SEPARADOR / EQUIVALE A .Y.").
       01  WS-IGRP-NO           PIC 9(3)  VALUE 0.
       01  WS-INCON-EVAL.
           05  IX-IGRP          PIC 9(3)  VALUE 0.
           05  IX-IFIRST        PIC 9(2)  VALUE 0.
           05  SW-IGRP-BAD      PIC X     VALUE "N".
           05  SW-ICODE-PRES    PIC X     VALUE "N".
      *----------------------------------------------------------------
      * PESQIN/PESQOUT, CLAVE, COPY, PRINT, TIT, CARRO
      *----------------------------------------------------------------
       01  PESQ-CFG.
           05  P-ACTIVE         PIC X     VALUE SPACE.
      *        I=PESQIN  O=PESQOUT  SPACE=NONE
           05  P-OFF1           PIC 9(5)  VALUE 0.
           05  P-LEN            PIC 9(3)  VALUE 0.
           05  P-OFF2           PIC 9(4)  VALUE 0.
       01  CLAVE-CFG.
           05  K-ACTIVE         PIC X     VALUE "N".
           05  K-OFF1           PIC 9(5)  VALUE 0.
           05  K-LEN            PIC 9(3)  VALUE 0.
           05  K-OFF2           PIC 9(5)  VALUE 0.
       01  COPY-CNT             PIC 9(2)  VALUE 0.
       01  COPY-TAB.
           05  COPY-ENT OCCURS 10.
               10  CP-FR        PIC 9(6).
               10  CP-LR        PIC 9(6).
               10  CP-SK        PIC 9(6).
       01  PRINT-CFG.
           05  PR-ACTIVE        PIC X     VALUE "N".
           05  PR-FL            PIC XX    VALUE "C ".
           05  PR-FR            PIC 9(6)  VALUE 0.
           05  PR-LR            PIC 9(6)  VALUE 999999.
           05  PR-SK            PIC 9(6)  VALUE 0.
           05  PR-SP            PIC 9     VALUE 1.
           05  PR-SR            PIC 9     VALUE 1.
       01  TIT-CNT              PIC 9     VALUE 0.
       01  TIT-TAB.
           05  TIT-ENT OCCURS 9.
               10  TI-USED      PIC X.
               10  TI-TEXT      PIC X(132).
               10  TI-SP        PIC 9.
      *        G1: PER-RECORD FIELD MAPS RENDERED AT PAGE TOP FROM
      *        THE RECORD THAT TRIGGERED THE PAGE (PAGE-LEAD RECORD)
               10  TI-NMAP      PIC 9(2).
               10  TI-MAP-ENT OCCURS 8.
                   15  TM-OFF   PIC 9(5).
                   15  TM-LEN   PIC 9(3).
                   15  TM-CONV  PIC XX.
                   15  TM-DIG   PIC 9(2).
                   15  TM-DEC   PIC 9(2).
                   15  TM-SO    PIC 9(3).
      *    G3: CARRO CARRIAGE-CONTROL ACTIONS, APPLIED CYCLICALLY TO
      *    PRINTED LINES.  WxA=WRITE THEN SKIP x  SxL=SKIP x LINES
      *    WCx/SCx=ADVANCE TO CHANNEL x (CH 1 = FORM FEED / NEW PAGE)
       01  CARRO-CNT            PIC 9(2)  VALUE 0.
       01  CARRO-IX             PIC 9(2)  VALUE 0.
       01  CARRO-TAB.
           05  CARRO-ENT OCCURS 24.
               10  CA-ACT       PIC X.
      *            W=WRITE+SKIP  S=SKIP-ONLY  C=TO-CHANNEL
               10  CA-N         PIC 9(2).
      *----------------------------------------------------------------
      * RECORD BUFFERS AND OUTPUT AREAS
      *----------------------------------------------------------------
       01  IN-REC               PIC X(32760) VALUE SPACES.
       01  WS-SRC               PIC X(32760) VALUE SPACES.
       01  WS-FBUF              PIC X(999) VALUE SPACES.
       01  IC-SRC               PIC X(999) VALUE SPACES.
       01  ICL                  PIC 9(5)  VALUE 0.
       01  ICN                  PIC 9(3)  VALUE 0.
       01  WS-HOLD              PIC X(80) VALUE SPACES.
       01  WS-TITCONT           PIC X(80) VALUE SPACES.
       01  SW-TITCONT           PIC X     VALUE "N".
       01  SW-NEED-CONT         PIC X     VALUE "N".
       01  TCP                  PIC 9(3)  VALUE 0.
      *    M6: THE SLICE THE CURRENT INCON RULE CHECKS. 3438 STAGES
      *    IT FROM THE GENER BLOCK OR FROM SEC-REC (S-PREFIX) AND
      *    WRITES CORRECTIONS BACK ONLY FOR THE PRIMARY FILE.
      *    M6: THE SLICE THE CURRENT FIELD/ACUM/TIT-MAP OPERATION
      *    READS. CALLERS STAGE IT FROM WS-SRC OR SEC-REC (S-PREFIX
      *    = SYSUT3) AND SET L = 1, SO THE DECODERS BELOW NEED NO
      *    KNOWLEDGE OF WHICH INPUT FILE THE OPERAND CAME FROM.
      *    LAST FULLY PROCESSED UNIT: BREAKS FIRE ON THE NEW RECORD,
      *    SO IMCOR FIELD VALUES MUST COME FROM THE CLOSING GROUP
       01  WS-PREV-SRC          PIC X(32760) VALUE SPACES.
       01  SEC-REC              PIC X(32760) VALUE SPACES.
       01  PSQ-REC              PIC X(80)  VALUE SPACES.
       01  OUT-MAIN             PIC X(32760) VALUE SPACES.
       01  OUT-SEC              PIC X(32760) VALUE SPACES.
       01  OUT-SEC-USED         PIC X      VALUE "N".
       01  PRTX                 PIC 9(2)  VALUE 0.
       01  H-PAGE-ED            PIC 9(5)  VALUE 0.
       01  PRT-LINES.
           05  PRT-LINE OCCURS 9 PIC X(132).
       01  PRT-USED.
           05  PRT-U OCCURS 9   PIC X     VALUE "N".
       01  COND-FLAGS.
           05  CFLAG OCCURS 8   PIC X     VALUE "N".
      *----------------------------------------------------------------
      * NUMERIC DECODE/ENCODE, MOD-10, HEX WORK AREAS
      *----------------------------------------------------------------
       01  DN-WORK.
           05  DN-VAL           PIC S9(15) COMP-3 VALUE 0.
           05  DN-DIGIT         PIC 9(2)   VALUE 0.
           05  DN-BYTE          PIC 9(4)  BINARY VALUE 0.
           05  DN-HI            PIC 9(4)  BINARY VALUE 0.
           05  DN-LO            PIC 9(4)  BINARY VALUE 0.
           05  DN-NEG           PIC X      VALUE "N".
      *    G4: SIGNED-DECODE HELPERS (BINARY TWO'S COMPLEMENT SPAN,
      *    ZONED OVERPUNCH LOOKUP)
           05  DN-POW           PIC S9(18) COMP-3 VALUE 0.
           05  DN-FIRST         PIC 9(4)  BINARY VALUE 0.
           05  DN-OVP           PIC 9(2)   VALUE 0.
      *    G5: DECIMAL-SCALED ACCUMULATOR OPERAND
           05  DN-OPND          PIC S9(15)V9(6) COMP-3 VALUE 0.
       01  OVP-TABLE.
      *    ZONED OVERPUNCH: POSITIVE {ABCDEFGHI = 0..9,
      *    NEGATIVE }JKLMNOPQR = 0..9 (CLASSIC DISPLAY SIGN)
           05  FILLER           PIC X(10) VALUE "{ABCDEFGHI".
           05  FILLER           PIC X(10) VALUE "}JKLMNOPQR".
       01  OVP-TAB REDEFINES OVP-TABLE.
           05  OVP-SET OCCURS 2.
               10  OVP-CH OCCURS 10 PIC X.
       01  EN-WORK.
           05  EN-STR           PIC X(32)  VALUE SPACES.
      *    9(3): STAGED FIELDS CAN BE UP TO 256 BYTES (MV/CL)
           05  EN-LEN           PIC 9(3)   VALUE 0.
       01  MOD10-WORK.
           05  M10-SUM          PIC 9(6)  BINARY VALUE 0.
           05  M10-PROD         PIC 9(4)  BINARY VALUE 0.
           05  M10-W            PIC 9     VALUE 2.
           05  M10-REM          PIC 9(4)  BINARY VALUE 0.
           05  M10-DV           PIC 9     VALUE 0.
       01  HEX-WORK.
           05  HEX-CHARS        PIC X(16) VALUE "0123456789ABCDEF".
           05  HX-BYTE          PIC 9(4)  BINARY VALUE 0.
           05  HX-HI            PIC 9(4)  BINARY VALUE 0.
           05  HX-LO            PIC 9(4)  BINARY VALUE 0.
       01  TRT-WORK.
      *        RAW BYTE <-> BINARY VALUE CONVERSION INTERFACE
           05  TRT-CHAR         PIC X      VALUE SPACE.
           05  TRT-VAL          PIC 9(4)  BINARY VALUE 0.
      *    G9 PORTABILITY: BYTE VALUE VIA BIG-ENDIAN BINARY REDEFINE
      *    (MVS, RM/COBOL AND GNUCOBOL -STD=MVS/RM ALL DEFINE
      *    BIG-ENDIAN BINARY) - REPLACES FUNCTION ORD/CHAR
       01  BC-WORK.
           05  BC-NUM           PIC 9(4)  BINARY VALUE 0.
       01  BC-BYTES REDEFINES BC-WORK.
           05  BC-HI            PIC X.
           05  BC-LO            PIC X.
      *    G9 PORTABILITY: SYSTEM DATE VIA ACCEPT FROM DATE
      *    (STANDARD COBOL-85) - REPLACES FUNCTION CURRENT-DATE.
      *    CENTURY WINDOW: YY < 50 -> 20YY, ELSE 19YY.
       01  DT-WORK.
           05  DT-YMD           PIC 9(6)  VALUE 0.
           05  DT-YMD-X REDEFINES DT-YMD.
               10  DT-YY        PIC XX.
               10  DT-MM        PIC XX.
               10  DT-DD        PIC XX.
           05  DT-CC            PIC XX     VALUE "19".
       01  ED-WORK.
           05  ED-DIGS          PIC X(18)  VALUE SPACES.
      *    ED-OUT MUST COVER THE LARGEST STAGED FIELD: A FULL MV/CL
      *    MOVE, OR A CL FILL, UP TO FT-LEN'S 999-BYTE RANGE
           05  ED-OUT           PIC X(999) VALUE SPACES.
           05  ED-P             PIC 9(2)   VALUE 0.
      *    7600 PRIVATE LOOP/WORK VARS - MUST NOT ALIAS CALLERS' I-N
           05  ED-I             PIC S9(4) BINARY VALUE 0.
           05  ED-M             PIC S9(4) BINARY VALUE 0.
           05  ED-N             PIC S9(4) BINARY VALUE 0.
      *----------------------------------------------------------------
      * MISC INDICES AND HOLDS
      *----------------------------------------------------------------
       01  IX-WORK.
           05  I                PIC 9(6)  BINARY VALUE 0.
           05  J                PIC 9(6)  BINARY VALUE 0.
           05  K                PIC 9(6)  BINARY VALUE 0.
           05  L                PIC 9(6)  BINARY VALUE 0.
           05  M                PIC 9(6)  BINARY VALUE 0.
           05  N                PIC 9(6)  BINARY VALUE 0.
           05  IX-GRP           PIC 9(3)  VALUE 0.
      *    IX-LVL MUST BE SIGNED: DOWNWARD PERFORM VARYING LOOPS
      *    DECREMENT BELOW 1; UNSIGNED DISPLAY WOULD STRIP THE SIGN
      *    AND LOOP FOREVER.
           05  IX-LVL           PIC S9(4) BINARY VALUE 0.
       01  WS-HOLDS.
           05  H-KEY1           PIC X(80) VALUE SPACES.
           05  H-KEY2           PIC X(80) VALUE SPACES.
           05  H-CODE           PIC X(8)  VALUE SPACES.
           05  H-GRP-TRUE       PIC X     VALUE "N".
           05  H-ANY-IN         PIC X     VALUE "N".
           05  H-IN-TRUE        PIC X     VALUE "N".
           05  H-OUT-TRUE       PIC X     VALUE "N".
           05  H-NUM            PIC 9(6)  VALUE 0.
           05  H-LINE           PIC X(132) VALUE SPACES.
           05  H-CNT-ED         PIC 9(9)  VALUE 0.
           05  H-FAMILY         PIC X     VALUE SPACE.
      *    G1: TITLE/MAP RENDER INDICES (KEPT SEPARATE FROM I-N/K
      *    WHICH THE 7000/7600 HELPERS CLOBBER)
           05  TIK              PIC 9(2)  VALUE 0.
           05  TIM              PIC 9(2)  VALUE 0.
      *    SEPARATE FROM H-LINE: A PAGE EJECT CAN FIRE WHILE H-LINE
      *    HOLDS THE DETAIL LINE ABOUT TO BE WRITTEN
           05  H-TITLE          PIC X(132) VALUE SPACES.
      *
       LINKAGE SECTION.
       01  L-MODE               PIC X(7).
      *
       PROCEDURE DIVISION USING L-MODE.
      *================================================================
      * 0000 MAIN CONTROL
      *================================================================
       0000-MAIN.
           MOVE L-MODE TO WS-MODE
           IF NOT MODE-OSGENER AND NOT MODE-OSLISTA
               DISPLAY "OSENGINE: INVALID MODE '" WS-MODE "'"
               MOVE 16 TO RETURN-CODE
               GOBACK
           END-IF
           OPEN OUTPUT SYSPRINT-F
           IF FS-PRT NOT = "00"
               DISPLAY "OSENGINE: SYSPRINT OPEN FAILED, STATUS "
                   FS-PRT
               MOVE 16 TO RETURN-CODE
               GOBACK
           END-IF
           PERFORM 9100-PRT-BANNER
           PERFORM 1000-PARSE-SYSIN
           IF SW-PARSE-ERR = "Y"
               MOVE "EXECUTION CANCELLED: SYSIN CARD ERRORS"
                   TO SYSPRINT-REC
               WRITE SYSPRINT-REC END-WRITE
               CLOSE SYSPRINT-F
               MOVE 12 TO RETURN-CODE
               GOBACK
           END-IF
           PERFORM 2000-OPEN-DATA
      *    M18: THE OSGENER TIT CARD HEADS THE SYSLIST ASSEMBLY-ERROR
      *    REPORT, SO IT IS WRITTEN ONCE AHEAD OF ANY VIOLATION LINE
           IF MODE-OSGENER AND TIT-CNT > 0 AND SW-EOF-UT1 = "N"
               MOVE TI-TEXT(1)(1:132) TO SYSLIST-REC
               WRITE SYSLIST-REC END-WRITE
           END-IF
           PERFORM 2500-LOAD-CONV-TABLES
           PERFORM 3000-PROCESS-RECORD THRU 3000-EXIT
               UNTIL SW-EOF-UT1 = "Y"
           PERFORM 5000-FINAL
           PERFORM 9200-PRT-SUMMARY
           PERFORM 8000-CLOSE-ALL
           MOVE WS-RC TO RETURN-CODE
           GOBACK.
      *
      *================================================================
      * 1000 SYSIN PARSING - ECHO CARDS, DISPATCH BY OP-CODE
      *================================================================
       1000-PARSE-SYSIN.
           OPEN INPUT SYSIN-F
           IF FS-SYSIN NOT = "00"
               MOVE "SYSIN OPEN FAILED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
           END-IF
           PERFORM UNTIL SW-EOF-SYSIN = "Y" OR SW-PARSE-ERR = "Y"
               PERFORM 1010-NEXT-CARD
               IF SW-EOF-SYSIN = "N"
      *                M11: WHILE AN INLINE CONV TABLE IS OPEN, EVERY
      *                CARD THAT IS NOT A CONTROL CARD IS ONE OF ITS
      *                ROWS. THE FIRST RECOGNISED OP-CODE (OR A BLANK
      *                CARD, OR EOF) CLOSES THE TABLE.
                       IF WS-INLINE-CV > 0
                           PERFORM 1050-IS-OPCODE THRU 1050-EXIT
                           IF SW-IS-OPCODE = "Y"
                               MOVE 0 TO WS-INLINE-CV
                               PERFORM 1100-PARSE-CARD THRU 1100-EXIT
                           ELSE
                               PERFORM 1060-INLINE-CONV-ROW
                                   THRU 1060-EXIT
                           END-IF
                       ELSE
      *                    M24: A TIT LITERAL MAY CLOSE ON THE NEXT
      *                    CARD. PULL IT NOW SO 1510 CAN FINISH THE
      *                    LITERAL - A ONE-CARD LOOKAHEAD, NOT A
      *                    READ NESTED INSIDE ANOTHER READ.
                           PERFORM 1070-TIT-NEEDS-CONT THRU 1070-EXIT
                           IF SW-NEED-CONT = "Y"
                               MOVE WS-CARD TO WS-HOLD
                               PERFORM 1010-NEXT-CARD
                               MOVE WS-CARD TO WS-TITCONT
                               MOVE WS-HOLD TO WS-CARD
                               MOVE "Y" TO SW-TITCONT
                           END-IF
                           PERFORM 1100-PARSE-CARD THRU 1100-EXIT
                           IF SW-TITCONT = "Y" OR SW-NEED-CONT = "Y"
                               MOVE WS-TITCONT TO SYSPRINT-REC
                               WRITE SYSPRINT-REC END-WRITE
                           END-IF
                           MOVE "N" TO SW-TITCONT
                       END-IF
               END-IF
           END-PERFORM
           CLOSE SYSIN-F
           MOVE 0 TO WS-INLINE-CV
      *    CROSS-CARD CHECK: S-PREFIXED CONDITIONS NEED CLAVE TO
      *    PAIR SYSUT3 RECORDS - OTHERWISE THEY COMPARE BLANKS
           IF K-ACTIVE = "N"
               PERFORM VARYING I FROM 1 BY 1 UNTIL I > COND-CNT
                   IF CT-FILE(I) = "3"
                       MOVE SPACES TO SYSPRINT-REC
                       STRING "WARNING: S-OFFSET CONDITION WITHOUT "
                           "CLAVE CARD - SYSUT3 READS AS BLANKS"
                           DELIMITED BY SIZE INTO SYSPRINT-REC
                       END-STRING
                       WRITE SYSPRINT-REC END-WRITE
                       EXIT PERFORM
                   END-IF
               END-PERFORM
           END-IF
           IF SW-PARSE-ERR = "N"
               PERFORM 1600-VALIDATE-CONFIG
           END-IF.
      *
       1010-NEXT-CARD.
           READ SYSIN-F INTO WS-CARD
               AT END MOVE "Y" TO SW-EOF-SYSIN
                      MOVE SPACES TO WS-CARD
           END-READ.
      *
       1070-TIT-NEEDS-CONT.
      *    M24: SHEET 3 EXEMPTS TIT FROM "A CONTINUATION CARD MUST
      *    REPEAT THE OP-CODE", SO A TIT LITERAL CAN OPEN ON ONE CARD
      *    AND CLOSE ON THE NEXT. AN ODD APOSTROPHE COUNT SAYS THE
      *    LITERAL IS STILL OPEN AT COLUMN 80.
           MOVE "N" TO SW-NEED-CONT
           IF WS-CARD(1:3) = "TIT"
               MOVE 0 TO I
               INSPECT WS-CARD TALLYING I FOR ALL "'"
               DIVIDE I BY 2 GIVING J REMAINDER K END-DIVIDE
               IF K = 1
                   MOVE "Y" TO SW-NEED-CONT
               END-IF
           END-IF.
       1070-EXIT.
           EXIT.
      *
       1050-IS-OPCODE.
      *    M11: DOES THIS CARD START A CONTROL STATEMENT? USED ONLY
      *    TO FIND THE END OF AN INLINE CONV TABLE. A BLANK CARD OR A
      *    COMMENT CLOSES THE TABLE TOO. (A TABLE ROW WHOSE COLUMN-1
      *    WORD HAPPENS TO SPELL AN OP-CODE WOULD END THE TABLE
      *    EARLY - THE SAME AMBIGUITY THE ORIGINAL UTILITY HAD.)
           MOVE "N" TO SW-IS-OPCODE
           IF WS-CARD = SPACES OR WS-CARD(1:1) = "*"
               MOVE "Y" TO SW-IS-OPCODE
               GO TO 1050-EXIT
           END-IF
           IF WS-CARD(1:1) = SPACE
               GO TO 1050-EXIT
           END-IF
           MOVE 0 TO I
           INSPECT WS-CARD TALLYING I
               FOR CHARACTERS BEFORE INITIAL SPACE
           IF I > 8
               MOVE 8 TO I
           END-IF
           MOVE SPACES TO H-CODE
           MOVE WS-CARD(1:I) TO H-CODE
           IF H-CODE = "RCIN" OR H-CODE = "RCOUT"
              OR H-CODE = "CLAVE" OR H-CODE = "COPY"
              OR H-CODE = "PRINT" OR H-CODE = "CARRO"
              OR H-CODE = "CORTE" OR H-CODE = "IMCOR"
              OR H-CODE = "GENER" OR H-CODE = "CODIG"
              OR H-CODE = "INCON" OR H-CODE = "PESQIN"
              OR H-CODE = "PESQOUT"
              OR H-CODE(1:4) = "COND" OR H-CODE(1:4) = "ACUM"
              OR H-CODE(1:5) = "FIELD" OR H-CODE(1:4) = "CONV"
              OR H-CODE(1:3) = "TIT"
               MOVE "Y" TO SW-IS-OPCODE
           END-IF.
       1050-EXIT.
           EXIT.
      *
       1060-INLINE-CONV-ROW.
      *    M11: ONE ROW OF THE INLINE TABLE FOR ENTRY WS-INLINE-CV.
      *    THE CARD IS A RAW 80-COLUMN IMAGE; ARGUMENT AND FUNCTION
      *    ARE CUT OUT BY THE SIA/SIF COLUMNS FROM THE CONV CARD.
           MOVE WS-CARD TO SYSPRINT-REC
           WRITE SYSPRINT-REC END-WRITE
           MOVE WS-INLINE-CV TO I
           IF CV-N(I) >= 500
               MOVE "CONV INLINE TABLE EXCEEDS 500 ROWS" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1060-EXIT
           END-IF
           ADD 1 TO CV-N(I) END-ADD
           MOVE CV-N(I) TO J
           MOVE WS-CARD(CV-ARGOFF(I):CV-INLEN(I)) TO CVE-ARG(I, J)
           MOVE WS-CARD(CV-FUNOFF(I):CV-OUTLEN(I)) TO CVE-FUN(I, J).
       1060-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1600 SEMANTIC BOUNDS VALIDATION OF ALL PARSED OPERANDS.
      * REFERENCE MODIFICATION WITH OUT-OF-BUFFER OFFSETS CORRUPTS
      * MEMORY AT RUNTIME - EVERY OFFSET/LENGTH PAIR IS CHECKED HERE
      * AGAINST ITS TARGET BUFFER BEFORE PROCESSING STARTS.
      *----------------------------------------------------------------
       1600-VALIDATE-CONFIG.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > COND-CNT
      *        M2: THE COUNT FORM HAS NO FIELD TO BOUNDS-CHECK
               IF CT-FILE(I) = "N"
                   MOVE 1 TO J
               ELSE
                   COMPUTE J = CT-OFF(I) + CT-LEN(I) END-COMPUTE
               END-IF
               IF CT-FILE(I) NOT = "N" AND
                  (CT-OFF(I) < 1 OR CT-LEN(I) < 1 OR J > 32761)
                   MOVE "CONDITION FIELD OUTSIDE RECORD BUFFER"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-PERFORM
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > ACUM-CNT
      *        G5: LITERAL OPERANDS CARRY NO FIELD OFFSET/LENGTH
               IF AT-SRCK(I) NOT = "L"
                   COMPUTE J = AT-OFF(I) + AT-LEN(I) END-COMPUTE
                   IF AT-OFF(I) < 1 OR AT-LEN(I) < 1 OR J > 32761
                      OR AT-LEN(I) > 15
                       MOVE "ACUM FIELD OUTSIDE RECORD BUFFER"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               END-IF
           END-PERFORM
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > FIELD-CNT
               PERFORM 1610-VALIDATE-FIELD
           END-PERFORM
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > INCON-CNT
               COMPUTE J = IC-OFF(I) + IC-LEN(I) END-COMPUTE
      *        M6: AN S-PREFIXED RULE ADDRESSES THE SYSUT3 RECORD,
      *        NOT AN 80-BYTE CARD IMAGE
               IF IC-FILE(I) = "3"
                   IF IC-OFF(I) < 1 OR IC-LEN(I) < 1 OR J > 32761
                       MOVE "INCON FIELD OUTSIDE RECORD BUFFER"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               ELSE
                   IF IC-OFF(I) < 1 OR IC-LEN(I) < 1 OR J > 81
                       MOVE "INCON FIELD OUTSIDE 80-BYTE CARD"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               END-IF
      *        D0.9 / M17: ONLY RELATIONAL RULES MAY BE .O.
      *        ALTERNATIVES. THE CORRECTING TYPES (ND/AB/ANB) REWRITE
      *        BYTES IN PLACE, AND THE MANUAL DEFINES NO SEMANTICS
      *        FOR CORRECTING AN ALTERNATIVE THAT WAS NOT THE ONE
      *        SATISFIED. EVERY .O. GROUP THE MANUAL PRINTS IS
      *        RELATIONAL, SO THIS COSTS NOTHING.
               IF IC-TYPE(I) NOT = "R "
                   MOVE 0 TO K
                   PERFORM VARYING J FROM 1 BY 1 UNTIL J > INCON-CNT
                       IF IC-GROUP(J) = IC-GROUP(I)
                           ADD 1 TO K END-ADD
                       END-IF
                   END-PERFORM
                   IF K > 1
                       MOVE "ONLY RELATIONAL INCON RULES MAY BE .O."
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               END-IF
           END-PERFORM
           IF G-ACTIVE = "Y"
               COMPUTE J = G-KOFF + G-KLEN END-COMPUTE
               COMPUTE K = G-COFF + G-CLEN END-COMPUTE
               IF G-KOFF < 1 OR G-KLEN < 1 OR J > 32761
                  OR G-KLEN > 80 OR G-COFF < 1 OR G-CLEN < 1
                  OR K > 32761 OR G-CLEN > 8
                   MOVE "GENER KEY/CODE OPERANDS OUT OF BOUNDS"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           IF K-ACTIVE = "Y"
               COMPUTE J = K-OFF1 + K-LEN END-COMPUTE
               COMPUTE K = K-OFF2 + K-LEN END-COMPUTE
               IF K-OFF1 < 1 OR K-LEN < 1 OR J > 32761 OR K > 32761
                  OR K-LEN > 80
                   MOVE "CLAVE OPERANDS OUT OF BOUNDS" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           IF P-ACTIVE NOT = SPACE
               COMPUTE J = P-OFF1 + P-LEN END-COMPUTE
               COMPUTE K = P-OFF2 + P-LEN END-COMPUTE
               IF P-OFF1 < 1 OR P-LEN < 1 OR J > 32761 OR K > 81
                   MOVE "PESQ OPERANDS OUT OF BOUNDS" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > CORTE-CNT
               IF CO-TYPE(I) = "K"
                   COMPUTE J = CO-OFF(I) + CO-LEN(I) END-COMPUTE
                   IF CO-OFF(I) < 1 OR CO-LEN(I) < 1 OR J > 32761
                      OR CO-LEN(I) > 80
                       MOVE "CORTE KEY OUT OF BOUNDS" TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               END-IF
               PERFORM VARYING M FROM 1 BY 1 UNTIL M > IM-CNT(I)
                   IF IM-SO(I, M) < 1 OR IM-SO(I, M) > 132
                       MOVE "IMCOR OUTPUT COLUMN OUT OF 1-132"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
                   IF IM-DIGITS(I, M) > 18
                       MOVE "IMCOR EDIT MASK DIGITS LIMIT IS 18"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
                   IF IM-KIND(I, M) = "F"
                       COMPUTE J = IM-OFF(I, M) + IM-LEN(I, M)
                       END-COMPUTE
                       IF J > 32761 OR IM-LEN(I, M) > 132
                           MOVE "IMCOR FIELD OUT OF BOUNDS"
                               TO WS-ERRMSG
                           PERFORM 9000-PARSE-ERROR
                       END-IF
                   END-IF
               END-PERFORM
           END-PERFORM
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > CONV-CNT
               COMPUTE J = CV-INOFF(I) + CV-INLEN(I) END-COMPUTE
               COMPUTE K = CV-OUTOFF(I) + CV-OUTLEN(I) END-COMPUTE
               IF CV-INOFF(I) < 1 OR J > 32761 OR CV-OUTOFF(I) < 1
                   MOVE "CONV INPUT FIELD OUT OF BOUNDS"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
               IF MODE-OSGENER AND K > 32761
                   MOVE "CONV OUTPUT BEYOND 256-BYTE RECORD"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
               IF MODE-OSLISTA AND K > 133
                   MOVE "CONV OUTPUT BEYOND 132-COL PRINT LINE"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-PERFORM.
      *
       1610-VALIDATE-FIELD.
           IF FT-SRC(I) = "F"
               COMPUTE J = FT-OFF(I) + FT-LEN(I) END-COMPUTE
               IF FT-OFF(I) < 1 OR FT-LEN(I) < 1 OR J > 32761
                   MOVE "FIELD INPUT OUTSIDE RECORD BUFFER"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           IF FT-OUT(I) < 1
               MOVE "FIELD OUTPUT OFFSET MUST BE >= 1" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
           END-IF
      *    CONVERSION-SPECIFIC INPUT CAPS (STAGING/VALUE LIMITS)
           EVALUATE FT-CONV(I)
               WHEN "UN"
      *            DN-VAL HOLDS 15 DIGITS = 8 PACKED BYTES MAX
                   IF FT-LEN(I) > 8
                       MOVE "UNPK INPUT LIMIT IS 8 BYTES"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               WHEN "ZD" WHEN "PD"
      *            ED-DIGS HOLDS 18 DIGITS MAX
                   IF FT-DIGITS(I) > 18
                       MOVE "EDIT MASK DIGITS LIMIT IS 18"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
      *        M21: SHEET 11 CAPS THE INPUT LENGTH PER CONVERSION -
      *        UNPK 8 (ABOVE), MOVE 132, HEXA 64
               WHEN "MV"
                   IF MODE-OSLISTA AND FT-LEN(I) > 132
                       MOVE "MOVE INPUT LIMIT IS 132 BYTES"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               WHEN "HX"
                   IF FT-LEN(I) > 64
                       MOVE "HEXA INPUT LIMIT IS 64 BYTES"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               WHEN OTHER
                   CONTINUE
           END-EVALUATE
      *    OUTPUT END POSITION = OFFSET + EMITTED LENGTH, PER CONV
           MOVE FT-LEN(I) TO J
           EVALUATE FT-CONV(I)
               WHEN "UN"
                   MULTIPLY 2 BY J END-MULTIPLY
                   SUBTRACT 1 FROM J END-SUBTRACT
               WHEN "HX"
                   MULTIPLY 2 BY J END-MULTIPLY
               WHEN "DV"
                   ADD 1 TO J END-ADD
               WHEN "MV" WHEN "CL"
                   CONTINUE
               WHEN OTHER
      *            EDITED/ENCODED FORMS EMIT AT MOST 24 BYTES
                   MOVE 24 TO J
           END-EVALUATE
           ADD FT-OUT(I) TO J END-ADD
           IF MODE-OSGENER AND J > 32761
               MOVE "FIELD OUTPUT BEYOND 256-BYTE RECORD"
                   TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
           END-IF
           IF MODE-OSLISTA AND J > 133
               MOVE "FIELD OUTPUT BEYOND 132-COL PRINT LINE"
                   TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
           END-IF.
      *
       1100-PARSE-CARD.
           MOVE WS-CARD TO SYSPRINT-REC
           WRITE SYSPRINT-REC END-WRITE
           IF WS-CARD = SPACES OR WS-CARD(1:1) = "*"
               GO TO 1100-EXIT
           END-IF
           IF WS-CARD(1:1) = SPACE
               MOVE "OP-CODE MUST START IN COLUMN 1" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1100-EXIT
           END-IF
           MOVE SPACES TO WS-OPCODE WS-OPRND
      *    OP-CODE = COL 1 UP TO FIRST BLANK; OPERAND = ALL THE REST
      *    (UNSTRING WOULD CUT THE OPERAND AT ITS FIRST INNER BLANK)
           MOVE 0 TO I
           INSPECT WS-CARD TALLYING I
               FOR CHARACTERS BEFORE INITIAL SPACE
           IF I > 8
               MOVE 8 TO I
           END-IF
           MOVE WS-CARD(1:I) TO WS-OPCODE
           IF I < 79
               COMPUTE J = 80 - I - 1 END-COMPUTE
               MOVE WS-CARD(I + 2:J) TO WS-OPRND
           END-IF
           MOVE 0 TO WS-COND-IDX
           MOVE 1 TO SC-PTR
           EVALUATE TRUE
               WHEN WS-OPCODE = "RCIN"
                   PERFORM 1200-PARSE-RC
               WHEN WS-OPCODE = "RCOUT"
                   PERFORM 1200-PARSE-RC
               WHEN WS-OPCODE(1:4) = "COND"
                   PERFORM 1210-PARSE-COND THRU 1210-EXIT
               WHEN WS-OPCODE(1:4) = "ACUM"
                   PERFORM 1220-PARSE-ACUM THRU 1220-EXIT
               WHEN WS-OPCODE(1:5) = "FIELD"
                   PERFORM 1230-PARSE-FIELD THRU 1230-EXIT
               WHEN WS-OPCODE(1:4) = "CONV"
                   PERFORM 1240-PARSE-CONV THRU 1240-EXIT
               WHEN WS-OPCODE = "CORTE"
                   PERFORM 1250-PARSE-CORTE THRU 1250-EXIT
               WHEN WS-OPCODE = "IMCOR"
                   PERFORM 1260-PARSE-IMCOR THRU 1260-EXIT
               WHEN WS-OPCODE = "GENER"
                   PERFORM 1300-PARSE-GENER
               WHEN WS-OPCODE = "CODIG"
                   PERFORM 1310-PARSE-CODIG THRU 1310-EXIT
               WHEN WS-OPCODE = "INCON"
                   PERFORM 1320-PARSE-INCON THRU 1320-EXIT
               WHEN WS-OPCODE = "PESQIN" OR WS-OPCODE = "PESQOUT"
                   PERFORM 1330-PARSE-PESQ THRU 1330-EXIT
               WHEN WS-OPCODE = "CLAVE"
                   PERFORM 1340-PARSE-CLAVE
               WHEN WS-OPCODE = "COPY"
                   PERFORM 1350-PARSE-COPY THRU 1350-EXIT
               WHEN WS-OPCODE = "PRINT"
                   PERFORM 1360-PARSE-PRINT
               WHEN WS-OPCODE(1:3) = "TIT"
                   PERFORM 1370-PARSE-TIT THRU 1370-EXIT
               WHEN WS-OPCODE = "CARRO"
                   PERFORM 1380-PARSE-CARRO THRU 1380-EXIT
               WHEN OTHER
                   STRING "UNKNOWN OP-CODE: " WS-OPCODE
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
           END-EVALUATE
           PERFORM 1900-MODE-GATE.
       1100-EXIT.
           EXIT.
      *
      * REJECT CARDS NOT VALID FOR THE ACTIVE PERSONALITY (D0.2)
       1900-MODE-GATE.
           IF MODE-OSLISTA
               IF WS-OPCODE = "GENER" OR WS-OPCODE = "CODIG"
                  OR WS-OPCODE = "INCON" OR WS-OPCODE = "PESQIN"
                  OR WS-OPCODE = "PESQOUT" OR WS-OPCODE = "COPY"
                   STRING WS-OPCODE " NOT VALID IN OSLISTA MODE"
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           IF MODE-OSGENER
      *        M18: TIT IS *NOT* OSLISTA-ONLY. SHEET 30 DEFINES IT
      *        FOR OSGENER AS THE SYSLIST ASSEMBLY-ERROR HEADING,
      *        WITH ITS OWN SYNTAX "TIT {Lnn},'literal'". D0.2 WAS
      *        WRONG ON THIS POINT AND IS AMENDED.
               IF WS-OPCODE = "PRINT"
                  OR WS-OPCODE = "CARRO" OR WS-OPCODE = "CORTE"
                  OR WS-OPCODE = "IMCOR"
                   STRING WS-OPCODE " NOT VALID IN OSGENER MODE"
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF.
      *
      *----------------------------------------------------------------
      * TOKEN SCANNER OVER WS-OPRND. RETURNS SC-TOKEN/SC-TLEN/SC-TYPE
      * AND SC-DELIM (DELIMITER CONSUMED AFTER TOKEN: , / OR SPACE).
      *----------------------------------------------------------------
       1500-GET-TOKEN.
           MOVE SPACES TO SC-TOKEN
           MOVE 0 TO SC-TLEN
           MOVE "E" TO SC-TYPE
           MOVE SPACE TO SC-DELIM
           PERFORM UNTIL SC-PTR > 80
               OR WS-OPRND(SC-PTR:1) NOT = SPACE
               ADD 1 TO SC-PTR END-ADD
           END-PERFORM
           IF SC-PTR > 80
               GO TO 1500-EXIT
           END-IF
           IF WS-OPRND(SC-PTR:1) = "," OR WS-OPRND(SC-PTR:1) = "/"
               MOVE WS-OPRND(SC-PTR:1) TO SC-DELIM
               ADD 1 TO SC-PTR END-ADD
               MOVE "E" TO SC-TYPE
               GO TO 1500-EXIT
           END-IF
      *    M3: A LOGICAL CONNECTOR IS ITS OWN TOKEN EVEN WHEN GLUED TO
      *    THE OPERANDS AROUND IT (".AND.20" = ".AND." THEN "20").
      *    NO DELIMITER FOLLOWS IT, SO 1540 IS SKIPPED.
           IF WS-OPRND(SC-PTR:1) = "."
               PERFORM 1535-GET-CONNECTOR
               IF SC-TYPE = "C"
                   GO TO 1500-EXIT
               END-IF
           END-IF
           EVALUATE TRUE
               WHEN WS-OPRND(SC-PTR:1) = "'"
                   PERFORM 1510-GET-QUOTED
               WHEN WS-OPRND(SC-PTR:2) = "X'"
                   ADD 1 TO SC-PTR END-ADD
                   PERFORM 1510-GET-QUOTED
                   MOVE "X" TO SC-TYPE
                   PERFORM 1520-HEX-TO-BYTES THRU 1520-EXIT
               WHEN OTHER
                   PERFORM 1530-GET-WORD
           END-EVALUATE
           PERFORM 1540-EAT-DELIM.
       1500-EXIT.
           EXIT.
      *
       1535-GET-CONNECTOR.
      *    M3: MATCH .AND. / .OR. / .Y. / .O. AT SC-PTR. ON A MATCH
      *    SETS SC-TYPE "C" AND STEPS OVER IT; OTHERWISE LEAVES THE
      *    SCANNER UNTOUCHED SO THE CALLER FALLS BACK TO 1530-GET-WORD
      *    AND A STRAY "." STILL RAISES THE USUAL CARD ERROR.
           PERFORM 1536-PEEK-CONNECTOR
           IF SC-CLEN > 0
               MOVE "C" TO SC-TYPE
               MOVE SC-CLEN TO SC-TLEN
               MOVE WS-OPRND(SC-PTR:SC-CLEN) TO SC-TOKEN
               ADD SC-CLEN TO SC-PTR END-ADD
           END-IF.
      *
       1536-PEEK-CONNECTOR.
      *    SIDE-EFFECT-FREE: SC-CLEN = LENGTH OF THE CONNECTOR AT
      *    SC-PTR, ELSE 0. USED BOTH TO EMIT THE TOKEN (1535) AND TO
      *    END A WORD THAT BUTTS UP AGAINST ONE (1530) - "GT,2.Y.LT"
      *    MUST YIELD "2", NOT "2.Y.LT".
      *    REF-MOD LENGTHS ARE GUARDED: WS-OPRND IS X(80). BOUNDS ARE
      *    PRE-SUBTRACTED (80-5+1=76, 80-4+1=77, 80-3+1=78) SO NO
      *    ARITHMETIC APPEARS IN A CONDITION.
           MOVE 0 TO SC-CLEN
           IF SC-PTR <= 76
               IF WS-OPRND(SC-PTR:5) = ".AND."
                   MOVE 5 TO SC-CLEN
               END-IF
           END-IF
           IF SC-CLEN = 0 AND SC-PTR <= 77
               IF WS-OPRND(SC-PTR:4) = ".OR."
                   MOVE 4 TO SC-CLEN
               END-IF
           END-IF
           IF SC-CLEN = 0 AND SC-PTR <= 78
               IF WS-OPRND(SC-PTR:3) = ".Y."
                   OR WS-OPRND(SC-PTR:3) = ".O."
                   MOVE 3 TO SC-CLEN
               END-IF
           END-IF.
      *
       1510-GET-QUOTED.
           ADD 1 TO SC-PTR END-ADD
           MOVE "L" TO SC-TYPE
           PERFORM UNTIL SC-PTR > 80
               OR WS-OPRND(SC-PTR:1) = "'"
               ADD 1 TO SC-TLEN END-ADD
               MOVE WS-OPRND(SC-PTR:1) TO SC-TOKEN(SC-TLEN:1)
               ADD 1 TO SC-PTR END-ADD
           END-PERFORM
           IF SC-PTR > 80
      *        M24: FINISH A TIT LITERAL ON THE CONTINUATION CARD
               IF SW-TITCONT = "Y"
                   MOVE "N" TO SW-TITCONT
                   MOVE 1 TO TCP
                   PERFORM UNTIL TCP > 80
                       OR WS-TITCONT(TCP:1) = "'"
                       ADD 1 TO SC-TLEN END-ADD
                       MOVE WS-TITCONT(TCP:1) TO SC-TOKEN(SC-TLEN:1)
                       ADD 1 TO TCP END-ADD
                   END-PERFORM
                   IF TCP > 80
                       MOVE "UNTERMINATED LITERAL" TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               ELSE
                   MOVE "UNTERMINATED LITERAL" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           ELSE
               ADD 1 TO SC-PTR END-ADD
           END-IF.
      *
       1520-HEX-TO-BYTES.
      *    CONVERT HEX DIGIT PAIRS IN SC-TOKEN TO RAW BYTES.
      *    LOWERCASE ACCEPTED; ODD LENGTH OR BAD DIGIT = CARD ERROR.
           DIVIDE SC-TLEN BY 2 GIVING J REMAINDER K END-DIVIDE
           IF K NOT = 0
               MOVE "HEX LITERAL MUST HAVE EVEN LENGTH"
                   TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1520-EXIT
           END-IF
      *    G9: INSPECT CONVERTING (STANDARD 85) VS FUNCTION UPPER-CASE
           INSPECT SC-TOKEN CONVERTING
               "abcdefghijklmnopqrstuvwxyz" TO
               "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
           MOVE 0 TO J
           PERFORM VARYING I FROM 1 BY 2 UNTIL I >= SC-TLEN
               OR SW-PARSE-ERR = "Y"
               PERFORM 1525-HEX-NIBBLE THRU 1525-EXIT
           END-PERFORM
           MOVE J TO SC-TLEN.
       1520-EXIT.
           EXIT.
      *
       1525-HEX-NIBBLE.
           MOVE 0 TO DN-HI DN-LO N
      *    N COUNTS MATCHED DIGITS - BOTH NIBBLES MUST MATCH
           PERFORM VARYING K FROM 1 BY 1 UNTIL K > 16
               IF SC-TOKEN(I:1) = HEX-CHARS(K:1)
                   COMPUTE DN-HI = K - 1 END-COMPUTE
                   ADD 1 TO N END-ADD
               END-IF
               IF SC-TOKEN(I + 1:1) = HEX-CHARS(K:1)
                   COMPUTE DN-LO = K - 1 END-COMPUTE
                   ADD 1 TO N END-ADD
               END-IF
           END-PERFORM
           IF N < 2
               MOVE "INVALID HEX DIGIT IN LITERAL" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1525-EXIT
           END-IF
           MULTIPLY 16 BY DN-HI GIVING DN-BYTE END-MULTIPLY
           ADD DN-LO TO DN-BYTE END-ADD
           ADD 1 TO J END-ADD
           PERFORM 7300-BYTE-TO-CHAR
           MOVE TRT-CHAR TO SC-TOKEN(J:1).
       1525-EXIT.
           EXIT.
      *
       1530-GET-WORD.
           MOVE "W" TO SC-TYPE
           PERFORM UNTIL SC-PTR > 80
               OR WS-OPRND(SC-PTR:1) = SPACE
               OR WS-OPRND(SC-PTR:1) = ","
               OR WS-OPRND(SC-PTR:1) = "/"
      *        M3: A CONNECTOR ALSO ENDS A WORD. WITHOUT THIS,
      *        "GT,2.Y.LT,5" READS THE COUNT OPERAND AS "2.Y.LT".
      *        "12.5" IS UNAFFECTED - ".5" IS NOT A CONNECTOR.
               IF WS-OPRND(SC-PTR:1) = "."
                   PERFORM 1536-PEEK-CONNECTOR
                   IF SC-CLEN > 0
                       EXIT PERFORM
                   END-IF
               END-IF
               ADD 1 TO SC-TLEN END-ADD
               MOVE WS-OPRND(SC-PTR:1) TO SC-TOKEN(SC-TLEN:1)
               ADD 1 TO SC-PTR END-ADD
           END-PERFORM.
      *
       1540-EAT-DELIM.
      *    CONSUME ONE TRAILING , OR / DELIMITER (SKIPPING BLANKS)
           PERFORM UNTIL SC-PTR > 80
               OR WS-OPRND(SC-PTR:1) NOT = SPACE
               ADD 1 TO SC-PTR END-ADD
           END-PERFORM
           IF SC-PTR <= 80
               IF WS-OPRND(SC-PTR:1) = "," OR WS-OPRND(SC-PTR:1) = "/"
                   MOVE WS-OPRND(SC-PTR:1) TO SC-DELIM
                   ADD 1 TO SC-PTR END-ADD
               END-IF
           END-IF.
      *
       1550-TOKEN-TO-NUM.
      *    NUMERIC CONVERSION OF SC-TOKEN -> H-NUM ("S" PREFIX KEPT
      *    BY CALLER). NON-NUMERIC -> PARSE ERROR.
           MOVE 0 TO H-NUM
           IF SC-TLEN = 0
               MOVE "MISSING NUMERIC OPERAND" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1550-EXIT
           END-IF
           IF SC-TLEN > 6
      *        H-NUM IS 9(6): LARGER VALUES WOULD TRUNCATE SILENTLY
               MOVE "NUMERIC OPERAND EXCEEDS 6 DIGITS" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1550-EXIT
           END-IF
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > SC-TLEN
               IF SC-TOKEN(I:1) < "0" OR SC-TOKEN(I:1) > "9"
                   STRING "NON-NUMERIC OPERAND: " SC-TOKEN(1:SC-TLEN)
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1550-EXIT
               END-IF
               MULTIPLY 10 BY H-NUM END-MULTIPLY
               MOVE SC-TOKEN(I:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               ADD DN-DIGIT TO H-NUM END-ADD
           END-PERFORM.
       1550-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1200 RCIN / RCOUT : CONDITION GROUP.  1210 CONDX.
      * FORMS: off,op,'lit'  OR  off,len,op,'lit'
      * CONNECTORS: .AND./.Y. , .OR./.O. , "/"=OR. NO MIXING PER GROUP.
      *----------------------------------------------------------------
       1200-PARSE-RC.
           ADD 1 TO WS-GROUP-NO END-ADD
           MOVE SPACE TO H-GRP-TRUE
      *    RESET SCANNER STATE: UNTIL IS TESTED BEFORE 1ST ITERATION
      *    AND WOULD SEE THE PREVIOUS CARD'S FINAL E+SPACE STATE
           MOVE SPACE TO SC-TYPE SC-DELIM
      *    H-GRP-TRUE REUSED HERE AS GROUP FAMILY: A, O OR SPACE
           PERFORM 1201-PARSE-ONE-COND THRU 1201-EXIT
               UNTIL SC-TYPE = "E" AND SC-DELIM = SPACE
               OR SW-PARSE-ERR = "Y".
      *
       1201-PARSE-ONE-COND.
           IF COND-CNT >= 150
               MOVE "CONDITION TABLE FULL (150)" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1201-EXIT
           END-IF
           ADD 1 TO COND-CNT END-ADD
           MOVE WS-GROUP-NO TO CT-GROUP(COND-CNT)
           IF WS-OPCODE = "RCIN"
               MOVE "I" TO CT-KIND(COND-CNT)
           ELSE
               MOVE "O" TO CT-KIND(COND-CNT)
           END-IF
           IF WS-COND-IDX > 0
               MOVE "C" TO CT-KIND(COND-CNT)
               MOVE WS-COND-IDX TO CT-FLAG(COND-CNT)
           ELSE
               MOVE 0 TO CT-FLAG(COND-CNT)
           END-IF
           MOVE "1" TO CT-FILE(COND-CNT)
           MOVE 0 TO CT-CNT(COND-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TYPE = "E"
               SUBTRACT 1 FROM COND-CNT END-SUBTRACT
               GO TO 1201-EXIT
           END-IF
      *    M2: SECOND SYNTAX ALTERNATIVE OF SHEETS 8 AND 9 IS
      *    "OP,CUENTA" - NO OFFSET, COMPARES THE RUNNING RECORD
      *    COUNT. AN OPERATOR IS ALPHABETIC AND AN OFFSET NUMERIC,
      *    SO THE TWO FORMS CANNOT BE CONFUSED.
           IF SC-TLEN = 2
               IF SC-TOKEN = "EQ  " OR SC-TOKEN = "NE  "
                  OR SC-TOKEN = "LT  " OR SC-TOKEN = "GT  "
                  OR SC-TOKEN = "LE  " OR SC-TOKEN = "GE  "
                  OR SC-TOKEN = "NL  " OR SC-TOKEN = "NH  "
                   MOVE "N" TO CT-FILE(COND-CNT)
                   MOVE SC-TOKEN(1:2) TO CT-OP(COND-CNT)
                   MOVE 0 TO CT-OFF(COND-CNT) CT-LEN(COND-CNT)
                   MOVE SPACES TO CT-LIT(COND-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO CT-CNT(COND-CNT)
                   PERFORM 1205-PARSE-CONNECTOR
                   GO TO 1201-EXIT
               END-IF
           END-IF
           IF SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
               MOVE "3" TO CT-FILE(COND-CNT)
               MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
               SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CT-OFF(COND-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TOKEN(1:1) >= "0" AND SC-TOKEN(1:1) <= "9"
               PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
               MOVE H-NUM TO CT-LEN(COND-CNT)
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           ELSE
               MOVE 0 TO CT-LEN(COND-CNT)
           END-IF
           IF SC-TLEN = 0
      *        M1: AN EMPTY OPERATOR FIELD ("27,,'9'") ASSUMES EQ.
      *        SHEETS 8 AND 9: "SI SE OMITE ASUME EQ".
               MOVE "EQ" TO CT-OP(COND-CNT)
           ELSE
               PERFORM 1560-VALIDATE-OP
               MOVE SC-TOKEN(1:2) TO CT-OP(COND-CNT)
           END-IF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TYPE NOT = "L" AND SC-TYPE NOT = "X"
               MOVE "LITERAL EXPECTED IN CONDITION" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1201-EXIT
           END-IF
           MOVE SC-TOKEN TO CT-LIT(COND-CNT)
           IF CT-LEN(COND-CNT) = 0
               MOVE SC-TLEN TO CT-LEN(COND-CNT)
           END-IF
           PERFORM 1205-PARSE-CONNECTOR.
       1201-EXIT.
           EXIT.
      *
       1205-PARSE-CONNECTOR.
      *    M3 RUN MODEL (MANUAL SHEET 8): A CARD IS A DISJUNCTION OF
      *    RUNS. "/" CLOSES THE CURRENT RUN AND OPENS A NEW ONE, SO
      *    THE FAMILY MAY CHANGE ACROSS IT; .AND./.Y. AND .OR./.O.
      *    CHAIN CONDITIONS INSIDE ONE RUN AND MAY NOT BE MIXED
      *    THERE. RUNS ARE OR-ED BY 3200, WHICH IS WHY "/" IS
      *    EQUIVALENT TO .O. IN EFFECT.
           MOVE SPACE TO CT-CONN(COND-CNT)
           IF SC-DELIM = "/"
      *        END OF RUN: NEXT CONDITION STARTS A FRESH GROUP AND A
      *        FRESH FAMILY. CT-CONN STAYS BLANK - IT DESCRIBES THE
      *        LINK *INSIDE* A RUN ONLY.
               ADD 1 TO WS-GROUP-NO END-ADD
               MOVE SPACE TO H-GRP-TRUE
           ELSE
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               EVALUATE TRUE
                   WHEN SC-TYPE = "E" AND SC-DELIM = SPACE
                       CONTINUE
                   WHEN SC-TOKEN = ".AND." OR SC-TOKEN = ".Y."
                       MOVE "A" TO CT-CONN(COND-CNT)
                   WHEN SC-TOKEN = ".OR." OR SC-TOKEN = ".O."
                       MOVE "O" TO CT-CONN(COND-CNT)
                   WHEN OTHER
                       MOVE "BAD CONNECTOR IN CONDITION GROUP"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
               END-EVALUATE
           END-IF
           IF CT-CONN(COND-CNT) NOT = SPACE
               IF H-GRP-TRUE = SPACE
                   MOVE CT-CONN(COND-CNT) TO H-GRP-TRUE
               ELSE
                   IF H-GRP-TRUE NOT = CT-CONN(COND-CNT)
                       MOVE "MIXED .AND./.OR. IN ONE GROUP FORBIDDEN"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   END-IF
               END-IF
           END-IF.
      *
       1560-VALIDATE-OP.
           IF SC-TOKEN NOT = "EQ" AND SC-TOKEN NOT = "NE"
              AND SC-TOKEN NOT = "LT" AND SC-TOKEN NOT = "GT"
              AND SC-TOKEN NOT = "LE" AND SC-TOKEN NOT = "GE"
              AND SC-TOKEN NOT = "NL" AND SC-TOKEN NOT = "NH"
               STRING "INVALID OPERATOR: " SC-TOKEN(1:8)
                   DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
               PERFORM 9000-PARSE-ERROR
           END-IF.
      *
       1210-PARSE-COND.
           IF WS-OPCODE(5:1) < "1" OR WS-OPCODE(5:1) > "8"
               MOVE "CONDX INDEX MUST BE 1-8" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1210-EXIT
           END-IF
           MOVE WS-OPCODE(5:1) TO TRT-CHAR
           PERFORM 7700-CHAR-TO-DIGIT
           MOVE DN-DIGIT TO WS-COND-IDX
           ADD 1 TO WS-GROUP-NO END-ADD
           MOVE SPACE TO H-GRP-TRUE
      *    M3: CONDX TAKES A CONDITION *GROUP*, EXACTLY LIKE
      *    RCIN/RCOUT (SHEET 9). THIS USED TO PARSE ONLY THE FIRST
      *    CONDITION AND DISCARD THE REST OF THE CARD IN SILENCE.
      *    SCANNER STATE RESET AS IN 1200: THE UNTIL IS TESTED FIRST.
           MOVE SPACE TO SC-TYPE SC-DELIM
           PERFORM 1201-PARSE-ONE-COND THRU 1201-EXIT
               UNTIL SC-TYPE = "E" AND SC-DELIM = SPACE
               OR SW-PARSE-ERR = "Y".
       1210-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1220 ACUMY[X]  OP,FMT,SI,LONG  (UP TO 10 TUPLES PER CARD)
      *----------------------------------------------------------------
       1220-PARSE-ACUM.
           IF WS-OPCODE(5:1) < "1" OR WS-OPCODE(5:1) > "9"
               MOVE "ACUM REGISTER MUST BE 1-9" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1220-EXIT
           END-IF
           MOVE 0 TO WS-COND-IDX
           IF WS-OPCODE(6:1) >= "1" AND WS-OPCODE(6:1) <= "8"
               MOVE WS-OPCODE(6:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO WS-COND-IDX
           END-IF
      *    RESET SCANNER STATE (SEE 1200): FORCE LOOP ENTRY
           MOVE SPACE TO SC-TYPE SC-DELIM
           PERFORM 1221-PARSE-ACUM-OP THRU 1221-EXIT
               UNTIL SC-TYPE = "E" AND SC-DELIM = SPACE
               OR SW-PARSE-ERR = "Y".
       1220-EXIT.
           EXIT.
      *
       1221-PARSE-ACUM-OP.
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TYPE = "E" AND SC-DELIM = SPACE
               GO TO 1221-EXIT
           END-IF
           IF ACUM-CNT >= 90
               MOVE "ACUM OPERATION TABLE FULL" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1221-EXIT
           END-IF
           ADD 1 TO ACUM-CNT END-ADD
           MOVE WS-OPCODE(5:1) TO TRT-CHAR
           PERFORM 7700-CHAR-TO-DIGIT
           MOVE DN-DIGIT TO AT-ACUM(ACUM-CNT)
           MOVE WS-COND-IDX TO AT-FLAG(ACUM-CNT)
           MOVE "F" TO AT-SRCK(ACUM-CNT)
           MOVE "1" TO AT-FILE(ACUM-CNT)
           MOVE 0 TO AT-DEC(ACUM-CNT)
           MOVE 0 TO AT-LIT(ACUM-CNT)
      *    THE DIVISION OPERATOR IS THE SAME CHARACTER THE SCANNER
      *    EATS AS A GROUP DELIMITER: AN EMPTY TOKEN ENDED BY "/"
      *    IN OPERATOR POSITION MEANS OP = "/"
           IF SC-TYPE = "E" AND SC-DELIM = "/"
               MOVE "/" TO AT-OP(ACUM-CNT)
           ELSE
               IF SC-TOKEN(1:1) NOT = "+"
                  AND SC-TOKEN(1:1) NOT = "-"
                  AND SC-TOKEN(1:1) NOT = "*"
                  AND SC-TOKEN(1:1) NOT = "/"
                   MOVE "ACUM OPERATOR MUST BE + - * /" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1221-EXIT
               END-IF
               MOVE SC-TOKEN(1:1) TO AT-OP(ACUM-CNT)
           END-IF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    "/,Z,..." LEAVES A LEFTOVER COMMA -> ONE EMPTY TOKEN
           IF SC-TYPE = "E" AND SC-DELIM = ","
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           END-IF
      *    M4: THE MANUAL'S SECOND ALTERNATIVE (SHEET 10) IS
      *    "COD.OP,NUM" - THE OPERAND POSITION HOLDS THE NUMERIC
      *    LITERAL ITSELF, WITH NO FORMAT LETTER. A FORMAT IS ALWAYS
      *    P/Z/S/B/L, SO A LEADING DIGIT, "-" OR "." IS UNAMBIGUOUS.
      *    (G5'S "L" MARKER IS KEPT BELOW AS A TOLERATED SYNONYM.)
           IF SC-TOKEN(1:1) >= "0" AND SC-TOKEN(1:1) <= "9"
              OR SC-TOKEN(1:1) = "-" OR SC-TOKEN(1:1) = "."
               MOVE "L" TO AT-SRCK(ACUM-CNT)
               MOVE "Z" TO AT-FMT(ACUM-CNT)
               PERFORM 1223-PARSE-ACUM-LIT THRU 1223-EXIT
               GO TO 1221-EXIT
           END-IF
      *    G5: FORMAT "L" = NUMERIC LITERAL OPERAND; P/Z/S/B MAY
      *    CARRY TRAILING DIGITS = IMPLIED DECIMAL PLACES (E.G. Z2)
           IF SC-TOKEN(1:1) = "L"
               MOVE "L" TO AT-SRCK(ACUM-CNT)
               MOVE "Z" TO AT-FMT(ACUM-CNT)
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               PERFORM 1223-PARSE-ACUM-LIT THRU 1223-EXIT
               GO TO 1221-EXIT
           END-IF
           IF SC-TOKEN(1:1) NOT = "P" AND SC-TOKEN(1:1) NOT = "Z"
              AND SC-TOKEN(1:1) NOT = "S" AND SC-TOKEN(1:1) NOT = "B"
               MOVE "ACUM FORMAT MUST BE P Z S B L" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1221-EXIT
           END-IF
           MOVE SC-TOKEN(1:1) TO AT-FMT(ACUM-CNT)
           IF SC-TLEN > 1
               MOVE SC-TOKEN(2:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO AT-DEC(ACUM-CNT)
           END-IF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    M6: "S12" = THE FIELD LIVES IN SYSUT3 (SHEET 10)
           IF SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
               MOVE "3" TO AT-FILE(ACUM-CNT)
               MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
               SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO AT-OFF(ACUM-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO AT-LEN(ACUM-CNT).
       1221-EXIT.
           EXIT.
      *
       1223-PARSE-ACUM-LIT.
      *    G5: PARSE A NUMERIC LITERAL (OPTIONAL "." DECIMAL POINT,
      *    OPTIONAL LEADING "-") FROM SC-TOKEN INTO AT-LIT.
      *    NOTE: THE SCANNER TREATS "," AS A DELIMITER, SO LITERALS
      *    USE "." REGARDLESS OF THE DISPLAY DECIMAL-POINT SETTING.
           MOVE 0 TO AT-LIT(ACUM-CNT)
           MOVE 0 TO EN-LEN
      *    EN-LEN REUSED AS DECIMAL-DIGIT COUNTER; K = SEEN-DOT FLAG
           MOVE 0 TO K
           MOVE 1 TO J
           IF SC-TLEN > 0 AND SC-TOKEN(1:1) = "-"
               MOVE 2 TO J
           END-IF
           PERFORM VARYING I FROM J BY 1 UNTIL I > SC-TLEN
               IF SC-TOKEN(I:1) = "."
                   MOVE 1 TO K
               ELSE
                   IF SC-TOKEN(I:1) < "0" OR SC-TOKEN(I:1) > "9"
                       MOVE "BAD NUMERIC LITERAL IN ACUM"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                       GO TO 1223-EXIT
                   END-IF
                   MOVE SC-TOKEN(I:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MULTIPLY 10 BY AT-LIT(ACUM-CNT) END-MULTIPLY
                   ADD DN-DIGIT TO AT-LIT(ACUM-CNT) END-ADD
                   IF K = 1
                       ADD 1 TO EN-LEN END-ADD
                   END-IF
               END-IF
           END-PERFORM
      *    SCALE DOWN BY THE NUMBER OF FRACTIONAL DIGITS SEEN
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > EN-LEN
               DIVIDE AT-LIT(ACUM-CNT) BY 10
                   GIVING AT-LIT(ACUM-CNT) END-DIVIDE
           END-PERFORM
           IF J = 2
               COMPUTE AT-LIT(ACUM-CNT) = 0 - AT-LIT(ACUM-CNT)
               END-COMPUTE
           END-IF.
       1223-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1230 FIELD[X]: SI,LONG,CONV,SO | AY,CONV,SO | 'LIT',CL,SO,LONG
      *----------------------------------------------------------------
       1230-PARSE-FIELD.
      *    M27: A FIELD CARD CARRIES SEVERAL "/"-SEPARATED GROUPS AND
      *    EVERY ONE OF THEM IS AN OPERATION (SHEET 33: "SE REALIZARAN
      *    EN EL MISMO ORDEN EN QUE APARECEN EN LAS TARJETAS"). THIS
      *    USED TO PARSE ONE GROUP AND DISCARD THE REST IN SILENCE.
      *    SCANNER STATE RESET AS IN 1200: THE UNTIL IS TESTED FIRST.
           MOVE SPACE TO SC-TYPE SC-DELIM
           PERFORM 1231-PARSE-FIELD-GROUP THRU 1231-EXIT
               UNTIL SC-TYPE = "E" AND SC-DELIM = SPACE
               OR SW-PARSE-ERR = "Y".
       1230-EXIT.
           EXIT.
      *
       1231-PARSE-FIELD-GROUP.
           IF FIELD-CNT >= 125
               MOVE "FIELD TABLE FULL (125)" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1231-EXIT
           END-IF
           ADD 1 TO FIELD-CNT END-ADD
           MOVE 0 TO FT-FLAG(FIELD-CNT)
           IF WS-OPCODE(6:1) >= "1" AND WS-OPCODE(6:1) <= "8"
               MOVE WS-OPCODE(6:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO FT-FLAG(FIELD-CNT)
           END-IF
           MOVE "M" TO FT-DEST(FIELD-CNT)
           MOVE "1" TO FT-FILE(FIELD-CNT)
           MOVE 0 TO FT-DIGITS(FIELD-CNT) FT-DEC(FIELD-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    M27: NOTHING LEFT ON THE CARD - GIVE THE ENTRY BACK
           IF SC-TYPE = "E" AND SC-DELIM = SPACE
               SUBTRACT 1 FROM FIELD-CNT END-SUBTRACT
               GO TO 1231-EXIT
           END-IF
      *    M5: "EC=xy" IS NOT AN OPERAND GROUP - IT OVERRIDES THE
      *    LISTING SPACING (x BETWEEN LINES OF ONE RECORD, y BETWEEN
      *    RECORDS), EXACTLY LIKE PRINT SP=/SR= (SHEET 11).
           IF SC-TOKEN(1:3) = "EC="
               IF SC-TLEN NOT = 5
                   MOVE "EC= NEEDS TWO SPACING DIGITS" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1231-EXIT
               END-IF
               MOVE SC-TOKEN(4:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO PR-SP
               MOVE SC-TOKEN(5:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO PR-SR
               SUBTRACT 1 FROM FIELD-CNT END-SUBTRACT
               GO TO 1231-EXIT
           END-IF
           EVALUATE TRUE
               WHEN SC-TYPE = "L" OR SC-TYPE = "X"
                   MOVE "L" TO FT-SRC(FIELD-CNT)
                   MOVE SC-TOKEN(1:40) TO FT-LIT(FIELD-CNT)
                   MOVE SC-TLEN TO FT-LLEN(FIELD-CNT)
                   MOVE 0 TO FT-OUTLEN(FIELD-CNT)
                   MOVE "CL" TO FT-CONV(FIELD-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   IF SC-TOKEN = "CL"
      *                'LITERAL2',CL,SO{,LONG} - FILL OPERATION.
      *                M27: THE FILL WIDTH IS THE OPTIONAL ",LONG"
      *                1236 ALREADY CONSUMED; WITHOUT THAT TEST THIS
      *                READ THE NEXT GROUP'S OPERAND AS THE WIDTH.
                       PERFORM 1236-PARSE-OUT-TOKEN
                       IF FT-OUTLEN(FIELD-CNT) > 0
                           MOVE FT-OUTLEN(FIELD-CNT)
                               TO FT-LEN(FIELD-CNT)
                       ELSE
                           MOVE FT-LLEN(FIELD-CNT)
                               TO FT-LEN(FIELD-CNT)
                       END-IF
                   ELSE
      *                M8: 'LITERAL1',SO - PLAIN TRANSFER, NO CL
      *                (SHEETS 11 AND 32). THE TOKEN JUST READ IS
      *                ALREADY THE OUTPUT POSITION. A ONE-SHOT FILL
      *                OF THE LITERAL'S OWN LENGTH IS EXACTLY THAT.
                       MOVE FT-LLEN(FIELD-CNT) TO FT-LEN(FIELD-CNT)
                       PERFORM 1238-OUT-FROM-TOKEN
                   END-IF
      *        M20: "AN" IS THE WRITTEN-RECORD COUNTER (SHEET 32),
      *        NOT ACCUMULATOR "N". IT MUST BE TESTED FIRST.
               WHEN SC-TOKEN = "AN  "
                   MOVE "N" TO FT-SRC(FIELD-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1235-PARSE-CONV-TYPE
                   PERFORM 1236-PARSE-OUT-TOKEN
               WHEN SC-TOKEN(1:1) = "A" AND SC-TLEN = 2
                   MOVE "A" TO FT-SRC(FIELD-CNT)
                   MOVE SC-TOKEN(2:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MOVE DN-DIGIT TO FT-ACUM(FIELD-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1235-PARSE-CONV-TYPE
                   PERFORM 1236-PARSE-OUT-TOKEN
               WHEN OTHER
                   MOVE "F" TO FT-SRC(FIELD-CNT)
      *            M6: "S12" = THE FIELD LIVES IN SYSUT3
                   IF SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
                       MOVE "3" TO FT-FILE(FIELD-CNT)
                       MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                       SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
                   END-IF
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO FT-OFF(FIELD-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO FT-LEN(FIELD-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1235-PARSE-CONV-TYPE
                   PERFORM 1236-PARSE-OUT-TOKEN
           END-EVALUATE.
       1231-EXIT.
           EXIT.
      *
       1235-PARSE-CONV-TYPE.
           MOVE 0 TO FT-OUTLEN(FIELD-CNT)
           EVALUATE TRUE
      *        M9: SHEETS 11 AND 32 BOTH MARK CONV OPTIONAL AND SAY
      *        "M" IS ASSUMED, SO AN EMPTY FIELD ("20,4,,10") IS A
      *        PLAIN MOVE - NOT THE CARD ERROR IT USED TO RAISE.
               WHEN SC-TLEN = 0
                   MOVE "MV" TO FT-CONV(FIELD-CNT)
               WHEN SC-TOKEN = "MOVE" OR SC-TOKEN = "M"
                   MOVE "MV" TO FT-CONV(FIELD-CNT)
      *        M19: A BARE FORMAT LETTER IS THE OUTPUT FORMAT OF AN
      *        ACCUMULATOR OR THE RECORD COUNTER ("AY,FORMATO" AND
      *        "AN,FORMATO", SHEET 32) - THERE IS NO INPUT FORMAT TO
      *        DECODE, THE VALUE IS ALREADY BINARY IN MEMORY.
               WHEN SC-TLEN = 1 AND
                    (SC-TOKEN(1:1) = "B" OR SC-TOKEN(1:1) = "P" OR
                     SC-TOKEN(1:1) = "Z" OR SC-TOKEN(1:1) = "S")
                   MOVE "AF" TO FT-CONV(FIELD-CNT)
                   MOVE SC-TOKEN(1:1) TO FT-OUTFMT(FIELD-CNT)
      *        M29: SHEET 32 VALIDATION CONVERSIONS - VERIFY THE
      *        CLASS AND REPLACE INVALID BYTES (AN/AB -> BLANK,
      *        NO -> ZERO). CHECKED BEFORE THE XY BRANCH BECAUSE
      *        "AN" WOULD OTHERWISE LOOK LIKE A FORMAT PAIR.
               WHEN SC-TOKEN = "AN  "
                   MOVE "VN" TO FT-CONV(FIELD-CNT)
               WHEN SC-TOKEN = "AB  "
                   MOVE "VA" TO FT-CONV(FIELD-CNT)
               WHEN SC-TOKEN = "NO  "
                   MOVE "VZ" TO FT-CONV(FIELD-CNT)
               WHEN SC-TOKEN = "UNPK" OR SC-TOKEN = "U"
                   MOVE "UN" TO FT-CONV(FIELD-CNT)
               WHEN SC-TOKEN = "HEXA" OR SC-TOKEN = "H"
                   MOVE "HX" TO FT-CONV(FIELD-CNT)
               WHEN SC-TLEN >= 3 AND
                    (SC-TOKEN(2:2) = "DV" OR SC-TOKEN(1:3) = "ZDV"
                     OR SC-TOKEN(1:3) = "zDV")
                   MOVE "DV" TO FT-CONV(FIELD-CNT)
      *        G6: XY FORMAT CROSS-CONVERSION - CHAR 2 IS A FORMAT
      *        LETTER (B/P/Z/S). OPTIONAL TRAILING DIGITS = OUTPUT
      *        LENGTH (E.G. ZP4). CHECKED BEFORE THE ZxDy/PxDy MASK
      *        BRANCH, WHOSE CHAR 2 IS ALWAYS A DIGIT OR "D".
               WHEN SC-TLEN >= 2 AND
                    (SC-TOKEN(1:1) = "B" OR SC-TOKEN(1:1) = "P" OR
                     SC-TOKEN(1:1) = "Z" OR SC-TOKEN(1:1) = "S") AND
                    (SC-TOKEN(2:1) = "B" OR SC-TOKEN(2:1) = "P" OR
                     SC-TOKEN(2:1) = "Z" OR SC-TOKEN(2:1) = "S")
                   MOVE "XY" TO FT-CONV(FIELD-CNT)
                   MOVE SC-TOKEN(1:1) TO FT-INFMT(FIELD-CNT)
                   MOVE SC-TOKEN(2:1) TO FT-OUTFMT(FIELD-CNT)
                   PERFORM VARYING I FROM 3 BY 1 UNTIL I > SC-TLEN
                       MOVE SC-TOKEN(I:1) TO TRT-CHAR
                       PERFORM 7700-CHAR-TO-DIGIT
                       MULTIPLY 10 BY FT-OUTLEN(FIELD-CNT)
                       END-MULTIPLY
                       ADD DN-DIGIT TO FT-OUTLEN(FIELD-CNT) END-ADD
                   END-PERFORM
               WHEN (SC-TOKEN(1:1) = "Z" OR SC-TOKEN(1:1) = "P")
                    AND SC-TLEN >= 3
                   PERFORM 1237-PARSE-MASK
               WHEN OTHER
                   STRING "UNKNOWN CONVERSION: " SC-TOKEN(1:8)
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
           END-EVALUATE.
      *
       1237-PARSE-MASK.
      *    ZXDY / PXDY EDIT MASKS: X TOTAL DIGITS, Y DECIMALS
           IF SC-TOKEN(1:1) = "Z"
               MOVE "ZD" TO FT-CONV(FIELD-CNT)
           ELSE
               MOVE "PD" TO FT-CONV(FIELD-CNT)
           END-IF
           MOVE 0 TO FT-DIGITS(FIELD-CNT) FT-DEC(FIELD-CNT)
           MOVE 0 TO J
           PERFORM VARYING I FROM 2 BY 1 UNTIL I > SC-TLEN
               EVALUATE TRUE
                   WHEN SC-TOKEN(I:1) = "D"
                       MOVE 1 TO J
                   WHEN SC-TOKEN(I:1) >= "0" AND SC-TOKEN(I:1) <= "9"
                       MOVE SC-TOKEN(I:1) TO TRT-CHAR
                       PERFORM 7700-CHAR-TO-DIGIT
                       IF J = 0
                           MULTIPLY 10 BY FT-DIGITS(FIELD-CNT)
                           END-MULTIPLY
                           ADD DN-DIGIT
                               TO FT-DIGITS(FIELD-CNT) END-ADD
                       ELSE
                           MULTIPLY 10 BY FT-DEC(FIELD-CNT) END-MULTIPLY
                           ADD DN-DIGIT
                               TO FT-DEC(FIELD-CNT) END-ADD
                       END-IF
                   WHEN OTHER
                       MOVE "BAD EDIT MASK" TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
               END-EVALUATE
           END-PERFORM.
      *
       1236-PARSE-OUT-TOKEN.
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1238-OUT-FROM-TOKEN.
      *
       1238-OUT-FROM-TOKEN.
      *    THE OUTPUT POSITION IS ALREADY IN SC-TOKEN (M8 NEEDS TO
      *    CLASSIFY A TOKEN IT HAS ALREADY READ).
           EVALUATE TRUE
               WHEN SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
                   MOVE "S" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               WHEN SC-TOKEN(1:1) = "T" AND SC-TLEN > 1
                   MOVE "3" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               WHEN SC-TOKEN(1:1) = "C" AND SC-TLEN > 1
                   MOVE "4" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
      *        M7: SHEET 11 DEFINES NINE PRINT LINES -
      *        so / Snnn / Tnnn / Cnnn / Qnnn / Xnnn / Pnnn / Onnn /
      *        Nnnn. ONLY THE FIRST FOUR EXISTED BEFORE.
               WHEN SC-TOKEN(1:1) = "Q" AND SC-TLEN > 1
                   MOVE "5" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               WHEN SC-TOKEN(1:1) = "X" AND SC-TLEN > 1
                   MOVE "6" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               WHEN SC-TOKEN(1:1) = "P" AND SC-TLEN > 1
                   MOVE "7" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               WHEN SC-TOKEN(1:1) = "O" AND SC-TLEN > 1
                   MOVE "8" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               WHEN SC-TOKEN(1:1) = "N" AND SC-TLEN > 1
                   MOVE "9" TO FT-DEST(FIELD-CNT)
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           END-EVALUATE
           IF MODE-OSGENER
               IF FT-DEST(FIELD-CNT) >= "3"
                  AND FT-DEST(FIELD-CNT) <= "9"
      *            THE EXTRA PRINT LINES EXIST ONLY IN OSLISTA
                   MOVE "EXTRA PRINT-LINE PREFIX NOT VALID IN OSGENER"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO FT-OUT(FIELD-CNT)
      *    M27: SHEET 32 ENDS THE GROUP WITH AN OPTIONAL ",LONG" (THE
      *    OUTPUT WIDTH). IT MUST BE CONSUMED HERE, OTHERWISE THE
      *    GROUP LOOP WOULD READ IT AS THE NEXT GROUP'S OFFSET. AN
      *    EXPLICIT WIDTH OVERRIDES THE ONE G6 DERIVES FROM A
      *    TRAILING DIGIT ON THE XY TOKEN (E.G. "ZP4").
           IF SC-DELIM = ","
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
               MOVE H-NUM TO FT-OUTLEN(FIELD-CNT)
           END-IF.
      *
      *----------------------------------------------------------------
      * 1240 CONV DD=DDNAME,NNK,SI,LONG1,SIA/SO,LONG2,SIF[,/INT]
      *----------------------------------------------------------------
       1240-PARSE-CONV.
           IF CONV-CNT >= 20
               MOVE "CONV TABLE LIMIT (20) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1240-EXIT
           END-IF
           ADD 1 TO CONV-CNT END-ADD
           MOVE "N" TO CV-INT(CONV-CNT)
           MOVE "N" TO CV-INLINE(CONV-CNT)
           MOVE "1" TO CV-INFILE(CONV-CNT)
           MOVE "M" TO CV-DEST(CONV-CNT)
           MOVE 0 TO CV-TIT(CONV-CNT)
           MOVE SPACES TO CV-DD(CONV-CNT)
           MOVE 0 TO CV-N(CONV-CNT)
      *    M12: CONVX - THE CONVERSION RUNS ONLY IF CONDITION X IS
      *    SET (SHEETS 13 AND 34), EXACTLY LIKE FIELDX AND ACUMYX.
           MOVE 0 TO CV-FLAG(CONV-CNT)
           IF WS-OPCODE(5:1) >= "1" AND WS-OPCODE(5:1) <= "8"
               MOVE WS-OPCODE(5:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO CV-FLAG(CONV-CNT)
           END-IF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    M13: "TITx/" SENDS THE RESULT INTO TITLE LINE x INSTEAD OF
      *    A DETAIL LINE (SHEET 13; OSLISTA ONLY).
           IF SC-TOKEN(1:3) = "TIT" AND SC-TLEN = 4
               IF MODE-OSGENER
                   MOVE "CONV TITx NOT VALID IN OSGENER MODE"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1240-EXIT
               END-IF
               MOVE SC-TOKEN(4:1) TO TRT-CHAR
               PERFORM 7700-CHAR-TO-DIGIT
               MOVE DN-DIGIT TO CV-TIT(CONV-CNT)
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           END-IF
      *    M11: DD= IS OPTIONAL. WITHOUT IT THE TABLE IS INCLUDED IN
      *    SYSIN AND 1000 COLLECTS THE ROWS THAT FOLLOW THIS CARD.
           IF SC-TOKEN(1:3) = "DD="
               MOVE SC-TOKEN(4:8) TO CV-DD(CONV-CNT)
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           ELSE
               MOVE "Y" TO CV-INLINE(CONV-CNT)
           END-IF
           IF SC-TLEN = 0
               MOVE "CONV CARD TRUNCATED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1240-EXIT
           END-IF
      *    MEMORY SIZE TOKEN NNK - ACCEPTED AND IGNORED (FIXED CAP)
           IF SC-TOKEN(SC-TLEN:1) NOT = "K"
      *        NOT A MEMORY TOKEN: TREAT AS FIRST NUMERIC OPERAND
               CONTINUE
           ELSE
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           END-IF
      *    M6: "S12" = THE FIELD TO CONVERT LIVES IN SYSUT3
           IF SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
               MOVE "3" TO CV-INFILE(CONV-CNT)
               MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
               SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CV-INOFF(CONV-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CV-INLEN(CONV-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CV-ARGOFF(CONV-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    M14: THE RESULT POSITION MAY CARRY A DESTINATION PREFIX -
      *    IN OSLISTA ONE OF THE NINE PRINT LINES (S/T/C/Q/X/P/O/N),
      *    IN OSGENER "S" MEANS SYSUT4 (SHEETS 13 AND 34).
           EVALUATE TRUE
               WHEN SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
                   MOVE "S" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "T" AND SC-TLEN > 1
                   MOVE "3" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "C" AND SC-TLEN > 1
                   MOVE "4" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "Q" AND SC-TLEN > 1
                   MOVE "5" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "X" AND SC-TLEN > 1
                   MOVE "6" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "P" AND SC-TLEN > 1
                   MOVE "7" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "O" AND SC-TLEN > 1
                   MOVE "8" TO CV-DEST(CONV-CNT)
               WHEN SC-TOKEN(1:1) = "N" AND SC-TLEN > 1
                   MOVE "9" TO CV-DEST(CONV-CNT)
           END-EVALUATE
           IF CV-DEST(CONV-CNT) NOT = "M"
               MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
               SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
               IF MODE-OSGENER AND CV-DEST(CONV-CNT) NOT = "S"
                   MOVE "EXTRA PRINT-LINE PREFIX NOT VALID IN OSGENER"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CV-OUTOFF(CONV-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CV-OUTLEN(CONV-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO CV-FUNOFF(CONV-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TOKEN = "INT"
               MOVE "Y" TO CV-INT(CONV-CNT)
           END-IF
      *    GEOMETRY GUARDS: ENTRY BUFFERS ARE X(40), ROWS X(256)
           IF CV-INLEN(CONV-CNT) > 40 OR CV-OUTLEN(CONV-CNT) > 40
               MOVE "CONV KEY/FUNCTION LENGTH EXCEEDS 40"
                   TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
           END-IF
           COMPUTE J = CV-ARGOFF(CONV-CNT) + CV-INLEN(CONV-CNT) - 1
           END-COMPUTE
           COMPUTE K = CV-FUNOFF(CONV-CNT) + CV-OUTLEN(CONV-CNT) - 1
           END-COMPUTE
           IF J > 256 OR K > 256
               MOVE "CONV TABLE OFFSETS EXCEED 256-BYTE ROW"
                   TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
           END-IF
      *    M11: AN INLINE ROW IS A CARD IMAGE, SO ITS ARGUMENT AND
      *    FUNCTION MUST FIT INSIDE THE 80 COLUMNS.
           IF CV-INLINE(CONV-CNT) = "Y"
               IF J > 80 OR K > 80
                   MOVE "INLINE CONV TABLE OFFSETS EXCEED 80 COLUMNS"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
               IF SW-PARSE-ERR = "N"
                   MOVE CONV-CNT TO WS-INLINE-CV
               END-IF
           END-IF.
       1240-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1250 CORTE: F[,ID='..'][,H] | CT,N | SI,LONG,SK,[S,]ID=..,SO1
      *----------------------------------------------------------------
       1250-PARSE-CORTE.
      *    M27: ONE CARD DECLARES SEVERAL "/"-SEPARATED BREAK LEVELS,
      *    MAJOR TO MINOR (SHEET 15). SCANNER STATE RESET AS IN 1200.
           MOVE SPACE TO SC-TYPE SC-DELIM
           PERFORM 1251-PARSE-CORTE-LVL THRU 1251-EXIT
               UNTIL SC-TYPE = "E" AND SC-DELIM = SPACE
               OR SW-PARSE-ERR = "Y".
       1250-EXIT.
           EXIT.
      *
       1251-PARSE-CORTE-LVL.
           IF CORTE-CNT >= 10
               MOVE "CORTE LEVEL LIMIT (10) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1251-EXIT
           END-IF
           ADD 1 TO CORTE-CNT END-ADD
           MOVE CORTE-CNT TO WS-LAST-CORTE
           MOVE SPACES TO CO-ID(CORTE-CNT)
           MOVE 0 TO CO-IDLEN(CORTE-CNT) CO-SO1(CORTE-CNT)
                     CO-SO2(CORTE-CNT)
                     CO-COUNT(CORTE-CNT) CO-CT(CORTE-CNT)
           MOVE "N" TO CO-PRTKEY(CORTE-CNT)
           MOVE "N" TO CO-SILENT(CORTE-CNT)
           MOVE SPACE TO CO-SK(CORTE-CNT)
           MOVE LOW-VALUES TO CO-PREV(CORTE-CNT)
      *    1255 CONSUMES THE NEXT ID='..' AND BLANKS IT OUT, SO ONE
      *    CALL PER LEVEL PICKS THEM UP IN CARD ORDER (M15).
           PERFORM 1255-EXTRACT-ID-LIT
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    M27: NOTHING LEFT ON THE CARD - GIVE THE LEVEL BACK
           IF SC-TYPE = "E" AND SC-DELIM = SPACE
               SUBTRACT 1 FROM CORTE-CNT END-SUBTRACT
               MOVE CORTE-CNT TO WS-LAST-CORTE
               GO TO 1251-EXIT
           END-IF
           EVALUATE TRUE
               WHEN SC-TOKEN = "F"
                   MOVE "F" TO CO-TYPE(CORTE-CNT)
                   PERFORM 1256-PARSE-CORTE-OPTS
               WHEN SC-TOKEN = "CT"
                   MOVE "C" TO CO-TYPE(CORTE-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO CO-CT(CORTE-CNT)
               WHEN OTHER
                   MOVE "K" TO CO-TYPE(CORTE-CNT)
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO CO-OFF(CORTE-CNT)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO CO-LEN(CORTE-CNT)
                   PERFORM 1256-PARSE-CORTE-OPTS
           END-EVALUATE.
       1251-EXIT.
           EXIT.
      *
       1255-EXTRACT-ID-LIT.
      *    PRE-EXTRACT ID='...' (LITERAL MAY HOLD SPACES/COMMAS),
      *    THEN BLANK IT OUT OF THE OPERAND STREAM.
           MOVE 0 TO I
           INSPECT WS-OPRND TALLYING I FOR CHARACTERS BEFORE "ID='"
           IF I < 76
               COMPUTE J = I + 5 END-COMPUTE
               MOVE 0 TO K
               PERFORM UNTIL J > 80
                   OR WS-OPRND(J:1) = "'"
                   OR K >= 40
      *            CO-ID IS X(40): LONGER LITERALS ARE TRUNCATED
                   ADD 1 TO K END-ADD
                   MOVE WS-OPRND(J:1) TO CO-ID(CORTE-CNT)(K:1)
                   ADD 1 TO J END-ADD
               END-PERFORM
               PERFORM UNTIL J > 80
                   OR WS-OPRND(J:1) = "'"
                   ADD 1 TO J END-ADD
               END-PERFORM
               MOVE K TO CO-IDLEN(CORTE-CNT)
               COMPUTE L = J - I END-COMPUTE
               ADD 1 TO L END-ADD
               MOVE SPACES TO WS-OPRND(I + 1:L)
           END-IF.
      *
       1256-PARSE-CORTE-OPTS.
      *    REMAINING TOKENS IN ANY ORDER: SK DIGIT, H, S, SO1 NUMBER
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               EVALUATE TRUE
                   WHEN SC-TOKEN = "H"
                       MOVE "H" TO CO-SK(CORTE-CNT)
                   WHEN SC-TOKEN = "S"
                       MOVE "Y" TO CO-SILENT(CORTE-CNT)
      *            M16: "I,s02" PRINTS THE FIELD THAT CAUSED THE
      *            BREAK AT s02. THE NUMBER AFTER "I" USED TO FALL
      *            THROUGH TO CO-SO1 AND SILENTLY OVERWRITE THE ID
      *            POSITION, SO BOTH THE FEATURE AND THAT CORRUPTION
      *            ARE FIXED HERE.
                   WHEN SC-TOKEN = "I"
                       MOVE "Y" TO CO-PRTKEY(CORTE-CNT)
                       PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                       PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                       MOVE H-NUM TO CO-SO2(CORTE-CNT)
                   WHEN SC-TLEN = 1 AND SC-TOKEN(1:1) >= "0"
                        AND SC-TOKEN(1:1) <= "9"
                        AND CO-SK(CORTE-CNT) = SPACE
                       MOVE SC-TOKEN(1:1) TO CO-SK(CORTE-CNT)
                   WHEN OTHER
                       PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                       MOVE H-NUM TO CO-SO1(CORTE-CNT)
               END-EVALUATE
      *        M27: "/" ENDS THIS LEVEL. WITHOUT THIS THE OPTIONS
      *        LOOP RAN TO END OF CARD AND SWALLOWED THE FOLLOWING
      *        LEVELS' OPERANDS AS SPACING/POSITION VALUES.
               IF SC-DELIM = "/"
                   EXIT PERFORM
               END-IF
           END-PERFORM.
      *
      *----------------------------------------------------------------
      * 1260 IMCOR: CANT,SO | AX,MASK,SO | SI,LONG,MASK,SO  ("/" SEP)
      *    ASSOCIATED WITH THE MOST RECENTLY PARSED CORTE LEVEL.
      *----------------------------------------------------------------
       1260-PARSE-IMCOR.
           IF WS-LAST-CORTE = 0
               MOVE "IMCOR WITHOUT PRECEDING CORTE" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1260-EXIT
           END-IF
           MOVE WS-LAST-CORTE TO IX-LVL
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               IF SC-TYPE = "E"
                   CONTINUE
               ELSE
                   PERFORM 1261-PARSE-IMCOR-FIELD THRU 1261-EXIT
               END-IF
           END-PERFORM.
       1260-EXIT.
           EXIT.
      *
       1261-PARSE-IMCOR-FIELD.
           IF IM-CNT(IX-LVL) >= 10
               MOVE "IMCOR FIELD LIMIT (10) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1261-EXIT
           END-IF
           ADD 1 TO IM-CNT(IX-LVL) END-ADD
           MOVE IM-CNT(IX-LVL) TO M
           MOVE 0 TO IM-DIGITS(IX-LVL, M) IM-DEC(IX-LVL, M)
           EVALUATE TRUE
               WHEN SC-TOKEN = "CANT"
                   MOVE "C" TO IM-KIND(IX-LVL, M)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO IM-SO(IX-LVL, M)
               WHEN SC-TOKEN(1:1) = "A" AND SC-TLEN = 2
                   MOVE "A" TO IM-KIND(IX-LVL, M)
                   MOVE SC-TOKEN(2:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MOVE DN-DIGIT TO IM-ACUM(IX-LVL, M)
                   PERFORM 1262-PARSE-IMCOR-MASK
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO IM-SO(IX-LVL, M)
               WHEN OTHER
                   MOVE "F" TO IM-KIND(IX-LVL, M)
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO IM-OFF(IX-LVL, M)
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO IM-LEN(IX-LVL, M)
                   PERFORM 1262-PARSE-IMCOR-MASK
                   PERFORM 1500-GET-TOKEN THRU 1500-EXIT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO IM-SO(IX-LVL, M)
           END-EVALUATE.
       1261-EXIT.
           EXIT.
      *
       1262-PARSE-IMCOR-MASK.
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           MOVE 0 TO J
           PERFORM VARYING I FROM 2 BY 1 UNTIL I > SC-TLEN
               EVALUATE TRUE
                   WHEN SC-TOKEN(I:1) = "D"
                       MOVE 1 TO J
                   WHEN SC-TOKEN(I:1) >= "0" AND SC-TOKEN(I:1) <= "9"
                       MOVE SC-TOKEN(I:1) TO TRT-CHAR
                       PERFORM 7700-CHAR-TO-DIGIT
                       IF J = 0
                           MULTIPLY 10 BY IM-DIGITS(IX-LVL, M)
                           END-MULTIPLY
                           ADD DN-DIGIT
                               TO IM-DIGITS(IX-LVL, M) END-ADD
                       ELSE
                           MULTIPLY 10 BY IM-DEC(IX-LVL, M) END-MULTIPLY
                           ADD DN-DIGIT
                               TO IM-DEC(IX-LVL, M) END-ADD
                       END-IF
               END-EVALUATE
           END-PERFORM.
      *
      *----------------------------------------------------------------
      * 1300 GENER SI1,LONG1/SI2,LONG2/'C1','C2',...
      *----------------------------------------------------------------
       1300-PARSE-GENER.
           MOVE "Y" TO G-ACTIVE
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO G-KOFF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO G-KLEN
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO G-COFF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO G-CLEN
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               IF SC-TYPE = "L"
                   IF G-NCODES >= 10
                       MOVE "GENER CODE LIMIT (10) EXCEEDED"
                           TO WS-ERRMSG
                       PERFORM 9000-PARSE-ERROR
                   ELSE
                       ADD 1 TO G-NCODES END-ADD
                       MOVE SC-TOKEN(1:8) TO G-CODE(G-NCODES)
                   END-IF
               END-IF
           END-PERFORM.
      *
      *----------------------------------------------------------------
      * 1310 CODIG 'COD',OBL,'COD1','COD2',...
      *----------------------------------------------------------------
       1310-PARSE-CODIG.
           IF CODIG-CNT >= 10
               MOVE "CODIG RULE LIMIT (10) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1310-EXIT
           END-IF
           ADD 1 TO CODIG-CNT END-ADD
           MOVE 0 TO CD-NTRIG(CODIG-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TYPE NOT = "L"
               MOVE "CODIG TARGET CODE LITERAL EXPECTED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1310-EXIT
           END-IF
           MOVE SC-TOKEN(1:8) TO CD-TARGET(CODIG-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TOKEN NOT = "OBL"
               MOVE "CODIG REQUIRES OBL KEYWORD" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1310-EXIT
           END-IF
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               IF SC-TYPE = "L"
                   ADD 1 TO CD-NTRIG(CODIG-CNT) END-ADD
                   MOVE CD-NTRIG(CODIG-CNT) TO K
                   MOVE SC-TOKEN(1:8) TO CD-TRIG(CODIG-CNT, K)
               END-IF
           END-PERFORM.
       1310-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1320 INCON 'COD'/SI,LONG,TYPE[,'LABEL']/... ("/" SEPARATED)
      *----------------------------------------------------------------
       1320-PARSE-INCON.
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TYPE NOT = "L"
               MOVE "INCON CARD CODE LITERAL EXPECTED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1320-EXIT
           END-IF
           MOVE SC-TOKEN(1:8) TO H-CODE
      *    M17: EACH RULE JOINS THE CURRENT GROUP. .O./.OR. KEEPS THE
      *    GROUP OPEN (ALTERNATIVES); "/" AND .Y./.AND. START A NEW
      *    ONE. A "/" IS EATEN BY 1540 AS THE PREVIOUS TOKEN'S
      *    DELIMITER, SO IT IS DETECTED FROM SC-DELIM AFTER THE RULE,
      *    NOT AS A TOKEN OF ITS OWN.
           ADD 1 TO WS-IGRP-NO END-ADD
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               EVALUATE TRUE
                   WHEN SC-TYPE = "C"
                       IF SC-TOKEN NOT = ".O." AND SC-TOKEN NOT = ".OR."
                           ADD 1 TO WS-IGRP-NO END-ADD
                       END-IF
                   WHEN SC-TYPE = "E"
                       CONTINUE
                   WHEN OTHER
                       PERFORM 1321-PARSE-INCON-RULE THRU 1321-EXIT
                       IF SC-DELIM = "/"
                           ADD 1 TO WS-IGRP-NO END-ADD
                       END-IF
               END-EVALUATE
           END-PERFORM.
       1320-EXIT.
           EXIT.
      *
       1321-PARSE-INCON-RULE.
           IF INCON-CNT >= 50
               MOVE "INCON RULE LIMIT (50) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1321-EXIT
           END-IF
           ADD 1 TO INCON-CNT END-ADD
           MOVE H-CODE TO IC-CODE(INCON-CNT)
           MOVE "1" TO IC-FILE(INCON-CNT)
           MOVE WS-IGRP-NO TO IC-GROUP(INCON-CNT)
           MOVE SPACES TO IC-LABEL(INCON-CNT)
           MOVE SPACES TO IC-RELOP(INCON-CNT)
           MOVE 0 TO IC-LLEN(INCON-CNT)
      *    M6: "S2" = THE FIELD LIVES IN SYSUT3 (SHEET 28)
           IF SC-TOKEN(1:1) = "S" AND SC-TLEN > 1
               MOVE "3" TO IC-FILE(INCON-CNT)
               MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
               SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO IC-OFF(INCON-CNT)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    G2: SECOND TOKEN IS EITHER A LENGTH (TYPE FORM) OR A
      *    RELATIONAL OPERATOR (RELATIONAL FORM "SI,OP,'LIT'")
      *    M1: AN EMPTY OPERATOR FIELD ("9,,'71'") IS THE RELATIONAL
      *    FORM WITH THE OPERATOR OMITTED - SHEET 28 ASSUMES EQ.
           IF SC-TLEN = 0
              OR SC-TOKEN = "EQ  " OR SC-TOKEN = "NE  "
              OR SC-TOKEN = "LT  " OR SC-TOKEN = "GT  "
              OR SC-TOKEN = "LE  " OR SC-TOKEN = "GE  "
              OR SC-TOKEN = "NL  " OR SC-TOKEN = "NH  "
               IF SC-TLEN = 0
                   MOVE "EQ" TO IC-RELOP(INCON-CNT)
               ELSE
                   MOVE SC-TOKEN(1:2) TO IC-RELOP(INCON-CNT)
               END-IF
               MOVE "R " TO IC-TYPE(INCON-CNT)
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE NOT = "L" AND SC-TYPE NOT = "X"
                   MOVE "INCON RELATIONAL RULE NEEDS A LITERAL"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1321-EXIT
               END-IF
               MOVE SC-TOKEN(1:40) TO IC-LIT(INCON-CNT)
               MOVE SC-TLEN TO IC-LLEN(INCON-CNT)
               MOVE SC-TLEN TO IC-LEN(INCON-CNT)
           ELSE
               PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
               MOVE H-NUM TO IC-LEN(INCON-CNT)
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               EVALUATE SC-TOKEN
                   WHEN "N   "  MOVE "N " TO IC-TYPE(INCON-CNT)
                   WHEN "ND  "  MOVE "ND" TO IC-TYPE(INCON-CNT)
                   WHEN "A   "  MOVE "A " TO IC-TYPE(INCON-CNT)
                   WHEN "AB  "  MOVE "AB" TO IC-TYPE(INCON-CNT)
                   WHEN "AN  "  MOVE "AN" TO IC-TYPE(INCON-CNT)
                   WHEN "ANB "  MOVE "NB" TO IC-TYPE(INCON-CNT)
                   WHEN "FD  "  MOVE "FD" TO IC-TYPE(INCON-CNT)
                   WHEN "FA  "  MOVE "FA" TO IC-TYPE(INCON-CNT)
                   WHEN OTHER
                       STRING "INVALID INCON TYPE: " SC-TOKEN(1:4)
                           DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                       PERFORM 9000-PARSE-ERROR
               END-EVALUATE
           END-IF
           IF SC-DELIM = ","
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "L"
                   MOVE SC-TOKEN(1:8) TO IC-LABEL(INCON-CNT)
               END-IF
           END-IF.
       1321-EXIT.
           EXIT.
      *
      *----------------------------------------------------------------
      * 1330 PESQIN/PESQOUT SI1,LONG,SI2  - 1340 CLAVE SI1,LONG,SI2
      *----------------------------------------------------------------
       1330-PARSE-PESQ.
           IF WS-OPCODE = "PESQIN"
               MOVE "I" TO P-ACTIVE
           ELSE
               MOVE "O" TO P-ACTIVE
           END-IF
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           IF SC-TYPE = "E" AND SC-DELIM = SPACE
               IF P-LEN = 0
                   MOVE "PESQ REQUIRES SI1,LONG,SI2" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
               END-IF
               GO TO 1330-EXIT
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO P-OFF1
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO P-LEN
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO P-OFF2.
       1330-EXIT.
           EXIT.
      *
       1340-PARSE-CLAVE.
           MOVE "Y" TO K-ACTIVE
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO K-OFF1
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO K-LEN
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO K-OFF2.
      *
      *----------------------------------------------------------------
      * 1350 COPY FR=N,LR=N,SK=N  - 1360 PRINT KEYWORDS - 1370 TITX
      *----------------------------------------------------------------
       1350-PARSE-COPY.
           IF COPY-CNT >= 10
               MOVE "COPY RANGE LIMIT (10) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1350-EXIT
           END-IF
           ADD 1 TO COPY-CNT END-ADD
           MOVE 0 TO CP-FR(COPY-CNT) CP-SK(COPY-CNT)
           MOVE 999999 TO CP-LR(COPY-CNT)
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               PERFORM 1355-COPY-KEYWORD
           END-PERFORM.
       1350-EXIT.
           EXIT.
      *
       1355-COPY-KEYWORD.
           EVALUATE TRUE
               WHEN SC-TOKEN(1:3) = "FR="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO CP-FR(COPY-CNT)
               WHEN SC-TOKEN(1:3) = "LR="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO CP-LR(COPY-CNT)
               WHEN SC-TOKEN(1:3) = "SK="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO CP-SK(COPY-CNT)
               WHEN OTHER
                   STRING "UNKNOWN COPY KEYWORD: " SC-TOKEN(1:8)
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
           END-EVALUATE.
      *
       1360-PARSE-PRINT.
           MOVE "Y" TO PR-ACTIVE
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               PERFORM 1365-PRINT-KEYWORD
           END-PERFORM.
      *
       1365-PRINT-KEYWORD.
           EVALUATE TRUE
               WHEN SC-TOKEN(1:3) = "FL="
                   MOVE SC-TOKEN(4:2) TO PR-FL
               WHEN SC-TOKEN(1:3) = "FR="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO PR-FR
               WHEN SC-TOKEN(1:3) = "LR="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO PR-LR
               WHEN SC-TOKEN(1:3) = "SK="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO PR-SK
               WHEN SC-TOKEN(1:3) = "SP="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO PR-SP
               WHEN SC-TOKEN(1:3) = "SR="
                   PERFORM 1366-KW-NUM THRU 1366-EXIT
                   MOVE H-NUM TO PR-SR
               WHEN OTHER
                   STRING "UNKNOWN PRINT KEYWORD: " SC-TOKEN(1:8)
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
           END-EVALUATE.
      *
       1366-KW-NUM.
           IF SC-TLEN <= 3
               MOVE "KEYWORD WITHOUT VALUE" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1366-EXIT
           END-IF
           MOVE SC-TOKEN(4:SC-TLEN - 3) TO H-LINE
           MOVE SPACES TO SC-TOKEN
           MOVE H-LINE(1:SC-TLEN - 3) TO SC-TOKEN
           SUBTRACT 3 FROM SC-TLEN END-SUBTRACT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT.
       1366-EXIT.
           EXIT.
      *
       1370-PARSE-TIT.
      *    M18: IN OSGENER "TIT {Lnn},'literal'" IS THE SYSLIST
      *    ERROR-REPORT HEADING (SHEET 30) - ONE LINE, NO INDEX. IT
      *    REUSES TITLE SLOT 1 AND THE SAME Lnn/LITERAL PARSER.
           IF MODE-OSGENER
               IF WS-OPCODE NOT = "TIT"
                   MOVE "OSGENER TIT TAKES NO LINE INDEX" TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1370-EXIT
               END-IF
               IF G-ACTIVE = "N"
                   MOVE "TIT REQUIRES A PRECEDING GENER CARD"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1370-EXIT
               END-IF
               MOVE "1" TO WS-OPCODE(4:1)
           END-IF
           IF WS-OPCODE(4:1) < "1" OR WS-OPCODE(4:1) > "9"
               MOVE "TIT INDEX MUST BE 1-9" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1370-EXIT
           END-IF
           MOVE WS-OPCODE(4:1) TO TRT-CHAR
           PERFORM 7700-CHAR-TO-DIGIT
           MOVE DN-DIGIT TO N
           IF N > TIT-CNT
               MOVE N TO TIT-CNT
           END-IF
           MOVE "Y" TO TI-USED(N)
           MOVE SPACES TO TI-TEXT(N)
           MOVE 1 TO TI-SP(N)
           MOVE 0 TO TI-NMAP(N)
           MOVE 1 TO M
      *    M = PENDING LITERAL COLUMN (FROM LNN)
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   EXIT PERFORM
               END-IF
               PERFORM 1375-TIT-TOKEN
           END-PERFORM.
       1370-EXIT.
           EXIT.
      *
       1375-TIT-TOKEN.
           EVALUATE TRUE
               WHEN SC-TYPE = "L"
                   COMPUTE J = M + SC-TLEN END-COMPUTE
                   SUBTRACT 1 FROM J END-SUBTRACT
                   IF J > 132
                       MOVE 133 TO SC-TLEN
                       SUBTRACT M FROM SC-TLEN END-SUBTRACT
                   END-IF
                   MOVE SC-TOKEN(1:SC-TLEN) TO TI-TEXT(N)(M:SC-TLEN)
               WHEN SC-TOKEN(1:1) = "L" AND SC-TLEN > 1
                   MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
                   SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   MOVE H-NUM TO M
      *        M22: BARE "FA"/"FN" DEFAULT TO COLUMN 91 (SHEET 6)
               WHEN SC-TOKEN = "FA  "
                   PERFORM 7500-DATE-ALPHA
                   MOVE ED-OUT(1:18) TO TI-TEXT(N)(91:18)
               WHEN SC-TOKEN = "FN  "
                   PERFORM 7510-DATE-NUM
                   MOVE ED-OUT(1:8) TO TI-TEXT(N)(91:8)
               WHEN SC-TOKEN(1:2) = "FA" AND SC-TLEN > 2
                   MOVE SC-TOKEN(3:SC-TLEN - 2) TO SC-TOKEN
                   SUBTRACT 2 FROM SC-TLEN END-SUBTRACT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   PERFORM 7500-DATE-ALPHA
                   MOVE ED-OUT(1:18) TO TI-TEXT(N)(H-NUM:18)
               WHEN SC-TOKEN(1:2) = "FN" AND SC-TLEN > 2
                   MOVE SC-TOKEN(3:SC-TLEN - 2) TO SC-TOKEN
                   SUBTRACT 2 FROM SC-TLEN END-SUBTRACT
                   PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
                   PERFORM 7510-DATE-NUM
                   MOVE ED-OUT(1:8) TO TI-TEXT(N)(H-NUM:8)
               WHEN SC-TOKEN(1:1) = "S" AND SC-TLEN = 2
                   MOVE SC-TOKEN(2:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MOVE DN-DIGIT TO TI-SP(N)
               WHEN SC-TOKEN(1:1) = "("
      *            G1: FIELD MAP "(SI,LONG,CONV,SO)"
                   PERFORM 1376-PARSE-TIT-MAP THRU 1376-EXIT
               WHEN OTHER
                   STRING "UNKNOWN TIT OPERAND: " SC-TOKEN(1:8)
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
           END-EVALUATE.
      *
       1376-PARSE-TIT-MAP.
      *    CURRENT TOKEN = "(SI" (COMMA WAS THE DELIMITER). READS
      *    LONG, CONV, SO ; SO TOKEN CARRIES A TRAILING ")".
           IF TI-NMAP(N) >= 8
               MOVE "TIT FIELD MAP LIMIT (8) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1376-EXIT
           END-IF
           ADD 1 TO TI-NMAP(N) END-ADD
           MOVE TI-NMAP(N) TO L
           MOVE 0 TO TM-DIG(N, L) TM-DEC(N, L)
      *    STRIP LEADING "(" FROM THE OFFSET TOKEN
           MOVE SC-TOKEN(2:SC-TLEN - 1) TO SC-TOKEN
           SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO TM-OFF(N, L)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO TM-LEN(N, L)
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
           EVALUATE TRUE
      *        M23: AN OMITTED CONV IS A PLAIN MOVE, AS EVERYWHERE
      *        ELSE - "(32,5,,21)" IS A VALID SHEET-6 MAP
               WHEN SC-TLEN = 0
                   MOVE "MV" TO TM-CONV(N, L)
               WHEN SC-TOKEN = "MOVE" OR SC-TOKEN = "M"
                   MOVE "MV" TO TM-CONV(N, L)
               WHEN SC-TOKEN = "UNPK" OR SC-TOKEN = "U"
                   MOVE "UN" TO TM-CONV(N, L)
               WHEN (SC-TOKEN(1:1) = "Z" OR SC-TOKEN(1:1) = "P")
                    AND SC-TLEN >= 3
                   IF SC-TOKEN(1:1) = "Z"
                       MOVE "ZD" TO TM-CONV(N, L)
                   ELSE
                       MOVE "PD" TO TM-CONV(N, L)
                   END-IF
                   PERFORM 1377-TIT-MASK THRU 1377-EXIT
               WHEN OTHER
                   MOVE "UNSUPPORTED TIT MAP CONVERSION"
                       TO WS-ERRMSG
                   PERFORM 9000-PARSE-ERROR
                   GO TO 1376-EXIT
           END-EVALUATE
           PERFORM 1500-GET-TOKEN THRU 1500-EXIT
      *    SO TOKEN MAY CARRY A TRAILING ")"
           IF SC-TLEN > 0 AND SC-TOKEN(SC-TLEN:1) = ")"
               SUBTRACT 1 FROM SC-TLEN END-SUBTRACT
           END-IF
           PERFORM 1550-TOKEN-TO-NUM THRU 1550-EXIT
           MOVE H-NUM TO TM-SO(N, L).
       1376-EXIT.
           EXIT.
      *
       1377-TIT-MASK.
           MOVE 0 TO J
           PERFORM VARYING I FROM 2 BY 1 UNTIL I > SC-TLEN
               EVALUATE TRUE
                   WHEN SC-TOKEN(I:1) = "D"
                       MOVE 1 TO J
                   WHEN SC-TOKEN(I:1) >= "0" AND SC-TOKEN(I:1) <= "9"
                       MOVE SC-TOKEN(I:1) TO TRT-CHAR
                       PERFORM 7700-CHAR-TO-DIGIT
                       IF J = 0
                           MULTIPLY 10 BY TM-DIG(N, L) END-MULTIPLY
                           ADD DN-DIGIT TO TM-DIG(N, L) END-ADD
                       ELSE
                           MULTIPLY 10 BY TM-DEC(N, L) END-MULTIPLY
                           ADD DN-DIGIT TO TM-DEC(N, L) END-ADD
                       END-IF
               END-EVALUATE
           END-PERFORM.
       1377-EXIT.
           EXIT.
      *
       1380-PARSE-CARRO.
      *    G3: CARRO CC1,CC2,... -> ACTION TABLE.
      *    WxA=WRITE+SKIP x   SxL=SKIP x LINES   WCx/SCx=TO CHANNEL x
           PERFORM UNTIL SW-PARSE-ERR = "Y"
               PERFORM 1500-GET-TOKEN THRU 1500-EXIT
               IF SC-TYPE = "E" AND SC-DELIM = SPACE
                   GO TO 1380-EXIT
               END-IF
               IF SC-TYPE NOT = "E"
                   PERFORM 1381-CARRO-TOKEN THRU 1381-EXIT
               END-IF
           END-PERFORM.
       1380-EXIT.
           EXIT.
      *
       1381-CARRO-TOKEN.
           IF CARRO-CNT >= 24
               MOVE "CARRO ENTRY LIMIT (24) EXCEEDED" TO WS-ERRMSG
               PERFORM 9000-PARSE-ERROR
               GO TO 1381-EXIT
           END-IF
           ADD 1 TO CARRO-CNT END-ADD
           MOVE 0 TO CA-N(CARRO-CNT)
           EVALUATE TRUE
               WHEN SC-TOKEN(1:2) = "WC" OR SC-TOKEN(1:2) = "SC"
                   MOVE "C" TO CA-ACT(CARRO-CNT)
                   MOVE SC-TOKEN(3:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MOVE DN-DIGIT TO CA-N(CARRO-CNT)
               WHEN SC-TOKEN(1:1) = "W" AND SC-TOKEN(3:1) = "A"
                   MOVE "W" TO CA-ACT(CARRO-CNT)
                   MOVE SC-TOKEN(2:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MOVE DN-DIGIT TO CA-N(CARRO-CNT)
               WHEN SC-TOKEN(1:1) = "S" AND SC-TOKEN(3:1) = "L"
                   MOVE "S" TO CA-ACT(CARRO-CNT)
                   MOVE SC-TOKEN(2:1) TO TRT-CHAR
                   PERFORM 7700-CHAR-TO-DIGIT
                   MOVE DN-DIGIT TO CA-N(CARRO-CNT)
               WHEN OTHER
                   STRING "UNKNOWN CARRO CODE: " SC-TOKEN(1:8)
                       DELIMITED BY SIZE INTO WS-ERRMSG END-STRING
                   PERFORM 9000-PARSE-ERROR
           END-EVALUATE.
       1381-EXIT.
           EXIT.
      *
       9000-PARSE-ERROR.
           MOVE "Y" TO SW-PARSE-ERR
           MOVE SPACES TO SYSPRINT-REC
           STRING "*** CARD ERROR: " WS-ERRMSG
               DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
           WRITE SYSPRINT-REC END-WRITE.
      *
      *================================================================
      * 2000 OPEN DATA FILES (COORDINATED - PITFALL #1: ALL READS
      * HAPPEN IN 24XX PARAGRAPHS ONLY)
      *================================================================
       2000-OPEN-DATA.
           OPEN INPUT SYSUT1-F
           IF FS-UT1 NOT = "00"
               STRING "SYSUT1 OPEN FAILED, STATUS " FS-UT1
                   DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
               WRITE SYSPRINT-REC END-WRITE
               MOVE 16 TO WS-RC
               MOVE "Y" TO SW-EOF-UT1
           END-IF
           OPEN OUTPUT SYSUT2-F
           IF FS-UT2 NOT = "00"
               MOVE "SYSUT2" TO H-CODE
               MOVE FS-UT2 TO H-KEY2(1:2)
               PERFORM 2050-OPEN-FAIL
           END-IF
           IF K-ACTIVE = "Y"
               OPEN INPUT SYSUT3-F
      *        "05" = OPTIONAL FILE NOT PRESENT (ACCEPTED)
               IF FS-UT3 NOT = "00" AND FS-UT3 NOT = "05"
                   MOVE "SYSUT3" TO H-CODE
                   MOVE FS-UT3 TO H-KEY2(1:2)
                   PERFORM 2050-OPEN-FAIL
               END-IF
               MOVE "Y" TO SW-UT3-OPEN
               PERFORM 2420-READ-UT3
           END-IF
           IF MODE-OSGENER
               IF P-ACTIVE NOT = SPACE
                   OPEN INPUT SYSUT6-F
                   IF FS-UT6 NOT = "00" AND FS-UT6 NOT = "05"
                       MOVE "SYSUT6" TO H-CODE
                       MOVE FS-UT6 TO H-KEY2(1:2)
                       PERFORM 2050-OPEN-FAIL
                   END-IF
                   MOVE "Y" TO SW-UT6-OPEN
                   PERFORM 2430-READ-UT6
               END-IF
               OPEN OUTPUT SYSUT4-F
               IF FS-UT4 NOT = "00"
                   MOVE "SYSUT4" TO H-CODE
                   MOVE FS-UT4 TO H-KEY2(1:2)
                   PERFORM 2050-OPEN-FAIL
               END-IF
               OPEN OUTPUT SYSUT5-F
               IF FS-UT5 NOT = "00"
                   MOVE "SYSUT5" TO H-CODE
                   MOVE FS-UT5 TO H-KEY2(1:2)
                   PERFORM 2050-OPEN-FAIL
               END-IF
               OPEN OUTPUT SYSLIST-F
               IF FS-LST NOT = "00"
                   MOVE "SYSLIST" TO H-CODE
                   MOVE FS-LST TO H-KEY2(1:2)
                   PERFORM 2050-OPEN-FAIL
               END-IF
           END-IF.
      *
       2050-OPEN-FAIL.
      *    H-CODE = DDNAME, H-KEY2(1:2) = FILE STATUS.
      *    LOG, SET RC 16 AND SUPPRESS THE PROCESSING LOOP.
           MOVE SPACES TO SYSPRINT-REC
           STRING H-CODE " OPEN FAILED, STATUS " H-KEY2(1:2)
               DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
           WRITE SYSPRINT-REC END-WRITE
           MOVE 16 TO WS-RC
           MOVE "Y" TO SW-EOF-UT1.
      *
       2500-LOAD-CONV-TABLES.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > CONV-CNT
      *        M11: AN INLINE TABLE WAS ALREADY BUILT BY 1060 WHILE
      *        SYSIN WAS BEING READ - THERE IS NO FILE TO OPEN.
               IF CV-INLINE(I) = "Y"
                   MOVE SPACES TO SYSPRINT-REC
                   STRING "CONV INLINE TABLE, ROWS: " CV-N(I)
                       DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
                   WRITE SYSPRINT-REC END-WRITE
               ELSE
                   PERFORM 2510-LOAD-ONE-CONV
               END-IF
           END-PERFORM.
      *
       2510-LOAD-ONE-CONV.
               MOVE SPACES TO WS-CONV-DDNAME
               MOVE CV-DD(I) TO WS-CONV-DDNAME
               MOVE 0 TO CV-N(I)
               MOVE "00" TO FS-CNV
               OPEN INPUT CONVTAB-F
               PERFORM UNTIL FS-CNV NOT = "00"
                   OR CV-N(I) >= 500
                   READ CONVTAB-F
                       AT END MOVE "10" TO FS-CNV
                       NOT AT END
                           ADD 1 TO CV-N(I) END-ADD
                           MOVE CV-N(I) TO J
                           MOVE CONVTAB-REC(CV-ARGOFF(I):
                                CV-INLEN(I))
                               TO CVE-ARG(I, J)
                           MOVE CONVTAB-REC(CV-FUNOFF(I):
                                CV-OUTLEN(I))
                               TO CVE-FUN(I, J)
                   END-READ
               END-PERFORM
               CLOSE CONVTAB-F
               MOVE SPACES TO SYSPRINT-REC
               STRING "CONV TABLE " CV-DD(I) " LOADED"
                   DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
               WRITE SYSPRINT-REC END-WRITE.
      *
      *================================================================
      * 2400 CENTRAL READ COORDINATOR (DOC01 PITFALL #1)
      *================================================================
       2410-READ-UT1.
           MOVE SPACES TO IN-REC
           READ SYSUT1-F INTO IN-REC
               AT END MOVE "Y" TO SW-EOF-UT1
           END-READ
           IF SW-EOF-UT1 = "N"
               ADD 1 TO REC-NO END-ADD
           END-IF.
      *
       2420-READ-UT3.
           MOVE SPACES TO SEC-REC
           READ SYSUT3-F INTO SEC-REC
               AT END MOVE "Y" TO SW-EOF-UT3
                      MOVE "N" TO SW-UT3-HAVE
               NOT AT END MOVE "Y" TO SW-UT3-HAVE
           END-READ.
      *
       2430-READ-UT6.
           MOVE SPACES TO PSQ-REC
           READ SYSUT6-F INTO PSQ-REC
               AT END MOVE "Y" TO SW-EOF-UT6
                      MOVE "N" TO SW-UT6-HAVE
               NOT AT END MOVE "Y" TO SW-UT6-HAVE
           END-READ.
      *
      *================================================================
      * 3000 MAIN PER-RECORD PIPELINE
      * ORDER (DOC03 + D0.3): PESQ -> CLAVE -> RCIN/RCOUT -> GENER
      *================================================================
       3000-PROCESS-RECORD.
           PERFORM 2410-READ-UT1
           IF SW-EOF-UT1 = "Y"
               GO TO 3000-EXIT
           END-IF
           IF P-ACTIVE NOT = SPACE
               PERFORM 3100-PESQ-MATCH
               IF SW-REC-OK = "N"
                   GO TO 3000-EXIT
               END-IF
           END-IF
           IF K-ACTIVE = "Y"
               PERFORM 3150-CLAVE-MATCH
           END-IF
           PERFORM 3200-EVAL-FILTERS
           IF SW-REC-OK = "N"
               GO TO 3000-EXIT
           END-IF
      *    M30: COPY SITS *AFTER* PESQ/CLAVE/RCIN IN THE SHEET-36
      *    FLOWCHART, SO IT COPIES ONLY THE RECORDS THOSE FILTERS
      *    ACCEPTED. IT USED TO SHORT-CIRCUIT AHEAD OF ALL THREE,
      *    WHICH MADE "RCIN ... / COPY" COPY THE WHOLE FILE.
           IF COPY-CNT > 0
               PERFORM 3050-COPY-MODE
               GO TO 3000-EXIT
           END-IF
           IF G-ACTIVE = "Y"
               PERFORM 3300-GENER-ACCUM
           ELSE
               PERFORM 3500-PROCESS-UNIT
           END-IF.
       3000-EXIT.
           EXIT.
      *
       3050-COPY-MODE.
      *    PURE RANGE COPY (OSGENER). SK = STRIDE WITHIN RANGE.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > COPY-CNT
               IF REC-NO >= CP-FR(I) AND REC-NO <= CP-LR(I)
                   IF CP-SK(I) = 0
                       PERFORM 4000-WRITE-MAIN-REC
                       EXIT PERFORM
                   ELSE
      *                SK=N MEANS COPY 1, SKIP N -> CYCLE OF N+1
      *                (SAME INTERPRETATION AS THE PRINT CARD)
                       COMPUTE J = REC-NO - CP-FR(I) END-COMPUTE
                       COMPUTE K = CP-SK(I) + 1 END-COMPUTE
                       DIVIDE J BY K GIVING M REMAINDER L END-DIVIDE
                       IF L = 0
                           PERFORM 4000-WRITE-MAIN-REC
                           EXIT PERFORM
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.
      *
       3100-PESQ-MATCH.
      *    SORTED-MERGE LOOKUP AGAINST SYSUT6 (PESQIN/PESQOUT)
           MOVE "N" TO SW-SEC-MATCH
           MOVE IN-REC(P-OFF1:P-LEN) TO H-KEY1
           PERFORM UNTIL SW-UT6-HAVE = "N"
               OR PSQ-REC(P-OFF2:P-LEN) >= H-KEY1(1:P-LEN)
               PERFORM 2430-READ-UT6
           END-PERFORM
           IF SW-UT6-HAVE = "Y"
               IF PSQ-REC(P-OFF2:P-LEN) = H-KEY1(1:P-LEN)
                   MOVE "Y" TO SW-SEC-MATCH
               END-IF
           END-IF
           IF P-ACTIVE = "I"
               MOVE SW-SEC-MATCH TO SW-REC-OK
           ELSE
               IF SW-SEC-MATCH = "Y"
                   MOVE "N" TO SW-REC-OK
               ELSE
                   MOVE "Y" TO SW-REC-OK
               END-IF
           END-IF.
      *
       3150-CLAVE-MATCH.
      *    SORTED-MERGE PAIRING WITH SYSUT3. NO MATCH -> SEC-REC BLANK
           MOVE "N" TO SW-SEC-MATCH
           MOVE IN-REC(K-OFF1:K-LEN) TO H-KEY1
           PERFORM UNTIL SW-UT3-HAVE = "N"
               OR SEC-REC(K-OFF2:K-LEN) >= H-KEY1(1:K-LEN)
               PERFORM 2420-READ-UT3
           END-PERFORM
           IF SW-UT3-HAVE = "Y"
               IF SEC-REC(K-OFF2:K-LEN) = H-KEY1(1:K-LEN)
                   MOVE "Y" TO SW-SEC-MATCH
               END-IF
           END-IF
           IF SW-SEC-MATCH = "N"
               MOVE SPACES TO SEC-REC
           END-IF.
      *
      *================================================================
      * 3200 RCIN / RCOUT GROUP EVALUATION
      * ACCEPT = (NO RCIN GROUPS OR ANY RCIN GROUP TRUE)
      *          AND (NO RCOUT GROUP TRUE)
      *================================================================
       3200-EVAL-FILTERS.
           MOVE "Y" TO SW-REC-OK
           MOVE "N" TO H-ANY-IN H-IN-TRUE H-OUT-TRUE
           MOVE 0 TO IX-GRP
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > COND-CNT
               IF CT-KIND(I) = "I" OR CT-KIND(I) = "O"
                   IF CT-GROUP(I) NOT = IX-GRP
                       MOVE CT-GROUP(I) TO IX-GRP
                       PERFORM 3250-EVAL-GROUP
                       IF CT-KIND(I) = "I"
                           MOVE "Y" TO H-ANY-IN
                           IF H-GRP-TRUE = "Y"
                               MOVE "Y" TO H-IN-TRUE
                           END-IF
                       ELSE
                           IF H-GRP-TRUE = "Y"
                               MOVE "Y" TO H-OUT-TRUE
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           IF H-ANY-IN = "Y" AND H-IN-TRUE = "N"
               MOVE "N" TO SW-REC-OK
           END-IF
           IF H-OUT-TRUE = "Y"
               MOVE "N" TO SW-REC-OK
           END-IF.
      *
       3250-EVAL-GROUP.
      *    EVALUATE ALL CONDITIONS OF GROUP IX-GRP.
      *    FAMILY: ANY "A" CONNECTOR -> AND-GROUP, ELSE OR-GROUP.
      *    (PARSER ALREADY FORBIDS MIXED FAMILIES.)
           MOVE "O" TO H-FAMILY
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > COND-CNT
               IF CT-GROUP(J) = IX-GRP AND CT-CONN(J) = "A"
                   MOVE "A" TO H-FAMILY
               END-IF
           END-PERFORM
           IF H-FAMILY = "A"
               MOVE "Y" TO H-GRP-TRUE
           ELSE
               MOVE "N" TO H-GRP-TRUE
           END-IF
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > COND-CNT
               IF CT-GROUP(J) = IX-GRP
                   IF CT-FILE(J) = "N"
                       PERFORM 3265-EVAL-COUNT-COND
                   ELSE
                       PERFORM 3260-EVAL-ONE-COND
                   END-IF
                   IF H-FAMILY = "A" AND SW-BLK-CORRUPT = "N"
                       MOVE "N" TO H-GRP-TRUE
                   END-IF
                   IF H-FAMILY = "O" AND SW-BLK-CORRUPT = "Y"
                       MOVE "Y" TO H-GRP-TRUE
                   END-IF
               END-IF
           END-PERFORM.
      *
       3260-EVAL-ONE-COND.
      *    RESULT IN SW-BLK-CORRUPT (REUSED AS SCRATCH BOOL): Y=TRUE
           IF CT-FILE(J) = "3"
               MOVE SEC-REC(CT-OFF(J):CT-LEN(J)) TO H-KEY2
           ELSE
               MOVE IN-REC(CT-OFF(J):CT-LEN(J)) TO H-KEY2
           END-IF
           MOVE "N" TO SW-BLK-CORRUPT
           EVALUATE CT-OP(J)
               WHEN "EQ"
                   IF H-KEY2(1:CT-LEN(J)) = CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "NE"
                   IF H-KEY2(1:CT-LEN(J)) NOT =
                      CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LT"
                   IF H-KEY2(1:CT-LEN(J)) < CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GT"
                   IF H-KEY2(1:CT-LEN(J)) > CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LE" WHEN "NH"
                   IF H-KEY2(1:CT-LEN(J)) <= CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GE" WHEN "NL"
                   IF H-KEY2(1:CT-LEN(J)) >= CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
           END-EVALUATE.
      *
       3265-EVAL-COUNT-COND.
      *    M2: "OP,CUENTA" FORM (SHEETS 8 AND 9). THE COMPARISON IS
      *    "CTA. REAL REG. : PARAMETRO CUENTA", I.E. THE RUNNING
      *    INPUT RECORD NUMBER AGAINST THE CARD OPERAND - NUMERIC,
      *    NOT THE CHARACTER COMPARE 3260 DOES ON FIELDS.
           MOVE "N" TO SW-BLK-CORRUPT
           EVALUATE CT-OP(J)
               WHEN "EQ"
                   IF REC-NO = CT-CNT(J)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "NE"
                   IF REC-NO NOT = CT-CNT(J)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LT"
                   IF REC-NO < CT-CNT(J)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GT"
                   IF REC-NO > CT-CNT(J)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LE" WHEN "NH"
                   IF REC-NO <= CT-CNT(J)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GE" WHEN "NL"
                   IF REC-NO >= CT-CNT(J)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
           END-EVALUATE.
      *
      *================================================================
      * 3300 GENER BLOCK ACCUMULATION (800-BYTE MATRIX, DOC04 DIAG 3)
      *================================================================
       3300-GENER-ACCUM.
           MOVE IN-REC(G-KOFF:G-KLEN) TO H-KEY1
           IF G-HAVE = "Y" AND
              H-KEY1(1:G-KLEN) NOT = G-CURKEY(1:G-KLEN)
               PERFORM 3400-FLUSH-BLOCK
           END-IF
           IF G-HAVE = "N"
               MOVE H-KEY1 TO G-CURKEY
               MOVE "Y" TO G-HAVE
               MOVE SPACES TO G-BLOCK
               PERFORM VARYING I FROM 1 BY 1 UNTIL I > 10
                   MOVE "N" TO G-USED(I)
               END-PERFORM
           END-IF
           MOVE IN-REC(G-COFF:G-CLEN) TO H-CODE
           MOVE 0 TO K
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > G-NCODES
               IF H-CODE(1:G-CLEN) = G-CODE(I)(1:G-CLEN)
                   MOVE I TO K
                   EXIT PERFORM
               END-IF
           END-PERFORM
           IF K = 0
               MOVE SPACES TO SYSLIST-REC
               STRING "UNMAPPED CARD CODE '" H-CODE(1:G-CLEN)
                   "' KEY " H-KEY1(1:G-KLEN) " - CARD DROPPED"
                   DELIMITED BY SIZE INTO SYSLIST-REC END-STRING
               WRITE SYSLIST-REC END-WRITE
           ELSE
               IF G-USED(K) = "Y"
      *            G7: DUPLICATE CODE IN ONE BATCH - POLICY IS
      *            FIRST-WINS; THE DUPLICATE IS LOGGED AND DROPPED
      *            (THE MANUAL LEAVES THIS CASE UNDEFINED)
                   MOVE SPACES TO SYSLIST-REC
                   STRING "DUPLICATE CARD CODE '" H-CODE(1:G-CLEN)
                       "' KEY " H-KEY1(1:G-KLEN)
                       " - DUPLICATE DROPPED (FIRST KEPT)"
                       DELIMITED BY SIZE INTO SYSLIST-REC END-STRING
                   WRITE SYSLIST-REC END-WRITE
               ELSE
                   MOVE IN-REC(1:80) TO G-SLOT(K)
                   MOVE "Y" TO G-USED(K)
               END-IF
           END-IF.
      *
      *================================================================
      * 3400 FLUSH FROZEN GENER BLOCK: CODIG -> INCON -> PROCESS
      * D0.1: SYSUT5 RECEIVES ONLY CODIG-COLLAPSE ORPHANS.
      *================================================================
       3400-FLUSH-BLOCK.
           MOVE "N" TO SW-BLK-CORRUPT
           PERFORM 3410-CHECK-CODIG
           IF SW-BLK-CORRUPT = "Y"
               PERFORM 3420-ORPHAN-BLOCK
           ELSE
               PERFORM 3430-APPLY-INCON-BLOCK
               MOVE G-BLOCK TO WS-SRC
               PERFORM 3500-PROCESS-UNIT
           END-IF
           MOVE "N" TO G-HAVE.
      *
       3410-CHECK-CODIG.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > CODIG-CNT
               OR SW-BLK-CORRUPT = "Y"
      *        LOCATE TARGET CODE SLOT
               MOVE 0 TO K
               PERFORM VARYING J FROM 1 BY 1 UNTIL J > G-NCODES
                   IF CD-TARGET(I)(1:G-CLEN) =
                      G-CODE(J)(1:G-CLEN)
                       MOVE J TO K
                       EXIT PERFORM
                   END-IF
               END-PERFORM
               MOVE "N" TO H-IN-TRUE
      *        H-IN-TRUE = RULE FIRES (TRIGGER PRESENT OR NO TRIGGERS)
               IF CD-NTRIG(I) = 0
                   MOVE "Y" TO H-IN-TRUE
               ELSE
                   PERFORM VARYING J FROM 1 BY 1
                       UNTIL J > CD-NTRIG(I)
                       PERFORM VARYING L FROM 1 BY 1
                           UNTIL L > G-NCODES
                           IF CD-TRIG(I, J)(1:G-CLEN) =
                              G-CODE(L)(1:G-CLEN)
                              AND G-USED(L) = "Y"
                               MOVE "Y" TO H-IN-TRUE
                           END-IF
                       END-PERFORM
                   END-PERFORM
               END-IF
               IF H-IN-TRUE = "Y"
                   IF K = 0 OR G-USED(K) = "N"
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               END-IF
           END-PERFORM.
      *
       3420-ORPHAN-BLOCK.
           ADD 1 TO ORPHAN-CNT END-ADD
           MOVE SPACES TO SYSLIST-REC
           STRING "CODIG FAILURE - BATCH KEY '"
               G-CURKEY(1:G-KLEN)
               "' ROUTED TO SYSUT5"
               DELIMITED BY SIZE INTO SYSLIST-REC END-STRING
           WRITE SYSLIST-REC END-WRITE
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 10
               IF G-USED(I) = "Y"
                   MOVE G-SLOT(I) TO SYSUT5-REC
                   WRITE SYSUT5-REC END-WRITE
               END-IF
           END-PERFORM.
      *
       3430-APPLY-INCON-BLOCK.
      *    APPLY EACH INCON RULE TO THE SLOT HOLDING ITS CARD CODE.
      *    CORRECTORS (ND/AB/NB) FIX BYTES IN PLACE; ALL FAILURES
      *    ARE LOGGED TO SYSLIST WITH THE RULE LABEL (DOC05).
           PERFORM 3439-INCON-GROUP-INIT
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > INCON-CNT
               MOVE 0 TO K
               PERFORM VARYING J FROM 1 BY 1 UNTIL J > G-NCODES
                   IF IC-CODE(I)(1:G-CLEN) = G-CODE(J)(1:G-CLEN)
                       MOVE J TO K
                       EXIT PERFORM
                   END-IF
               END-PERFORM
               IF K > 0 AND G-USED(K) = "Y"
                   MOVE K TO L
                   SUBTRACT 1 FROM L END-SUBTRACT
                   MULTIPLY 80 BY L END-MULTIPLY
                   ADD IC-OFF(I) TO L END-ADD
                   MOVE "Y" TO SW-ICODE-PRES
               ELSE
                   MOVE "N" TO SW-ICODE-PRES
               END-IF
               PERFORM 3438-INCON-STEP
           END-PERFORM
           PERFORM 3437-INCON-GROUP-CLOSE.
      *
       3437-INCON-GROUP-CLOSE.
      *    M17: AN .O. GROUP IS AN INCONSISTENCY ONLY WHEN EVERY
      *    ALTERNATIVE FAILED. A ONE-RULE GROUP IS THE ORDINARY CASE
      *    AND BEHAVES EXACTLY AS BEFORE.
           IF IX-IGRP > 0 AND SW-IGRP-BAD = "Y"
               PERFORM 3445-LOG-INCON
           END-IF
           MOVE 0 TO IX-IGRP
           MOVE "N" TO SW-IGRP-BAD.
      *
       3438-INCON-STEP.
      *    ONE RULE. GROUPS ARE PARSED IN ORDER SO THEIR RULES ARE
      *    CONTIGUOUS: A CHANGE OF IC-GROUP CLOSES THE PREVIOUS ONE.
           IF IC-GROUP(I) NOT = IX-IGRP
               PERFORM 3437-INCON-GROUP-CLOSE
               MOVE IC-GROUP(I) TO IX-IGRP
               MOVE I TO IX-IFIRST
               MOVE "Y" TO SW-IGRP-BAD
           END-IF
           IF SW-ICODE-PRES = "Y"
      *        M6: STAGE THE OPERAND, RUN THE RULE AT OFFSET 1, THEN
      *        WRITE ANY CORRECTION BACK - BUT NEVER INTO SYSUT3,
      *        WHICH IS AN INPUT FILE AND IS NEVER REWRITTEN.
               MOVE L TO ICL
               MOVE IC-LEN(I) TO ICN
               MOVE SPACES TO IC-SRC
               IF IC-FILE(I) = "3"
                   MOVE SEC-REC(IC-OFF(I):ICN) TO IC-SRC(1:ICN)
               ELSE
                   MOVE G-BLOCK(ICL:ICN) TO IC-SRC(1:ICN)
               END-IF
               MOVE 1 TO L
               PERFORM 3440-APPLY-INCON-RULE
               IF IC-FILE(I) NOT = "3"
                   MOVE IC-SRC(1:ICN) TO G-BLOCK(ICL:ICN)
               END-IF
               IF H-OUT-TRUE = "N"
                   MOVE "N" TO SW-IGRP-BAD
               END-IF
           ELSE
      *        THE RULE'S CARD CODE IS ABSENT FROM THE BLOCK: THERE
      *        IS NOTHING TO CHECK, SO THE GROUP IS NOT A VIOLATION.
               MOVE "N" TO SW-IGRP-BAD
           END-IF.
      *
       3439-INCON-GROUP-INIT.
           MOVE 0 TO IX-IGRP IX-IFIRST
           MOVE "N" TO SW-IGRP-BAD.
      *
       3445-LOG-INCON.
      *    LOGGED ONCE PER VIOLATED GROUP, UNDER ITS FIRST RULE.
           MOVE SPACES TO SYSLIST-REC
           STRING "INCON " IC-TYPE(IX-IFIRST) " VIOLATION CODE '"
               IC-CODE(IX-IFIRST)(1:G-CLEN) "' KEY '"
               G-CURKEY(1:G-KLEN) "' " IC-LABEL(IX-IFIRST)
               DELIMITED BY SIZE INTO SYSLIST-REC END-STRING
           WRITE SYSLIST-REC END-WRITE.
      *
       3440-APPLY-INCON-RULE.
      *    RULE I APPLIED AT IC-SRC(L:IC-LEN(I))
           MOVE "N" TO H-OUT-TRUE
      *    H-OUT-TRUE = VIOLATION SEEN
           EVALUATE IC-TYPE(I)
               WHEN "R "
      *            G2: RELATIONAL RULE - VIOLATION WHEN THE FIELD
      *            FAILS THE COMPARISON AGAINST THE LITERAL
                   PERFORM 3470-INCON-RELATIONAL
               WHEN "N " WHEN "ND"
                   PERFORM VARYING M FROM L BY 1
                       UNTIL M > L + IC-LEN(I) - 1
                       IF IC-SRC(M:1) < "0" OR IC-SRC(M:1) > "9"
                           MOVE "Y" TO H-OUT-TRUE
                           IF IC-TYPE(I) = "ND"
                               MOVE "0" TO IC-SRC(M:1)
                           END-IF
                       END-IF
                   END-PERFORM
               WHEN "A " WHEN "AB"
                   PERFORM VARYING M FROM L BY 1
                       UNTIL M > L + IC-LEN(I) - 1
                       IF NOT (IC-SRC(M:1) >= "A"
                               AND IC-SRC(M:1) <= "Z")
                          AND IC-SRC(M:1) NOT = SPACE
                           MOVE "Y" TO H-OUT-TRUE
                           IF IC-TYPE(I) = "AB"
                               MOVE SPACE TO IC-SRC(M:1)
                           END-IF
                       END-IF
                   END-PERFORM
               WHEN "AN" WHEN "NB"
                   PERFORM VARYING M FROM L BY 1
                       UNTIL M > L + IC-LEN(I) - 1
                       IF NOT (IC-SRC(M:1) >= "A"
                               AND IC-SRC(M:1) <= "Z")
                          AND (IC-SRC(M:1) < "0"
                               OR IC-SRC(M:1) > "9")
                          AND IC-SRC(M:1) NOT = SPACE
                           MOVE "Y" TO H-OUT-TRUE
                           IF IC-TYPE(I) = "NB"
                               MOVE SPACE TO IC-SRC(M:1)
                           END-IF
                       END-IF
                   END-PERFORM
               WHEN "FD" WHEN "FA"
                   PERFORM 3450-CHECK-DATE
           END-EVALUATE
      *    M17: LOGGING MOVED TO 3445, DRIVEN PER *GROUP* BY 3437 -
      *    AN .O. ALTERNATIVE THAT FAILS IS NOT ITSELF A VIOLATION.
           CONTINUE.
      *
       3450-CHECK-DATE.
      *    FD = DDMMAA (DAY FIRST). FA = A[A]MMDD (YEAR FIRST).
           MOVE 0 TO DN-HI DN-LO
           IF IC-TYPE(I) = "FD"
               PERFORM 3455-DIG2-DAY-FIRST
           ELSE
               PERFORM 3456-DIG2-YEAR-FIRST
           END-IF
           IF DN-HI < 1 OR DN-HI > 31
               MOVE "Y" TO H-OUT-TRUE
           END-IF
           IF DN-LO < 1 OR DN-LO > 12
               MOVE "Y" TO H-OUT-TRUE
           END-IF.
      *
       3470-INCON-RELATIONAL.
      *    G2: COMPARE IC-SRC(L:IC-LEN) TO IC-LIT VIA IC-RELOP.
      *    THE RULE PASSES WHEN THE RELATION HOLDS; A FAILED
      *    RELATION IS THE INCONSISTENCY (H-OUT-TRUE = "Y").
           MOVE IC-LEN(I) TO M
           MOVE "N" TO SW-BLK-CORRUPT
           EVALUATE IC-RELOP(I)
               WHEN "EQ"
                   IF IC-SRC(L:M) = IC-LIT(I)(1:M)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "NE"
                   IF IC-SRC(L:M) NOT = IC-LIT(I)(1:M)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LT"
                   IF IC-SRC(L:M) < IC-LIT(I)(1:M)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GT"
                   IF IC-SRC(L:M) > IC-LIT(I)(1:M)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LE" WHEN "NH"
                   IF IC-SRC(L:M) <= IC-LIT(I)(1:M)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GE" WHEN "NL"
                   IF IC-SRC(L:M) >= IC-LIT(I)(1:M)
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
           END-EVALUATE
           IF SW-BLK-CORRUPT = "N"
               MOVE "Y" TO H-OUT-TRUE
           END-IF.
      *
       3455-DIG2-DAY-FIRST.
      *    DN-HI = DAY (POS 1-2), DN-LO = MONTH (POS 3-4)
           PERFORM 3457-PAIR-TO-NUMS.
      *
       3456-DIG2-YEAR-FIRST.
      *    AMMDD/AAMMDD: MONTH AND DAY ARE THE LAST 4 BYTES
           COMPUTE M = L + IC-LEN(I) - 4 END-COMPUTE
           PERFORM 3458-PAIR-TAIL-TO-NUMS.
      *
       3457-PAIR-TO-NUMS.
           IF IC-SRC(L:2) IS NUMERIC
               MOVE IC-SRC(L:2) TO H-KEY2(1:2)
               PERFORM 7710-PAIR-TO-NUM
               MOVE DN-DIGIT TO DN-HI
           ELSE
               MOVE 99 TO DN-HI
           END-IF
           IF IC-SRC(L + 2:2) IS NUMERIC
               MOVE IC-SRC(L + 2:2) TO H-KEY2(1:2)
               PERFORM 7710-PAIR-TO-NUM
               MOVE DN-DIGIT TO DN-LO
           ELSE
               MOVE 99 TO DN-LO
           END-IF.
      *
       3458-PAIR-TAIL-TO-NUMS.
           IF G-BLOCK(M:2) IS NUMERIC
               MOVE G-BLOCK(M:2) TO H-KEY2(1:2)
               PERFORM 7710-PAIR-TO-NUM
               MOVE DN-DIGIT TO DN-LO
           ELSE
               MOVE 99 TO DN-LO
           END-IF
           IF G-BLOCK(M + 2:2) IS NUMERIC
               MOVE G-BLOCK(M + 2:2) TO H-KEY2(1:2)
               PERFORM 7710-PAIR-TO-NUM
               MOVE DN-DIGIT TO DN-HI
           ELSE
               MOVE 99 TO DN-HI
           END-IF.
      *
      *================================================================
      * 3500 PROCESS ONE UNIT (RECORD OR FROZEN BLOCK) IN WS-SRC
      *================================================================
       3500-PROCESS-UNIT.
           IF G-ACTIVE = "N"
               MOVE IN-REC TO WS-SRC
               IF MODE-OSGENER AND INCON-CNT > 0
                   PERFORM 3460-APPLY-INCON-RECORD
               END-IF
           END-IF
           PERFORM 3510-SET-COND-FLAGS
           IF MODE-OSLISTA
      *        BREAKS FIRE BEFORE ACCUMULATING THE CURRENT RECORD,
      *        SO GROUP TOTALS EXCLUDE THE NEW GROUP'S FIRST RECORD
               PERFORM 3600-CHECK-BREAKS
               PERFORM 3520-RUN-ACUMS
               PERFORM 4200-OUTPUT-LISTA THRU 4200-EXIT
           ELSE
               PERFORM 3520-RUN-ACUMS
               PERFORM 4100-OUTPUT-GENER
           END-IF
           ADD 1 TO PROC-CNT END-ADD
           MOVE WS-SRC TO WS-PREV-SRC.
      *
       3460-APPLY-INCON-RECORD.
      *    NO GENER BLOCK: RULES APPLY DIRECTLY AT RECORD OFFSETS.
      *    REUSES 3440 BY TREATING WS-SRC COPY AS SLOT 1 CONTENT.
           MOVE WS-SRC(1:80) TO G-BLOCK(1:80)
           PERFORM 3439-INCON-GROUP-INIT
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > INCON-CNT
               MOVE IC-OFF(I) TO L
               MOVE "Y" TO SW-ICODE-PRES
               PERFORM 3438-INCON-STEP
           END-PERFORM
           PERFORM 3437-INCON-GROUP-CLOSE
           MOVE G-BLOCK(1:80) TO WS-SRC(1:80).
      *
       3510-SET-COND-FLAGS.
      *    M3: A CONDX CARD IS A CONDITION *GROUP*, EXACTLY LIKE
      *    RCIN/RCOUT, SO IT MUST BE FOLDED PER GROUP (3550) AND NOT
      *    OR-ED CONDITION BY CONDITION. THE FLAG IS SET WHEN ANY
      *    GROUP CARRYING IT IS TRUE; ALL CONDITIONS OF ONE GROUP
      *    COME FROM ONE CARD AND THEREFORE SHARE CT-FLAG.
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 8
               MOVE "N" TO CFLAG(I)
           END-PERFORM
           MOVE 0 TO IX-GRP
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > COND-CNT
               IF CT-KIND(I) = "C"
                   IF CT-GROUP(I) NOT = IX-GRP
                       MOVE CT-GROUP(I) TO IX-GRP
                       PERFORM 3550-EVAL-COND-GROUP
                       IF H-GRP-TRUE = "Y"
                           MOVE "Y" TO CFLAG(CT-FLAG(I))
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.
      *
       3550-EVAL-COND-GROUP.
      *    AS 3250, BUT THE FIELD SOURCE IS WS-SRC (UNIT BUFFER).
      *    FAMILY: ANY "A" CONNECTOR -> AND-GROUP, ELSE OR-GROUP.
           MOVE "O" TO H-FAMILY
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > COND-CNT
               IF CT-GROUP(J) = IX-GRP AND CT-CONN(J) = "A"
                   MOVE "A" TO H-FAMILY
               END-IF
           END-PERFORM
           IF H-FAMILY = "A"
               MOVE "Y" TO H-GRP-TRUE
           ELSE
               MOVE "N" TO H-GRP-TRUE
           END-IF
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > COND-CNT
               IF CT-GROUP(J) = IX-GRP
                   IF CT-FILE(J) = "N"
                       PERFORM 3265-EVAL-COUNT-COND
                   ELSE
                       PERFORM 3515-EVAL-COND-SRC
                   END-IF
                   IF H-FAMILY = "A" AND SW-BLK-CORRUPT = "N"
                       MOVE "N" TO H-GRP-TRUE
                   END-IF
                   IF H-FAMILY = "O" AND SW-BLK-CORRUPT = "Y"
                       MOVE "Y" TO H-GRP-TRUE
                   END-IF
               END-IF
           END-PERFORM.
      *
       3515-EVAL-COND-SRC.
      *    LIKE 3260 BUT FIELD SOURCE IS WS-SRC (UNIT BUFFER)
           IF CT-FILE(J) = "3"
               MOVE SEC-REC(CT-OFF(J):CT-LEN(J)) TO H-KEY2
           ELSE
               MOVE WS-SRC(CT-OFF(J):CT-LEN(J)) TO H-KEY2
           END-IF
           MOVE "N" TO SW-BLK-CORRUPT
           EVALUATE CT-OP(J)
               WHEN "EQ"
                   IF H-KEY2(1:CT-LEN(J)) = CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "NE"
                   IF H-KEY2(1:CT-LEN(J)) NOT =
                      CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LT"
                   IF H-KEY2(1:CT-LEN(J)) < CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GT"
                   IF H-KEY2(1:CT-LEN(J)) > CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "LE" WHEN "NH"
                   IF H-KEY2(1:CT-LEN(J)) <= CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
               WHEN "GE" WHEN "NL"
                   IF H-KEY2(1:CT-LEN(J)) >= CT-LIT(J)(1:CT-LEN(J))
                       MOVE "Y" TO SW-BLK-CORRUPT
                   END-IF
           END-EVALUATE.
      *
       3520-RUN-ACUMS.
      *    NESTED IF: COBOL OR DOES NOT SHORT-CIRCUIT, SO A SINGLE
      *    CONDITION WOULD EVALUATE CFLAG(0) WHEN THE FLAG IS 0
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > ACUM-CNT
               IF AT-FLAG(I) = 0
                   PERFORM 3525-RUN-ONE-ACUM
               ELSE
                   IF CFLAG(AT-FLAG(I)) = "Y"
                       PERFORM 3525-RUN-ONE-ACUM
                   END-IF
               END-IF
           END-PERFORM.
      *
       3525-RUN-ONE-ACUM.
           IF AT-SRCK(I) = "L"
      *        G5: NUMERIC LITERAL OPERAND (ALREADY A TRUE DECIMAL)
               MOVE AT-LIT(I) TO DN-OPND
           ELSE
      *        M6: STAGE FROM SYSUT1 OR SYSUT3 (S-PREFIXED OFFSET)
               MOVE AT-LEN(I) TO M
               MOVE SPACES TO WS-FBUF
               IF AT-FILE(I) = "3"
                   MOVE SEC-REC(AT-OFF(I):M) TO WS-FBUF(1:M)
               ELSE
                   MOVE WS-SRC(AT-OFF(I):M) TO WS-FBUF(1:M)
               END-IF
               MOVE 1 TO L
               MOVE AT-FMT(I) TO H-KEY2(1:1)
               PERFORM 7000-DECODE-NUMERIC
      *        G5: SCALE THE RAW INTEGER BY ITS IMPLIED DECIMALS TO
      *        A TRUE DECIMAL SO OPERANDS OF DIFFERENT SCALES ALIGN
               MOVE DN-VAL TO DN-OPND
               IF AT-DEC(I) > 0
                   MOVE 1 TO DN-POW
                   PERFORM VARYING J FROM 1 BY 1 UNTIL J > AT-DEC(I)
                       MULTIPLY 10 BY DN-POW END-MULTIPLY
                   END-PERFORM
                   DIVIDE DN-POW INTO DN-OPND END-DIVIDE
               END-IF
           END-IF
           MOVE AT-ACUM(I) TO K
           EVALUATE AT-OP(I)
               WHEN "+"
                   ADD DN-OPND TO ACUM-REG(K) END-ADD
               WHEN "-"
                   SUBTRACT DN-OPND FROM ACUM-REG(K) END-SUBTRACT
               WHEN "*"
                   MULTIPLY DN-OPND BY ACUM-REG(K) END-MULTIPLY
               WHEN "/"
                   IF DN-OPND = 0
      *                DOC05: DIVISION BY ZERO MUST NOT ABEND.
      *                FORCE 0, WARN IN SYSPRINT, CONTINUE.
                       MOVE 0 TO ACUM-REG(K)
                       MOVE SPACES TO SYSPRINT-REC
                       STRING "WARNING: DIVISION BY ZERO IN ACUM"
                           DELIMITED BY SIZE INTO SYSPRINT-REC
                       END-STRING
                       WRITE SYSPRINT-REC END-WRITE
                   ELSE
      *                MUST BE DN-OPND, NOT DN-VAL: THE LITERAL
      *                BRANCH NEVER TOUCHES DN-VAL (SO DIVISION BY A
      *                LITERAL USED THE PREVIOUS FIELD'S VALUE), AND
      *                DN-VAL IS ALSO THE UNSCALED INTEGER.
                       DIVIDE DN-OPND INTO ACUM-REG(K) END-DIVIDE
                   END-IF
           END-EVALUATE.
      *
      *================================================================
      * 3700 FIELD ENGINE: BUILD OUTPUT AREAS FROM WS-SRC
      * TARGETS: OUT-MAIN, OUT-SEC (OSGENER) / PRT-LINE 1-9 (OSLISTA)
      *================================================================
       3700-RUN-FIELDS.
           MOVE SPACES TO OUT-MAIN OUT-SEC
           MOVE "N" TO OUT-SEC-USED
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 9
               MOVE SPACES TO PRT-LINE(I)
               MOVE "N" TO PRT-U(I)
           END-PERFORM
      *    NESTED IF: AVOID CFLAG(0) EVALUATION (NO SHORT-CIRCUIT)
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > FIELD-CNT
               IF FT-FLAG(I) = 0
                   PERFORM 3710-RUN-ONE-FIELD
               ELSE
                   IF CFLAG(FT-FLAG(I)) = "Y"
                       PERFORM 3710-RUN-ONE-FIELD
                   END-IF
               END-IF
           END-PERFORM
      *    NO FIELD CARDS: DEFAULT-COPY THE UNIT *BEFORE* CONVS SO
      *    TABLE LOOKUPS ARE NOT CLOBBERED BY THE COPY
           IF FIELD-CNT = 0
               IF MODE-OSGENER
                   MOVE WS-SRC(1:32760) TO OUT-MAIN
               ELSE
                   MOVE WS-SRC(1:132) TO PRT-LINE(1)
                   MOVE "Y" TO PRT-U(1)
               END-IF
           END-IF
           PERFORM 3800-RUN-CONVS.
      *
       3710-RUN-ONE-FIELD.
           MOVE SPACES TO ED-OUT
           MOVE 0 TO EN-LEN
           EVALUATE TRUE
               WHEN FT-SRC(I) = "L"
                   PERFORM 3720-FLD-LITERAL
               WHEN FT-SRC(I) = "A"
                   PERFORM 3730-FLD-ACUM
               WHEN FT-SRC(I) = "N"
                   PERFORM 3735-FLD-COUNTER
               WHEN OTHER
                   PERFORM 3740-FLD-FIELD
           END-EVALUATE
           IF EN-LEN > 0
               PERFORM 3790-EMIT-FIELD
           END-IF.
      *
       3720-FLD-LITERAL.
      *    'LIT',CL: FILL FT-LEN BYTES REPEATING THE LITERAL
           MOVE 0 TO K
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > FT-LEN(I)
               OR J > 999
               COMPUTE K = J - 1 END-COMPUTE
               DIVIDE K BY FT-LLEN(I) GIVING M REMAINDER L END-DIVIDE
               ADD 1 TO L END-ADD
               MOVE FT-LIT(I)(L:1) TO ED-OUT(J:1)
           END-PERFORM
      *    FT-LEN AND EN-LEN ARE BOTH 9(3), SO THE FILL LOOP ABOVE
      *    ALREADY BOUNDS THIS AT ED-OUT'S 999 BYTES.
           MOVE FT-LEN(I) TO EN-LEN.
      *
       3730-FLD-ACUM.
           MOVE ACUM-REG(FT-ACUM(I)) TO DN-VAL
           IF FT-CONV(I) = "AF"
      *        M19: "AY,FORMATO" - ENCODE, DO NOT EDIT
               PERFORM 7100-ENCODE-NUMERIC
           ELSE
               PERFORM 3750-EDIT-BY-CONV
           END-IF.
      *
       3735-FLD-COUNTER.
      *    M20: "AN,FORMATO" - THE COUNT OF RECORDS WRITTEN SO FAR
      *    (SHEET 32). OUT-CNT IS THE SYSUT2 WRITE COUNTER.
           MOVE OUT-CNT TO DN-VAL
           IF FT-CONV(I) = "AF"
               PERFORM 7100-ENCODE-NUMERIC
           ELSE
               PERFORM 3750-EDIT-BY-CONV
           END-IF.
      *
       3740-FLD-FIELD.
      *    M6: STAGE THE OPERAND FROM THE FILE ITS OFFSET NAMES
      *    (S-PREFIX = SYSUT3), THEN WORK AT OFFSET 1 OF WS-FBUF.
           MOVE FT-LEN(I) TO M
           MOVE SPACES TO WS-FBUF
           IF FT-FILE(I) = "3"
               MOVE SEC-REC(FT-OFF(I):M) TO WS-FBUF(1:M)
           ELSE
               MOVE WS-SRC(FT-OFF(I):M) TO WS-FBUF(1:M)
           END-IF
           MOVE 1 TO L
           EVALUATE FT-CONV(I)
               WHEN "MV"
                   MOVE WS-FBUF(L:M) TO ED-OUT(1:M)
                   MOVE M TO EN-LEN
               WHEN "UN"
                   MOVE "P" TO H-KEY2(1:1)
                   PERFORM 7000-DECODE-NUMERIC
                   COMPUTE EN-LEN = 2 * M - 1 END-COMPUTE
                   PERFORM 7150-VAL-TO-DIGITS
               WHEN "HX"
                   PERFORM 7400-HEX-EXPAND
               WHEN "DV"
                   PERFORM 7200-MOD10
               WHEN "ZD" WHEN "PD"
                   IF FT-CONV(I) = "PD"
                       MOVE "P" TO H-KEY2(1:1)
                   ELSE
                       MOVE "Z" TO H-KEY2(1:1)
                   END-IF
                   PERFORM 7000-DECODE-NUMERIC
                   PERFORM 3750-EDIT-BY-CONV
               WHEN "XY"
                   MOVE FT-INFMT(I) TO H-KEY2(1:1)
                   PERFORM 7000-DECODE-NUMERIC
                   PERFORM 7100-ENCODE-NUMERIC
               WHEN "VN" WHEN "VA" WHEN "VZ"
                   PERFORM 7450-VALIDATE-CLASS
           END-EVALUATE.
      *
       7450-VALIDATE-CLASS.
      *    M29: AN / AB / NO (SHEET 32). COPY THE FIELD, REPLACING
      *    EVERY BYTE OUTSIDE THE REQUESTED CLASS - BLANK FOR THE
      *    ALPHA FORMS, ZERO FOR THE NUMERIC ONE. SAME CHARACTER
      *    CLASSES AS THE INCON CORRECTORS IN 3440.
           MOVE WS-FBUF(1:M) TO ED-OUT(1:M)
           MOVE M TO EN-LEN
           PERFORM VARYING N FROM 1 BY 1 UNTIL N > M
               EVALUATE FT-CONV(I)
                   WHEN "VZ"
                       IF ED-OUT(N:1) < "0" OR ED-OUT(N:1) > "9"
                           MOVE "0" TO ED-OUT(N:1)
                       END-IF
                   WHEN "VA"
                       IF NOT (ED-OUT(N:1) >= "A"
                               AND ED-OUT(N:1) <= "Z")
                          AND ED-OUT(N:1) NOT = SPACE
                           MOVE SPACE TO ED-OUT(N:1)
                       END-IF
                   WHEN "VN"
                       IF NOT (ED-OUT(N:1) >= "A"
                               AND ED-OUT(N:1) <= "Z")
                          AND (ED-OUT(N:1) < "0"
                               OR ED-OUT(N:1) > "9")
                          AND ED-OUT(N:1) NOT = SPACE
                           MOVE SPACE TO ED-OUT(N:1)
                       END-IF
               END-EVALUATE
           END-PERFORM.
      *
       3750-EDIT-BY-CONV.
      *    EDIT DN-VAL WITH FT-DIGITS/FT-DEC MASK INTO ED-OUT/EN-LEN
           MOVE FT-DIGITS(I) TO ED-P
           IF ED-P = 0
               MOVE 9 TO ED-P
           END-IF
           MOVE FT-DEC(I) TO J
           PERFORM 7600-EDIT-NUM.
      *
       3790-EMIT-FIELD.
           MOVE FT-OUT(I) TO K
           IF MODE-OSGENER
               IF FT-DEST(I) = "S"
                   MOVE ED-OUT(1:EN-LEN) TO OUT-SEC(K:EN-LEN)
                   MOVE "Y" TO OUT-SEC-USED
               ELSE
                   MOVE ED-OUT(1:EN-LEN) TO OUT-MAIN(K:EN-LEN)
               END-IF
           ELSE
      *        M7: NINE PRINT LINES. FT-DEST IS "M" (LINE 1), "S"
      *        (LINE 2) OR THE DIGIT 3..9 FOR THE T/C/Q/X/P/O/N
      *        OUTPUT PREFIXES OF SHEET 11.
               EVALUATE FT-DEST(I)
                   WHEN "M"
                       MOVE 1 TO PRTX
                   WHEN "S"
                       MOVE 2 TO PRTX
                   WHEN OTHER
                       MOVE FT-DEST(I) TO TRT-CHAR
                       PERFORM 7700-CHAR-TO-DIGIT
                       MOVE DN-DIGIT TO PRTX
               END-EVALUATE
               MOVE ED-OUT(1:EN-LEN) TO PRT-LINE(PRTX)(K:EN-LEN)
               MOVE "Y" TO PRT-U(PRTX)
           END-IF.
      *
       3800-RUN-CONVS.
      *    EXTERNAL TABLE LOOKUPS -> OUTPUT AREAS
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > CONV-CNT
      *        M12: CONVX RUNS ONLY WHEN CONDITION X IS SET. NESTED
      *        IF - COBOL "OR" DOES NOT SHORT-CIRCUIT, SO A SINGLE
      *        CONDITION WOULD EVALUATE CFLAG(0) WHEN THE FLAG IS 0
               MOVE "Y" TO H-IN-TRUE
               IF CV-FLAG(I) NOT = 0
                   IF CFLAG(CV-FLAG(I)) NOT = "Y"
                       MOVE "N" TO H-IN-TRUE
                   END-IF
               END-IF
               IF H-IN-TRUE = "Y"
      *        M6: THE FIELD TO CONVERT MAY LIVE IN SYSUT3
               IF CV-INFILE(I) = "3"
                   MOVE SEC-REC(CV-INOFF(I):CV-INLEN(I)) TO H-KEY2
               ELSE
                   MOVE WS-SRC(CV-INOFF(I):CV-INLEN(I)) TO H-KEY2
               END-IF
               MOVE 0 TO K
               IF CV-INT(I) = "Y"
                   PERFORM VARYING J FROM 1 BY 1 UNTIL J > CV-N(I)
                       IF H-KEY2(1:CV-INLEN(I)) <=
                          CVE-ARG(I, J)(1:CV-INLEN(I))
                           MOVE J TO K
                           EXIT PERFORM
                       END-IF
                   END-PERFORM
               ELSE
                   PERFORM VARYING J FROM 1 BY 1 UNTIL J > CV-N(I)
                       IF H-KEY2(1:CV-INLEN(I)) =
                          CVE-ARG(I, J)(1:CV-INLEN(I))
                           MOVE J TO K
                           EXIT PERFORM
                       END-IF
                   END-PERFORM
               END-IF
               IF K = 0 AND CV-N(I) > 0
      *            MISS DEFAULTS TO FINAL TABLE ENTRY (DOC01 4.5)
                   MOVE CV-N(I) TO K
               END-IF
               IF K > 0
                   PERFORM 3810-EMIT-CONV
               END-IF
               END-IF
           END-PERFORM.
      *
       3810-EMIT-CONV.
      *    ROUTE ONE LOOKUP RESULT. M13: A TITX CONVERSION LANDS IN
      *    THE TITLE TEMPLATE, WHICH 4265 COPIES OUT AT PAGE TOP, SO
      *    THE HEADING SHOWS THE VALUE OF THE PAGE-LEAD RECORD.
      *    M14: OTHERWISE CV-DEST NAMES SYSUT4 OR A PRINT LINE.
           IF CV-TIT(I) > 0
               MOVE CVE-FUN(I, K)(1:CV-OUTLEN(I))
                   TO TI-TEXT(CV-TIT(I))
                      (CV-OUTOFF(I):CV-OUTLEN(I))
           ELSE
               IF MODE-OSGENER
                   IF CV-DEST(I) = "S"
                       MOVE CVE-FUN(I, K)(1:CV-OUTLEN(I))
                           TO OUT-SEC(CV-OUTOFF(I):CV-OUTLEN(I))
                       MOVE "Y" TO OUT-SEC-USED
                   ELSE
                       MOVE CVE-FUN(I, K)(1:CV-OUTLEN(I))
                           TO OUT-MAIN(CV-OUTOFF(I):CV-OUTLEN(I))
                   END-IF
               ELSE
                   EVALUATE CV-DEST(I)
                       WHEN "M"
                           MOVE 1 TO PRTX
                       WHEN "S"
                           MOVE 2 TO PRTX
                       WHEN OTHER
                           MOVE CV-DEST(I) TO TRT-CHAR
                           PERFORM 7700-CHAR-TO-DIGIT
                           MOVE DN-DIGIT TO PRTX
                   END-EVALUATE
                   MOVE CVE-FUN(I, K)(1:CV-OUTLEN(I))
                       TO PRT-LINE(PRTX)
                          (CV-OUTOFF(I):CV-OUTLEN(I))
                   MOVE "Y" TO PRT-U(PRTX)
               END-IF
           END-IF.
      *
      *================================================================
      * 4000/4100 OSGENER WRITERS + FIRST-5 AUDIT (DOC01 2.2)
      *================================================================
       4000-WRITE-MAIN-REC.
           MOVE IN-REC(1:32760) TO SYSUT2-REC
           WRITE SYSUT2-REC END-WRITE
           ADD 1 TO OUT-CNT END-ADD.
      *
       4100-OUTPUT-GENER.
           PERFORM 3700-RUN-FIELDS
           MOVE OUT-MAIN TO SYSUT2-REC
           WRITE SYSUT2-REC END-WRITE
           ADD 1 TO OUT-CNT END-ADD
           IF OUT-SEC-USED = "Y"
               MOVE OUT-SEC TO SYSUT4-REC
               WRITE SYSUT4-REC END-WRITE
               ADD 1 TO OUT4-CNT END-ADD
           END-IF
           IF AUDIT-CNT < 5
               ADD 1 TO AUDIT-CNT END-ADD
               MOVE SPACES TO SYSPRINT-REC
               STRING "AUDIT " AUDIT-CNT ": " OUT-MAIN(1:100)
                   DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
               WRITE SYSPRINT-REC END-WRITE
           END-IF.
      *
      *================================================================
      * 3600 CONTROL BREAKS (OSLISTA). LEVELS DECLARED MAJOR->MINOR.
      * D0.3: EVALUATED ONLY ON ACCEPTED RECORDS (AFTER FILTERS).
      *================================================================
       3600-CHECK-BREAKS.
           MOVE 0 TO H-NUM
           PERFORM VARYING IX-LVL FROM 1 BY 1
               UNTIL IX-LVL > CORTE-CNT
               EVALUATE CO-TYPE(IX-LVL)
                   WHEN "K"
                       MOVE WS-SRC(CO-OFF(IX-LVL):CO-LEN(IX-LVL))
                           TO H-KEY1
                       IF CO-PREV(IX-LVL) = LOW-VALUES
                           MOVE H-KEY1 TO CO-PREV(IX-LVL)
                       ELSE
                           IF H-KEY1(1:CO-LEN(IX-LVL)) NOT =
                              CO-PREV(IX-LVL)(1:CO-LEN(IX-LVL))
                              AND H-NUM = 0
                               MOVE IX-LVL TO H-NUM
                           END-IF
                       END-IF
                   WHEN "C"
                       IF CO-CT(IX-LVL) > 0 AND
                          CO-COUNT(IX-LVL) >= CO-CT(IX-LVL)
                          AND H-NUM = 0
                           MOVE IX-LVL TO H-NUM
                       END-IF
               END-EVALUATE
           END-PERFORM
           IF H-NUM > 0
               PERFORM VARYING IX-LVL FROM CORTE-CNT BY -1
                   UNTIL IX-LVL < H-NUM
                   IF CO-TYPE(IX-LVL) NOT = "F"
                       PERFORM 4300-DO-BREAK-LEVEL
                       MOVE 0 TO CO-COUNT(IX-LVL)
                       IF CO-TYPE(IX-LVL) = "K"
                           MOVE WS-SRC(CO-OFF(IX-LVL):
                                CO-LEN(IX-LVL))
                               TO CO-PREV(IX-LVL)
                       END-IF
                   END-IF
               END-PERFORM
           END-IF
           PERFORM VARYING IX-LVL FROM 1 BY 1
               UNTIL IX-LVL > CORTE-CNT
               ADD 1 TO CO-COUNT(IX-LVL) END-ADD
           END-PERFORM.
      *
       4300-DO-BREAK-LEVEL.
      *    PRINT ID + IMCOR SUMMARY FOR LEVEL IX-LVL, RESET ACUMS
           MOVE SPACES TO H-LINE
           IF CO-IDLEN(IX-LVL) > 0
               IF CO-SO1(IX-LVL) > 0
                   MOVE CO-SO1(IX-LVL) TO K
               ELSE
                   MOVE 1 TO K
               END-IF
               MOVE CO-ID(IX-LVL)(1:CO-IDLEN(IX-LVL))
                   TO H-LINE(K:CO-IDLEN(IX-LVL))
           END-IF
      *    M16: ECHO THE BREAKING FIELD ITSELF. IT COMES FROM THE
      *    CLOSING GROUP'S LAST RECORD (WS-PREV-SRC, SEE D0.3), NOT
      *    THE RECORD THAT TRIGGERED THE BREAK.
           IF CO-PRTKEY(IX-LVL) = "Y" AND CO-TYPE(IX-LVL) = "K"
               MOVE CO-SO2(IX-LVL) TO K
               IF K < 1
                   MOVE 1 TO K
               END-IF
               MOVE WS-PREV-SRC(CO-OFF(IX-LVL):CO-LEN(IX-LVL))
                   TO H-LINE(K:CO-LEN(IX-LVL))
           END-IF
           PERFORM VARYING M FROM 1 BY 1
               UNTIL M > IM-CNT(IX-LVL)
               EVALUATE IM-KIND(IX-LVL, M)
                   WHEN "C"
                       MOVE CO-COUNT(IX-LVL) TO H-CNT-ED
                       MOVE H-CNT-ED TO
                           H-LINE(IM-SO(IX-LVL, M):9)
                   WHEN "A"
      *                G5: SCALE THE TRUE-DECIMAL ACCUMULATOR UP BY
      *                THE MASK'S DECIMAL COUNT SO 7600 (WHICH SPLITS
      *                THE LAST y DIGITS) RENDERS THE FRACTION
                       MOVE 1 TO DN-POW
                       PERFORM VARYING J FROM 1 BY 1
                           UNTIL J > IM-DEC(IX-LVL, M)
                           MULTIPLY 10 BY DN-POW END-MULTIPLY
                       END-PERFORM
                       COMPUTE DN-VAL ROUNDED =
                           ACUM-REG(IM-ACUM(IX-LVL, M)) * DN-POW
                       END-COMPUTE
                       MOVE IM-DIGITS(IX-LVL, M) TO ED-P
                       IF ED-P = 0
                           MOVE 9 TO ED-P
                       END-IF
                       MOVE IM-DEC(IX-LVL, M) TO J
                       PERFORM 7600-EDIT-NUM
                       MOVE ED-OUT(1:EN-LEN) TO
                           H-LINE(IM-SO(IX-LVL, M):EN-LEN)
                       MOVE 0 TO ACUM-REG(IM-ACUM(IX-LVL, M))
                   WHEN "F"
                       MOVE WS-PREV-SRC(IM-OFF(IX-LVL, M):
                            IM-LEN(IX-LVL, M)) TO
                           H-LINE(IM-SO(IX-LVL, M):
                            IM-LEN(IX-LVL, M))
               END-EVALUATE
           END-PERFORM
           IF CO-SILENT(IX-LVL) = "N" OR IM-CNT(IX-LVL) > 0
               MOVE H-LINE TO SYSUT2-REC
               WRITE SYSUT2-REC END-WRITE
               ADD 1 TO LN-CNT END-ADD
           END-IF
           EVALUATE CO-SK(IX-LVL)
               WHEN "H"
                   MOVE 99 TO LN-CNT
               WHEN "1" WHEN "2" WHEN "3"
                   PERFORM 4290-BLANK-LINES
           END-EVALUATE.
      *
       4290-BLANK-LINES.
           MOVE CO-SK(IX-LVL) TO TRT-CHAR
           PERFORM 7700-CHAR-TO-DIGIT
           MOVE DN-DIGIT TO N
           PERFORM N TIMES
               MOVE SPACES TO SYSUT2-REC
               WRITE SYSUT2-REC END-WRITE
               ADD 1 TO LN-CNT END-ADD
           END-PERFORM.
      *
      *================================================================
      * 4200 OSLISTA LISTING OUTPUT (PRINT / TIT / FL=C,X,XC)
      *================================================================
       4200-OUTPUT-LISTA.
           IF PR-ACTIVE = "Y"
               IF REC-NO < PR-FR OR REC-NO > PR-LR
                   GO TO 4200-EXIT
               END-IF
               IF PR-SK > 0
                   COMPUTE J = REC-NO - PR-FR END-COMPUTE
                   COMPUTE K = PR-SK + 1 END-COMPUTE
                   DIVIDE J BY K GIVING L REMAINDER M END-DIVIDE
                   IF M NOT = 0
                       GO TO 4200-EXIT
                   END-IF
               END-IF
           END-IF
           PERFORM 3700-RUN-FIELDS
           PERFORM VARYING I FROM 1 BY 1 UNTIL I > 9
               IF PRT-U(I) = "Y"
                   MOVE PRT-LINE(I) TO H-LINE
                   PERFORM 4250-WRITE-PRINT-LINE
                   IF PR-FL = "X " OR PR-FL = "XC"
                       PERFORM 4270-WRITE-HEX-LINE
                   END-IF
      *            G3: CARRO CARRIAGE CONTROL, WHEN PRESENT, DRIVES
      *            LINE SPACING IN PLACE OF PRINT SP=
                   IF CARRO-CNT > 0
                       PERFORM 4280-APPLY-CARRO
                   ELSE
                       IF PR-SP > 1
                           COMPUTE N = PR-SP - 1 END-COMPUTE
                           PERFORM 4295-N-BLANKS
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           IF CARRO-CNT = 0 AND PR-SR > 1
               COMPUTE N = PR-SR - 1 END-COMPUTE
               PERFORM 4295-N-BLANKS
           END-IF.
       4200-EXIT.
           EXIT.
      *
       4280-APPLY-CARRO.
      *    G3: CONSUME THE NEXT CARRO ACTION CYCLICALLY.
      *    W=WRITE+SKIP N  S=SKIP N LINES  C=TO CHANNEL
      *    (CHANNEL 1 = TOP OF FORM -> FORCE A PAGE EJECT)
           ADD 1 TO CARRO-IX END-ADD
           IF CARRO-IX > CARRO-CNT
               MOVE 1 TO CARRO-IX
           END-IF
           EVALUATE CA-ACT(CARRO-IX)
               WHEN "W" WHEN "S"
                   IF CA-N(CARRO-IX) > 0
                       MOVE CA-N(CARRO-IX) TO N
                       PERFORM 4295-N-BLANKS
                   END-IF
               WHEN "C"
                   IF CA-N(CARRO-IX) = 1
                       MOVE 99 TO LN-CNT
                   ELSE
                       MOVE 2 TO N
                       PERFORM 4295-N-BLANKS
                   END-IF
           END-EVALUATE.
      *
       4250-WRITE-PRINT-LINE.
           IF LN-CNT > 60
               PERFORM 4260-NEW-PAGE
           END-IF
           IF PR-FL = "X "
      *        HEX-ONLY FORMAT: SUPPRESS THE CHARACTER LINE
               CONTINUE
           ELSE
               MOVE H-LINE TO SYSUT2-REC
               WRITE SYSUT2-REC END-WRITE
               ADD 1 TO LN-CNT END-ADD
           END-IF.
      *
       4260-NEW-PAGE.
           ADD 1 TO PAGE-NO END-ADD
           MOVE 0 TO LN-CNT
      *    M25: "LA PRIMERA LINEA SE IMPRIMIRA SIEMPRE" (SHEET 6).
      *    WITH NO TIT CARD AT ALL THERE IS STILL A HEADING LINE,
      *    CARRYING ONLY THE PAGE NUMBER. CARRO SUPPRESSES IT.
           IF TIT-CNT = 0 AND CARRO-CNT = 0
               MOVE SPACES TO H-TITLE
               MOVE PAGE-NO TO H-PAGE-ED
               MOVE "-PAGINA " TO H-TITLE(110:8)
               MOVE H-PAGE-ED TO H-TITLE(118:5)
               MOVE H-TITLE TO SYSUT2-REC
               IF PAGE-NO > 1
                   WRITE SYSUT2-REC AFTER ADVANCING PAGE END-WRITE
               ELSE
                   WRITE SYSUT2-REC END-WRITE
               END-IF
               ADD 1 TO LN-CNT END-ADD
           END-IF
           PERFORM VARYING TIK FROM 1 BY 1 UNTIL TIK > TIT-CNT
               IF TI-USED(TIK) = "Y"
      *            G1: RENDER PAGE-LEAD RECORD FIELD MAPS INTO H-TITLE
                   PERFORM 4265-RENDER-TIT
      *            M25: SHEET 6 - LINE 1 ALWAYS CARRIES THE USER
      *            IDENTIFICATION LEGEND AND "-PAGINA XXXXX" FROM
      *            COLUMN 110. SUPPRESSED WHEN CARRO IS CODED, WHICH
      *            TAKES OVER PAGE HANDLING.
                   IF TIK = 1 AND CARRO-CNT = 0
                       MOVE PAGE-NO TO H-PAGE-ED
                       MOVE "-PAGINA " TO H-TITLE(110:8)
                       MOVE H-PAGE-ED TO H-TITLE(118:5)
                   END-IF
                   MOVE H-TITLE TO SYSUT2-REC
      *            G8: EJECT TO A NEW PAGE AHEAD OF THE FIRST TITLE
      *            LINE OF PAGES AFTER THE FIRST (STANDARD ADVANCING
      *            PAGE -> FORM FEED, PORTABLE ACROSS MVS/RM)
                   IF PAGE-NO > 1 AND LN-CNT = 0
                       WRITE SYSUT2-REC AFTER ADVANCING PAGE
                       END-WRITE
                   ELSE
                       WRITE SYSUT2-REC END-WRITE
                   END-IF
                   ADD 1 TO LN-CNT END-ADD
                   IF TI-SP(TIK) > 1
                       COMPUTE N = TI-SP(TIK) - 1 END-COMPUTE
                       PERFORM 4295-N-BLANKS
                   END-IF
               END-IF
           END-PERFORM
           IF TIT-CNT > 0
               PERFORM 4295-ONE-BLANK
           END-IF.
      *
       4265-RENDER-TIT.
      *    G1: BUILD TITLE LINE TIK INTO H-TITLE, APPLYING ANY
      *    FIELD MAPS AGAINST THE CURRENT PAGE-LEAD RECORD (WS-SRC).
           MOVE TI-TEXT(TIK) TO H-TITLE
           PERFORM VARYING TIM FROM 1 BY 1 UNTIL TIM > TI-NMAP(TIK)
      *        TITLE MAPS READ THE PAGE-LEAD RECORD (SHEET 6: "UN
      *        CAMPO DEL ARCHIVO DE ENTRADA"), STAGED LIKE ANY OTHER
               MOVE TM-LEN(TIK, TIM) TO M
               MOVE SPACES TO WS-FBUF
               MOVE WS-SRC(TM-OFF(TIK, TIM):M) TO WS-FBUF(1:M)
               MOVE 1 TO L
               EVALUATE TM-CONV(TIK, TIM)
                   WHEN "MV"
                       MOVE WS-FBUF(L:M)
                           TO H-TITLE(TM-SO(TIK, TIM):M)
                   WHEN "UN"
                       MOVE "P" TO H-KEY2(1:1)
                       PERFORM 7000-DECODE-NUMERIC
                       COMPUTE EN-LEN = 2 * M - 1 END-COMPUTE
                       PERFORM 7150-VAL-TO-DIGITS
                       MOVE ED-OUT(1:EN-LEN)
                           TO H-TITLE(TM-SO(TIK, TIM):EN-LEN)
                   WHEN "ZD" WHEN "PD"
                       IF TM-CONV(TIK, TIM) = "PD"
                           MOVE "P" TO H-KEY2(1:1)
                       ELSE
                           MOVE "Z" TO H-KEY2(1:1)
                       END-IF
                       PERFORM 7000-DECODE-NUMERIC
                       MOVE TM-DIG(TIK, TIM) TO ED-P
                       IF ED-P = 0
                           MOVE 9 TO ED-P
                       END-IF
                       MOVE TM-DEC(TIK, TIM) TO J
                       PERFORM 7600-EDIT-NUM
                       MOVE ED-OUT(1:EN-LEN)
                           TO H-TITLE(TM-SO(TIK, TIM):EN-LEN)
               END-EVALUATE
           END-PERFORM.
      *
       4270-WRITE-HEX-LINE.
      *    HEX REPRESENTATION OF FIRST 66 PRINT COLUMNS (2X66=132)
           MOVE SPACES TO ED-DIGS
           MOVE SPACES TO SYSUT2-REC
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > 66
               MOVE H-LINE(J:1) TO TRT-CHAR
               PERFORM 7310-CHAR-TO-BYTE
               MOVE TRT-VAL TO HX-BYTE
               DIVIDE HX-BYTE BY 16 GIVING HX-HI REMAINDER HX-LO
               END-DIVIDE
               COMPUTE K = (J - 1) * 2 + 1 END-COMPUTE
               MOVE HEX-CHARS(HX-HI + 1:1) TO SYSUT2-REC(K:1)
               MOVE HEX-CHARS(HX-LO + 1:1) TO SYSUT2-REC(K + 1:1)
           END-PERFORM
           WRITE SYSUT2-REC END-WRITE
           ADD 1 TO LN-CNT END-ADD.
      *
       4295-N-BLANKS.
           PERFORM N TIMES
               PERFORM 4295-ONE-BLANK
           END-PERFORM.
      *
       4295-ONE-BLANK.
           MOVE SPACES TO SYSUT2-REC
           WRITE SYSUT2-REC END-WRITE
           ADD 1 TO LN-CNT END-ADD.
      *
      *================================================================
      * 5000 END-OF-FILE: FLUSH BLOCK, FIRE REMAINING + F BREAKS
      *================================================================
       5000-FINAL.
           IF G-ACTIVE = "Y" AND G-HAVE = "Y"
               PERFORM 3400-FLUSH-BLOCK
           END-IF
           IF MODE-OSLISTA AND CORTE-CNT > 0
               PERFORM VARYING IX-LVL FROM CORTE-CNT BY -1
                   UNTIL IX-LVL < 1
                   IF CO-TYPE(IX-LVL) NOT = "F"
                       IF CO-COUNT(IX-LVL) > 0
                           PERFORM 4300-DO-BREAK-LEVEL
                       END-IF
                   END-IF
               END-PERFORM
               PERFORM VARYING IX-LVL FROM 1 BY 1
                   UNTIL IX-LVL > CORTE-CNT
                   IF CO-TYPE(IX-LVL) = "F"
      *                GRAND-TOTAL CANT = UNITS PROCESSED, NOT RAW
      *                RECORDS READ (FILTERED ONES DO NOT COUNT)
                       MOVE PROC-CNT TO CO-COUNT(IX-LVL)
                       PERFORM 4300-DO-BREAK-LEVEL
                   END-IF
               END-PERFORM
           END-IF.
      *
      *================================================================
      * 7000 DECODE NUMERIC FIELD WS-FBUF(L:M), FORMAT IN H-KEY2(1:1)
      * -> DN-VAL (SIGNED). PITFALL #2: NIBBLE ARITHMETIC ONLY.
      *================================================================
       7000-DECODE-NUMERIC.
           MOVE 0 TO DN-VAL
           MOVE "N" TO DN-NEG
           EVALUATE H-KEY2(1:1)
               WHEN "Z"
                   PERFORM VARYING N FROM L BY 1
                       UNTIL N > L + M - 1
                       IF WS-FBUF(N:1) >= "0" AND WS-FBUF(N:1) <= "9"
                           MOVE 0 TO DN-DIGIT
                           PERFORM 7050-DIGIT-OF
                           MULTIPLY 10 BY DN-VAL END-MULTIPLY
                           ADD DN-DIGIT TO DN-VAL END-ADD
                       ELSE
      *                    G4: ZONED OVERPUNCH SIGN ON ANY BYTE
                           PERFORM 7060-ZONE-OVERPUNCH
                           MULTIPLY 10 BY DN-VAL END-MULTIPLY
                           ADD DN-DIGIT TO DN-VAL END-ADD
                       END-IF
                   END-PERFORM
               WHEN "P" WHEN "S"
                   PERFORM VARYING N FROM L BY 1
                       UNTIL N > L + M - 1
                       MOVE WS-FBUF(N:1) TO TRT-CHAR
                       PERFORM 7310-CHAR-TO-BYTE
                       MOVE TRT-VAL TO DN-BYTE
                       DIVIDE DN-BYTE BY 16
                           GIVING DN-HI REMAINDER DN-LO END-DIVIDE
                       IF N = L + M - 1 AND H-KEY2(1:1) = "P"
      *                    LAST BYTE: HIGH NIBBLE DIGIT + SIGN NIBBLE
                           MULTIPLY 10 BY DN-VAL END-MULTIPLY
                           ADD DN-HI TO DN-VAL END-ADD
                           IF DN-LO = 13
                               MOVE "Y" TO DN-NEG
                           END-IF
                       ELSE
                           MULTIPLY 100 BY DN-VAL END-MULTIPLY
                           MULTIPLY 10 BY DN-HI END-MULTIPLY
                           ADD DN-HI TO DN-VAL END-ADD
                           ADD DN-LO TO DN-VAL END-ADD
                       END-IF
                   END-PERFORM
               WHEN "B"
                   MOVE 0 TO DN-FIRST
                   PERFORM VARYING N FROM L BY 1
                       UNTIL N > L + M - 1
                       MOVE WS-FBUF(N:1) TO TRT-CHAR
                       PERFORM 7310-CHAR-TO-BYTE
                       IF N = L
                           MOVE TRT-VAL TO DN-FIRST
                       END-IF
                       MULTIPLY 256 BY DN-VAL END-MULTIPLY
                       ADD TRT-VAL TO DN-VAL END-ADD
                   END-PERFORM
      *            G4: TWO'S-COMPLEMENT - HIGH BIT OF FIRST BYTE SET
      *            MEANS NEGATIVE; SUBTRACT 256^M
                   IF DN-FIRST >= 128
                       MOVE 1 TO DN-POW
                       PERFORM M TIMES
                           MULTIPLY 256 BY DN-POW END-MULTIPLY
                       END-PERFORM
                       SUBTRACT DN-POW FROM DN-VAL END-SUBTRACT
                   END-IF
           END-EVALUATE
           IF DN-NEG = "Y"
               COMPUTE DN-VAL = 0 - DN-VAL END-COMPUTE
           END-IF.
      *
       7050-DIGIT-OF.
           PERFORM VARYING K FROM 1 BY 1 UNTIL K > 10
               IF WS-FBUF(N:1) = HEX-CHARS(K:1)
                   COMPUTE DN-DIGIT = K - 1 END-COMPUTE
                   EXIT PERFORM
               END-IF
           END-PERFORM.
      *
       7060-ZONE-OVERPUNCH.
      *    G4: DECODE A ZONED OVERPUNCH BYTE IN WS-FBUF(N:1).
      *    POSITIVE SET -> DIGIT, NEGATIVE SET -> DIGIT + DN-NEG.
      *    UNRECOGNIZED -> DIGIT 0 (LEGACY ND-STYLE TOLERANCE).
           MOVE 0 TO DN-DIGIT
           PERFORM VARYING K FROM 1 BY 1 UNTIL K > 10
               IF WS-FBUF(N:1) = OVP-CH(1, K)
                   COMPUTE DN-DIGIT = K - 1 END-COMPUTE
               END-IF
               IF WS-FBUF(N:1) = OVP-CH(2, K)
                   COMPUTE DN-DIGIT = K - 1 END-COMPUTE
                   MOVE "Y" TO DN-NEG
               END-IF
           END-PERFORM.
      *
      *================================================================
      * 7100 ENCODE DN-VAL INTO FORMAT FT-OUTFMT(I) -> ED-OUT/EN-LEN
      *================================================================
       7100-ENCODE-NUMERIC.
           MOVE SPACES TO EN-STR
           MOVE 0 TO EN-LEN
           IF DN-VAL < 0
               MOVE "Y" TO DN-NEG
               COMPUTE DN-VAL = 0 - DN-VAL END-COMPUTE
           ELSE
               MOVE "N" TO DN-NEG
           END-IF
      *    EXTRACT SIGNIFICANT DIGITS RIGHT TO LEFT INTO EN-STR
           MOVE 0 TO K
           PERFORM UNTIL DN-VAL = 0 OR K >= 18
               DIVIDE DN-VAL BY 10 GIVING DN-VAL
                   REMAINDER DN-DIGIT END-DIVIDE
               ADD 1 TO K END-ADD
               MOVE HEX-CHARS(DN-DIGIT + 1:1) TO EN-STR(K:1)
           END-PERFORM
           IF K = 0
               MOVE 1 TO K
               MOVE "0" TO EN-STR(1:1)
           END-IF
      *    G6: CARD-SPECIFIED OUTPUT LENGTH -> LEFT-PAD DIGIT COUNT.
      *    NEEDED DIGITS: Z=LEN, P=2*LEN-1, S=2*LEN (LEN IN BYTES).
           IF FT-OUTLEN(I) > 0
               EVALUATE FT-OUTFMT(I)
                   WHEN "Z"
                       MOVE FT-OUTLEN(I) TO J
                   WHEN "P"
                       COMPUTE J = 2 * FT-OUTLEN(I) - 1 END-COMPUTE
                   WHEN "S"
                       COMPUTE J = 2 * FT-OUTLEN(I) END-COMPUTE
                   WHEN OTHER
                       MOVE K TO J
               END-EVALUATE
               PERFORM UNTIL K >= J
                   ADD 1 TO K END-ADD
                   MOVE "0" TO EN-STR(K:1)
               END-PERFORM
           END-IF
      *    EN-STR NOW HOLDS DIGITS REVERSED, K = COUNT
           EVALUATE FT-OUTFMT(I)
               WHEN "Z"
                   MOVE K TO EN-LEN
                   PERFORM VARYING J FROM 1 BY 1 UNTIL J > K
                       COMPUTE N = K - J + 1 END-COMPUTE
                       MOVE EN-STR(N:1) TO ED-OUT(J:1)
                   END-PERFORM
               WHEN "P" WHEN "S"
                   PERFORM 7120-ENCODE-PACKED
               WHEN "B"
                   PERFORM 7130-ENCODE-BINARY
           END-EVALUATE.
      *
       7120-ENCODE-PACKED.
      *    P: DIGITS + SIGN NIBBLE (C POS / D NEG). S: NO SIGN.
           IF FT-OUTFMT(I) = "P"
               COMPUTE EN-LEN = (K + 2) / 2 END-COMPUTE
           ELSE
               COMPUTE EN-LEN = (K + 1) / 2 END-COMPUTE
           END-IF
           MOVE 0 TO M
      *    BUILD NIBBLE STREAM LEFT TO RIGHT INTO ED-OUT
           COMPUTE N = EN-LEN * 2 END-COMPUTE
           IF FT-OUTFMT(I) = "P"
               SUBTRACT 1 FROM N END-SUBTRACT
           END-IF
      *    N = NUMBER OF DIGIT NIBBLES AVAILABLE
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > EN-LEN
               MOVE 0 TO DN-HI DN-LO
               MULTIPLY J BY 2 GIVING L END-MULTIPLY
               SUBTRACT 2 FROM L END-SUBTRACT
               SUBTRACT L FROM N GIVING L END-SUBTRACT
               IF L >= 1 AND L <= K
                   PERFORM 7125-NIB-OF-L
                   MOVE DN-DIGIT TO DN-HI
               END-IF
               MULTIPLY J BY 2 GIVING L END-MULTIPLY
               SUBTRACT 1 FROM L END-SUBTRACT
               SUBTRACT L FROM N GIVING L END-SUBTRACT
               IF J = EN-LEN AND FT-OUTFMT(I) = "P"
                   IF DN-NEG = "Y"
                       MOVE 13 TO DN-LO
                   ELSE
                       MOVE 12 TO DN-LO
                   END-IF
               ELSE
                   IF L >= 1 AND L <= K
                       PERFORM 7125-NIB-OF-L
                       MOVE DN-DIGIT TO DN-LO
                   END-IF
               END-IF
               MULTIPLY 16 BY DN-HI GIVING DN-BYTE END-MULTIPLY
               ADD DN-LO TO DN-BYTE END-ADD
               PERFORM 7300-BYTE-TO-CHAR
               MOVE TRT-CHAR TO ED-OUT(J:1)
           END-PERFORM.
      *
       7125-NIB-OF-L.
      *    DN-DIGIT = NUMERIC VALUE OF REVERSED DIGIT STRING AT L
           MOVE 0 TO DN-DIGIT
           PERFORM VARYING DN-BYTE FROM 1 BY 1 UNTIL DN-BYTE > 10
               IF EN-STR(L:1) = HEX-CHARS(DN-BYTE:1)
                   COMPUTE DN-DIGIT = DN-BYTE - 1 END-COMPUTE
                   EXIT PERFORM
               END-IF
           END-PERFORM.
      *
       7130-ENCODE-BINARY.
      *    G6: HONOR CARD-SPECIFIED BYTE WIDTH (DEFAULT 4)
           IF FT-OUTLEN(I) > 0
               MOVE FT-OUTLEN(I) TO EN-LEN
           ELSE
               MOVE 4 TO EN-LEN
           END-IF
      *    REBUILD VALUE FROM REVERSED DIGITS
           MOVE 0 TO DN-VAL
           PERFORM VARYING J FROM K BY -1 UNTIL J < 1
               PERFORM 7135-ACC-DIGIT
           END-PERFORM
           PERFORM VARYING J FROM EN-LEN BY -1 UNTIL J < 1
               DIVIDE DN-VAL BY 256 GIVING DN-VAL
                   REMAINDER DN-BYTE END-DIVIDE
               PERFORM 7300-BYTE-TO-CHAR
               MOVE TRT-CHAR TO ED-OUT(J:1)
           END-PERFORM.
      *
       7135-ACC-DIGIT.
           MOVE J TO L
           PERFORM 7125-NIB-OF-L
           MULTIPLY 10 BY DN-VAL END-MULTIPLY
           ADD DN-DIGIT TO DN-VAL END-ADD.
      *
       7150-VAL-TO-DIGITS.
      *    DN-VAL -> EN-LEN ZERO-PADDED DISPLAY DIGITS IN ED-OUT
           IF DN-VAL < 0
               COMPUTE DN-VAL = 0 - DN-VAL END-COMPUTE
           END-IF
           PERFORM VARYING J FROM EN-LEN BY -1 UNTIL J < 1
               DIVIDE DN-VAL BY 10 GIVING DN-VAL
                   REMAINDER DN-DIGIT END-DIVIDE
               MOVE HEX-CHARS(DN-DIGIT + 1:1) TO ED-OUT(J:1)
           END-PERFORM.
      *
      *================================================================
      * 7200 MOD-10 CHECK DIGIT (zDVy): WEIGHTS 2,1 RIGHT-TO-LEFT,
      * PRODUCT>9 -> SUBTRACT 9, DV = (10 - SUM MOD 10) MOD 10.
      * OUTPUT = INPUT DIGITS + DV APPENDED.
      *================================================================
       7200-MOD10.
           MOVE 0 TO M10-SUM
           MOVE 2 TO M10-W
           PERFORM VARYING J FROM M BY -1 UNTIL J < 1
               COMPUTE N = L + J - 1 END-COMPUTE
               MOVE 0 TO DN-DIGIT
               PERFORM VARYING K FROM 1 BY 1 UNTIL K > 10
                   IF WS-FBUF(N:1) = HEX-CHARS(K:1)
                       COMPUTE DN-DIGIT = K - 1 END-COMPUTE
                       EXIT PERFORM
                   END-IF
               END-PERFORM
               COMPUTE M10-PROD = DN-DIGIT * M10-W END-COMPUTE
               IF M10-PROD > 9
                   SUBTRACT 9 FROM M10-PROD END-SUBTRACT
               END-IF
               ADD M10-PROD TO M10-SUM END-ADD
               IF M10-W = 2
                   MOVE 1 TO M10-W
               ELSE
                   MOVE 2 TO M10-W
               END-IF
           END-PERFORM
           DIVIDE M10-SUM BY 10 GIVING M10-PROD
               REMAINDER M10-REM END-DIVIDE
           IF M10-REM = 0
               MOVE 0 TO M10-DV
           ELSE
               COMPUTE M10-DV = 10 - M10-REM END-COMPUTE
           END-IF
           MOVE WS-FBUF(L:M) TO ED-OUT(1:M)
           MOVE HEX-CHARS(M10-DV + 1:1) TO ED-OUT(M + 1:1)
           COMPUTE EN-LEN = M + 1 END-COMPUTE.
      *
      *================================================================
      * 7300/7310 RAW BYTE <-> CHARACTER (NATIVE COLLATING ORDINALS)
      *================================================================
       7300-BYTE-TO-CHAR.
      *    G9: BIG-ENDIAN REDEFINE INSTEAD OF FUNCTION CHAR
           MOVE DN-BYTE TO BC-NUM
           MOVE BC-LO TO TRT-CHAR.
      *
       7310-CHAR-TO-BYTE.
      *    G9: BIG-ENDIAN REDEFINE INSTEAD OF FUNCTION ORD
           MOVE 0 TO BC-NUM
           MOVE TRT-CHAR TO BC-LO
           MOVE BC-NUM TO TRT-VAL.
      *
       7700-CHAR-TO-DIGIT.
      *    G9: TRT-CHAR ("0"-"9") -> DN-DIGIT, TABLE LOOKUP
      *    INSTEAD OF FUNCTION NUMVAL. NON-DIGITS YIELD 0.
           MOVE 0 TO DN-DIGIT
           PERFORM VARYING BC-NUM FROM 1 BY 1 UNTIL BC-NUM > 10
               IF TRT-CHAR = HEX-CHARS(BC-NUM:1)
                   COMPUTE DN-DIGIT = BC-NUM - 1 END-COMPUTE
               END-IF
           END-PERFORM.
      *
       7710-PAIR-TO-NUM.
      *    G9: TWO DIGIT CHARS IN H-KEY2(1:2) -> DN-DIGIT (0-99)
           MOVE H-KEY2(1:1) TO TRT-CHAR
           PERFORM 7700-CHAR-TO-DIGIT
           MOVE DN-DIGIT TO DN-BYTE
           MOVE H-KEY2(2:1) TO TRT-CHAR
           PERFORM 7700-CHAR-TO-DIGIT
           MULTIPLY 10 BY DN-BYTE END-MULTIPLY
           ADD DN-BYTE TO DN-DIGIT END-ADD.
      *
       7400-HEX-EXPAND.
      *    WS-FBUF(L:M) -> 2M HEX CHARACTERS IN ED-OUT
           PERFORM VARYING J FROM 1 BY 1 UNTIL J > M
               COMPUTE N = L + J - 1 END-COMPUTE
               MOVE WS-FBUF(N:1) TO TRT-CHAR
               PERFORM 7310-CHAR-TO-BYTE
               MOVE TRT-VAL TO HX-BYTE
               DIVIDE HX-BYTE BY 16 GIVING HX-HI REMAINDER HX-LO
               END-DIVIDE
               COMPUTE K = J * 2 - 1 END-COMPUTE
               MOVE HEX-CHARS(HX-HI + 1:1) TO ED-OUT(K:1)
               MOVE HEX-CHARS(HX-LO + 1:1) TO ED-OUT(K + 1:1)
           END-PERFORM
           COMPUTE EN-LEN = M * 2 END-COMPUTE.
      *
      *================================================================
      * 7500/7510 SYSTEM DATE: FA (18 ALPHA) / FN (8 NUMERIC)
      *================================================================
       7500-DATE-ALPHA.
           MOVE SPACES TO ED-OUT
           PERFORM 7520-GET-DATE
      *    ED-DIGS(1:8) = YYYYMMDD
           MOVE ED-DIGS(7:2) TO ED-OUT(1:2)
           MOVE SPACE TO ED-OUT(3:1)
           EVALUATE ED-DIGS(5:2)
               WHEN "01" MOVE "ENERO"      TO ED-OUT(4:9)
               WHEN "02" MOVE "FEBRERO"    TO ED-OUT(4:9)
               WHEN "03" MOVE "MARZO"      TO ED-OUT(4:9)
               WHEN "04" MOVE "ABRIL"      TO ED-OUT(4:9)
               WHEN "05" MOVE "MAYO"       TO ED-OUT(4:9)
               WHEN "06" MOVE "JUNIO"      TO ED-OUT(4:9)
               WHEN "07" MOVE "JULIO"      TO ED-OUT(4:9)
               WHEN "08" MOVE "AGOSTO"     TO ED-OUT(4:9)
               WHEN "09" MOVE "SETIEMBRE"  TO ED-OUT(4:9)
               WHEN "10" MOVE "OCTUBRE"    TO ED-OUT(4:9)
               WHEN "11" MOVE "NOVIEMBRE"  TO ED-OUT(4:9)
               WHEN "12" MOVE "DICIEMBRE"  TO ED-OUT(4:9)
           END-EVALUATE
           MOVE ED-DIGS(1:4) TO ED-OUT(14:4)
           MOVE 18 TO EN-LEN.
      *
       7510-DATE-NUM.
           PERFORM 7520-GET-DATE
           MOVE SPACES TO ED-OUT
           MOVE ED-DIGS(7:2) TO ED-OUT(1:2)
           MOVE "/" TO ED-OUT(3:1)
           MOVE ED-DIGS(5:2) TO ED-OUT(4:2)
           MOVE "/" TO ED-OUT(6:1)
           MOVE ED-DIGS(3:2) TO ED-OUT(7:2)
           MOVE 8 TO EN-LEN.
      *
       7520-GET-DATE.
      *    G9: ACCEPT FROM DATE (STANDARD COBOL-85, YYMMDD) WITH
      *    CENTURY WINDOW -> ED-DIGS(1:8) = YYYYMMDD.
      *    REPLACES FUNCTION CURRENT-DATE.
           ACCEPT DT-YMD FROM DATE
           IF DT-YY < "50"
               MOVE "20" TO DT-CC
           ELSE
               MOVE "19" TO DT-CC
           END-IF
           MOVE SPACES TO ED-DIGS
           MOVE DT-CC TO ED-DIGS(1:2)
           MOVE DT-YY TO ED-DIGS(3:2)
           MOVE DT-MM TO ED-DIGS(5:2)
           MOVE DT-DD TO ED-DIGS(7:2).
      *
      *================================================================
      * 7600 EDIT DN-VAL WITH ED-P TOTAL DIGITS, J DECIMALS
      * DECIMAL COMMA (ARGENTINE CONVENTION), LEADING ZERO SUPPRESS
      *================================================================
       7600-EDIT-NUM.
           MOVE SPACES TO ED-OUT ED-DIGS
           IF DN-VAL < 0
               MOVE "Y" TO DN-NEG
               COMPUTE DN-VAL = 0 - DN-VAL END-COMPUTE
           ELSE
               MOVE "N" TO DN-NEG
           END-IF
      *    EXTRACT ED-P DIGITS RIGHT-JUSTIFIED INTO ED-DIGS
           PERFORM VARYING ED-I FROM ED-P BY -1 UNTIL ED-I < 1
               DIVIDE DN-VAL BY 10 GIVING DN-VAL
                   REMAINDER DN-DIGIT END-DIVIDE
               MOVE HEX-CHARS(DN-DIGIT + 1:1) TO ED-DIGS(ED-I:1)
           END-PERFORM
      *    LAYOUT: INTEGER PART (ZERO-SUPPRESSED) [, DECIMALS]
           COMPUTE ED-M = ED-P - J END-COMPUTE
           MOVE 0 TO ED-N
           MOVE "N" TO H-OUT-TRUE
           PERFORM VARYING ED-I FROM 1 BY 1 UNTIL ED-I > ED-M
               ADD 1 TO ED-N END-ADD
               IF ED-DIGS(ED-I:1) = "0" AND H-OUT-TRUE = "N"
                  AND ED-I < ED-M
                   MOVE SPACE TO ED-OUT(ED-N:1)
               ELSE
                   MOVE ED-DIGS(ED-I:1) TO ED-OUT(ED-N:1)
                   MOVE "Y" TO H-OUT-TRUE
               END-IF
           END-PERFORM
           IF J > 0
               ADD 1 TO ED-N END-ADD
               MOVE "," TO ED-OUT(ED-N:1)
               COMPUTE ED-I = ED-M + 1 END-COMPUTE
               PERFORM VARYING ED-I FROM ED-I BY 1 UNTIL ED-I > ED-P
                   ADD 1 TO ED-N END-ADD
                   MOVE ED-DIGS(ED-I:1) TO ED-OUT(ED-N:1)
               END-PERFORM
           END-IF
           IF DN-NEG = "Y"
               PERFORM VARYING ED-I FROM 1 BY 1 UNTIL ED-I > ED-N
                   IF ED-OUT(ED-I:1) NOT = SPACE
                       IF ED-I > 1
                           MOVE "-" TO ED-OUT(ED-I - 1:1)
                       END-IF
                       EXIT PERFORM
                   END-IF
               END-PERFORM
           END-IF
           MOVE ED-N TO EN-LEN.
      *
      *================================================================
      * 8000/9XXX HOUSEKEEPING
      *================================================================
       8000-CLOSE-ALL.
           CLOSE SYSUT1-F SYSUT2-F
           IF SW-UT3-OPEN = "Y"
               CLOSE SYSUT3-F
           END-IF
           IF SW-UT6-OPEN = "Y"
               CLOSE SYSUT6-F
           END-IF
           IF MODE-OSGENER
               CLOSE SYSUT4-F SYSUT5-F SYSLIST-F
           END-IF
           CLOSE SYSPRINT-F.
      *
       9100-PRT-BANNER.
           MOVE SPACES TO SYSPRINT-REC
           STRING "SCD 1/84 ENGINE - MODE: " WS-MODE
               DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
           WRITE SYSPRINT-REC END-WRITE
           MOVE "CONTROL CARDS (SYSIN ECHO):" TO SYSPRINT-REC
           WRITE SYSPRINT-REC END-WRITE.
      *
       9200-PRT-SUMMARY.
           MOVE SPACES TO SYSPRINT-REC
           STRING "RECORDS READ:    " REC-NO
               DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
           WRITE SYSPRINT-REC END-WRITE
           MOVE SPACES TO SYSPRINT-REC
           STRING "RECORDS WRITTEN: " OUT-CNT
               DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
           WRITE SYSPRINT-REC END-WRITE
           IF MODE-OSGENER
               MOVE SPACES TO SYSPRINT-REC
               STRING "SYSUT4 WRITTEN:  " OUT4-CNT
                   DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
               WRITE SYSPRINT-REC END-WRITE
               MOVE SPACES TO SYSPRINT-REC
               STRING "ORPHAN BATCHES:  " ORPHAN-CNT
                   DELIMITED BY SIZE INTO SYSPRINT-REC END-STRING
               WRITE SYSPRINT-REC END-WRITE
           END-IF.
