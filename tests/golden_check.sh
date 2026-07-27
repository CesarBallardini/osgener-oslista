#!/bin/bash
# ===================================================================
# GOLDEN-FILE REGRESSION - plan item 6.5.
# Diffs the run_sim.sh outputs against the committed tests/expected/ set.
# The OSLISTA heading carries the run date (TIT FA) - it is
# normalized to <DATE> on both sides before comparing.
# Regenerate baselines after an INTENDED behavior change with:
#   bash tests/run_sim.sh && bash tests/golden_check.sh --update
# (run from the repository root; the scripts are committed non-executable,
#  so invoke them through bash rather than as ./tests/x.sh)
# ===================================================================
cd "$(dirname "$0")/.." || exit 1

FILES="datasets/sysut2.dat datasets/sysut5_rejects.dat \
datasets/sysut2_lista.dat logs/syslist.log"
NORM='s/[0-9]{2} [A-Z]+ +[0-9]{4}/<DATE>/'

if [ "$1" = "--update" ]; then
    mkdir -p tests/expected
    for f in $FILES; do
        sed -E "$NORM" "$f" > "tests/expected/$(basename "$f")"
    done
    echo "Golden baselines updated in tests/expected/."
    exit 0
fi

FAIL=0
for f in $FILES; do
    b=$(basename "$f")
    if [ ! -f "tests/expected/$b" ]; then
        echo "FAIL  golden: tests/expected/$b missing (run --update once)"
        FAIL=1
        continue
    fi
    if sed -E "$NORM" "$f" | diff -q - "tests/expected/$b" > /dev/null
    then echo "PASS  golden: $b"
    else
        echo "FAIL  golden: $b differs from baseline:"
        sed -E "$NORM" "$f" | diff - "tests/expected/$b" | head -10
        FAIL=1
    fi
done
exit $FAIL
