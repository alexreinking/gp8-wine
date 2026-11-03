# gp8-wine

Set up Guitar Pro 8 under Wine (via [Bottles](https://usebottles.com), Flatpak) on KDE.

Put the official Guitar Pro installer (`*.exe`, acquired legally and independently)
next to `install.sh`, then:

    ./install.sh

It needs only bash and tools in a stock Fedora Kinoite (no `make`). Guitar Pro is only
installed if it isn't already, and it fails up front, before changing anything, if there
is nothing to install it from. In order, it:

1. **Installs Bottles** from Flathub (per-user) if it's missing, and **creates** a bottle
   named "Guitar Pro" if there isn't one.
2. **Ensures the Segoe UI fonts**, downloaded from
   [mrbvrz/segoe-ui-linux](https://github.com/mrbvrz/segoe-ui-linux) at a pinned commit and
   verified against `fonts.sha256` (they're Microsoft's, so not stored in this repo). They
   are copied into the bottle, **registered with Wine**, and the default
   `Segoe UI -> Times New Roman` replacements are removed. The registry change is checked
   against the live prefix, then the bottle is restarted. This comes *before* Guitar Pro so
   it never runs without its fonts.
3. **Installs Guitar Pro** by running the installer silently, then closes the copy the
   installer launches.
4. **Installs the official icon**: extracts the embedded PNGs from `GuitarPro.exe`
   (`scripts/extract-images.py`), installs the largest square one (up to 512px) into
   `~/.local/share/icons/hicolor`, and points the Bottles-generated `.desktop` file at it
   (or creates `guitar-pro-8.desktop`). It also sets `StartupWMClass` to the window class
   the bottle's runner really uses (`steam_proton` for Proton-based runners) so the
   desktop ties the running window to the entry, and tells running KDE processes to
   reload icons.
5. **Installs the anti-sleep hook** (`gp-inhibit`, below).

Every step is idempotent and can be run alone; see `./install.sh --help`
(`install-bottle`, `install-fonts`, `install-guitar-pro`, `install-icon`, `install-inhibit`).

`./install.sh uninstall` removes the icon (restoring Bottles' own icon in its `.desktop`
file) and the anti-sleep hook. It does **not** remove the bottle, Guitar Pro, or the fonts.

Settings (environment variables): `INSTALLER` (installer path), `BOTTLE_NAME`,
`BOTTLE_DIR`, `PREFIX`, `BINDIR`, `UNITDIR`.

## Requirements

`flatpak` (Bottles is fetched from Flathub if absent), `python3`, `curl`, `jq`,
`pipewire` (`pw-dump`, `pw-record`), `kde-inhibit` (kde-cli-tools), `systemctl`. All are
in a stock Fedora Kinoite.

`./install.sh check-deps` reports anything missing, with Fedora package names. `install`
runs it first, so nothing is changed if a tool is absent; each step command also checks
just the tools it needs.

## gp-inhibit

Keeps KDE from locking the screen or turning it off while Guitar Pro is playing sound.

Wine's audio stream stays open and "running" even when playback is paused (it just
carries silence), so the script finds Guitar Pro's PipeWire stream by
`application.name` and samples it for non-zero audio. While there is signal, it holds a
`kde-inhibit --power --screenSaver` inhibitor; when the audio goes silent it releases it.

- Any non-silent output from Guitar Pro counts, including the metronome and count-in.
- The inhibitor is held through quiet stretches (rests, a muted track) and released only
  after a full minute of silence. Change that with `GP_INHIBIT_SILENCE_SECS` in the
  service environment.
- The level meter's capture stream identifies itself as pavucontrol so Plasma's tray
  doesn't flash a "recording" indicator on every poll.
- If a Guitar Pro update changes the PipeWire `application.name`
  (currently `Arobas Music® Guitar Pro® 8`), edit `pattern` in `gp-inhibit.sh`.

## Notes

- The Bottles sandbox can't see this directory, so the installer is copied into the
  bottle's `drive_c/windows/temp` for the duration of the install.
- The official installer (e.g. `guitar-pro-soundbank-full.exe`, the "Download Guitar Pro
  WINDOWS" link on Arobas Music's site; the soundbanks are bundled in) is an Inno Setup
  6.1 installer, so it is run with `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART`.
  Only the first `*.exe` in this directory is used; set `INSTALLER=` to choose another.
- Extracted images go to `build/` and are git-ignored; the installer is too.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
