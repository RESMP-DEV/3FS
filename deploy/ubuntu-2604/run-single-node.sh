#!/usr/bin/env bash
# Run the single-node 3FS launcher (tests/fuse/run.sh) on Ubuntu 26.04.
# Usage: run-single-node.sh <repo> <compat-lib-dir> <test-dir>
# Requires: build/bin populated (build-in-docker.sh), rxe0 up (setup-rxe.sh),
# FDB debs installed, limits from limits-99-3fs.conf active in THIS session.
set -euo pipefail

REPO=${1:?usage: run-single-node.sh <repo> <compat-lib-dir> <test-dir>}
LIBDIR=${2:?compat-lib-dir (see deploy/ubuntu-2604/README.md)}
TESTDIR=${3:?test-dir}

if [ "$(ulimit -Sl)" != unlimited ] || [ "$(ulimit -Sn)" -lt 1048576 ]; then
  echo "ERROR: memlock/nofile limits not active in this session." >&2
  echo "Install limits-99-3fs.conf, then log in through a NEW ssh connection" >&2
  echo "(rotate any ControlMaster: ssh -O exit <host>). Limits apply per login." >&2
  exit 1
fi

command -v fdbserver >/dev/null || { echo "ERROR: fdbserver not on PATH (install FDB debs)"; exit 1; }
for b in mgmtd_main meta_main storage_main hf3fs_fuse_main admin_cli; do
  [ -x "$REPO/build/bin/$b" ] || { echo "ERROR: missing $REPO/build/bin/$b"; exit 1; }
done

mkdir -p "$TESTDIR"
cd "$REPO"
exec env LD_LIBRARY_PATH="$LIBDIR" \
  bash tests/fuse/run.sh "$REPO/build/bin" "$TESTDIR"
