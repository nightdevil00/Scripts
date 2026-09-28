# Arch_Installers

Eight standalone Arch Linux installer and repair scripts. They are independent of
each other — there is no shared library and no entry point that runs all of them.
Pick the one that matches what you are doing, copy it to a USB stick, and run it
from an Arch live environment.

> **These scripts partition disks, format filesystems and write bootloaders.**
> Read the script before you run it, and read the caveats at the bottom of this
> file. Several of them take raw partition boundaries as typed input, and a typo
> there can destroy a Windows installation.

## Which one to use

| Script | Use it for | Bootloader | Menu? |
| --- | --- | --- | --- |
| [`main.sh`](main.sh) | Full desktop install with a choice of DE | GRUB | prompts |
| [`DUALBOOT-GRUB.sh`](DUALBOOT-GRUB.sh) | Arch alongside Windows, GRUB | GRUB | prompts |
| [`DUALBOOT-Windows_Arch_Limine.sh`](DUALBOOT-Windows_Arch_Limine.sh) | Arch alongside Windows, separate ESP | Limine | prompts |
| [`arch_tool.sh`](arch_tool.sh) | Install *or* repair, Limine, Windows-aware | Limine | 4 modes |
| [`diskpartitioner.sh`](diskpartitioner.sh) | Prepare partitions, then hand off to `archinstall` | none | menu |
| [`repair_pc.sh`](repair_pc.sh) | Recover a broken Limine install | Limine | linear |
| [`omarchy-doctor.sh`](omarchy-doctor.sh) | Triage: reset a password, read logs, fsck | none | menu |
| [`archrescue.sh`](archrescue.sh) | Minimal mount-and-chroot rescue | none | menu |

### Full installs

**[`main.sh`](main.sh)** is the only one that offers a desktop environment —
GNOME, KDE, Niri, Hyprland or none — and the only one that can install **ext4**
as well as btrfs. It also provisions Hyprland dotfiles from JaKooLit or Omarchy.
It is the only script that checks for UEFI mode. **Its root check is inverted
(see caveats), so as written it exits immediately.** Fix that line before use.

**[`DUALBOOT-GRUB.sh`](DUALBOOT-GRUB.sh)** installs Arch next to an existing
Windows install using GRUB, with optional LUKS2. It scans all disks for Windows
partitions and reports them as protected, but that protection is advisory — see
caveats.

**[`DUALBOOT-Windows_Arch_Limine.sh`](DUALBOOT-Windows_Arch_Limine.sh)** does
the same with Limine, and creates a **separate 2 GB ESP for Arch** so Windows'
own ESP is never touched. Richest package set of the three — firewalld, bluez,
acpid, avahi, reflector, the full pipewire stack — and it can run unattended via
`AUTO_DISK`, `AUTO_LUKS_PASS` and `AUTO_USER`.

**[`arch_tool.sh`](arch_tool.sh)** is a 4-mode tool: dualboot install, full wipe
install, Limine repair, and an Omarchy keyring fix. It is the most capable of
the installers — byte-accurate 1 MiB-aligned partitioning in the largest free
block, copies `EFI/Microsoft` into the new ESP so Limine can chainload Windows,
enables `multilib`, supports installing from a local offline repo. **Its repair
mode is broken on encrypted systems** (see caveats).

**[`diskpartitioner.sh`](diskpartitioner.sh)** does the smallest job: it creates
the partitions in free space, or deletes one, formats them, and mounts them to
`/mnt` — then tells you to run the official `archinstall`. Use it when you want
`archinstall`'s install flow but a scripted partitioning step.

### Repair

There are four repair scripts here, plus `System_Repair/` in this repo. They are
not interchangeable.

