# OSLISTA & OSGENER — User Guide

*Reference manual for programmers using the SCD 1/84 data-set utilities (modernized engine). Verified against the genuine SCD publication in `manual/OSLSGEN.txt` — every example below is replayed against the real binaries by `tests/manual_examples.sh`.*

---

## 1. What These Utilities Are

Both utilities operate on **non-VSAM** sequential (SEQ) or indexed-sequential (IS) data sets, fixed or variable record format (SPANNED not supported). They are driven entirely by 80-column control cards read from SYSIN — no compiled program changes are needed for new jobs. In many cases they replace writing a COBOL program.

| Utility | Purpose | Typical uses |
|---|---|---|
| **OSLISTA** | Print listings/reports from a data set | Field selection, arithmetic totals, external table decoding, control-break subtotals, formatted headings, printer carriage control |
| **OSGENER** | Generate/transform data sets | Conditional record copy, multi-card batch consolidation with consistency checks, Mod-10 check digit generation, two-file match/merge, record reformatting |

---

## 2. Files (DD Statements)

### 2.1 Inputs

| DDNAME | Required | Used by | Content |
|---|---|---|---|
| `SYSIN` | Yes | both | 80-column control cards |
| `SYSUT1` | Yes | both | Main input data set (SEQ or IS) |
| `SYSUT3` | No | both | Secondary master, for key match/merge (`CLAVE`, `S`-prefixed offsets) |
| `SYSUT6` | No | OSGENER | Search/lookup records ("pesquisas") for `PESQIN`/`PESQOUT` |
| *(user DD)* | No | both | External translation tables loaded by `CONV DD=ddname` |

### 2.2 Outputs

| DDNAME | Required | Used by | Content |
|---|---|---|---|
| `SYSUT2` | Yes | both | Main result data set |
| `SYSUT4` | No | OSGENER | Secondary output — receives fields whose output offset carries the `S` prefix |
| `SYSUT5` | No | OSGENER | Orphan/reject workspace: records from batches that collapsed under `CODIG` presence rules |
| `SYSPRINT` | Yes | both | Operation log: echo of SYSIN cards, error frames; OSGENER also logs the **first 5 successfully processed records** for audit |
| `SYSLIST` | No | OSGENER | Detailed inconsistency report (data-type corruption, date failures, batch-drop notices, custom error labels) |

> ⚠ Two source documents disagree on whether INCON data failures also route records to SYSUT5, or only CODIG batch collapses do (corrected records continuing normally). See "Open spec conflicts" in `docs/plan.md` (D0.1); this guide follows the engineering spec: **SYSUT5 = CODIG collapses only**.

### 2.3 Job Card / JCL Skeleton (MVS)

```jcl
//SCDJOB01 JOB (ACCT),'RUN OSGENER',CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//STEP01   EXEC PGM=OSGENER              <- or PGM=OSLISTA (max 8 chars)
//SYSPRINT DD SYSOUT=*
//SYSLIST  DD SYSOUT=*
//SYSUT1   DD DSN=YOUR.INPUT.MASTER,DISP=SHR
//SYSUT3   DD DSN=YOUR.SECOND.MASTER,DISP=SHR      <- optional
//SYSUT6   DD DSN=YOUR.LOOKUP.KEYS,DISP=SHR        <- optional, OSGENER
//DDTABLE  DD DSN=YOUR.CONV.TABLE,DISP=SHR         <- one per CONV card
//SYSUT2   DD DSN=YOUR.OUTPUT.MASTER,
//            DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(10,5),RLSE),
//            DCB=(RECFM=FB,LRECL=150,BLKSIZE=0)
//SYSUT5   DD DSN=YOUR.REJECTS,DISP=(NEW,CATLG,DELETE),
//            SPACE=(TRK,(5,5),RLSE),DCB=(RECFM=FB,LRECL=80,BLKSIZE=0)
//SYSIN    DD *
  ...control cards...
/*
```

### 2.4 Open Systems (Linux/Windows) Execution

DDNAMEs are resolved through **environment variables** of the same name:

```sh
export SYSUT1=./datasets/sysut1.dat
export SYSUT2=./datasets/sysut2.dat
export SYSIN=./datasets/sysin_gener.dat
export SYSPRINT=./logs/sysprint.log
export SYSLIST=./logs/syslist.log
./bin/OSGENER          # see run_sim.sh for a complete example
```

