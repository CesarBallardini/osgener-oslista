# OSLISTA / OSGENER

[![test](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/test.yml/badge.svg)](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/test.yml)
[![lint](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/lint.yml/badge.svg)](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/lint.yml)
[![lint-strict](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/lint-strict.yml/badge.svg)](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/lint-strict.yml)
[![check-dialects](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/check-dialects.yml/badge.svg)](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/check-dialects.yml)
[![lint-extra](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/lint-extra.yml/badge.svg)](https://github.com/CesarBallardini/osgener-oslista/actions/workflows/lint-extra.yml)
[![License: MIT](.github/badges/license-mit.svg)](LICENSE)

A clean-room reimplementation of two 1984 IBM mainframe utilities — **OSLISTA** (report
writer) and **OSGENER** (file generator) — from *SCD, Centro de Cómputos, Departamento de
Ingeniería, publicación 1/84*.

Both are driven by 80-column control cards read from `SYSIN`. A single COBOL engine,
`src/OSENGINE.CBL`, parses those cards at run time and behaves as either utility; two thin
stubs select the personality.

The originals were written by **Jorge Vattuone** at the CUPED, the Argentine state's central
data-processing centre. A single paragraph in *40 años de informática en el Estado argentino*
(EDUNTREF, 2007) is the only published account of them — quoted and translated in
[**A Little History**](docs/a-little-history.md).

```sh
make            # list targets
make all        # build bin/OSGENER and bin/OSLISTA
make test       # build + every suite below
```

## Make targets

Bare `make` prints this list — `help` is the default target, so nothing is built by accident.

### Build & housekeeping

| Target | Does |
|---|---|
| `all` | Build `bin/OSGENER` and `bin/OSLISTA` (default build; runs `setup`, `osgener`, `oslista`) |
| `osgener` | Build `bin/OSGENER` only — the OSGENER stub linked with the engine |
| `oslista` | Build `bin/OSLISTA` only — the OSLISTA stub linked with the engine |
| `ostests` | Build `bin/OSTESTS`, the in-COBOL assert harness |
| `setup` | Create `bin/` (a dependency of `all`; rarely called directly) |
| `clean` | Remove `bin/`, `datasets/`, `logs/` |
| `help` | Print the target list — the default target |

Add `DIALECT=rm` to any build target to compile `-std=rm` with the RM copybooks instead of
the default `-std=mvs`: `make all DIALECT=rm`. Both produce byte-identical results.

### Test

| Target | Does |
|---|---|
| `test` | **The gate.** Builds everything, then runs the unit harness, the simulation, and all four suites below |
| `manual-tests` | The 93 manual-example conformance cases on their own |
| `mf-tests` | The real-mainframe replay on its own — skips cleanly without the private data |

`tests/run_tests.sh` and `tests/golden_check.sh` have no target of their own; they run as part
of `test`, or directly. `tests/golden_check.sh --update` regenerates the golden baselines after
an intended output change.

### Container

| Target | Does |
|---|---|
| `docker-build` | Build the Debian 13 image (the image build runs `make test`, so it fails if the suites fail) |
| `docker-test` | Build, then run every suite in the container — bind-mounts `private/` read-only **only if it exists** |
| `docker-shell` | Interactive `bash` inside the image, with the same conditional mount |

### Quality gates

| Target | Does |
|---|---|
| `lint` | `cobc -fsyntax-only -Wall -Wextra -Werror`. Any new warning is a build failure |
| `lint-extra` | Count the two deliberately suppressed advisory classes (terminator, possible-truncate) |
| `lint-strict` | Audit against `-std=mvs-strict` using the portable copybook |
| `check-dialects` | Compile every source under all four profiles: `mvs`, `rm`, `mvs-strict`, `rm-strict` |

## Continuous integration

Each target above has its own workflow, so each gets its own badge and a red badge names the
thing that broke:

| Workflow | Runs | Note |
|---|---|---|
| `test.yml` | every suite, as a matrix over **both dialects** (`mvs` and `rm`) | proves the byte-identical claim instead of asserting it |
| `lint.yml` | `make lint` | |
| `lint-strict.yml` | `make lint-strict` | |
| `check-dialects.yml` | `make check-dialects` | |
| `lint-extra.yml` | `make lint-extra` | **advisory — cannot fail.** The badge is green by construction; the useful output is the count, published to the run summary |

All five install the toolchain through the shared composite action in
`.github/actions/setup-gnucobol`, so they cannot drift apart. It pins `gnucobol3` rather than
the `gnucobol` metapackage, whose default could flip to GnuCOBOL 4 and silently change what
the `-std` profiles mean.

The mainframe suite reports `SKIP` in CI: its data is confidential and never pushed.

## Requirements

**On the host:** GnuCOBOL 3.x — `choco install gnucobol` on Windows, `apt install gnucobol`
on Debian. Verified on 3.2.0 (Debian 13) and 3.1.2 (Debian 12).

**Or nothing at all**, using the container. The image build runs `make test`, so a green
image *is* a green test run:

```sh
make docker-test        # build the image, then run every suite
```

The confidential job data is kept out of the build context and is never baked into the image.
`make docker-test` bind-mounts it read-only **only when it is present**, so the same command
works either way — with the data the mainframe suite runs, without it it reports `SKIP` and
everything else still passes. By hand:

```sh
docker build -t osgener-oslista .
docker run --rm osgener-oslista
docker run --rm -v "$PWD/private:/src/private:ro" osgener-oslista
docker run --rm osgener-oslista make lint check-dialects
```

## What it is measured against

| Suite | What it proves | Command |
|---|---|---|
| `tests/OSTESTS.CBL` | 5 in-COBOL asserts on the core algorithms | `make ostests` |
| `tests/run_tests.sh` | 63 behaviour, limit and negative-parse cases | — |
| `tests/manual_examples.sh` | **all 93 control-card examples printed in the manual** | `make manual-tests` |
| `tests/golden_check.sh` | 4 end-to-end simulation baselines | — |
| `tests/mainframe_check.sh` | **8 steps of a real 1984 production job, diffed against the mainframe's own output** | `make mf-tests` |

The last one is the strongest gate: everything else checks the engine against a *reading* of
the manual, that one checks it against what the genuine utility actually did. Its input data
is confidential and is not distributed — the suite **skips cleanly** when absent, so a public
clone still builds and passes everything else.

`make lint` is `-Werror`, so any new warning fails the build, and `make check-dialects` must compile under all four
profiles (mvs, rm, and both `-strict` variants).

## Layout

```
src/         OSENGINE.CBL, the two dispatch stubs, per-dialect copybooks
tests/       all suites + the unit harness + committed golden baselines
docs/        manual/  the SCD 1/84 source and its full English translation
             user-guide.md, plan.md, a-little-history.md
jcl/         RUNPROC.JCL - the MVS deck
Dockerfile   reproducible build + test environment (Debian 13)
LICENSE      MIT
private/     confidential data, git-ignored, never published
```

## Documentation

- **`docs/manual/osgenls-manual.md`** — complete English translation of the SCD 1/84 manual:
  every syntax box, all 76 printed examples, the diagrams as Mermaid, plus an appendix
  cataloguing the transcription slips in the source.
- **`docs/manual/OSLSGEN.txt`** — the authoritative original (CP437; read it with
  `iconv -f CP437` and a binary-safe `grep -a`, or the box-drawn diagrams disappear).
- **`docs/user-guide.md`** — how to write control cards, command by command.
- **`docs/plan.md`** — implementation history and every design decision (D0.1–D0.10),
  including the 29 conformance gaps found by replaying the manual and the one found by
  replaying the real job.
- **`docs/a-little-history.md`** — who wrote the originals, and why. A published history of
  computing in the Argentine state names the author (**Jorge Vattuone**) and the organisation
  (the **CUPED**), and lists a design brief that maps one-for-one onto the control cards
  implemented here.

## References

- Pablo A. Fontdevila, Arturo Laguado Duca and Horacio Cao, *40 años de informática en el
  Estado argentino*, EDUNTREF — Universidad Nacional de Tres de Febrero, 1st ed., November
  2007. The single published account of OSGENER and OSLISTA's origin is on page 37; it is
  quoted and translated in [`docs/a-little-history.md`](docs/a-little-history.md).
  - A copy is kept at
    [`docs/Cuarenta_anos_de_informatica_en_el_Estado.pdf`](docs/Cuarenta_anos_de_informatica_en_el_Estado.pdf).
  - Published for free download by **co-author Horacio Cao on his own website**, which is the
    evidence that the authors distribute it freely:
    [horaciocao.com.ar/…/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf](https://www.horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf)
    — archived in the
    [Wayback Machine snapshot of 2021-05-08](https://web.archive.org/web/20210508192023/https://www.horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf),
    which is where this copy was retrieved from. Publicly funded research.

## Files, in mainframe terms

```
SYSUT1  main input (required)        SYSUT2   main output (required)
SYSUT3  secondary input (CLAVE)      SYSUT4   secondary output (OSGENER)
SYSUT6  probe file (PESQIN/PESQOUT)  SYSUT5   rejected batches (OSGENER)
SYSIN   control cards                SYSPRINT log (required)
                                     SYSLIST  inconsistency report (OSGENER)
```

DDNAMEs resolve through environment variables, so on open systems:

```sh
export SYSUT1=./in.dat SYSUT2=./out.dat SYSIN=./cards.txt SYSPRINT=./log.txt
./bin/OSGENER
```

## License

[MIT](LICENSE) — © 2026 Cesar Ballardini.

The MIT grant covers this reimplementation, not the third-party documents distributed
alongside it:

- The **SCD 1/84 manual** under `docs/manual/` is the work of its original authors. The CUPED
  released the utilities and their documentation as public-domain software within the
  Argentine public administration, which is why it can be reproduced here in full.
- The **book** under `docs/` remains © its authors and EDUNTREF. It is publicly funded
  research, it carries no restriction on copying, and its authors distribute it free of
  charge — co-author Horacio Cao publishes the very same PDF for download on his own site,
  [horaciocao.com.ar](https://www.horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf)
  ([archived](https://web.archive.org/web/20210508192023/https://www.horaciocao.com.ar/wp-content/uploads/2015/05/08_Cuarenta_anos_de_informatica_en_el_Estado.pdf)).
  It is included here as the cited source for `docs/a-little-history.md`.
