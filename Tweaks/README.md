# Tweaks

Small one-off scripts for setting up and tuning a system. Each does one thing,
takes no configuration, and can be re-run safely. They are independent — there is
no entry point that runs them all.

Most of these are Arch-specific, because they use `pacman` and `systemctl`.

| Script | What it does | Needs root? |
| --- | --- | --- |
| [`install_nerd_fonts.sh`](install_nerd_fonts.sh) | Install Nerd Fonts for waybar glyphs, rebuild the font cache | yes, for `pacman` |
| [`setup-xdg-dirs.sh`](setup-xdg-dirs.sh) | Create the XDG user directories, bookmark Downloads and Projects in Nautilus | no |
| [`set-gedit-default.sh`](set-gedit-default.sh) | Make gedit the default app for ~26 text and source file types | no |
| [`install_nautilus_scripts_util.sh`](install_nautilus_scripts_util.sh) | Add "Create File" and "Open Terminal Here" to the Nautilus right-click menu | only to install `zenity` |
| [`toggle_sddm_autologin.sh`](toggle_sddm_autologin.sh) | Turn SDDM autologin on or off | yes |
| [`tune-snappiness`](tune-snappiness) | Tune VM memory and writeback thresholds for an SSD | yes |
| [`disable-services.sh`](disable-services.sh) | Stop `docker.service` and `systemd-binfmt.service` starting at boot | yes |
| [`make-sudoless.sh`](make-sudoless.sh) | Grant passwordless sudo via a `/etc/sudoers.d` drop-in | yes |

## Fetch and run

```sh
git clone https://github.com/nightdevil00/Scripts
cd Scripts/Tweaks
```

Then run the one you want:

```sh
./install_nerd_fonts.sh          # no arguments
sudo ./toggle_sddm_autologin.sh --enable
sudo ./tune-snappiness --persist
```

`toggle_sddm_autologin.sh` and `tune-snappiness` are the only two that take
arguments; everything else runs and does its thing. With no argument,
`toggle_sddm_autologin.sh` just reports the current state.

## What each one changes

### `install_nerd_fonts.sh`

Installs `ttf-hack-nerd`, `ttf-cascadia-code-nerd`, `ttf-firacode-nerd`,
`ttf-jetbrains-mono-nerd` and `ttf-nerd-fonts-symbols-mono`, then runs
`fc-cache -f -v`. Reversible with `sudo pacman -Rns` on those five packages.

Arch package names only. Budget a few hundred MB, and expect `fc-cache -f -v` to
be slow and extremely noisy the first time — `-f` forces a full rebuild of the
cache, which is not happening in the background.

### `setup-xdg-dirs.sh`

Creates `~/Desktop`, `Downloads`, `Templates`, `Public`, `Documents`, `Music`,
`Pictures`, `Videos` and `Projects`, then appends `Downloads` and `Projects` to
`~/.config/gtk-3.0/bookmarks`. Uses `xdg-user-dirs-update` when available and
falls back to plain `mkdir`. It prints the `nautilus -q` you need to run to see
the bookmarks, but does not run it for you.

The bookmark is added unconditionally, while `xdg-user-dirs-update` will not
create `Projects` — it is not a standard XDG directory. So you can end up with a
bookmark pointing at a directory that does not exist. It also only writes
`gtk-3.0/bookmarks`, so a GTK4-only setup gets nothing.

### `set-gedit-default.sh`

Writes `[Default Applications]` entries into `~/.config/mimeapps.list` for
around 26 MIME types, using the desktop id `org.gnome.gedit.desktop`.

Worth knowing: it also claims `application/json`, so `.json` files stop opening
in a JSON-aware editor. Several of the types it lists are non-standard
(`text/x-python`, `text/x-csv`, `text/x-log`, `application/x-yaml`) and match
nothing. The desktop id breaks on GNOME Text Editor and newer gedit naming. To
undo it, edit `~/.config/mimeapps.list` or run
`xdg-mime default <other.desktop> <type>`.

### `install_nautilus_scripts_util.sh`