---

## 3. Control Card Rules (SYSIN)

- Cards are 80 columns.
- **Operation code must begin in column 1.**
- Operands follow, separated from the op-code and each other by **at least one blank**; individual parameters within an operand group are comma-separated. Keyword operands use `KEYWORD=value`.
- Literals go in single quotes: `'ARG'`. Hex literals: `X'C1C2'`.
- A statement that does not fit on one card continues on a **new card repeating the operation code** — **except `TIT`**, whose literal may simply be opened on one card and closed on the next.
- Most cards take several **`/`-separated operand groups**, and *every* group is executed, in the order written: `FIELD 1,3,M,1/4,3,M,10` performs two moves, `CORTE 1,2/4,8/62,5` declares three break levels.
- Offsets (`Si`, `so`) are 1-based byte positions in the record. Prefixing an *input* offset with `S` (e.g. `S12`) addresses **SYSUT3** instead of SYSUT1 — valid on `RCIN`/`RCOUT`, `COND`, `ACUM`, `FIELD`, `CONV` and `INCON`. In OSGENER, prefixing an *output* offset with `S` (e.g. `S37`) writes that field to **SYSUT4** instead of SYSUT2.
- Input and output records may be up to **32760 bytes** (largest non-spanned QSAM record); card offsets may address up to 99999.

### 3.1 Which Command Runs Where

| Command | OSLISTA | OSGENER |
|---|:---:|:---:|
| `RCIN` / `RCOUT`, `CONDx`, `ACUMy[x]`, `FIELD[x]`, `CONV[x]`, `CLAVE` | ✔ | ✔ |
| `TIT` | ✔ *(TIT1–TIT9, page headings)* | ✔ *(one line, SYSLIST error heading — §6.6)* |
| `PRINT`, `CARRO`, `CORTE`, `IMCOR` | ✔ | — |
| `COPY`, `GENER`, `CODIG`, `INCON`, `PESQIN` / `PESQOUT` | — | ✔ |

A command used in the wrong personality is rejected at parse time with `… NOT VALID IN … MODE`.

### 3.2 Capacity Limits

| Item | Limit |
|---|---|
| RCIN/RCOUT conditions | 150 |
| FIELD operations | 125 |
| Accumulators (ACUM) | 9 |
| Logical indicators (COND) | 8 |
| CONV translation tables | 20 |
| CORTE break levels | 10 |
| GENER card codes / slots | 10 (800-byte block, 10 × 80) |
| ACUM operations per card | 10 |
| COPY ranges | 10 |
| TIT heading lines (OSLISTA) | 9 |
| IMCOR fields per break | 10 |
| INCON rules | 50 |
| Print lines per record (OSLISTA) | 9 |
| CONV rows per table | 500 |
| Record length (SYSUT1/2/3/4) | 32760 |

---

## 4. Record-Level Commands

*(§4.1–4.5 are common to both utilities. §4.6 `CORTE` and §4.7 `IMCOR` are **OSLISTA-only** — control breaks belong to the report writer — but are documented here because they build on `ACUM` and the edit masks above. See the matrix in §3.1.)*

### 4.1 `RCIN` / `RCOUT` — Record Filtering

```
RCIN  Si, op, 'literal'  [.AND. | .Y. | .OR. | .O. | / ...]
RCIN  op, cuenta         ...                       (record-count form)
RCOUT ...                                          (same operand syntax)
```

- `RCIN` **includes** records matching the condition; `RCOUT` **excludes** them.
- `Si` — input offset (prefix `S` → SYSUT3). Length is taken from the literal.
- `op` — `EQ`, `NE`, `LT`, `GT`, `LE`, `GE`, `NL` (not low), `NH` (not high). **Omitting it entirely assumes `EQ`**: `27,,'9'` means "column 27 equals `'9'`".
- **Count form** — with no offset, `op,cuenta` compares the **running input record number** against a number: `RCOUT LT,8000` skips the first 7999 records.
- Literals may be character `'...'` or hex `X'...'`.

**How the connectors group** — a card is a **disjunction of runs**:

- `/` closes the current run and opens a new one; runs are OR-ed together.
- `.AND.`/`.Y.` and `.OR.`/`.O.` chain conditions *inside* one run, and the two families **may not be mixed within a run** (a card error). Since `/` already means OR, that restriction never blocks anything you need.

