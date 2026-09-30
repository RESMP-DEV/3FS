#!/usr/bin/env bash
# Build 3FS for Ubuntu 26.04 inside the repo's ubuntu:22.04 dev container.
# Usage: build-in-docker.sh [jobs]
set -euo pipefail

JOBS=${1:-$(nproc)}
REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)

sudo docker build -f "$REPO_ROOT/dockerfile/dev.dockerfile" -t 3fs-dev "$REPO_ROOT"

# safe.directory is mandatory: cmake/GitVersion.cmake shells out to git, and the
# container's root user does not own the host-mounted repo.
sudo docker run --rm -v "$REPO_ROOT":/ws -w /ws 3fs-dev bash -c "
  git config --global --add safe.directory /ws &&
  if [ -f build/git-state.txt ] && [ ! -s build/git-state.txt ]; then
    rm -f build/git-state.txt
  fi &&
  cmake -S . -B build \
    -DCMAKE_CXX_COMPILER=clang++-14 -DCMAKE_C_COMPILER=clang-14 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DSHUFFLE_METHOD=g++11 &&
  cmake --build build -j $JOBS
"
