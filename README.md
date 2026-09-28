# Scripts

Installer, recovery and setup scripts for Arch Linux.

## What's here

| Collection | What it does |
| --- | --- |
| [OfflineArch](OfflineArch/) | Builds a custom Arch ISO that installs Arch with no internet, in DualBoot or full-wipe mode, and runs the installer automatically on first boot |
| [System_Repair](System_Repair/) | Rescue script for getting back into an install that will not boot — finds the root partition, handles LUKS, mounts Btrfs subvolumes and boot partitions, and chroots |
| [Arch_Installers](Arch_Installers/) | Eight standalone installers and repair tools — full installs with a choice of desktop environment, Windows dualboot with GRUB or Limine, disk partitioning, and a Limine recovery script |
| [Tweaks](Tweaks/) | Eight one-off setup scripts — Nerd Fonts for waybar, XDG directories, default applications, SDDM autologin, memory tuning, disabling services |
| [Dotfiles_Backup](Dotfiles_Backup/) | `dotback` — takes a timestamped backup of `~/.config` and `~/.local` plus your package lists on Arch, and restores it on a fresh machine |

Each collection is self-contained and has its own `README.md` with requirements,
usage and caveats.

## Layout

```
Scripts/
  OfflineArch/       build the ISO, and the installer it runs
  System_Repair/     run this from a live USB when a machine won't boot
  Arch_Installers/   installers and repair tools, one script per job
  Tweaks/            one-off setup and tuning scripts
  Dotfiles_Backup/   backup and restore a dotfiles setup
```

## Getting a machine installed

`Arch_Installers/` is the folder to look at, and there are eight scripts in it
because they do genuinely different things. [Its
README](Arch_Installers/README.md) has a table mapping each one to the job it
fits.

In short: `main.sh` for a full desktop with your choice of DE,
`DUALBOOT-GRUB.sh` or `DUALBOOT-Windows_Arch_Limine.sh` to sit alongside
Windows, `diskpartitioner.sh` to prepare partitions and then use the official
`archinstall`, and `repair_pc.sh` to recover a broken Limine install.

## Repairing one that will not boot

There are two families here, and they are not interchangeable.

**[`System_Repair/system_repair.sh`](System_Repair/system_repair.sh)** is the one
to reach for by default. It finds your partitions instead of asking you to type
them, handles btrfs, ext4 and xfs, **writes nothing to disk**, and unmounts on
exit.

**[`Arch_Installers/repair_pc.sh`](Arch_Installers/repair_pc.sh)**
(`archrescue.sh` and `omarchy-doctor.sh` too) will additionally reinstall the
kernel, install NVIDIA drivers and rewrite the Limine config. That is more
power and more risk.

The two disagree about where the ESP goes — `System_Repair` mounts it at
`/mnt/boot/efi`, the `Arch_Installers` repair scripts at `/mnt/boot` — and about
subvolume names and the LUKS mapper name. **If you installed with a script from
`Arch_Installers/`, repair with one from `Arch_Installers/`.**

## Requirements

Arch Linux, or an Arch live environment for the recovery scripts. `System_Repair`
checks its own dependencies and stops with a clear message if something is
missing. The rest assume a stock Arch ISO, which is most of what they need —
with the exceptions called out in their own READMEs, such as `diskpartitioner.sh`
needing `bc`, and `main.sh` needing `yay` and network access for AUR packages.

`OfflineArch` also needs `archiso` and network access when building the ISO, to
populate the offline package cache.

## A note on quality

These scripts are works in progress, and a few of them have bugs that stop them
working at all. The READMEs say which ones and what to fix — `main.sh` has an
inverted root check and exits immediately, `arch_tool.sh`'s repair mode dies on
encrypted systems, and `omarchy-doctor.sh` advertises a 14-item menu of which
eight do nothing. Read the caveats in the relevant README before running
anything that partitions a disk.