```
RCIN GT,4000.AND.LT,5000/GT,6000.Y.LT,10000
     -> (rec > 4000 AND rec < 5000) OR (rec > 6000 AND rec < 10000)
```

Example — keep only Argentine records from branches above 0500:

```
RCIN 1,EQ,'ARG'.Y.4,GT,'0500'
```

### 4.2 `CONDx` — Logical Indicators (x = 1..8)

```
COND1 Si, op, 'literal'  [.AND. | .Y. | .OR. | .O. | / ...]
COND6 op, cuenta         ...
```

A `CONDx` card carries a whole **condition group**, with exactly the operand syntax, `EQ` default, count form and run grouping described for `RCIN`/`RCOUT` above. If the group holds, indicator *x* is set ON **for the remainder of the current record's processing**. Several `CONDx` cards may carry the same *x*; the indicator is set if any of them is true. Indicators gate `FIELDx`, `ACUMyx` and `CONVx` execution (see below).

```
COND1 4,,'10'.Y.28,LT,'260'/4,,'20'.Y.29,LT,'260'
```

### 4.3 `ACUM` — Accumulators (9 double-precision decimal registers)

```
ACUMy[x]  op, format, Si, long   / ...     (up to 10 operations per card)
ACUMy[x]  op, num                / ...     (numeric literal operand)
```

- `y` — accumulator number 1–9. Optional `x` — only execute when COND indicator *x* is ON.
- `op` — `+`, `-`, `*`, `/`. Operations apply left to right, in card order.
- `format` — how the input field is stored: `P` packed signed (COMP-3), `Z` zoned decimal, `S` packed unsigned, `B` binary. A trailing digit gives implied decimals (`Z2` = two decimal places). `Si` may be `S`-prefixed for SYSUT3.
- **Literal operand** — write the number directly in the operand position: `*,2000`, `+,50`, `/,100`. No format letter.
- Implicit decimal points are aligned per the card configuration.

```
ACUM1 +,Z,400,9/+,50//,100      (field + 50) / 100
```
- **Division by zero never abends**: the accumulator is forced to 0, a warning is written to SYSPRINT, and processing continues.

### 4.4 `FIELD` — Field Selection, Conversion & Editing

```
FIELD[x]  Si, long, conv, so [, long]   / ...     input field
FIELD[x]  Ay, conv, so [, long]         / ...     accumulator y
FIELD[x]  AN, formato, so, long         / ...     written-record counter
FIELD[x]  'literal', so                 / ...     literal, transferred as-is
FIELD[x]  'literal', CL, so, long       / ...     fill so..so+long-1 with it
FIELD     EC=xy                                   listing spacing override
```

- Optional `x` (1–8): the operation runs **only if COND indicator x is ON**; otherwise the output area keeps spaces/previous content.
- **Every `/`-separated group on the card is executed, in the order written.**
- `Si` — input offset; prefix `S` reads **SYSUT3**. `conv` may be omitted entirely (`20,4,,10`), which means `MOVE`.
- `Ay` — take the value from accumulator *y*. `AN` — take the count of records written so far. For either, a bare format letter (`B`/`P`/`Z`/`S`) encodes the value in that format; an edit mask (`ZxDy`/`PxDy`) formats it for printing instead.
- `so` — output offset. OSLISTA: 1–132 on any of **nine print lines per record** — no prefix = line 1, then `Snnn` `Tnnn` `Cnnn` `Qnnn` `Xnnn` `Pnnn` `Onnn` `Nnnn` for lines 2–9. OSGENER: prefix `S` diverts the field to SYSUT4. The optional trailing `,long` sets the output width.
- `EC=xy` — override listing spacing for the run: *x* between lines of one record, *y* between records (same meaning as `PRINT SP=`/`SR=`).
- Maximum input length depends on the conversion: `UNPK` 8, `HEXA` 64, `MOVE` 132 (OSLISTA).

Conversion types (`conv`):

