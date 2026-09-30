#!/usr/bin/env bash
# Entrypoint for the containerized single-node 3FS launcher (tests/fuse/run.sh).
# Requires: privileged, host network (rxe0 + address autodetect), /dev/fuse.
set -euo pipefail

# Bash cannot expand ${3FS_*...} names (leading digit), so read env via printenv.
BIN=$(printenv 3FS_BIN); BIN=${BIN:-/ws/build/bin}
DATA=$(printenv 3FS_DATA); DATA=${DATA:-/data}

for b in mgmtd_main meta_main storage_main hf3fs_fuse_main admin_cli; do
  [ -x "$BIN/$b" ] || { echo "ERROR: missing $BIN/$b (run the builder profile first)" >&2; exit 1; }
done
for b in fdbserver fdbcli; do
  command -v "$b" >/dev/null || { echo "ERROR: $b not on PATH" >&2; exit 1; }
done

if [ -n "$(ls -A "$DATA" 2>/dev/null)" ] && [ "$(printenv 3FS_KEEP_DATA)" != "1" ]; then
  echo "ERROR: $DATA is not empty. Clean it, or set 3FS_KEEP_DATA=1 to reuse existing state." >&2
  exit 1
fi

# rxe0 must exist on the host before we start (setup-rxe.sh); we share the host
# network, sysfs, and /dev/infiniband through network_mode: host + privileged.
# Check sysfs, not `rdma link show rxe0`: jammy's iproute2 5.15 rejects the bare
# device name ("Wrong device name"), unlike the host's newer iproute2.
if [ ! -d /sys/class/infiniband/rxe0 ]; then
  echo "ERROR: host rxe0 RDMA link not found (/sys/class/infiniband/rxe0 missing). Run deploy/ubuntu-2604/setup-rxe.sh first." >&2
  exit 1
fi

export TOKEN=${TOKEN:-$(head -c 32 /dev/urandom | base64 | tr -d '=+/' | head -c 32)}
echo "starting single-node 3FS: bin=$BIN data=$DATA"
exec bash /ws/tests/fuse/run.sh "$BIN" "$DATA"
