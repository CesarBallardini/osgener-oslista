# Plan: Full Implementation of OSGENER / OSLISTA (SCD 1/84 Modernization)

Goal: produce `src/OSENGINE.CBL`, a single engine (GnuCOBOL, mainframe personality) that runs as OSLISTA or OSGENER with behavioral parity with the SCD 1/84 manual.

**Legend:** `[x]` done and verified · ⚠ **NOT COMPLETED** = open work item.

---

## Phase 0 — Decisions & Spec Conflict Resolution ✅ complete

- [x] **D0.1 — SYSUT5 routing.** SYSUT5 receives only CODIG-collapse orphans; INCON corrects in place (ND/AB/ANB) and logs to SYSLIST. (Resolved a contradiction between the provisional transcriptions.)
- [x] **D0.2 — Command/mode matrix.** CORTE/IMCOR/PRINT/TIT/CARRO = OSLISTA-only; GENER/CODIG/INCON/PESQ/COPY = OSGENER-only; CLAVE valid in both. Mode-gated at parse time.
- [x] **D0.3 — Break semantics.** Breaks evaluate only on accepted records, BEFORE accumulating the current record; IMCOR field values come from the closing group's last record (`WS-PREV-SRC`).
- [x] **D0.4 — Dual-binary strategy.** Thin stubs CALLing the engine; the `*D`/`*L` column-7 scheme the provisional transcriptions proposed was abandoned as unsound.
- [x] **D0.5 — Entry interface.** `CALL "OSENGINE" USING` a `PIC X(7)` mode field.
- [x] **D0.6 — Toolchain.** GnuCOBOL 3.2 via Chocolatey; `cobc -x -std=mvs`; `COB_CONFIG_DIR`/`COB_CC`/native-make PATH handled in the Makefile. `make lint` (cobc `-fsyntax-only -Wall -Wextra`) and `make lint-strict` (`-std=mvs-strict` portability audit) added.
- [x] **D0.7 — Fixture repair.** SYSUT1/SYSUT6 sorted by PESQ key; RCIN OR-group accepts ARG+BRA; INCON offsets match the data; OSLISTA writes its own SYSUT2 file; fixture literals in English.

## Phase 1 — Skeleton & I/O Layer ✅ complete