| Code | Effect | Output length |
|---|---|---|
| `MOVE` / `M` | Direct move (default) | `long` |
| `UNPK` / `U` | Unpack COMP-3 to display digits; sign nibble C/E/F = +, D = − | `2 × long − 1` |
| `HEXA` / `H` | Show raw bytes as hex characters | `2 × long` |
| `ZxDy` / `PxDy` | Numeric edit masks — zoned (`Z`) or packed (`P`) input, *x* total digits, *y* decimals | per mask |
| `'lit', CL` | Padding/initializer: fill the output area with the literal (`'lit',CL,so,long`) | `long` |
| `xDVy` | **Mod-10 check digit**: weights 2,1,2,1… right-to-left; product > 9 → subtract 9; digit = (10 − sum mod 10) mod 10, appended at end of output field | field + 1 |
| Two-letter `XY` | Format cross-conversion, input format letter + output format letter over `B/P/Z/S` — e.g. `ZP` zoned→packed, `BP` binary→packed. A trailing digit sets the output width (`ZP4`) | per formats |
| `AN` | Verify **alphanumeric**; replace anything else with blanks | `long` |
| `AB` | Verify **alphabetic**; replace anything else with blanks | `long` |
| `NO` | Verify **zoned decimal**; replace anything else with zeros | `long` |

Example — unpack a balance then append its check digit:

```
COND1  12,2,LT,'95'
FIELD1 40,6,UNPK,60          unpacked value occupies 60–70 (11 bytes)
FIELD1 60,11,zDVy,120        check-digit-protected copy at 120
```

### 4.5 `CONV` — External Table Translation

```
CONV[x] [TITt/] [DD=ddname/] [nnK/] Si, long1, SiA / So, long2, SiF [/INT]
```

- **The table may be included inline in SYSIN, or held in its own file.** With `DD=ddname` the named file is loaded; **with `DD=` omitted, the rows simply follow the CONV card in the deck** and are read until the next control card, a blank card, or end of SYSIN. Up to **20 tables**, 500 rows each. `nnK` reserves memory and is accepted for compatibility.
- Optional `x` (1–8): the conversion runs only if COND indicator *x* is ON.
- `TITt/` (OSLISTA): send the result into **title line *t*** instead of a detail line.
- For each record: the input key at `Si`(`long1`) — prefix `S` for SYSUT3 — is searched against the table's argument column (`SiA`); the matching row's function column (`SiF`, `long2`) is moved to output offset `So`. `So` takes the same destination prefixes as `FIELD` (print lines 2–9 in OSLISTA, `S` = SYSUT4 in OSGENER).

Inline example — decode a sex code, with a fall-through row for anything unmatched:

```
CONV  22,1,10/23,9,20
         1         MASCULINO
         2         FEMENINO
                   ERROR
```
- Default match: exact equality. With `/INT`: **interval lookup** — table must be pre-sorted ascending; the first row whose argument is ≥ the key wins (ceiling rule).
- **A miss falls through to the last table row's function** (use the final row as your "unknown" default).

### 4.6 `CORTE` — Control Breaks, up to 10 nested levels *(OSLISTA only)*

```
CORTE F [, ID='literal'] [, H]                     end-of-file (grand-total) level
CORTE Si, long, sk, [S], ID='literal', so1 [, I, so2]   / ...
CORTE CT, cantidad                                 forced break every N records
```

- Levels stack major→minor; a break at one level fires all lower levels.
- **Several levels may be declared on one card**, `/`-separated, each with its own `ID='…'`: `CORTE F/10,18,2,ID='CUENTA',1,I,8/2,4,2,ID='CAJA',1,I,8`.
- `sk` — line spacing after the break; `H` = page eject.
- `S` — break silently (reposition, no totals line of its own; totals still available to IMCOR).
- `I, so2` — also print the **field that caused the break** at output position `so2`, taken from the closing group's last record.
- `CT, n` — automatic break every *n* processed records.
- Input files must be sorted by the break keys.

### 4.7 `IMCOR` — Break Totals Line *(OSLISTA only)*

```
IMCOR CANT, so1 [/ Si, long, conv, so2 | / Ax, conv, so2 ...]
```

- `CANT` — prints the group's record count as a fixed 9-digit field at `so1`.
- Additional operands map accumulators (`Ax`) or record fields with `ZxDy`/`PxDy` edit masks. Up to 10 fields per break.
- After printing, the level's accumulators reset to zero and the previous-key buffer takes the new key value.

---

## 5. OSLISTA Commands

*(`PRINT`, `CARRO`, `CORTE` and `IMCOR` are OSLISTA-only. `TIT` and `CLAVE` also exist in OSGENER — see §3.1 and §6.6.)*