**[`repair_pc.sh`](repair_pc.sh)** is the most reliable of the three repair
scripts in this folder. Linear, logged, no menu, `y/N` at each gate. Network →
mount → chroot → reinstall kernel → write `limine.conf` → NVRAM entry → reboot.
It is the only one that detects a UKI (`/boot/EFI/Linux/*.efi`,
`/boot/*-linux.efi`, `/boot/uki.efi`) and writes a matching config, and the only
one that falls back to copying `BOOTX64.EFI` into `\EFI\BOOT\` when
`efibootmgr` fails.

**[`archrescue.sh`](archrescue.sh)** is the smallest and cleanest: connect to
Wi-Fi, mount, chroot, reboot. It is the script the other two were derived from.
It can reinstall the kernel, install NVIDIA drivers and rebuild the initramfs.

**[`omarchy-doctor.sh`](omarchy-doctor.sh)** is an expanded `archrescue.sh` with
a 14-item menu, of which items 5–12 are stubs that just reopen the chroot menu.
The genuinely useful additions are the three `archrescue.sh` lacks: `fsck -f`,
`passwd <user>` and `journalctl -xb`. **Menu item 4 ("Full System Update &
Repair") runs `pacman -Syu` against the live ISO, not against your installed
system.**

**`System_Repair/system_repair.sh`** (in the parent folder) is a different design
and is the one to prefer for a read-only rescue: it finds your partitions instead
of asking you to type them, handles ext4 and xfs as well as btrfs, writes
nothing to disk, and unmounts on exit. Prefer it unless you specifically need
the NVIDIA or bootloader work these scripts do.

#### The ESP convention matters

The repair scripts in this folder mount the ESP at `/mnt/boot`, putting a vfat
filesystem exactly where Limine looks for the kernel — and
`System_Repair/system_repair.sh` mounts it at `/mnt/boot/efi` instead. The two
families have **mutually incompatible** expectations. If you built the system
with a script from this folder, repair it with one from this folder.

They also disagree on subvolume names. These installers create `@snapshots`,
`@swap`, `@var_log` and `@var_cache_pacman_pkg`; `System_Repair` looks for
`@.snapshots`, `@log`, `@pkg` and `@var`. And the LUKS mapper here is named
`root`, where `System_Repair` hardcodes `cryptroot`.

## Requirements

- **An Arch live environment** (the ISO is ideal) and **root**.
- `lsblk`, `blkid`, `parted`, `partprobe`, `mkfs.fat` (`dosfstools`),
  `cryptsetup`, `btrfs-progs`, `pacstrap`, `genfstab`, `arch-chroot`,
  `mkinitcpio`, `efibootmgr`, `partprobe`, `wipefs`, `openssl`.
- `main.sh` additionally needs `yay`, `git` and network access for AUR packages.
- `diskpartitioner.sh` needs `bc`, which is **not** on the stock ISO by default.
- `archrescue.sh` and `omarchy-doctor.sh` need `iwctl` and `lspci`, and
  `multilib` enabled in the *target's* `pacman.conf` (they install
  `lib32-nvidia-utils`).

Nothing here checks its own dependencies, except `System_Repair`. A missing
command surfaces as a mid-script error, not a clean preflight failure.

## Fetch and run

There is no installer — these are individual scripts, so fetch the one you want.

```sh
curl -LO https://raw.githubusercontent.com/nightdevil00/Scripts/main/Arch_Installers/repair_pc.sh \
  && chmod +x repair_pc.sh
