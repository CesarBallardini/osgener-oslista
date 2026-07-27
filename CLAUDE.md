# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clean-room reimplementation of two 1984 SCD mainframe utilities (SCD Computing Center publication 1/84):

- **OSLISTA** — prints reports/listings from non-VSAM SEQ/IS datasets (field selection, arithmetic, external table lookups, control-break totals).
- **OSGENER** — generates files (conditional copy, multi-card batch consolidation, consistency validation, Mod-10 check digit, two-file match/merge).

A **single unified engine** (`src/OSENGINE.CBL`) parses SYSIN control cards at runtime and behaves as either utility. **Status: fully implemented and tested** — strict COBOL-85, builds under GnuCOBOL in two dialect profiles (mvs and rm) from one source. Full history and decisions are in `docs/plan.md` (all phases + G1–G9 complete). The engine is validated against the genuine manual (`docs/manual/`) and against a real 1984 production job — see below.

## Repository layout

```
src/      OSENGINE.CBL + stubs/{OSGENER,OSLISTA}.CBL + copy/{gnucobol,rm}/
tests/    OSTESTS.CBL, run_sim.sh, the four suites, expected/ baselines
docs/     manual/{OSLSGEN.txt, osgenls-manual.md}, user-guide.md, plan.md
jcl/      RUNPROC.JCL
private/  CONFIDENTIAL, git-ignored, never published
```

## Document map

- **`docs/manual/OSLSGEN.txt`** — the genuine SCD 1/84 publication. **The authority.** CP437-encoded: read it with `iconv -f CP437` and a binary-safe `grep -a`, or the box-drawn diagrams vanish silently.
- **`docs/manual/osgenls-manual.md`** — complete English translation: all 37 sheets, syntax boxes verbatim, all 76 printed examples, diagrams as Mermaid, Appendix A cataloguing the source's transcription slips, Appendix B a quick syntax + limits reference.
- **`docs/user-guide.md`** — user-facing command reference, command by command.
- **`docs/plan.md`** — full implementation history: phases 0–10, decisions D0.1–D0.10, the 29 manual-conformance gaps (M1–M29) and the one real-job gap (M30).

## Build & Test Commands

Toolchain: **GnuCOBOL 3.2** (`choco install gnucobol`). The Makefile exports `COB_CONFIG_DIR` and `COB_CC` for the Chocolatey layout, forces `-ffilename-mapping`, and uses Windows-style PATH entries (native GNU make).

```sh
make               # lists available targets (default = help)
make all           # bin/OSGENER + bin/OSLISTA (each = stub + OSENGINE.CBL)
make all DIALECT=rm  # same, built -std=rm with the RM copybook (default: gnucobol/-std=mvs)
make ostests       # bin/OSTESTS unit-test harness
make test          # build all + unit tests + run_sim.sh + golden diff + engine suite
make lint          # cobc -fsyntax-only -Wall -Wextra; MUST stay at 0 warnings
make lint-extra    # count the two suppressed advisory classes (terminator/truncate)
make lint-strict   # -std=mvs-strict conformance audit (portable copybook)
make check-dialects  # compile all sources under mvs / rm / mvs-strict / rm-strict
make clean         # removes bin/, datasets/, logs/
```

Sources: `src/OSENGINE.CBL` (unified engine, ~3400 lines, fixed format ≤ col 72, strict COBOL-85), `src/stubs/OSGENER.CBL` + `src/stubs/OSLISTA.CBL` (thin dispatchers that CALL `OSENGINE` USING a `PIC X(7)` mode). Tests: `tests/run_tests.sh` (unit-style behavior + limits + negative-parse, currently 63 cases I1–I49 / L1–L4 / N1–N9) and `tests/golden_check.sh` (diffs the four simulation outputs against committed `tests/expected/` baselines; run-date normalized). `tests/OSTESTS.CBL` is the 5-case in-COBOL assert harness.

**Dialect portability (plan G9):** the engine is dialect-clean COBOL-85 — no intrinsic functions (date via `ACCEPT FROM DATE`+century window, digit-table lookups, `INSPECT CONVERTING`, big-endian `BINARY` redefine for byte⇄char), and early exits use `GO TO <n>-EXIT` / `PERFORM … THRU`. The only dialect-bound code is the CONV-table `SELECT`, resolved via `src/copy/gnucobol/SELCONV.cpy` (`ASSIGN TO DYNAMIC`) vs `src/copy/rm/SELCONV.cpy` (RM native), chosen by `-I src/copy/$(DIALECT)`.

DDNAMEs resolve via environment variables (`DD_SYSUT1` → `dd_SYSUT1` → `SYSUT1` → literal): `export SYSUT1=./datasets/sysut1.dat` etc.

Editing conventions: keep `make lint` at 0 and `make check-dialects` green after any change. Every statement that has a COBOL-85 scope terminator uses one explicitly (`END-IF`/`END-PERFORM`/`END-ADD`/…); only `DISPLAY` is left unterminated (no `END-DISPLAY` in strict dialects). Lines must not exceed column 72. Decisions D0.1–D0.10, the bug-fix history, and remaining minor limitations are in the plan; the user-facing command reference is `docs/user-guide.md`.

## Architecture

```
SYSUT1 (main in, req) ──┐
SYSUT3 (secondary in) ──┤
SYSUT6 (lookup, OSGENER)┼─> CORE ENGINE ─> SYSUT2 (main out, req)
SYSIN  (control cards) ─┘                  SYSUT4 (secondary out, OSGENER; FIELD "S"-prefixed output offset)
                                           SYSUT5 (orphan/reject batches, OSGENER)
                                           SYSPRINT (log, req) / SYSLIST (inconsistency report, OSGENER)
```