### 5.1 `PRINT` — Listing Format

```
PRINT FL=[C|X|XC], FR=nn, LR=nn, SK=nn, SP=[1|2|3], SR=[1|2|3]
```

- `FL` — `C` character, `X` hexadecimal, `XC` mixed: each record printed as its characters with the hex nibbles on the line below (invaluable for debugging corrupt bytes).
- `FR` / `LR` — first/last record number to print. `SK` — records to skip per cycle (stride).
- `SP` — internal line spacing; `SR` — spacing between records.

### 5.2 `TIT` — Report Headings (TIT1..TIT9)

> `TIT` is **not** OSLISTA-only — OSGENER has its own one-line form for the SYSLIST error report; see §6.7.

```
TITx  (Si,long,conv,so), [FN | FNnn | FA | FAnn], Sn, Lnn, 'literal'
```

- Up to 9 heading lines. `(Si,long,conv,so)` maps record fields into the heading; `conv` may be omitted for a plain move.
- `FNnn` — today's date, numeric, 8 bytes at column *nn*. `FAnn` — alphabetic date, 18 bytes (e.g. `23 DE JULIO DE 2026`). **Bare `FN` / `FA` default to column 91.**
- `Lnn` — starting column of the following text literal. `Sn` — spacing after the line (1–3).
- A heading literal may be **opened on the TIT card and closed on the next card**, which is the one place the "repeat the op-code" continuation rule does not apply.
- **Line 1 is always printed** — even with no `TIT` card at all — and carries `-PAGINA nnnnn` from column 110. Coding `CARRO` suppresses this.

### 5.3 `CLAVE` — Two-File Match *(valid in both utilities)*

```
CLAVE Si1, long, Si2
```

Matches SYSUT1 (key at `Si1`) against SYSUT3 (key at `Si2`), key length `long`. **Both files must already be sorted by this key.** After the match, `S`-prefixed offsets in other cards read the paired SYSUT3 record.

### 5.4 `CARRO` — Printer Carriage Control

```
CARRO cc1, cc2, ..., ccx
```

Assigned sequentially to printed lines: `WxA` print then skip *x* lines (0–3); `WCx` / `SCx` write/skip to hardware channel *x* (1–C hex); `SxL` skip *x* lines without printing.

---

## 6. OSGENER-Only Commands

### 6.1 `COPY` — Range Copy

```
COPY FR=nnnn, LR=nnnn, SK=nnnn
```

Mass linear copy of record ranges; up to 10 independent range groups can be concatenated.

### 6.2 `PESQIN` / `PESQOUT` — Lookup-File Filtering

```
PESQIN  Si1, long, Si2        include records whose key matches SYSUT6
PESQOUT Si1, long, Si2        exclude records whose key matches SYSUT6
```

`Si1` = key in SYSUT1, `Si2` = key in SYSUT6. **Both files must be pre-sorted.**

### 6.3 `GENER` — Multi-Card Batch Consolidation

```
GENER Si1, long1 / Si2, long2 / 'cod1', 'cod2', ...
```

- `Si1,long1` — batch link key. `Si2,long2` — card-type code position.
- Consecutive input cards sharing the key are consolidated into an internal **800-byte block of ten 80-byte slots**. Each card lands in the slot corresponding to its code's position in the declared code list — **by declared priority, not arrival order**.
- When the key changes, the block freezes, `CODIG`/`INCON` validations run against it, then FIELD/CONV/output processing operates **on the 800-byte block**, and the block resets for the next key.
- Card offsets in subsequent FIELD/INCON cards address the block: slot 1 = bytes 1–80, slot 2 = 81–160, etc.

### 6.4 `CODIG` — Mandatory-Presence Rules

```
CODIG 'Cod', OBL [, 'Cod1', 'Cod2', ...]
```

- With a trigger list: if any of `Cod1`, `Cod2`… is present in the frozen block, card `Cod` **must** also be present.
- Without a trigger list: card `Cod` is unconditionally mandatory in every batch.
- On violation the whole batch **collapses**: a drop notice is written to SYSLIST and the batch's records go to **SYSUT5**.

### 6.5 `INCON` — Data Validation & Active Correction

```
INCON 'cod' / Si, long, type [, 'ERRLABEL']  [/ | .Y. | .AND. | .O. | .OR. ...]
INCON 'cod' / Si, op, 'literal'              ...
```

