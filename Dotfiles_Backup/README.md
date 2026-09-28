# Dotfiles_Backup

One script, `dotback`, that takes a timestamped backup of a dotfiles setup on
Arch and puts it back again. It is designed for reinstalling a machine: back up
before, restore after, and the desktop comes back roughly as it was.

This backs up *your own* configuration. It is not a dotfiles repository, and it
does not sync anything between machines.

## Requirements

- **Arch Linux** — it shells out to `pacman -Qq` and `pacman -S`.
- `tar`, `gzip`, `pacman` — checked by the script, which exits if any is missing.
- `sha256sum`, `du`, `sed` — used but not checked.
- Optionally `yay` or `paru`, for the AUR package list. Without one, the AUR
  list is still written but with a warning.

## Usage

```sh
./dotback backup              # take a backup
./dotback backup --dry-run    # show what it would do, change nothing
./dotback restore             # restore the most recent backup
./dotback restore --dry-run
./dotback help
```

The flag comes **after** the subcommand — `./dotback --dry-run backup` will just
print the help.

`backup` needs no privileges. `restore` only needs root for the `pacman` step,
and it calls `sudo` itself. `--dry-run` suppresses that too, so you can see the
whole plan as your own user.

## What a backup contains

Each run creates a new directory:

```
~/backups/dotfiles_2026-09-28_14-31-07/
```

It is a **directory of separate artifacts, not one archive**:

| File | What |
| --- | --- |
| `packages-official.txt` | `pacman -Qqen` — repo packages, excluding optional deps |
| `packages-aur.txt` | `pacman -Qqem` — foreign/AUR packages, if `yay` or `paru` is installed |
| `config.tar.gz` | `~/.config`, minus `google-chrome`, `Steam` and `steam` |
| `local.tar.gz` | `~/.local/share`, `~/.local/bin`, `~/.local/state` |
| `checksums.sha256` | SHA256 of the four files above |

Both tarballs are built with `tar -C "$HOME"`, so members are relative paths like
`.config/nvim/` — no leading `/`, nothing to escape into. `local.tar.gz` has a
four-step fallback that progressively drops `.local/state`, then `.local/bin`,
then `.local/share`, and finally archives the whole of `.local` instead.

`~/backups` grows without bound. There is no rotation, no pruning and no
retention policy — every `backup` adds another directory.

## How restore works

`restore` picks the **newest** `~/backups/dotfiles_*` by modification time. There
is no menu and no way to pick an older one; sort the directory yourself and
rename the one you want if you need to.

It then runs, in order:

1. `sudo pacman -S --needed --noconfirm -` from `packages-official.txt`
2. `yay -S --needed --noconfirm -` (or `paru`) from `packages-aur.txt`, skipped
   with a warning if no helper is installed
3. `tar xzf config.tar.gz -C "$HOME"`
4. `tar xzf local.tar.gz -C "$HOME"`

## Caveats

**Restoring overwrites your live config silently.** `tar xzf` with no
`--keep-old-files` and no prompt — whatever is in `~/.config` and `~/.local` now
gets clobbered by whatever was in the archive. There is no dry-run in the
restore path for the extraction itself either. Do not restore onto a running
desktop.

Files that exist locally but are *not* in the archive are left alone. Nothing is
pruned, so restoring an older backup can leave newer files behind.

**`checksums.sha256` is written but never verified.** Nothing in the script ever
reads it back, so a truncated or corrupted tarball is restored as-is.

**The coverage is `~/.config` and `~/.local` only.** Not backed up:

- dotfiles in your home directory — `~/.bashrc`, `~/.zshrc`, `~/.gitconfig`,
  `~/.ssh`, `~/.gnupg`, `~/.xinitrc`
- anything under `/etc` — `pacman.conf`, `makepkg.conf`, `sudoers.d`,
  `sddm.conf`, the `sysctl.d` files written by `Tweaks/tune-snappiness`

So a restore gets your applications' settings back, not your shell.

**Package installs are `--noconfirm`.** Conflicts get resolved without asking.
There is no record of which packages were removed, so a restore adds to your
system and never takes away from it — the result drifts from the original over
time.

**Backing up a live `~/.config` can capture it mid-write.** There is no
`--one-file-system` and no `--ignore-failed-read`, so SQLite state and
Thunderbird mail directories may be captured inconsistent. Close the applications
you care about first.

Two smaller ones: the summary at the end runs even under `--dry-run`, so a dry
run still prints "Backup complete" for a directory that was never created. And
`run_or_dry` uses `eval "$@"` — the arguments are internal literals, so this is
not injectable, but it does defeat proper quoting.