- [x] 1.1 Divisions + SELECT/ASSIGN for all 9 DDNAMEs (env-var resolvable).
- [x] 1.2 Mode dispatch + per-mode command rejection.
- [x] 1.3 Central read coordinator (legacy pitfall #1 - see "Mandatory Legacy Fixes" in CLAUDE.md).
- [x] 1.4 SYSIN echo to SYSPRINT; OSGENER first-5-records audit.

## Phase 2 — SYSIN Parser ✅ complete

- [x] 2.1 Tokenizer: col-1 op-codes, quoted + `X'..'` hex literals, `KEYWORD=value`, `ID='...'` extraction.
- [x] 2.2 Command tables with limits (150/125/90/20/10/10/50/10/10).
- [x] 2.3 All loops bounded by parsed-entry counts (pitfall #3).
- [x] 2.4 Compile rules: AND/OR family mixing forbidden; col-1 enforcement; INCON error labels; hex-literal validation (even length, valid digits, lowercase accepted); 6-digit numeric-operand bound; CONV geometry guards; S-offset-without-CLAVE warning.

## Phase 3 — Common Engine Commands ✅ complete (gaps → Phase 8)

- [x] 3.1 RCIN/RCOUT: 8 operators, S-prefix → SYSUT3, char/hex literals, OR/AND groups.
- [x] 3.2 CONDx flag matrix.
- [x] 3.3 ACUM: 9 registers, + − * /, P/Z/S/B decode, flag suppression, div-by-zero → 0 + warning. *(Numeric-literal operands and decimal alignment → G5.)*
- [x] 3.4 FIELD: MV/UNPK/HEXA/ZxDy/PxDy/CL/zDVy/XY, FIELDx gating, S-prefix output → SYSUT4. *(XY output lengths derived from value → G6.)*
- [x] 3.5 CONV: 20 tables, exact + `/INT` ceiling lookup, miss → last entry.
- [x] 3.6 CORTE/IMCOR: 10 levels, F/CT/key types, CANT, edited accumulators, resets.

## Phase 4 — OSLISTA-Specific ✅ complete (gaps → Phase 8)

- [x] 4.1 PRINT FL=C/X/XC (hex dump line), FR/LR/SK, SP/SR.
- [x] 4.2 TIT1–9: literals, Lnn, FN/FA dates, Sn. *(Per-record field maps → G1.)*
- [x] 4.3 CLAVE sorted-merge pairing.
- [x] 4.4 CARRO parsed; line-skip semantics applied. *(Hardware channel skips → G3.)*

## Phase 5 — OSGENER-Specific ✅ complete (gap → Phase 8)

- [x] 5.1 COPY ranges (stride aligned with PRINT semantics: SK = skip per cycle).
- [x] 5.2 PESQIN/PESQOUT sorted-merge include/exclude.
- [x] 5.3 GENER 800-byte block, priority-slot ordering, freeze on key change/EOF. *(Duplicate code overwrites its slot → G7.)*
- [x] 5.4 CODIG OBL rules; collapse → SYSUT5 + SYSLIST (D0.1).
- [x] 5.5 INCON all 8 types, in-place correction, SYSLIST labels.
- [x] 5.6 SYSUT4 mirror output via FIELD S-prefix.

## Phase 6 — Test & Verification ✅ complete

- [x] 6.1 `tests/OSTESTS.CBL` TC-02 fixed (binary→alphanumeric MOVE staged through PIC 9); all 5 TCs PASS; harness fully translated to English.
- [x] 6.2 **Engine behavior tests** (`tests/run_tests.sh` I1–I8, run against the REAL binaries rather than mirrored harness logic): division-by-zero warning, FD date edges (days 00/32, months 00/13), CONV `/INT` ceiling + miss→last-entry, GENER priority-slot ordering, HEXA doubling, ZxDy masks, negative packed decode (X'413D' → −413), UNPK nibble expansion.
- [x] 6.3 Fixture rebuilt per D0.7; simulation outputs verified byte-exact (Mod-10 digits hand-checked; totals 2500,75 / 550,00 / 50,00; counts 4/2/1; 2 orphan records; 3 SYSLIST notices).
- [x] 6.4 **Bounds + negative tests** (`tests/run_tests.sh` L1–L4, N1–N9): 151st condition, 126th FIELD, 11th CORTE, 21st CONV all rejected with clean rc=12 card errors; scripted negative paths for odd/invalid hex, oversized numeric, valueless keyword, CONV geometry, column-1 rule, T-prefix in OSGENER, mixed AND/OR, semantic bounds validator.
- [x] 6.5 **Golden-file regression** (`tests/golden_check.sh` + committed `tests/expected/` baselines): the four simulation outputs are diffed on every `make test` (run-date in the OSLISTA heading normalized to `<DATE>`); `--update` regenerates baselines after intended changes.

## Phase 7 — Packaging & Docs ✅ complete

- [x] 7.1 Makefile: build, ostests, test, lint, lint-strict, clean targets.
- [x] 7.2 `RUNPROC.JCL`: PGM ≤ 8 chars, English, deck matches simulation.
- [x] 7.3 `docs/user-guide.md` §9 implementation notes in sync; `CLAUDE.md` build docs current; all code/comments English (SCD card names and FA Spanish month names retained by design).

## Phase 8 — Functional Gap Closure ✅ COMPLETED

All eight gaps implemented and verified (tests I9–I16 in `tests/run_tests.sh`), in **both** the mvs and rm dialect builds, byte-identical:

- [x] **G1 — TIT per-record field maps** `(Si,long,conv,so)`: parsed into a per-title map table; rendered at page top from the page-lead record (the record whose line triggered the eject) via `4265-RENDER-TIT` into a dedicated `H-TITLE` buffer. Supports MOVE / UNPK / ZxDy / PxDy. (Test I16.)
- [x] **G2 — INCON relational form** (`Si, op, 'literal'`): second-token classification distinguishes it from the type form; `IC-TYPE="R "` evaluated in `3470-INCON-RELATIONAL`; a failed relation is the inconsistency, logged to SYSLIST with the rule label. (Test I9.)
- [x] **G3 — CARRO** parsed into an action table (`WxA`/`SxL`/`WCx`/`SCx`) and applied cyclically to printed lines; channel-1 forces a page eject. When CARRO is present it drives spacing in place of `PRINT SP=`. (Test I15.)
- [x] **G4 — Signed numeric decode**: zoned overpunch (`{ABC…}JKL…` sets, `7060-ZONE-OVERPUNCH`) and two's-complement binary (high-bit-of-first-byte → subtract 256^n). (Tests I10, I11.)
- [x] **G5 — ACUM literal operands + implied-decimal alignment**: format `L` = numeric literal (`1223-PARSE-ACUM-LIT`, accepts `.`); format suffix digits (e.g. `Z2`) = implied decimals. Accumulators now hold true decimals (`DN-OPND`), and IMCOR scales by the mask's decimal count. (Tests I12, I13.)
- [x] **G6 — XY conversions with card-specified output length**: trailing digits on the XY token (e.g. `ZP4`) set `FT-OUTLEN`, honored by `7100-ENCODE-NUMERIC`/`7130-ENCODE-BINARY` (left-pad / fixed byte width). XY now checked before the ZxDy mask branch (disambiguated on char-2).
- [x] **G7 — Duplicate GENER code policy**: first-wins; the duplicate is logged to SYSLIST and dropped. (Test I14.)
- [x] **G8 — Page separators**: `WRITE … AFTER ADVANCING PAGE` emits a real form feed ahead of the first title line of pages after the first (portable across mvs/rm; a lone `X'0C'` is stripped by GnuCOBOL LINE SEQUENTIAL — verified). Requires a TIT line; a no-title listing does not eject (documented). (Test I15.)
- [x] **G9 — Dialect portability layer (RM/COBOL-85 vs MVS "on the fly")** — *FULLY COMPLETED:*
  - [x] (a) **Intrinsic functions eliminated** with standard-85 equivalents: `CURRENT-DATE` → `ACCEPT … FROM DATE` + century window (`7520-GET-DATE`); all 16 per-digit `NUMVAL` sites → table lookup (`7700-CHAR-TO-DIGIT` / `7710-PAIR-TO-NUM`); `UPPER-CASE` → `INSPECT CONVERTING`; `ORD`/`CHAR` → big-endian `BINARY` redefine (`BC-WORK`, valid on GnuCOBOL-mvs/-rm, real MVS and RM/COBOL, which all define big-endian binary); harness `FUNCTION REM` → `DIVIDE … REMAINDER`.
  - [x] (b) **Per-dialect copybook layer**: dialect-bound CONV-table SELECT extracted to `src/copy/gnucobol/SELCONV.cpy` (`ASSIGN TO DYNAMIC`) and `src/copy/rm/SELCONV.cpy` (RM native variable assign), pulled in with a standard `COPY` via `-I src/copy/$(DIALECT)`; Makefile `DIALECT=gnucobol|rm` knob selects copybooks + `-std`; `-ffilename-mapping` forced in COBFLAGS because `rm-strict.conf` disables env-var DDNAME resolution (found when the RM build wrote a literal `SYSPRINT` file). **Proof: `make all DIALECT=rm` passes all 21 engine tests and reproduces all 4 golden baselines byte-identically.**
  - [x] (c) **Strict-85 conformance — COMPLETED**: all 41 `EXIT PARAGRAPH` uses reworked to the classic COBOL-85 pattern — `GO TO <nnnn>-EXIT` + trailing `<nnnn>-EXIT. EXIT.` paragraphs + `PERFORM … THRU` (23 paragraphs, 126 call sites converted by a warning-driven Perl transformer; `GO TO`/`THRU`/`EXIT PERFORM` empirically verified accepted by `mvs-strict`, `rm-strict` and `cobol85`). **Result: 0 errors under `-std=mvs-strict` and `-std=rm-strict`** with the portable (`copy/rm`) SELECT; the only remaining extension anywhere is the deliberate `DYNAMIC` in `copy/gnucobol`. `make check-dialects` gates all 4 profiles (mvs, rm, mvs-strict, rm-strict); both dialect builds pass 21/21 engine tests + 4/4 golden baselines.

## Phase 9 — Source-parity reconciliation against the genuine manual ✅ **COMPLETED**

The real SCD 1/84 publication is now in the repo at `docs/manual/OSLSGEN.txt`; the full English
translation is `docs/manual/osgenls-manual.md` (sheet-by-sheet, with the diagrams as Mermaid and a catalogue of
the transcription slips in Appendix A). This closes the "Source-parity caveat" that `CLAUDE.md`
carried. Phases 0–8 were validated against those provisional transcriptions, **not** against this document.

- [x] **9.1 — Manual translated and indexed** (`docs/manual/osgenls-manual.md`): all 37 sheets, every syntax box,
      every operand table, all 76 printed control-card examples, both functional-processing
      flowcharts, both file-connectivity diagrams, plus Appendix B (quick syntax reference + the
      complete table-limit list).
- [x] **9.2 — Manual-example conformance suite** (`tests/manual_examples.sh`, wired into `make test`
      and available alone as `make manual-tests`): **93 cases**, one per printed example (IDs
      `H<sheet>-<n>`) plus a handful of prose-only forms the manual documents but does not
      exemplify. Cards are coded as printed, except for the Appendix-A transcription slips, which
      are coded in their corrected reading and marked `[fix]`. Cases carry an expectation: `OK`
      (must be accepted) or a gap ID `Mnn` (known to be rejected). The suite gates on `FAIL`
      (an `OK` case that regressed) and reports `XPASS` when a documented gap starts working.
- [x] **9.3 — Gap analysis complete.** Opening standing: **47 PASS / 46 XFAIL / 0 FAIL**.
- [x] ✅ **9.4 — Close the M-gaps. COMPLETED — all 29 closed** (M1–M29).
      **Final standing: 93 PASS / 0 FAIL / 0 XFAIL** — every control-card example printed in the
      manual is accepted and behaves correctly. Engine suite **63/63**, `make lint` 0,
      `make check-dialects` clean, 4/4 golden baselines, all verified in **both** the mvs and rm
      builds.

      Four of the twenty-nine gaps were **not** in the original audit — they were found while
      fixing others, which is the main lesson of this phase:
      - **M26** (800-byte input record) — found writing a test for M1.
      - **M27** (only the first `/`-group of a card parsed) — found writing a test for M26; the
        most serious defect in the whole exercise.
      - **M28** (256-byte output record; sheet 32 writes to column 320) — found when M8 stopped
        truncating H33-2.
      - **M29** (`AN`/`NO`/`AB` FIELD validation conversions absent) — the original inventory had
        wrongly marked these ✅; exposed when M19 let H33-5 reach its fourth group.

      Two long-standing bugs unrelated to any single card also fell out: the ACUM division
      operand (`DN-VAL` for `DN-OPND`) and `3510-SET-COND-FLAGS` ignoring connectors.

### Feature inventory — manual vs. engine

Legend: ✅ conformant · ⚠ partial · ❌ not implemented.

| Sheet | Card / feature | Manual specifies | Engine |
|---|---|---|---|
| 3 | Op-code in column 1, operands after ≥1 blank | yes | ✅ |
| 3 | Card continuation = new card with op-code, **except TIT** | yes | ✅ (M24) |
| 5 | `PRINT FL=C/X/XC, FR, LR, SK, SP, SR` | all six | ✅ |
| 6 | `TIT1`–`TIT9` literal, `Lnn`, `Sn` | yes | ✅ |
| 6 | `TIT` `(Si,long,conv,so)` field map | yes | ✅ (M23) |
| 6 | `TIT` `FNnn` / `FAnn` dated headings | yes | ✅ |
| 6 | `TIT` bare `FN` / `FA` → default column 91 | yes | ✅ (M22) |
| 6 | Title line 1 always printed with user legend + `-PAGINA XXXXX` at col 110 | yes | ✅ (M25) |
| 6 | Date lengths: numeric 8, alphabetic 18 | yes | ✅ |
| 7 | `CLAVE Si1,long,Si2` | yes | ✅ |
| 8/9 | `RCIN`/`RCOUT`/`CONDx` — 8 operators, `'literal'`, `X'literal'`, S-prefix, 150 max | yes | ✅ |
| 8/9 | Omitted operator defaults to `EQ` | yes | ✅ (M1) |
| 8/9 | Count-only condition `op,cuenta` (no `Si`) | yes | ✅ (M2) |
| 8/9 | Connectors `.AND.` `.Y.` `.OR.` `.O.`; `/` ≡ `.O.` | yes | ✅ (M3, D0.8) |
| 8/9 | AND/OR family mixing forbidden in one group | yes | ✅ (per run — D0.8) |
| 9 | `CONDx` takes a whole condition group, not one condition | yes | ✅ (M3) |
| 10 | `ACUMy` / `ACUMyx`, `+ - * /`, formats `P Z S B`, ≤ 10 ops on one card | yes | ✅ |
| 10 | Numeric-literal operand `Cod.op,num` | yes | ✅ (M4) |
| 11 | `FIELD` / `FIELDx`; `MOVE/M`, `UNPK/U`, `HEXA/H`, `ZxDy`, `PxDy` | yes | ✅ |
| 11 | Max input lengths: UNPK 8, MOVE 132, HEXA 64 | yes | ✅ |
| 11 | `EC=xy` line-spacing control | yes | ✅ (M5) |
| 11 | S-prefixed **input** offset (SYSUT3) | yes | ✅ (M6) |
| 11 | 9 print lines: `so`, `Snnn`, `Tnnn`, `Cnnn`, `Qnnn`, `Xnnn`, `Pnnn`, `Onnn`, `Nnnn` | 9 lines | ✅ (M7) |
| 11 | `Ay,conv,so` accumulator output | yes | ✅ |
| 11 | `'literal',so` plain literal | yes | ✅ (M8) |
| 11 | Omitted `conv` defaults to MOVE | yes | ✅ (M9) |
| 11/15/32 | Several `/`-separated groups per card, all honoured, in order | yes | ✅ (M27) |
| 11 | 125 FIELD operations max | yes | ✅ |
| 12 | Quoted `'/'` as a literal | example 5 | ✅ (M10) |
| 13 | `CONV` table from **SYSIN inline** or `DD=ddname` | both | ✅ (M11) |
| 13 | `CONVx` condition-gated conversion | yes | ✅ (M12) |
| 13 | `TITx/` prefix — convert into a title line | yes | ✅ (M13) |
| 13 | `nnK` table-size operand (default 500 B) | yes | ✅ (parsed, ignored — fixed cap) |
| 13 | Output prefix on `So` (print line / SYSUT4) | yes | ✅ (M14) |
| 13 | `/INT` interval lookup, miss → last table entry | yes | ✅ |
| 13 | 20 conversions max | yes | ✅ |
| 15 | `CORTE` `F`, `Si,long`, `CT,cantidad`, `sk`(1/2/3/H), `S`, `ID='lit',sol`, 10 max, long ≤ 256 | yes | ✅ |
| 15 | Several levels on one card, each with its own `ID='…'` | yes | ✅ (M15, via M27) |
| 32 | FIELD output `,long` operand | yes | ✅ (M27) |
| 15 | `I,s02` — print the breaking field | yes | ✅ (M16) |
| 16 | `IMCOR` `CANT,sol`, `si,long,PxDy/ZxDy,s02`, `Ax`, 10 max | yes | ✅ |
| 17 | `CARRO` `WxA` / `WCx` / `SCx` / `SxL`, default `W1A`, CARRO-without-TIT ⇒ no titles | yes | ✅ |
| 21 | Three inputs (SYSUT1/3/6 + SYSIN), five outputs (SYSPRINT/SYSLIST/SYSUT2/4/5) | yes | ✅ |
| 21 | SYSPRINT carries the first five processed records | yes | ✅ |
| 24 | `PESQIN` / `PESQOUT Si1,long,Si2` | yes | ✅ |
| 26 | `COPY FR/LR/SK`, up to 10 groups | yes | ✅ |
| 27 | `GENER` 800-byte area, code-priority ordering, 10 codes | yes | ✅ |
| 28 | `INCON` types `N ND A AB AN ANB FA FD` | all 8 | ✅ |
| 28 | `INCON` relational form `Si,op,'literal'` | yes | ✅ (G2) |
| 28 | `INCON` `/` ≡ `.Y.` (**AND**, unlike RCIN/COND where `/` ≡ OR) | yes | ✅ (M17, D0.9) |
| 28 | `INCON` `.O.` alternatives — violated only if all fail | yes | ✅ (M17) |
| 28 | `INCON` S-prefixed offset | yes | ✅ (M6) |
| 29 | `CODIG 'Cod',OBL{,'Cod1'…}` | yes | ✅ |
| 30 | `TIT {Lnn},'literal'` — **OSGENER SYSLIST error-report heading** | yes | ✅ (M18) |
| 32 | `FIELD` conv `M`, `XY` (B/P/Z/S in→out), `AN`, `NO`, `AB`, `xDVy` mod-10 | yes | ✅ |
| 32 | `'literal2',CL` fill | yes | ✅ |
| 32 | `Ay,formato` with a bare format letter | yes | ✅ (M19) |
| 32 | `AN,formato` — written-record counter to output | yes | ✅ (M20) |
| 32 | Output `,long` operand | yes | ✅ |
| 32 | `So` S-prefix ⇒ SYSUT4 | yes | ✅ |
| 34 | `CONV` (OSGENER): as sheet 13 minus `TITx` | yes | ✅ |

### Open gaps (M-series)

Each is exercised by the `tests/manual_examples.sh` cases listed.

- [x] ✅ **M1 — Omitted comparison operator must default to `EQ`.** `RCIN 27,,'9'` is rejected with
      `INVALID OPERATOR:`. Sheets 8, 9, 28 all state "si se omite asume EQ". Fix in
      `1201-PARSE-ONE-COND` / `1560-VALIDATE-OP` / `1321-PARSE-INCON-RULE`.
      *(H8-2, H8-3, H9-1, H9-4, H9-6, H28-2, H28-5)*
      **FIXED.** An empty operator field arrives as a zero-length token (the scanner
      returns `SC-TYPE = "E"` for the `,,`), so both parsers now branch on `SC-TLEN = 0`:
      `1201-PARSE-ONE-COND` defaults `CT-OP` to `EQ` and skips `1560-VALIDATE-OP`; in
      `1321-PARSE-INCON-RULE` the empty field additionally disambiguates the **relational** form
      from the type form, so it joins the relop test and defaults `IC-RELOP` to `EQ`.
      **Tests: I22–I24** (RCIN, CONDx, INCON — each asserts the default actually *compares* as EQ,
      not merely that the card parses). *(H8-3, H8-7, H9-1, H9-4, H9-6 now OK; H8-2 → M2,
      H9-5 → M26, H28-2/H28-5 → M17.)*
- [x] ✅ **M2 — Count-only conditions `op,cuenta`. FIXED.** The second syntax alternative on sheets 8 and 9
      (compare the running record count, no `Si`) was not recognised; the engine always demanded a
      leading offset. *(H8-2, H8-4, H8-5, H9-3 — all now OK.)*
      New `CT-CNT PIC 9(6)` per condition and `CT-FILE = "N"` as the discriminator (an operator is
      alphabetic and an offset numeric, so the two forms cannot be confused on the first token).
      `1201-PARSE-ONE-COND` takes the count branch; `1600-VALIDATE-CONFIG` skips the bounds check
      for count entries (they have no field); the new `3265-EVAL-COUNT-COND` compares `REC-NO`
      against `CT-CNT` **numerically** — the sheet-8 wording is "cta. real reg. : parametro
      cuenta" — rather than through the character compare `3260`/`3515` use for fields. Dispatch
      sits at the two call sites (`3250`, `3550`) so each evaluator keeps one job.
      **Tests: I25–I27** (count window `GT,2.Y.LT,5`, `RCOUT LT,3`, and count mixed with a field
      test inside one AND-run on CONDx).
- [x] ✅ **M3 — Logical connectors are dead code. FIXED.** `1205-PARSE-CONNECTOR` tested
      for `.AND.`/`.Y.`/`.OR.`/`.O.`, but `1530-GET-WORD` only broke on `,` `/` and blank, so the
      token actually read was `.AND.20` (connector glued to the next operand) and never matched.
      Connectors worked **only when written surrounded by blanks** — which is how negative test N8
      writes them, and why nothing caught it. The manual never writes them that way.
      Two further defects surfaced while fixing it, both silent:
      - `WS-GROUP-NO` advanced once per **card** and `3250-EVAL-GROUP` chose one family for the
        whole card ("any `A` connector ⇒ AND-fold everything"), so the manual's mixed examples
        (`GT,4000.AND.LT,5000/GT,6000.Y.LT,10000`, sheet 8) would have ANDed all four conditions.
      - `1210-PARSE-COND` performed the condition parser **once** instead of looping, so
        `COND1 1,EQ,'A'/1,EQ,'B'` parsed the first condition and **discarded the rest of the card
        without a diagnostic** — the flag never fired for `B`.

      **Decision D0.8 — connector/run model (sheet 8).** "…may not be specified together in one
      connection of conditions. The use of `/` is equivalent to the `.O.` connector" is read as:
      a card is a **disjunction of runs**; `/` closes the current run and opens a new one (so the
      family may change across it); `.AND.`/`.Y.` and `.OR.`/`.O.` chain conditions *inside* one run
      and may not be mixed there. Runs are OR-ed by `3200-EVAL-FILTERS`, which is exactly why `/`
      and `.O.` are equivalent in effect. This makes every printed example legal, gives the
      sum-of-products reading the sheet-8/sheet-9 examples plainly intend, and keeps
      `A .AND. B .OR. C` (one run, no `/`) an error — so negative test **N8 still passes**.

      Implementation: new `1535-GET-CONNECTOR` scans a connector as a first-class token
      (`SC-TYPE = "C"`) even when glued to its operands, with pre-subtracted ref-mod bounds and its
      own `SC-CLEN` (I/J/K/L are held across `1500-GET-TOKEN` by callers such as
      `1376-PARSE-TIT-MAP`); `1205` advances the group on `/`; `1210` loops like `1200`.
      INCON now rejects a connector token explicitly rather than misparsing it — see M17.
      **Tests: I17–I21** (AND-fold, OR-fold, OR-of-ANDs across `/`, family switch across `/`,
      CONDx group), all five new since the fold paths had never once been executed. *(H8-6 now OK;
      H8-7 and H9-5 fall through to M1.)*

      **Follow-up, same day — a third silent defect.** `3510-SET-COND-FLAGS` ignored `CT-GROUP`
      and `CT-CONN` altogether and OR-ed every COND condition of a card, so
      `COND1 1,EQ,'A'.Y.2,EQ,'1'` raised the flag on *any* record matching *either* test. Test I21
      had missed it by using `/` (OR), which an OR-everything implementation satisfies by accident.
      `3510` now walks groups and folds each through the new `3550-EVAL-COND-GROUP` (the `3250`
      logic against the `WS-SRC` unit buffer). **Test I21b.**

      **Follow-up 2 — `1530-GET-WORD` had to learn about connectors too** (found while closing M2):
      a connector glued to an *unquoted* operand, as in `GT,2.Y.LT,5`, made the word scanner read
      `2.Y.LT`. Quoted operands had hidden this because `1510-GET-QUOTED` stops at the closing
      quote. The match is now a side-effect-free `1536-PEEK-CONNECTOR` used by both
      `1535-GET-CONNECTOR` (emit the token) and `1530-GET-WORD` (end the word). `12.5` is
      unaffected — `.5` is not a connector.
- [x] ✅ **M4 — ACUM numeric literal is `Cod.op,num`, not `op,L,num`.** G5 introduced an `L` format
      letter that the manual does not have; the manual's two-token form is rejected with
      `ACUM FORMAT MUST BE P Z S B L`. Accept a bare numeric second token as the literal (keep `L`
      as a tolerated synonym). *(H10-1, H10-2, H10-5, H10-6 — all now OK.)*
      **FIXED.** One arm in `1221-PARSE-ACUM-OP`: a leading digit, `-` or `.` in the
      operand position is the literal itself (a format is always `P/Z/S/B/L`, so there is no
      ambiguity). `L` is kept as a tolerated synonym.

      **It exposed a pre-existing division bug.** `3525-RUN-ONE-ACUM` divided by `DN-VAL` where
      every other operator uses `DN-OPND` — and the literal branch only ever sets `DN-OPND`. So
      division by a literal silently divided by *the previous field operand*: `+,Z,1,3//,3` on
      "150" returned 1 (150/150) instead of 50. The same typo made division by a **scaled** field
      use the unscaled integer. The zero-check one line above already used `DN-OPND`, which is what
      identified it as a typo rather than intent. Note the old `L` form failed identically, so this
      had been broken since G5 and no test covered it.
      **Tests: I36–I38** (literal multiply, literal divide, and the sheet-10 `ACUM36`
      "$ Ley 18188" chain `(150+50)/100`).
- [x] ✅ **M5 — `FIELD EC=xy`** (per-card override of same-record / different-record line spacing,
      sheet 11) is not implemented at all. *(H12-1)*
- [x] ✅ **M6 — S-prefixed *input* offsets.** The `S` prefix meaning "field lives in SYSUT3" is
      documented for `FIELD`, `CONV` and `INCON` inputs (sheets 11, 13, 28, 32, 34). The engine only
      honours `S` on **output** positions. *(H12-4, H28-3, H33-6)*
- [x] ✅ **M7 — Only 4 print lines instead of 9.** `PRT-LINE OCCURS 4` and `1236-PARSE-OUT-TOKEN`
      handle none/`S`/`T`/`C`; the manual defines nine lines with prefixes `S T C Q X P O N`.
      *(H12-4)*
- [x] ✅ **M8 — Plain `'literal',so` rejected as the first FIELD operand group** with
      `LITERAL FIELD REQUIRES CL`; it is accepted in later groups. `'literal1',so` (no `CL`) is a
      documented form on both sheet 11 and sheet 32. *(H33-2, H33-3, H33-4)*
- [x] ✅ **M9 — Omitted `conv` must default to MOVE.** `FIELD 1,80,,1` → `UNKNOWN CONVERSION:`;
      sheets 11 and 32 both mark `conv` optional and `M` "assumed". *(H33-1)*
      **FIXED** — one `WHEN SC-TLEN = 0` arm in `1235-PARSE-CONV-TYPE`. It only became
      reachable on H12-3/H33-1 after M27 stopped discarding their later groups. **Test I35.**
- [x] ✅ **M10 — A quoted `'/'` is mis-tokenized as a group delimiter.** *(H12-5)*
- [x] ✅ **M11 — CONV tables inline in SYSIN.** `DD=ddname` is optional in the manual: when omitted,
      the table rows follow the CONV card inside SYSIN (this is how 6 of the 10 printed CONV
      examples are written). The engine hard-rejects with `CONV REQUIRES DD=DDNAME FIRST`. This is
      the largest single gap. *(H14-1, H14-3, H35-1, H35-4 — all now OK.)*
      **FIXED.** `DD=` is now optional; without it the entry is flagged `CV-INLINE` and
      `1000-PARSE-SYSIN` switches to row-collection mode: each following card that is **not** a
      control card becomes a row (`1060-INLINE-CONV-ROW`), cut by the `SiA`/`SiF` columns from the
      CONV card exactly as the file loader does. `1050-IS-OPCODE` decides where the table ends; a
      blank card, a comment, a recognised op-code or EOF closes it. `2500-LOAD-CONV-TABLES` splits
      into a dispatcher plus `2510-LOAD-ONE-CONV` and skips inline entries, and a parse-time guard
      requires an inline table's argument/function to fit inside the 80 card columns.
      *Known ambiguity, inherent to the format:* a table row whose column-1 word happens to spell
      an op-code ends the table early — the original utility had the same exposure.
      **Tests: I39, I40** (both verbatim from manual sheet 14 — the sex decode with its
      blank-argument fall-through row, and the `/INT` age table).

      *Mistake worth recording:* the first cut used plain `PERFORM 1050-IS-OPCODE` on paragraphs
      that contain `GO TO …-EXIT`, so control fell straight through into the following paragraphs
      and the whole deck mis-parsed. The codebase convention is `PERFORM … THRU …-EXIT` — follow it
      for any paragraph with an early exit.
- [x] ✅ **M12 — `CONVx` condition-gated conversions** (x = 1–8) are an unknown op-code.
      *(H14-2, H14-4, H35-2, H35-5 — all now OK.)*
      **FIXED.** Dispatch widened to `WS-OPCODE(1:4) = "CONV"`, the digit parsed into a
      new `CV-FLAG`, and `3800-RUN-CONVS` gates on `CFLAG(CV-FLAG(I))` — using the nested-IF form,
      because COBOL's `OR` does not short-circuit and a single condition would evaluate `CFLAG(0)`
      when the flag is 0 (the same trap already documented in `3520`/`3700`).
      **Tests: I40** (gated conversion fires) and **I41** (same card, flag off, leaves the field
      unconverted).
- [x] ✅ **M13 — `CONV TITx/` prefix** — apply the conversion into title line x. *(H14-5)*
- [x] ✅ **M14 — CONV output-position prefix** — print-line select in OSLISTA, SYSUT4 in OSGENER.
      *(H35-3)*
- [x] ✅ **M15 — Multi-level CORTE cards carrying more than one `ID='…'`.** `1255-EXTRACT-ID-LIT`
      pre-extracts only the first, so the remaining literal text corrupts the operand stream.
      *(H15-1)*
      **FIXED as a side effect of M27** — `1255` blanks each `ID='…'` after copying it,
      so once `1250` became a per-level loop the calls hand the literals out in card order. No
      change to `1255` itself was needed. **Test I34.**
- [x] ✅ **M16 — CORTE `I,s02`.** `I` is parsed and then `CONTINUE`d, and the following `s02` number
      falls through to `CO-SO1`, silently overwriting the `ID=` output position. Both the "print the
      breaking field" behaviour and the position corruption need fixing. *(covered by H15-1/H15-3;
      the corruption is silent, so add a behavioural assertion when fixing.)*
- [x] ✅ **M17 — INCON connectors. FIXED.** Same tokenizer root cause as M3, plus the
      manual's inversion: inside INCON `/` means **AND** ("el separador / equivale a .Y.") while in
      RCIN/RCOUT/COND it means OR. *(H28-2, H28-5, H28-6 — all now OK.)*

      The semantic consequence is the interesting part. `/` and `.Y.`/`.AND.` separate
      **independent checks**, each individually violable — which is what the engine already did, so
      that half needed no change. `.O.`/`.OR.` instead builds **alternatives**: sheet 28's
      `18,,'1'.O.18,,'3'.O.18,,'S'` says the field must be one of a set, so a failing alternative
      is *not* an inconsistency and the group is reported only when every alternative fails.
      Rules now carry `IC-GROUP`; `3430`/`3460` drive a small state machine
      (`3439-INCON-GROUP-INIT` → `3438-INCON-STEP` → `3437-INCON-GROUP-CLOSE`) that folds each
      group and logs at most once per group through the extracted `3445-LOG-INCON` (logging came
      out of `3440`, which now only evaluates and corrects). Group boundaries are detected from
      `SC-DELIM` *after* the rule, because `1540-EAT-DELIM` consumes a `/` as the previous token's
      delimiter rather than surfacing it as a token.

      **Decision D0.9 — only relational rules may be `.O.` alternatives.** The correcting type
      codes (`ND`/`AB`/`ANB`) rewrite bytes in place, and the manual defines no semantics for
      correcting an alternative that was *not* the one satisfied. Every `.O.` group the manual
      prints is relational, so the restriction costs nothing and is enforced in
      `1600-VALIDATE-CONFIG`.
      **Tests: I28–I30** (alternation reports once, `/` reports independently, corrector-in-`.O.`
      rejected).
- [x] ✅ **M18 — OSGENER `TIT` card.** Sheet 30 defines `TIT {Lnn},'literal'` for OSGENER as the
      SYSLIST assembly-error report heading (requires a preceding GENER). **Decision D0.2 is wrong
      on this point** and must be amended: TIT is valid in *both* modes, with different syntax and a
      different target (OSLISTA: up to 9 report headings; OSGENER: one SYSLIST heading).
      *(H30-1, H30-2)*
- [x] ✅ **M19 — `FIELD Ay,formato`** with a bare `B`/`P`/`Z`/`S` output-format letter is rejected
      with `UNKNOWN CONVERSION: B`. *(H33-5)*
- [x] ✅ **M20 — `FIELD AN,formato`** — transfer the written-record counter to the output (sheet 32).
      *(H33-7)*
- [x] ✅ **M21 — Missing FIELD input-length caps.** Sheet 11 gives MOVE ≤ 132 and HEXA ≤ 64;
      `1610-VALIDATE-FIELD` enforces only UNPK ≤ 8 and mask ≤ 18 digits.
- [x] ✅ **M22 — Bare `FN` / `FA` on TIT** (date at default column 91). *(H6-6, H6-7)*
- [x] ✅ **M23 — TIT field map with omitted `conv`** — `(32,5,,21)` → `UNSUPPORTED TIT MAP
      CONVERSION`; should default to MOVE like every other `conv`. *(H6-4)*
- [x] ✅ **M24 — TIT literal continuation onto the next card.** Sheet 3 explicitly exempts TIT from
      the "continuation card must repeat the op-code" rule, and sheet 6 example 3 shows a literal
      opened on the TIT card and closed on the following card. The engine reports
      `UNTERMINATED LITERAL`. *(H6-3)*
- [x] ✅ **M27 — Multi-group cards parse only their FIRST `/`-separated group. FIXED.** `1100-PARSE-CARD`
      calls `1230-PARSE-FIELD` / `1250-PARSE-CORTE` **once per card**, with no loop over the `/`
      groups, so `FIELD 1,3,M,1/4,3,M,10` registers one operation and **silently discards the
      rest of the card**. Verified: that card emits `AAA` at column 1 and nothing at column 10.
      Sheet 33 is explicit — "las operaciones de selección de campos se realizarán en el mismo
      orden en que aparecen en las tarjetas de control" — and nearly every FIELD, CORTE and CONV
      example in the manual is multi-group.
      **Why nothing caught it:** `tests/run_sim.sh` writes one group per card (lines 61–64, 73–74), so
      the golden baselines are blind to it, and a dropped group produces *no card error*, so the
      conformance suite scored those cards as PASS.
      **Consequence for Phase 9 scoring:** a PASS in `tests/manual_examples.sh` means "the card was
      accepted", which for a multi-group card is weaker than "the card was honoured". The affected
      PASSes (H12-2, H12-3, H15-3, H15-4, H16-1…3, H27-x, H33-x) must be re-verified with
      behavioural assertions once this is fixed. Same class as the `1210-PARSE-COND` defect found
      under M3. **Found while building the M26 test.**

      **Fix.** `1230-PARSE-FIELD` and `1250-PARSE-CORTE` became driver loops over new group
      paragraphs (`1231-PARSE-FIELD-GROUP`, `1251-PARSE-CORTE-LVL`), matching the pattern
      `1200`/`1210`/`1220`/`1260`/`1320` already used; each returns its speculative table entry if
      the card is exhausted. Two boundary bugs had to be fixed for the loops to be safe:
      - `1236-PARSE-OUT-TOKEN` now consumes sheet 32's optional trailing `,long` (into
        `FT-OUTLEN`, overriding the width G6 derives from a trailing digit on an XY token). Without
        it the loop read that width as the *next* group's offset. The `'lit',CL` branch takes its
        fill width from there instead of doing its own unconditional read, which had the same bug.
      - `1256-PARSE-CORTE-OPTS` ran to end of card, swallowing the following levels' operands as
        spacing/position values; it now stops at a `/`.

      **This also closed M15 for free**: `1255-EXTRACT-ID-LIT` blanks each `ID='…'` after copying
      it, so one call per level hands them out in card order.

      **Two conformance cards that had been scoring PASS immediately started FAILing** once their
      later groups were actually parsed — precisely the weak-PASS effect predicted above. Both were
      already-known gaps hiding behind the truncation: H12-3 and H33-1 on M9 (empty `conv`), H12-2
      on M7 (the `Onnn` 8th-print-line prefix). H12-3 and H33-1 pass now that M9 is closed.
      **Tests: I32–I34** (two FIELD groups; four mixed groups including two `CL` fills; two CORTE
      levels each with its own `ID=`).