Applied to the block slot holding card code `cod`. `Si` may be `S`-prefixed to check the paired SYSUT3 record instead.

**Note the inverted separator.** Inside `INCON`, `/` is equivalent to **`.Y.` (AND)**, not to OR as it is on `RCIN`/`RCOUT`/`COND`. So `/`-separated rules are **independent checks**, each reported on its own, while `.O.`/`.OR.` builds a set of **alternatives** — the field must satisfy at least one, and only if *all* of them fail is a single inconsistency reported:

```
INCON '092'/18,,'1'.O.18,,'3'.O.18,,'S'      column 18 must be one of 1/3/S
```

Only relational rules may be `.O.` alternatives; the correcting types below rewrite bytes in place, and the manual defines no behaviour for correcting an alternative that was not the one satisfied.

The comparison operator may be omitted, assuming `EQ`. Validation types:

| Type | Meaning | On violation |
|---|---|---|
| `N` | Strict numeric zoned | error reported |
| `ND` | Numeric **corrector** | offending bytes forced to `0` in memory |
| `A` | Strict alphabetic | error reported |
| `AB` | Alphabetic **corrector** | offending bytes forced to space |
| `AN` / `ANB` | Alphanumeric strict / corrector | as above |
| `FD` / `FA` | Calendar check, `DDMMAA` / `AMMDD` | day must be 01–31, month 01–12; failures reported to SYSLIST |

- An optional quoted label (≤ 8 chars, e.g. `'ERR-ZONA'`) is echoed in SYSLIST's error-type column when this rule fires — label your rules so operations staff can identify exactly which card failed.
- A relational form (`Si, op, 'literal'`) validates a field against a literal/range.

### 6.6 `TIT` — SYSLIST Error-Report Heading

```
TIT [Lnn,] 'literal'
```

OSGENER's `TIT` is a **different card from OSLISTA's**: one line, no `1`–`9` index, and it heads the SYSLIST assembly-error report rather than a printed page. It requires a preceding `GENER` card. `Lnn` sets the starting column (default 1) and the literal may continue on the following card.

```
GENER 1,7/80,1/'0','1','2','3'
TIT L18,'  ERRORS IN MASTER-FILE ASSEMBLY  '
```

### 6.7 Output Redirection Recap

- FIELD output offset `so` → SYSUT2 (main output).
- FIELD output offset `Sso` (e.g. `S37`) → SYSUT4 (secondary/mirror output).
- CONV result offset `So`, same prefixes.
- CODIG-collapsed batches → SYSUT5 + SYSLIST notice.

---

## 7. Worked Examples

### 7.1 OSGENER — Conditional Bank File with Check Digit

```
RCIN  1,4,GT,'0500'          keep branches > 0500
COND1 12,2,LT,'95'           flag 1 if year < 95
FIELD1 40,6,UNPK,60/60,11,ZDVZ,120
      if flag 1: unpack the balance (6 packed -> 11 display) at 60,
      then append its Mod-10 check digit at 120 - both groups on one card
```

