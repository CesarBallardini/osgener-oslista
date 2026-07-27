# ===================================================================
# OSLISTA / OSGENER - reproducible build and test environment
#
#   docker build -t osgener-oslista .        # builds AND runs make test
#   docker run --rm osgener-oslista          # run the suites again
#   docker run --rm osgener-oslista make lint check-dialects
#
# The confidential job data is never part of the image: the mainframe
# suite skips cleanly without it. To run that suite too, mount it:
#
#   docker run --rm -v "$PWD/private:/src/private:ro" osgener-oslista
#
# Debian rather than Alpine: the suites need bash (process
# substitution) and perl, and Debian packages GnuCOBOL with the
# dialect configs this project compiles against (mvs, rm, and both
# -strict variants), which the musl builds do not reliably carry.
# ===================================================================
FROM debian:trixie-slim

# gnucobol      - cobc + libcob + the dialect .conf files
# gcc, libc6-dev- cobc translates COBOL to C and invokes the C compiler
# make          - the build driver
# bash          - tests use process substitution; /bin/sh will not do
# perl          - tests/mainframe_check.sh filters NUL-bearing records
# diffutils     - golden and manual suites diff against baselines
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        gnucobol \
        gcc \
        libc6-dev \
        make \
        bash \
        perl \
        diffutils \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# The image is a distributed copy of the software, and MIT requires the
# copyright notice to travel with it.
COPY LICENSE ./

# Sources first, then the suites: editing a test does not invalidate
# the layer that compiled the engine.
COPY Makefile ./
COPY src/ ./src/
COPY tests/ ./tests/

# Build both binaries and the unit harness, then run every suite.
# Failing here fails the image build, so a green image is a green
# test run by construction.
RUN make all ostests && make test

# Re-run on `docker run`. Overridable: `docker run ... make lint`
CMD ["make", "test"]