```

From an Arch live USB, plug in Ethernet if you can (it saves a Wi-Fi prompt),
then run it as root:

```sh
sudo ./repair_pc.sh
```

You type a root partition name like `nvme0n1p2` and the script prefixes `/dev/`
for you, in the two rescue scripts. The other scripts want the full path. If you
are not sure which disk you are on, `lsblk -f` first.

## Caveats

Worth knowing before you rely on any of this. These were found by reading the
scripts, not by running them on real hardware.

**Broken as written**

- **`main.sh` cannot run.** It errors out if `$EUID` is 0, telling you to run it
  as a regular user — but everything it does (`parted`, `cryptsetup`, `pacstrap`,
  `arch-chroot`, `reboot`) needs root. Change the check to `ne 0` before use.
- **`arch_tool.sh` repair mode dies on encrypted systems.** It reads `$PASSWORD`
  under `set -u` before that variable is ever assigned, so any LUKS repair
  exits with an unbound-variable error. `repair_pc.sh` is the working version of
  the same flow.
- **`archrescue.sh` cannot escalate inside the chroot.** Its inner `run_as_root`
  is `bash -c "$1"` with no elevation, so if you chroot as a non-root user every
  action — `pacman`, `mkinitcpio` — fails.

**Silent data-loss risks**

- **Typed partition boundaries.** `DUALBOOT-GRUB.sh`,
  `DUALBOOT-Windows_Arch_Limine.sh` and `main.sh` ask you to type raw start/end
  values in GB. There is no bounds check, no overlap check, and no confirmation
  that the range misses your Windows partitions. A typo overwrites them.
- **"Protected" Windows partitions are advisory only.** `DUALBOOT-GRUB.sh` and
  `diskpartitioner.sh` scan every disk for `EFI/Microsoft`, `Windows`, `bootmgr`
  and `Boot`, print them as "will not be modified" — and then do nothing to
  enforce it.
- **Plaintext passwords land in the target filesystem.** `DUALBOOT-GRUB.sh`
  writes them to `/mnt/arch_install_vars.sh` and `arch_tool.sh` to
  `/mnt/pwhash.env`, both world-readable until a later chroot step removes them.
- **`arch_tool.sh` keyring mode can permanently disable signature checking.** It
  sets `LocalFileSigLevel = Never` with `sed`, runs `pacman -Udd`, then sets it
  back — but with `set -e`, a failed install skips the restore.

**Wrong results on encrypted systems**

- **`repair_pc.sh` and `arch_tool.sh` write a broken `limine.conf` on LUKS.**
  Both `export IS_LUKS` and then use it inside an `arch-chroot` heredoc, which
  scrubs the environment. The variable is always `false` in there, so the config
  gets a plain `root=UUID=…` cmdline pointing at the LUKS container with no
  `cryptdevice=` — unbootable. Read the generated config before rebooting.
- **`repair_pc.sh` falls back to the literal string `YOUR_ROOT_PARTITION_UUID`**
  when it cannot determine your root, and only logs a warning. That produces a
  config that cannot boot.

**Overstated features**

- **Snapper does nothing.** `DUALBOOT-Windows_Arch_Limine.sh` installs the
  package and creates `@snapshots`, but never runs `snapper init` and never
  installs `snapper-grub`. Snapshots will not be bootable.
- **`DUALBOOT-Windows_Arch_Limine.sh` cannot complete a clean-disk install.**
  In the no-Windows branch it never sets `EFI_PART_NUM`, so `efibootmgr --part`
  gets an empty argument and `set -e` aborts inside the chroot. It also assumes
  NVMe naming and appends `p` unconditionally, giving `sdap2` on `/dev/sda`.
- **The repair "fallback" entry points at `initramfs-linux-fallback.img`,** a
  file Arch does not ship.
- **`main.sh` passes `space_cache=v2` to btrfs,** deprecated since kernel 5.15
  and removed later — the mount can fail outright on current Arch.
- **`main.sh` installs NVIDIA on every machine,** with no `lspci` check, and
  `main.sh`'s Hyprland dotfile installer `sed`s and `chmod`s the wrong filename
  (`install.sh` instead of `install_dotfiles.sh`), so it never substitutes the
  username.
- **`main.sh` creates its dualboot partition with no filesystem type and no
  `esp` flag,** and parses `parted print free` output assuming a `GB` unit, so
  the start/end values are often wrong.

**Other**

- `archrescue.sh` and `omarchy-doctor.sh` both advertise Limine/GRUB repair in
  their headers. Neither implements it — `omarchy-doctor.sh` item 8 just opens a
  shell.
- `omarchy-doctor.sh` runs `fsck -f` on an online, mounted btrfs filesystem.
- `setup`-style clean installs (`mklabel gpt`, `wipefs -a`, `luksErase`) are
  destructive by design. `arch_tool.sh` full-wipe mode wipes the whole disk.
- Timezone, keymap and hostname are hardcoded to `UTC`, `us` and `arch` in most
  of these, or guessed from the live environment — so the installed system
  inherits whatever the ISO had.
- `main.sh` sets `GRUB_ENABLE_CRYPTODISK=y` *and* a `cryptdevice=` cmdline, which
  are conflicting approaches to unlocking the same volume.