Installs two scripts into `~/.local/share/nautilus/scripts/`: **Create File**
(uses `zenity` to prompt for a name, which it auto-installs if missing) and
**Open Terminal Here** (falls back through `xdg-terminal-exec`, `alacritty`,
`konsole`, `gnome-terminal`). Reversible by deleting both files.

**Do not run it with `sudo`** — `$HOME` becomes root's, and the scripts end up in
`/root/.local/share/nautilus/scripts`, where Nautilus will never look for them.
It rewrites both files every run, so any local edits to them are lost. And the
`Create File` name it takes from zenity is not sanitised: a name containing `/`
or `..` is created relative to wherever Nautilus was open.

### `toggle_sddm_autologin.sh`

```sh
sudo ./toggle_sddm_autologin.sh            # report current state
sudo ./toggle_sddm_autologin.sh --enable
sudo ./toggle_sddm_autologin.sh --disable
```

Uncomments or comments the `auth` line in `/etc/pam.d/sddm-autologin` with
`sed -i`. Reversible with the opposite flag.

Two things to know. It edits the PAM file **in place, with no `.bak`** — a
corrupted `/etc/pam.d` locks you out of the graphical login entirely. And it
only does half the job: the autologin *user* also has to be set under
`[Autologin] User=` in `/etc/sddm.conf`, which this never touches. If
`sddm-autologin` does not exist it reports autologin as enabled, which is wrong.

### `tune-snappiness`

```sh
sudo ./tune-snappiness            # apply now, until reboot
sudo ./tune-snappiness --persist  # apply, and write /etc/sysctl.d/99-snappiness.conf
sudo ./tune-snappiness --remove   # delete the conf file
```

Sets `vm.swappiness=10`, `vm.vfs_cache_pressure=50`, `vm.dirty_ratio=10` and
`vm.dirty_background_ratio=5`. `--persist` writes them to
`/etc/sysctl.d/99-snappiness.conf`, where the `99-` prefix gives them high
precedence.

**`--remove` is buggy.** It deletes the conf file and then immediately re-applies
the same non-default values at runtime, while printing that it reset to
defaults. You are back to kernel defaults only after a reboot.

These are SSD-oriented values. The low `dirty_ratio` and
`dirty_background_ratio` force much more frequent writeback, which is actively
harmful on spinning disks and USB or SD media. Kernel defaults, for reference,
are 60 / 100 / 20 / 10.

### `disable-services.sh`

Runs `sudo systemctl disable` on `docker.service` and `systemd-binfmt.service`.
They keep running until you reboot, and you can still start them by hand —
`disable` only removes the "wants" symlink, and it does not mask them. Undo with
`sudo systemctl enable docker.service systemd-binfmt.service`.

It touches `docker.service` but not `docker.socket`. And it prints
"have been disabled" unconditionally, with no `set -e` and no check that the
units exist — so if one is missing, `systemctl` errors and the script still
reports success.

### `make-sudoless.sh`

Writes `/etc/sudoers.d/mihai-nopasswd` containing
`mihai ALL=(ALL) NOPASSWD: ALL` and `chmod 440`s it. It exits early if the file
already exists, so it is safe to re-run. Undo with
`sudo rm /etc/sudoers.d/mihai-nopasswd`.

**Edit it before you use it.** `USER="mihai"` is hardcoded near the top, so on
any other account it grants passwordless root to a user named `mihai` — or to
nothing at all, if no such user exists.

Also worth weighing: this is full passwordless root for *every* command, with no
prompt and no audit trail in the sudo log. It is fine on a throwaway live USB and
a bad idea on a machine holding anything you care about.

## Caveats

- Everything here is **Arch-specific** except `setup-xdg-dirs.sh`,
  `set-gedit-default.sh` and `disable-services.sh`.
- Several scripts print a success message unconditionally and have no `set -e`,
  so a failed step still reports success. `disable-services.sh` and
  `toggle_sddm_autologin.sh` are the worst for this.
- `set-gedit-default.sh` swallows every `xdg-mime` failure with
  `2>/dev/null || true`.
- None of these are idempotent in the strict sense — `make-sudoless.sh` and
  `toggle_sddm_autologin.sh` are close, but `install_nautilus_scripts_util.sh`
  overwrites its two generated files on every run.
