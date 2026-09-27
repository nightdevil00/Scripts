# Scripts

Installer and recovery scripts for Arch Linux.

## What's here

| Script | What it does |
| --- | --- |
| [OfflineArch](OfflineArch/) | Builds a custom Arch ISO that installs Arch with no internet, in DualBoot or full-wipe mode, and runs the installer automatically on first boot |
| [System_Repair](System_Repair/) | Rescue script for getting back into an install that will not boot — finds the root partition, handles LUKS, mounts Btrfs subvolumes and boot partitions, and chroots |

Both are self-contained. Each has its own `README.md` with requirements, usage
and caveats.

## Layout

```
Scripts/
  OfflineArch/     build the ISO, and the installer it runs
  System_Repair/   run this from a live USB when a machine won't boot
```

## Requirements

Arch Linux, or an Arch live environment for `System_Repair`. Both scripts check
their own dependencies and stop with a clear message if something is missing.
`OfflineArch` also needs `archiso` and network access when building the ISO, to
populate the offline package cache.