**Strict per-record command precedence** (manual sheets 18-19 and 36-37): PESQIN/PESQOUT match → CLAVE (SYSUT3 match) → RCIN/RCOUT filters → GENER block build → CODIG presence rules → INCON validation/correction → ACUM → CORTE → FIELD/zDVy → CONV → write (SYSUT4 if "S" prefix, else SYSUT2). Validations always precede calculations; packing transforms happen just before the final write.

**SYSIN card format**: op-code strictly in column 1, operands separated by ≥1 blank, 80 columns. Table limits: 150 conditions (RCIN/RCOUT), 125 FIELD ops, 9 accumulators, 8 COND flags, 20 CONV tables, 10 CORTE levels, 10 GENER codes.

**GENER**: consolidates consecutive cards sharing a key into an 800-byte array (ten 80-byte slots), positioned by code priority declared on the card — not arrival order. Later FIELD/CONV operate on this buffer, not raw lines.

**Key algorithms** (see the manual translation): COMP-3 unpack via nibble extraction (byte÷16 / remainder; sign nibble C/E/F=+, D=−); Mod-10 check digit with right-to-left weights 2,1,2,1… (product>9 → subtract 9); CONV `/INT` interval lookup on pre-sorted keys with fall-through to last table entry on miss.

## Mandatory Legacy Fixes (do not reintroduce)

1. **Buffer isolation**: never nest file reads inside GENER loop logic; all reads happen at one central coordinator level.
2. **UNPK**: use bitwise nibble extraction on bytes read as binary integers — never string-based tricks.
3. **Table bounds**: INCON (and similar) loops must iterate only over the count of parsed instructions, never the full allocated OCCURS space.

## Verification

`make test` is the gate: 5/5 `OSTESTS` asserts, both simulations rc=0, 4/4 golden baselines, 63/63 engine tests, 93/93 manual examples, 8/8 mainframe steps — kept green in both the `gnucobol` and `rm` dialect builds. `make lint` at 0 and `make check-dialects` clean are also required.

The doc-level contradictions the transcriptions carried (SYSUT5 routing, the unreachable `BRA0290` CODIG case, mismatched field columns) were **resolved as decisions D0.1–D0.7** and the fixture was rebuilt accordingly; see the plan. They are no longer open — do not "fix" the fixture back toward the old transcriptions' narrative.

## Real-mainframe validation (plan Phase 10)

`private/` holds a **real production job**: input datasets, the outputs the genuine 1984 OSGENER produced, and its JCL. `tests/mainframe_check.sh` (`make mf-tests`, also in `make test`) replays 8 OSGENER steps of that job and diffs against the mainframe output — **8/8 PASS**, six byte-exact. It skips cleanly whenever the confidential data is absent, so a public clone still builds and passes everything else. The suite was seeded by an independent Python reimplementation of the same utility.

**Everything job-specific is confidential** — dataset names, control cards, the job's identity. None of it may appear in a published file. `tests/mainframe_check.sh` therefore holds only the mechanism and sources its step table from `private/<job>/mf-steps.sh`, found by glob so no identifier is committed. **Add or change steps in that private file, never in `tests/`.**

This is the strongest gate in the repo, and it immediately found **M30**: `COPY` short-circuited ahead of PESQ/CLAVE/RCIN, so `RCIN … / COPY` copied the whole file. No synthetic test caught it because the manual's examples never combine a filter with `COPY` on one card — only real decks do.

Two properties of the transcoded data, both documented in Phase 10 and handled by the harness, not bugs: the SYSUT6 probe files open with a text header that is **EBCDIC-low but ASCII-high** (so it blocks an ASCII sorted merge), and two records carry an embedded `X'00'` that LINE SEQUENTIAL cannot round-trip.

## Source parity — ACHIEVED 2026-07-27

The genuine SCD 1/84 manual is in the repo: **`docs/manual/OSLSGEN.txt`**, translated in full to **`docs/manual/osgenls-manual.md`** (all 37 sheets, syntax boxes verbatim, diagrams as Mermaid, Appendix A cataloguing the transcription slips, Appendix B a quick syntax + limits reference). **The manual is the authority.**

Every printed control-card example replays against the real binaries: `tests/manual_examples.sh` (93 cases, `make manual-tests`, part of `make test`) is at **93 PASS / 0 FAIL / 0 XFAIL**. The 29 conformance gaps found by the 2026-07-27 audit (**M1–M29**) are all closed — see plan Phase 9 for each one.

Reading the manual (`OSLSGEN.txt`) needs `iconv -f CP437` and **binary-safe grep (`grep -a`)** — the box-drawn diagrams are otherwise silently dropped.

Decisions added or changed by that pass: **D0.8** (connector/run model — a condition card is a disjunction of runs; `/` opens a new run and may change family), **D0.9** (only relational INCON rules may be `.O.` alternatives), **D0.10** (records are `X(32760)`, card offsets `PIC 9(5)`), and **D0.2 amended** — `TIT` is valid in *both* modes, with different syntax and target per mode.

**When adding features, assert on behaviour, never on "the card was accepted".** Every gap in this phase hid a further *silent* defect that parse-acceptance could not see — most importantly M27, where only the first `/`-separated group of a FIELD/CORTE card was parsed and the rest was discarded with no diagnostic. Also: `PERFORM x` on a paragraph containing `GO TO x-EXIT` falls through into the following paragraphs — always `PERFORM x THRU x-EXIT`.