*(The manual writes the check digit as `xDVy`, where *x*/*y* are the input and output format letters; `ZDVZ` is zoned in, zoned out.)*

### 7.2 OSGENER — Batch Consolidation with Integrity Rules

```
RCIN  1,3,EQ,'ARG'
GENER 1,3/80,1/'0','1','2','3'      batch key = cols 1-3; type code = col 80
CODIG '1',OBL,'2'                    if a type-2 card exists, type-1 is mandatory
INCON '0'/12,6,FD/14,1,ND            date check + numeric correction on type-0 card
FIELD 1,3,MOVE,1
FIELD 18,6,MOVE,10
```

*(Note: an RCIN placed before GENER filters records **before** batching — batches of non-matching keys never form. Order your cards deliberately.)*

### 7.3 OSLISTA — Multi-Level Report with Mixed Hex Printing

```
PRINT FL=XC, SP=1, SR=2
TIT1  L10,'SCD - REPORTE DE CONTROL GEOGRAFICO', FA70
CORTE F, ID='TOTAL GENERAL', H
CORTE 1,2,1,S, ID='PROVINCIA: ', 5
IMCOR CANT,10/A1,Z9D2,40
```

Prints every record in char+hex, breaks on province change (cols 1–2) silently, prints province record-count at col 10 and accumulator 1 (edited, 9 digits, 2 decimals) at col 40, and ends with a grand total on a fresh page.

---

## 8. Diagnostics & Troubleshooting

| Symptom | Where to look |
|---|---|
| Job did nothing / wrong records selected | SYSPRINT — cards are echoed; check op-code starts in column 1 and AND/OR are not mixed in one group |
| Records missing from SYSUT2 | RCIN/RCOUT logic; PESQIN/PESQOUT key sort order; CLAVE sort order |
| Batches in SYSUT5 | SYSLIST drop notices — a CODIG rule fired; the label column tells you which |
| Zeros/blanks where data expected | An INCON `ND`/`AB` corrector fired — see SYSLIST detail lines |
| Date errors | INCON FD/FA: day 01–31, month 01–12 enforced |
| Garbled numeric output | Wrong format letter (P/Z/S/B) on ACUM/FIELD, or UNPK applied to non-packed data — use `PRINT FL=XC` in OSLISTA to inspect raw bytes |
| Accumulator zero unexpectedly | Division by zero occurred — check SYSPRINT for the warning |
| First-5-records audit | OSGENER always logs the first 5 successfully processed records in SYSPRINT — use them to sanity-check your FIELD layout before checking the full output |

---

## 9. Implementation Notes (current engine)

The GnuCOBOL engine (`src/OSENGINE.CBL`) implements the full command set above, and is verified against **every control-card example printed in the SCD 1/84 manual** (`tests/manual_examples.sh`, 93 cases, all passing). Points worth knowing:

- **TIT per-record field maps** `(Si,long,conv,so)` are rendered at page top from the **page-lead record** (the record whose line triggered the eject). Supported map conversions: MOVE, UNPK, ZxDy, PxDy. Literals, `Lnn`, `FAnn`, `FNnn`, `Sn` all work. FA emits the date with **Spanish month names** by design (SCD manual behavior, e.g. `23 JULIO 2026`).
- **INCON** supports both the type form (N/ND/A/AB/AN/ANB/FD/FA + optional error label) and the **relational form** `Si, op, 'literal'` — a failed relation is the inconsistency, logged to SYSLIST. Remember that `/` means AND here (§6.5).
- **CONV tables** may be inline in SYSIN or in a `DD=` file; the inline form ends at the next control card, a blank card, or end of SYSIN. A table row whose column-1 word happens to spell an op-code would therefore end the table early — the same ambiguity the original utility had.
- **CARRO** actions `WxA`, `SxL`, `WCx`, `SCx` are applied cyclically to printed lines; **channel 1 forces a page eject** (form feed). When CARRO is present it drives line spacing in place of `PRINT SP=`.
- **ACUM** accepts field operands and **numeric literals** written directly (`ACUM1 +,2.5`; the non-standard `+,L,2.5` is still tolerated); a format suffix gives **implied decimals** (e.g. `Z2` = 2 implied decimal places). Accumulators hold true decimal values; the IMCOR `ZxDy`/`PxDy` mask controls displayed decimals.
- **Signed decode**: zoned (Z) honors **overpunch** signs (`{ABC…` positive, `}JKL…` negative); binary (B) is **two's-complement** (big-endian). Packed (P) reads the trailing sign nibble.
- **XY re-format conversions** take an optional **card-specified output length** as trailing digits (e.g. `ZP4` = zoned→packed, 4-byte output); with no length the value's own width is used.
- **Duplicate card code** inside one GENER batch: **first-wins** — the duplicate is logged to SYSLIST and dropped.
- **Page separators**: a form feed is emitted (`WRITE … AFTER ADVANCING PAGE`) ahead of the first title line of pages after the first. Even a deck with **no TIT card** still gets a heading line carrying `-PAGINA nnnnn`, unless `CARRO` is coded.
- `S`-prefixed offsets (SYSUT3) compare against blanks unless a `CLAVE` card is present to drive the pairing (a SYSPRINT warning is issued).
- **Character classes are uppercase-only** throughout (`A`–`Z`), matching the EBCDIC-era repertoire: this applies to the INCON `A`/`AB`/`AN`/`ANB` checks and the FIELD `AN`/`AB` conversions alike, so lowercase input is treated as invalid and corrected.

## 10. Code Quality Tooling (COBOL OSS stack)

There is no ruff-style all-in-one linter for COBOL — the compiler is the primary linter. Practical OSS stack:

- **`cobc` warnings / strict dialects** — GnuCOBOL itself as linter (`-fsyntax-only -Wall -Wextra`, `-std=mvs-strict` for dialect conformance).
- **[SuperBOL Studio OSS](https://github.com/OCamlPro/superbol-studio-oss)** — LSP + VS Code/Emacs tooling built on the GnuCOBOL front-end; the most active open-source COBOL project.
- **[Che4z COBOL LSP](https://github.com/eclipse-che4z/che-che4z-lsp-for-cobol)** — Eclipse open-source LSP, IBM Enterprise COBOL oriented.
- **cobol-check** (Open Mainframe Project) — unit-test framework (this repo uses its own `tests/OSTESTS.CBL` harness instead).
- **ProLeap / Koopa parsers** — open-source COBOL parsers for building custom static-analysis rules.
- Note: **SonarQube's COBOL analyzer is commercial** (not part of the free Community Build).

Wired into this repo:

- **`make lint`** — `cobc -fsyntax-only -Wall -Wextra` over all sources; **kept at 0 warnings**. Two warning classes are suppressed with documented rationale (see Makefile):
  - `-Wno-terminator`: the code uses an explicit scope terminator on **every statement that has one in MVS COBOL / COBOL-85** (`END-IF`, `END-PERFORM`, `END-EVALUATE`, `END-READ`, `END-ADD`, `END-COMPUTE`, `END-WRITE`, `END-STRING`, `END-SUBTRACT`, `END-MULTIPLY`, `END-DIVIDE`, `END-CALL` — all verified accepted by `-std=mvs-strict`). The only unterminated statements are `DISPLAY`s, because `END-DISPLAY` is a MicroFocus/GnuCOBOL extension that `-std=mvs-strict` and `-std=cobol85` **reject** (verified empirically); the suppression exists solely for those.
  - `-Wno-possible-truncate`: advisory only — numeric MOVE truncation semantics are identical on IBM MVS COBOL (`TRUNC(STD)`, modeled by GnuCOBOL's `binary-truncate`); deliberate nibble/digit staging triggers it, and oversized card operands are rejected by the parse-time bounds validator `1600-VALIDATE-CONFIG`. `make lint-extra` shows the suppressed classes for review when adding new code.

**Dialect portability (plan G9, complete):** the engine is written in strict COBOL-85 — all intrinsic functions replaced with standard equivalents (`ACCEPT FROM DATE` + century window, digit-table lookups, `INSPECT CONVERTING`, a big-endian `BINARY` redefine for byte⇄char), and early paragraph exits use the classic `GO TO <n>-EXIT` / `PERFORM … THRU` pattern. The only dialect-bound code is the CONV-table `SELECT`, resolved via copybooks: build with `make all DIALECT=gnucobol` (default, `-std=mvs`, `ASSIGN TO DYNAMIC`) or `make all DIALECT=rm` (`-std=rm`, RM native variable assign). Both builds pass the full test suite with byte-identical outputs. `-ffilename-mapping` is forced because the RM dialect config disables env-var DDNAME resolution. **`make check-dialects`** verifies all four compiler profiles in one shot — `-std=mvs`, `-std=rm`, and genuine conformance under `-std=mvs-strict` and `-std=rm-strict` (0 errors each with the portable copybook).
- **`make lint-strict`** — audit against `-std=mvs-strict`; flags the GnuCOBOL intrinsics (`CURRENT-DATE`, `NUMVAL`, `ORD`…) a real 1980s MVS compiler wouldn't have.

## 11. Golden Rules

1. **Sort first.** CLAVE, PESQIN/PESQOUT, CONV `/INT`, and CORTE all require pre-sorted inputs.
2. **Column 1 is sacred.** Op-codes start there; anything else is a card error.
3. **Never mix AND with OR** in one condition group.
4. **Card order = execution order matters**: filters (RCIN) run before batching (GENER); validations (INCON/CODIG) run before arithmetic (ACUM); packing/formatting (FIELD/zDVy/CONV) runs last, just before the write.
5. **Label your INCON rules** — future you, at 3 a.m., will thank you when reading SYSLIST.
6. **Respect the limits table** (§3.1); exceeding a table is a parse-time error.
