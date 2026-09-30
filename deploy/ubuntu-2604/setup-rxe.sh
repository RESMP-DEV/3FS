#!/usr/bin/env bash
# Bring up soft-RoCE (rxe0) on an ordinary Ethernet NIC and persist it.
# Usage: setup-rxe.sh <interface>   e.g. setup-rxe.sh enp7s0
set -euo pipefail

NETDEV=${1:?usage: setup-rxe.sh <interface>}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

sudo apt-get install -y rdma-core ibverbs-utils perftest
sudo modprobe rdma_rxe
sudo rdma link add rxe0 type rxe netdev "$NETDEV" 2>/dev/null || true
rdma link show rxe0

echo 'rdma_rxe' | sudo tee /etc/modules-load.d/rdma_rxe.conf >/dev/null
sudo cp "$SCRIPT_DIR/rxe0-link.service" /etc/systemd/system/
sudo sed -i "s/@NETDEV@/$NETDEV/" /etc/systemd/system/rxe0-link.service
sudo systemctl daemon-reload
sudo systemctl enable rxe0-link.service
echo "rxe0 on $NETDEV active and persisted across reboots"
