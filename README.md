# acontainer

A small container runtime experiment written in Zig.

## What it does

- bootstraps a Debian rootfs in `/tmp/rootfs` with `debootstrap`
- starts a process in new mount, PID, UTS, and IPC namespaces
- `chroot`s into the rootfs
- mounts `/proc`
- launches `/bin/sh` inside the container

## Requirements

- Zig `0.16.0`
- `debootstrap`

## Usage

Build:

```bash
zig build
```

Run:

```bash
sudo -E ./zig-out/bin/acontainer
```

## Notes

- This currently runs rootful inside the container namespaces.
- The rootfs lives at `/tmp/rootfs`.
- Remove `/tmp/rootfs` if you want a fresh bootstrap.