- [x] ✅ **M26 — Input record buffer is only 800 bytes. FIXED.** `IN-REC PIC X(800)` (:345) and the
      `> 801` guards in `1600-VALIDATE-CONFIG` reject offsets the manual itself uses: sheet 9
      example 5 tests column **810**, sheet 33 example 6 reads column **1062**. The 800 figure is
      the **GENER** assembly-area size (ten 80-byte cards) and should not bound SYSUT1/SYSUT3
      records, which the manual leaves unconstrained apart from "no SPANNED". Found while closing
      M1. *(H9-5 now OK; also unblocks H33-6 once M6 is fixed.)*

      **Decision D0.10 — the input record is `X(32760)`**, the largest non-spanned QSAM record an
      MVS dataset can hold, so no legitimate LRECL is ever rejected (~64 KB of working storage
      across `SYSUT1-REC`/`SYSUT3-REC`/`IN-REC`/`WS-SRC`/`WS-PREV-SRC`/`SEC-REC`). `G-BLOCK` stays
      **800** — ten 80-byte slots is a real manual constraint (sheet 27), not a record limit.
      Raising the buffers alone would have been dishonest: every card offset was `PIC 9(4)`, so an
      offset above 9999 truncated **silently** through `1550-TOKEN-TO-NUM`'s 6-digit `H-NUM`. The
      twelve input-record offsets (`CT-/AT-/FT-/CV-IN/CO-/IM-OFF`, `G-KOFF`, `G-COFF`, `P-OFF1`,
      `K-OFF1`, `K-OFF2`, `TM-OFF`) are now `PIC 9(5)` and the scratch subscripts `I`–`N` are
      `PIC 9(6) BINARY` so the `offset + length` sums cannot wrap. Offsets that address only a
      card or a table row (`IC-OFF`, `P-OFF2`, `CV-ARGOFF`, `CV-FUNOFF`, `CV-OUTOFF`) keep their
      narrower widths and their own guards. All nine `> 801` guards became `> 32761`.
      **Tests: I31** (reads columns 810 and 1062); **N9** re-pointed at the new boundary (its old
      offset 795 is now legitimately in range).
