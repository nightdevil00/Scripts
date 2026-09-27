# system_repair.sh

A rescue script for getting back into an Arch Linux install that will not boot.
Run it from an Arch live USB: it finds your root partition, works out whether it
is encrypted, mounts the whole thing including Btrfs subvolumes and boot
partitions, and optionally drops you into a chroot.

It only mounts things. Nothing on disk is written to unless you make changes
inside the chroot yourself.

## Requirements

- **Root**, and an Arch live environment (the ISO is ideal)
- `cryptsetup`, `lsblk`, `blkid`, `mount`, `umount`, `btrfs`, `arch-chroot`
- Bash 4.3 or newer — it uses `local -n` for the partition list

On a stock Arch ISO every one of these is already present.

## Usage

```sh
sudo ./system_repair.sh
```

Then follow the prompts:

1. **Pick a disk** — listed by name, size and model. Enter `0` to quit.
2. **Pick a partition** — the script scans for LUKS and for btrfs/ext4/xfs. If
   nothing is encrypted it uses the filesystem partition directly; if more than
   one candidate matches it asks you to choose.
3. **Unlock, if encrypted** — prompts for the LUKS passphrase and opens it as
   `/dev/mapper/cryptroot`.
4. **Confirm the filesystem** — detected with `blkid`. If it cannot tell, it
   offers ext4, btrfs or xfs.
5. **Chroot or not** — `y` to enter, anything else to unmount and exit.

Inside the chroot it prints the commands you probably want:

```
pacman -Syu                    # Update system
mkinitcpio -P                  # Regenerate initramfs
passwd username                # Reset password
systemctl enable service       # Enable service
exit                           # Leave chroot
```

The usual reason you are here is a machine that stopped booting after a kernel
update. Inside the chroot, reinstall the kernel and rebuild the initramfs:

```sh
pacman -Syu
mkinitcpio -P
```

## What it mounts

Everything under `/mnt`.

| Target | Source |
| --- | --- |
| `/mnt` | root filesystem, or the `@` subvolume |
| `/mnt/home` | `@home` |
| `/mnt/var/log` | `@log` |
| `/mnt/var/cache/pacman/pkg` | `@pkg` |
| `/mnt/.snapshots` | `@.snapshots` |
| `/mnt/var` | `@var` |
| `/mnt/root` | `@root` |
| `/mnt/boot` | partition labelled `BOOT` |
| `/mnt/boot/efi` | `vfat` partition labelled `EFI` |
| `/mnt/{dev,proc,sys,run}` | bind mounts from the live system |

For ext4 and xfs the root filesystem is mounted as a single volume, so a
separate `/home` *partition* is not mounted — only Btrfs subvolumes are handled.

Subvolumes are matched by name against a fixed list (`@`, `@home`, `@log`,
`@pkg`, `@.snapshots`, `@var`, `@root`). If none of them exist, the filesystem
is mounted whole. Non-standard subvolume names are not detected, so a layout
using e.g. `@data` will not be picked up.

## Cleanup

An `EXIT` trap unmounts `/mnt` recursively and closes `cryptroot`, so the
script tidies up after itself even if you interrupt it. Closing the mapper
means you will be asked for the passphrase again next time.

## Caveats

Worth knowing before you rely on it:

- **A separate `/home` on ext4 or xfs is not mounted**, only Btrfs subvolumes.
- **Subvolumes are matched by a fixed name list.** `@`, `@home`, `@log`, `@pkg`,
  `@.snapshots`, `@var` and `@root` are recognised. A layout using any other
  name — `@data`, say — is not detected.
- **The LUKS mapper is always named `cryptroot`.** Fine if your `fstab` refers
  to the device by UUID. If it refers to a differently-named mapper, mounts
  inside the chroot will fail.
- There is no dry-run mode and no `--target` flag. `/mnt` and the `cryptroot`
  mapper name are hardcoded at the top of the script; edit them there if you
  need otherwise.

## Fixed in this version

Three bugs were corrected; all three were found by reading the script rather
than by running it.

- **An ESP with no separate `/boot` is now mounted at `/mnt/boot/efi`.** It used
  to go to `/mnt/boot`, which put a vfat filesystem exactly where the bootloader
  looks for the kernel and initramfs — so the most common repair, reinstalling
  the kernel inside the chroot, appeared to do nothing.
- **A Btrfs filesystem with no `@` subvolume no longer has an arbitrary
  subvolume mounted as `/`.** The old code took whichever subvolume it found
  first, which is usually `@home`. It now mounts the top level, warns, and tells
  you how to mount the right one by hand.
- **Boot partition detection works on NVMe.** The old pattern `^[^0-9]*1$` only
  ever matched `sda1`, because `[^0-9]*` cannot span the `0` in `nvme0n1p1`. The
  script now extracts the trailing partition number and compares it, so `sda1`,
  `mmcblk0p1` and `nvme0n1p1` are all recognised — while `sda11` and `nvme0n1p2`
  correctly are not.
