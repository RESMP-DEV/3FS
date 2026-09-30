#!/usr/bin/env bash
# Pre-training-shaped IO benchmark: sustained parallel shard streaming
# Usage: bench-3fs.sh <directory> <label>
# Env: JOBS (default 8), SIZE per job (default 512M), RUNTIME seconds (default 30)
set -euo pipefail

DIR=$1
LABEL=$2
JOBS=${JOBS:-8}
SIZE=${SIZE:-512M}
RUNTIME=${RUNTIME:-30}

cd "$DIR"
mkdir -p "bench-$LABEL"
cd "bench-$LABEL"

echo "[$LABEL] prep: write $JOBS x $SIZE (direct)"
fio --name=prep --rw=write --bs=1M --direct=1 --size="$SIZE" \
    --numjobs="$JOBS" --group_reporting --output-format=json --output=prep.json

echo "[$LABEL] sequential reads (shard streaming), 1M direct"
for n in 1 4 8; do
  fio --name=pt --rw=read --bs=1M --direct=1 --size="$SIZE" \
      --numjobs="$n" --time_based --runtime="$RUNTIME" --group_reporting \
      --output-format=json --output="seq-n$n.json"
done

echo "[$LABEL] random reads (shard sampling), 64k direct"
for n in 1 4 8; do
  fio --name=pt --rw=randread --bs=64k --direct=1 --size="$SIZE" \
      --numjobs="$n" --time_based --runtime="$RUNTIME" --group_reporting \
      --output-format=json --output="rand-n$n.json"
done

if [ "$LABEL" = 3fs ]; then
  echo "[3fs] sustained steady-state: seq read, 8 jobs, 120s"
  fio --name=pt --rw=read --bs=1M --direct=1 --size="$SIZE" \
      --numjobs=8 --time_based --runtime=120 --group_reporting \
      --output-format=json --output=sustained-120s.json
fi

echo "[$LABEL] results (MB/s):"
for f in prep seq-n1 seq-n4 seq-n8 rand-n1 rand-n4 rand-n8 sustained-120s; do
  [ -f "$f.json" ] || continue
  bw=$(jq -r '.jobs[0] | if .jobname == "prep" then .write.bw / 1024 else .read.bw / 1024 end' "$f.json" 2>/dev/null || echo ERR)
  iops=$(jq -r '.jobs[0] | if .jobname == "prep" then .write.iops else .read.iops end' "$f.json" 2>/dev/null || echo ERR)
  printf "  %-16s %8.1f MB/s  %10.0f iops\n" "$f" "$bw" "$iops"
done