- [x] ✅ **M25 — Mandatory first title line.** Sheet 6: line 1 is always printed (unless `CARRO` is
      coded) and carries the user identification legend plus `-PAGINA XXXXX` from position 110. The
      engine tracks `PAGE-NO` but never renders the legend or the page number.

### Decisions to re-open

- [x] **D0.9 — only relational INCON rules may be `.O.` alternatives**
      (recorded in full under M17 above): the correcting types rewrite bytes in place and the
      manual defines no correction semantics for a losing alternative.
- [x] **D0.8 — connector/run model** (recorded in full under M3 above): a
      condition card is a disjunction of runs; `/` opens a new run and may change the family;
      `.AND.`/`.Y.` and `.OR.`/`.O.` chain inside a run and may not be mixed there.
- [x] ✅ **D0.2 AMENDED** — `TIT` is **not** OSLISTA-only. Sheet 30 defines it for
      OSGENER as the SYSLIST assembly-error heading, with its own syntax `TIT {Lnn},'literal'`
      (no line index, requires a preceding GENER). The corrected matrix is:
      **PRINT / CARRO / CORTE / IMCOR** = OSLISTA-only; **GENER / CODIG / INCON / PESQIN /
      PESQOUT / COPY** = OSGENER-only; **CLAVE, TIT, RCIN/RCOUT, COND, ACUM, FIELD, CONV** = both
      (TIT with different syntax and a different target per mode). Implemented in `1900-MODE-GATE`
      and `1370-PARSE-TIT`; the heading is written to SYSLIST from `0000-MAIN` ahead of any
      violation line.
