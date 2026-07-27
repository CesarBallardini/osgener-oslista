#!/bin/bash
# ===================================================================
# MAINFRAME REGRESSION SUITE - driver
#
# Replays steps of a real production job against the output the
# GENUINE 1984 OSGENER produced on the mainframe. This is the
# strongest validation in the repo: every other suite checks the
# engine against a reading of the manual, this one checks it against
# what the utility actually did on real data.
#
# The job's datasets and control cards are CONFIDENTIAL, so nothing
# job-specific lives in this file. It provides only the mechanism and
# sources a step table from the private data directory:
#
#     private/<job>/mf-steps.sh
#
# When that is absent - a public clone, CI - the suite SKIPS and the
# build still passes. Adding or changing steps never touches the
# published tree.
#
# Exit code: 0 = all PASS or skipped, 1 = any FAIL.
# ===================================================================
cd "$(dirname "$0")/.." || exit 1

GC_BIN="/c/ProgramData/chocolatey/lib/gnucobol/tools/bin"
if [ -d "$GC_BIN" ]; then PATH="$GC_BIN:$PATH"; fi

# Locate a private step table. Glob, so no job identifier appears here.
STEPS=""
for c in private/*/mf-steps.sh; do
    [ -f "$c" ] && STEPS="$c" && break
done
if [ -z "$STEPS" ]; then
    echo "SKIP  mainframe suite: no private/*/mf-steps.sh (confidential job data absent)"
    exit 0
fi
D=$(dirname "$STEPS")

W="tests/work-mf"
rm -rf "$W" && mkdir -p "$W"

resolve_bin () {
    if [ -x "bin/$1" ]; then echo "bin/$1"
    elif [ -x "bin/$1.exe" ]; then echo "bin/$1.exe"
    else echo "ERROR: bin/$1 missing - run 'make all' first" >&2; exit 1
    fi
}
G=$(resolve_bin OSGENER) || exit 1

PASS=0; FAIL=0; FAILED=""

# Records are compared after stripping CR and trailing blanks: the
# mainframe datasets are RECFM=FB (blank padded) while LINE SEQUENTIAL
# trims the pad. Column positions and every embedded blank are still
# compared exactly.
norm () { sed 's/\r$//; s/ *$//' "$1"; }

# Some records carry an embedded NUL byte (0x00) as data. The original
# datasets had no record terminators, so that was ordinary data.
# The Linux/Debian build round-trips those records perfectly and the
# affected steps are byte-exact without any filtering; the Windows
# GnuCOBOL build drops them. Where NUL=1 is set they are therefore
# dropped from BOTH sides so the suite is green on either host, and
# the exclusion is reported. A host-runtime difference, not OSGENER.
nonul () {
    perl -ne 's/\r$//; s/ *$//; print "$_\n" unless /\x00/' "$1"
}

note () { echo "NOTE  $*"; }

# mf <step> <expected-dataset> <sysin-deck> <input...>
#   P6=<file>  supply SYSUT6      NUL=1  tolerate NUL-bearing records
mf () {
    local step="$1" want="$2" deck="$3"; shift 3
    printf '%b\n' "$deck" > "$W/$step.sysin"
    if [ $# -gt 1 ]; then cat "$@" > "$W/$step.ut1"
    else cp "$1" "$W/$step.ut1"; fi

    SYSIN="$W/$step.sysin" SYSUT1="$W/$step.ut1" \
    SYSUT6="${P6:-$W/empty}" SYSUT2="$W/$step.out" \
    SYSPRINT="$W/$step.prt" SYSLIST="$W/$step.lst" \
    SYSUT3="$W/empty" SYSUT4="$W/$step.u4" SYSUT5="$W/$step.u5" \
    "$G" >/dev/null 2>&1
    local rc=$?

    local n
    if [ "${NUL:-0}" = "1" ]; then
        n=$(diff -a <(nonul "$W/$step.out") <(nonul "$D/$want") \
            | grep -c '^[<>]')
    else
        n=$(diff -a <(norm "$W/$step.out") <(norm "$D/$want") \
            | grep -c '^[<>]')
    fi

    # Only the step label is printed - never the dataset name.
    if [ $rc -eq 0 ] && [ "$n" = "0" ]; then
        PASS=$((PASS+1))
        printf 'PASS  %-7s %6s records match the mainframe%s\n' "$step" \
               "$(grep -c '' "$W/$step.out")" \
               "$([ "${NUL:-0}" = 1 ] && echo '  (NUL records excluded)')"
    else
        FAIL=$((FAIL+1)); FAILED="$FAILED $step"
        printf 'FAIL  %-7s rc=%s  %s differing lines\n' "$step" "$rc" "$n"
    fi
    unset P6 NUL
}
: > "$W/empty"

echo "=================================================================="
echo " Real-mainframe regression"
echo "=================================================================="

# shellcheck source=/dev/null
. "$STEPS"

echo "=================================================================="
printf ' mainframe steps: %d PASS  %d FAIL\n' "$PASS" "$FAIL"
echo "=================================================================="
if [ "$FAIL" -ne 0 ]; then echo " FAILED:$FAILED"; exit 1; fi
exit 0
