# Single-node 3FS on Ubuntu 26.04 LTS (soft-RoCE)

Working recipe for running [3FS](https://github.com/deepseek-ai/3FS) all-on-one-node
on Ubuntu 26.04 LTS with soft-RoCE (`rdma_rxe`) instead of an RDMA NIC.
Full write-up with every gotcha: see the gist linked from the fork README.

Tested on: AMD B550, Ryzen (32 threads), single 3.6 TB NVMe, RTL8125 2.5GbE,
Ubuntu 26.04.1 LTS.

## Files

| file | purpose |
|---|---|
| `build-in-docker.sh` | Build 3FS in the repo's `ubuntu:22.04` dev container (clang-14 no longer exists in 26.04 repos). Bakes in the `safe.directory` fix and clears a poisoned empty `build/git-state.txt`. |
| `setup-rxe.sh` + `rxe0-link.service` | Create `rxe0` soft-RoCE link on an Ethernet NIC and persist it across reboots. |
| `limits-99-3fs.conf` | `memlock unlimited` + `nofile 1048576` — without these, `storage_main` dies with `reg_mr errno 12` / `TooManyOpenFiles`. Install to `/etc/security/limits.d/`; applies to NEW login sessions only. |
| `run-single-node.sh` | Wrapper around `tests/fuse/run.sh` with the compat `LD_LIBRARY_PATH` and limit checks. |
| `bench-3fs.sh` | fio benchmark, pre-training-shaped (parallel shard streaming, direct I/O), raw disk vs 3FS mount. |

## Compat libs

Binaries built in the 22.04 container pin 22.04 sonames (Boost 1.74,
`libfuse3.so.3`, ICU 70, glog, tcmalloc, libevent 2.1, `libaio.so.1`) that 26.04
does not ship. Dump them from the container once:

```bash
docker run --rm -v $HOME/3fs-lib:/out 3fs-dev bash -c '
  cd /usr/lib/x86_64-linux-gnu &&
  cp -aL libboost_atomic.so.1.74.0 libboost_context.so.1.74.0 libboost_filesystem.so.1.74.0 \
         libboost_program_options.so.1.74.0 libboost_regex.so.1.74.0 libboost_system.so.1.74.0 \
         libboost_thread.so.1.74.0 libglog.so.0 libtcmalloc.so.4 libprofiler.so.0 \
         libevent-2.1.so.7 libaio.so.1 libicui18n.so.70 libicuuc.so.70 libicudata.so.70 /out/ &&
  cp -aL /usr/local/lib/x86_64-linux-gnu/libfuse3.so.3 /out/'
```

Never include the container's `libc.so.6` or `ld-linux` in that directory.

## Order of operations

```bash
sudo cp limits-99-3fs.conf /etc/security/limits.d/99-3fs.conf   # then re-login (new ssh session)
./build-in-docker.sh                                            # ~30 min
./setup-rxe.sh enp7s0
sudo apt-get install -y fio                                      # for bench-3fs.sh
# install FDB 7.3.63 debs, then: sudo systemctl disable --now foundationdb && sudo systemctl stop foundationdb
./run-single-node.sh ~/3fs ~/3fs-lib ~/3fs-test
```

Verify: `mount | grep hf3fs`, then read/write through `~/3fs-test/mnt/test`.