- [ ] **D0.1–D0.7 re-check.** D0.1 (SYSUT5 routing) is consistent with sheet 21 ("records *without*
      inconsistencies belonging to a group that could not be correctly assembled") and with the
      sheet-36 flowchart — **confirmed, no change**. D0.3–D0.7 are implementation decisions the
      manual does not speak to — unaffected. The remaining doc-derived judgements should be
      re-read against the translation as the M-gaps are closed.

## Phase 10 — Validation against real mainframe output ✅ **COMPLETED**

Phases 0–9 measured the engine against a *reading* of the manual. This phase measures it against
the **genuine 1984 utility's actual output**: `private/` holds the input datasets, the expected
outputs and the JCL (`jcl.txt`) of a real production personnel job, ~34 MB in all.

**The job's dataset names and control cards are confidential**, so none of them appear in the
published tree. `tests/mainframe_check.sh` holds only the mechanism and sources its step table
from `private/<job>/mf-steps.sh`, located by glob so that not even the job's name is committed.
Adding or changing a step never touches a published file.

- [x] **10.1 — `tests/mainframe_check.sh`** replays the OSGENER steps of that job and diffs our
      output against the mainframe's. **8 steps, 8 PASS.** Wired into `make test`; `make mf-tests`
      runs it alone; it **skips cleanly** when the confidential data is absent.
      Byte-exact: STEP21, STEP23, STEP27, STEP33, STEP35, STEP37.
      Exact apart from two records carrying an embedded `X'00'` as data: STEP03, STEP05.
      STEP41 cannot be checked — its output dataset was not captured.
- [x] **10.2 — M30 fixed** (below).
- [x] **10.3 — Simulation deck rebuilt** so the golden baselines defend the Phase-9 features
      instead of being blind to them (see below).

### M30 — `COPY` bypassed every record filter

- [x] ✅ **M30 — `COPY` short-circuited ahead of PESQ/CLAVE/RCIN. FIXED.**
      `3000-PROCESS-RECORD` tested `COPY-CNT > 0` **first** and jumped straight to the writer, so
      `RCIN 1,,'E' / COPY` copied the whole file. The sheet-36 flowchart puts COPY *after*
      PESQIN/PESQOUT → CLAVE → RCIN/RCOUT, and that is now the order.
      **Found immediately** by the first real-mainframe replay (JCL STEP23 returned 15560 records
      where the mainframe produced 5706). No synthetic test had caught it because the manual's own
      examples never combine a filter with `COPY` on one card — only real production decks do.
      Now byte-exact against the mainframe.

### Notes on the transcoded data (not defects)

- **EBCDIC collation.** Both SYSUT6 probe datasets open with a descriptive text record. In EBCDIC
  letters sort **below** digits, so on the mainframe those files were correctly ordered for the
  sorted merge; transcoded to ASCII, letters sort **above** digits and the same record blocks the
  merge. The step table drops that header record, after which the merge reproduces the mainframe
  result exactly. Supporting an EBCDIC collating sequence for key comparisons would be the
  alternative; it is not needed for any manual-documented behaviour and is left open.
- **Embedded `X'00'`.** A few records carry a NUL byte as data. The original datasets were
  `RECFM=FB` with no record terminators, so that was ordinary data. **This is host-dependent:**
  the Linux/Debian GnuCOBOL build round-trips those records perfectly — verified in the container,
  where the affected steps are byte-exact with no filtering at all — while the Windows build drops
  them. The affected comparisons therefore exclude those records on both sides so the suite is
  green on either host, and the exclusion is reported in the test output.
- **Concatenated DDs.** `//SYSUT1 DD ... // DD ...` concatenation is emulated by concatenating the
  files before the run, which is what MVS does.

### Simulation deck rebuilt (10.3)

`tests/run_sim.sh` previously wrote **one operand group per card**, which is exactly why the golden
baselines were blind to M27 for so long. Both decks now use multi-group cards and exercise the
Phase-9 features end to end, so the four baselines defend them:

- OSGENER: multi-group `FIELD` (M27), omitted operator (M1), omitted `conv` (M9), plain
  `'literal',so` with no `CL` (M8), `AN` record counter (M20), `NO` validation conversion (M29),
  condition-gated `CONV2` over an **inline SYSIN table** (M11/M12), `S`-prefixed SYSUT3 input
  offset (M6), `.O.` INCON alternation (M17).
- OSLISTA: `TIT` literal continued on the next card (M24), title field map with omitted `conv`
  (M23), ACUM numeric literal in the manual's two-token form (M4), print lines beyond line 2
  (M7), `CORTE I,so2` breaking-field echo (M16), two break levels on one card each with its own
  `ID=` (M15/M27).

A **new SYSUT3 dataset** was added — `CLAVE` two-file matching had no end-to-end coverage at all
before this. Only `sysut2.dat`/`sysut2_lista.dat` baselines changed, and only as the new cards
require.

⚠ **Open question raised by that coverage:** in GENER mode the block is flushed when the batch key
changes, by which point the `CLAVE` pairing has already advanced to the *next* key's SYSUT3 record —
so an `S`-prefixed FIELD inside a GENER batch reads the following batch's secondary record. The
current behaviour is now locked by a golden baseline, but the manual does not say what it should
be. Revisit if a real deck ever combines `GENER` with `S`-prefixed offsets.

## Phase 11 — A third-party deck, with SORT as the oracle ✅ **COMPLETED** (2026-07-29)

Phase 10's evidence is the strongest in the repo but it is *ours*: one job, one site, and its
data cannot be published. This phase adds a much smaller piece of evidence with a property
Phase 10 lacks — it is **entirely external, and public**.

**Source:** [`Nazgonzalezz/JCL-practica` → *cambiar OSGENER por un SORT*](https://github.com/Nazgonzalezz/JCL-practica/blob/main/cambiar%20OSGENER%20por%20un%20SORT),
a JCL practice exercise that replaces an OSGENER field-selection step with an IBM SORT step.
It therefore carries the OSGENER deck **and** the `OUTREC` written to reproduce it byte for byte:

```
SELEC      199,2,PZ,5,3/';',8        5:199,2,PD,TO=ZD,LENGTH=3
SELEC      4,3,PZ,26,5              26:4,3,PD,TO=ZD,LENGTH=5
```

Somebody else, working from a working system, wrote down which byte lands where and how wide
each packed→zoned result is. That is an oracle we did not author, and it confirms independently:
the `2n-1` digit width of an n-byte packed field, the left zero fill, the `'literal',So` group,
and the placement of seven selections into one delimited 30-byte record — a shape **no example in
the manual exercises**.

**Provenance, recorded rather than smoothed over:** the deck's op-code is `SELEC` and its DDs are
`SYSUT` / `SYSLST`, so it is a **sibling installation's** OSGENER, not the SCD 1/84 one. The
operand grammar, however, is character-for-character sheet 32's `FIELD` — `Si,long1,conv,So,long`,
`'literal',So`, `/` between groups, `PZ` among the XY codes. An unrelated site coding the identical
grammar is corroboration of the manual's reading; it is *not* licence to add `SELEC` as an alias,
and case T8 pins that the foreign op-code is diagnosed rather than silently dropped.

- [x] **11.1 — `tests/thirdparty_deck.sh`**, 9 cases, **9 PASS**. Wired into `make test` and CI;
      `make deck-tests` runs it alone. Fixture is 3 records of 230 bytes, packed fields built from
      printable bytes (`X'41' X'53' X'4C'` = `"ASL"` = +41534) so it stays a text file.
      - T1 the deck itself, one `FIELD` card per original `SELEC` card, diffed against the
        record the `OUTREC` specifies.
      - T2 the same seven groups as three continuation cards — identical output.
      - T3 the same cards in reverse order — identical output (targets are disjoint). Also a
        regression guard for M27-shaped defects: dropping "all but the first group" would drop a
        *different* group here than in T1.
      - T4 with only the first card, nothing but its four bytes appears — the output record is
        built, not copied.
      - T5/T6 `PZ` widths: 2 packed bytes → exactly 3 zoned digits, 3 → exactly 5.
      - T7 declared output wider than the value → left zero fill.
      - T8 `SELEC` rejected with `UNKNOWN OP-CODE`.
      - T9 3 records read / 3 written.

**No engine change was needed** — every case passed on the first replay, which is the result this
phase was hoping for and could not assume.

⚠ **Behaviour brushed against, deliberately not asserted:** a negative packed field converted `PZ`
loses its sign — `7100-ENCODE-NUMERIC` moves digits only for `Z` output and never applies an
overpunch, so `X'41534D'` (−41534) and `X'41534C'` (+41534) both render `41534`. On IBM, `PD→ZD`
carries the sign in the zone of the last byte. The deck's data is unsigned, the manual states no
rule, and no evidence in the repo settles it, so nothing here locks the current behaviour in.
Revisit if a real deck ever converts a signed field to zoned.

## Review Gate

- [x] All Phase 0 decisions documented with rationale.
- [x] Unit harness green; integration outputs match the redesigned fixture byte-for-byte.
- [x] No loop iterates past its parsed-entry count; no file read outside the coordinator; UNPK is nibble-arithmetic only.
- [x] SYSPRINT/SYSLIST content matches manual behavior (card echo, first-5 audit, error labels).
- [x] All code and comments in English (verified by sweep).
- [x] `make lint` at 0 warnings; every statement with a dialect-valid scope terminator uses it explicitly (DISPLAY excepted — no `END-DISPLAY` in MVS COBOL).

---

## Status history

**Initial bring-up** — engine written (~2500 lines), compiled clean under `-std=mvs`. Six bugs found and fixed during bring-up:
1. `UNSTRING DELIMITED BY ALL SPACE` truncated operands at the first embedded blank.
2. `H-KEY2(1:1)` aliased as AND/OR family flag and comparison buffer — RCIN always false.
3. Unsigned display `IX-LVL` in downward PERFORM VARYING — infinite loop at EOF.
4. `7600-EDIT-NUM` clobbered caller loop variables — IMCOR wrote through garbage subscripts.
5. Stale scanner state made the test-before UNTIL skip RCIN/ACUM cards that weren't the deck's first card.
6. Breaks fired after accumulation — totals bled one record across groups.

**Second review** — 7 defects fixed:
1. COPY stride off-by-one vs PRINT interpretation.
2. Subscript-0 `CFLAG(0)` reads (COBOL OR doesn't short-circuit) in 3520/3700.
3. `1240` invalid ref-mod on truncated CONV card.
4. `CO-ID` X(40) overrun on long `ID='...'` literals.
5. `1366` invalid ref-mod on valueless keyword (`FR=`).
6. IMCOR F-kind fields read the new group's record — added `WS-PREV-SRC`.
7. `Tnnn`/`Cnnn` output prefixes silently discarded in OSGENER — now a parse error.

**Hardening pass** — 6 edge defects fixed, all with verified error paths:
1. FILE STATUS checked after every OPEN (rc=16, processing suppressed on failure).
2. CONV geometry validated at parse time (lengths ≤ 40, offsets ≤ 256).
3. Hex literals: odd length and invalid digits are card errors; lowercase accepted.
4. Numeric operands > 6 digits are card errors (no silent truncation).
5. Grand-total CANT counts processed units, not raw records read.
6. S-offset conditions without CLAVE emit a SYSPRINT warning.

**Lint-clean pass** — `make lint` driven from 294 warnings to **0**:
1. **Real bug**: `ASSIGN TO WS-CONV-DDNAME` was interpreted under `-std=mvs` as the assignment-name literal `'DDNAME'` — dynamic CONV DD names never worked. Fixed with `ASSIGN TO DYNAMIC`; CONV now exercised end-to-end in the simulation (country-name lookup at col 40).
2. 17 `arithmetic-osvs` composite COMPUTEs restructured into single-operation MULTIPLY/ADD/SUBTRACT statements.
3. Latent staging overruns fixed: `ED-OUT` X(24)→X(256) (MV/CL/HEXA/UNPK could exceed 24), `EN-LEN` 9(2)→9(3), print-line end-position checks.
4. New `1600-VALIDATE-CONFIG` parse-time bounds pass: every offset/length pair validated against its buffer (COND/ACUM/FIELD/INCON/GENER/CLAVE/PESQ/CORTE/IMCOR/CONV), plus conversion-specific caps (UNPK ≤ 8 bytes, edit masks ≤ 18 digits). This partially covers item 6.4.
5. Two warning classes suppressed with documented rationale in the Makefile: `-Wno-terminator` (see the terminator pass below for the final policy) and `-Wno-possible-truncate` (advisory only — numeric MOVE truncation semantics are identical on IBM MVS COBOL / `TRUNC(STD)`; intentional nibble/digit staging triggers it; semantic bounds enforced by #4). A `make lint-extra` advisory target counts the suppressed classes for review when adding new code.

**Scope-terminator pass** — the code now uses an explicit scope terminator on **every statement that has one in MVS COBOL / COBOL-85**:
1. Dialect facts established empirically: IBM COBOL for MVS & VM is COBOL-85-level, so `END-IF/END-PERFORM/END-EVALUATE/END-READ/END-ADD/END-COMPUTE/END-SUBTRACT/END-MULTIPLY/END-DIVIDE/END-STRING/END-UNSTRING/END-WRITE/END-CALL` are all valid (`-std=mvs-strict` accepts them — 0 rejects), while **`END-DISPLAY` is a MF/GnuCOBOL extension rejected by `-std=mvs-strict` and `-std=cobol85`**.
2. **252 terminators inserted** across all sources (72 END-ADD, 70 END-COMPUTE, 29 END-WRITE, 24 END-STRING, 21 END-SUBTRACT, 21 END-MULTIPLY, 13 END-DIVIDE, 2 END-CALL) using a Perl transformer driven by the compiler's own `-Wterminator` warning list, applied bottom-up; one mis-nested site (COMPUTE inside a one-line `IF … END-IF.`) caught by the compiler and restructured by hand.
3. Final policy: only the 13 `DISPLAY` statements remain unterminated (no valid terminator exists in the dialect); `-Wno-terminator` is kept solely for them, with the rationale recorded in the Makefile and `docs/user-guide.md` §10.
4. Post-pass checks: no line exceeds column 72; `-std=mvs-strict` clean for all inserted terminators.

**Test-completion pass** — plan items 6.2/6.4/6.5 closed with `tests/run_tests.sh` (21 tests) + `tests/golden_check.sh` (4 baselines), both wired into `make test`. Building them surfaced and fixed **two more real bugs**:
1. `4100`/`4200` overwrote `OUT-MAIN`/`PRT-LINE(1)` with the default record copy AFTER `3800-RUN-CONVS` had written lookup results — CONV output was clobbered whenever no FIELD card was present (default copy moved into `3700` before the CONV pass; exposed by test I3).
2. The ACUM division operator `/` was consumed by the tokenizer as a group delimiter, so `ACUM1 /,…` was rejected as a card error (empty-token-with-`/`-delimiter now recognized as the operator; leftover comma skipped; exposed by test I1).

**Phase-8 gap-closure pass** — all eight functional gaps (G1–G8) implemented; engine suite grew to 29 tests (added I9–I16). Two bugs surfaced and fixed while building the tests:
1. `3700`/`4100`/`4200` copied the default record into the output area *after* `3800-RUN-CONVS`, clobbering CONV lookups when no FIELD card was present — the default copy moved ahead of the CONV pass.
2. `4265-RENDER-TIT` initially built into `H-LINE`, which `4250` still needed for the pending detail line during a page eject — split into a dedicated `H-TITLE` buffer.

The ACUM model was also refined: accumulators now hold true decimals and IMCOR scales by the mask's decimal count (the sim's ACUM card became `Z2`, output text unchanged).

**Manual-parity pass** — the genuine SCD 1/84 publication arrived (`docs/manual/OSLSGEN.txt`). It was translated in full to `docs/manual/osgenls-manual.md`, and all 76 printed control-card examples were replayed against the real binaries (`tests/manual_examples.sh`, 93 cases). Result: **47 accepted, 46 rejected**. The rejections are catalogued as gaps **M1–M25** in Phase 9. The three most consequential findings:

1. **Logical connectors have never worked.** `.AND.`/`.Y.`/`.OR.`/`.O.` are parsed for in `1205-PARSE-CONNECTOR`, but `1530-GET-WORD` does not treat them as delimiters, so the token read is the connector glued to the following operand and the comparison always fails. Every deck in the repo uses `/` only, which is why no test caught it. Plan items 2.4 and 3.1 overstated this (M3).
2. **CONV cannot read a table inline from SYSIN** — `DD=ddname` is hard-required, but the manual makes it optional and 6 of its 10 CONV examples use the inline form (M11). `CONVx` condition gating and the `TITx/` prefix are likewise absent (M12, M13).
3. **`TIT` is valid in OSGENER** (sheet 30, as the SYSLIST error-report heading). Decision D0.2 is wrong on that point and is re-opened (M18).

Also newly known: omitted comparison operators do not default to `EQ` (M1), count-only conditions are unsupported (M2), ACUM numeric literals need a non-standard `L` marker (M4), only 4 of the manual's 9 print lines exist (M7), `FIELD EC=xy` is missing (M5), S-prefixed *input* offsets are unsupported (M6), and the mandatory `-PAGINA XXXXX` title legend is never rendered (M25).

**Verified state (pre-parity baseline, unchanged by the parity pass):** `make test` from clean → build OK, 5/5 unit TCs PASS, both simulations rc=0, 4/4 golden baselines match, **29/29 engine tests PASS**. `make lint`: **0 warnings, 0 errors**. `make check-dialects`: all four profiles clean. The `DIALECT=rm` build passes 29/29 + 4/4 golden byte-identically. Residual `-Wterminator` hits = 13 (all DISPLAY, by policy).

**Gap-closure pass** — all 29 M-gaps closed; see Phase 9.4. The conformance suite went **47 → 93 PASS, 46 → 0 XFAIL**, and the engine suite **30 → 63 tests** (I17–I49 added, plus N7/N9 re-pointed at boundaries the fixes moved). Decisions **D0.8** (connector/run model), **D0.9** (relational-only `.O.` INCON alternatives) and **D0.10** (32760-byte records, `PIC 9(5)` offsets) were taken along the way, and **D0.2 was amended** — TIT is valid in both modes.

Only one golden baseline changed in the whole pass, and only at the end: `sysut2_lista.dat` gained the `-PAGINA 00001` legend that sheet 6 requires on title line 1 (M25). It was regenerated deliberately; the other three baselines are byte-identical to their earlier form, which is the strongest evidence that 29 gap fixes introduced no behavioural drift.

**Verified state (final):** `make test` rc=0 — 5/5 unit TCs, both simulations rc=0, **4/4 golden baselines**, **63/63 engine tests**, **93/93 manual examples**. `make lint`: **0 warnings, 0 errors**. `make check-dialects`: all four profiles clean. The `DIALECT=rm` build reproduces 63/63, 93/93 and 4/4 identically.
