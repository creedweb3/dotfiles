# dotfiles

A tinted, translucent Hyprland rice for Arch Linux. Every colour comes from
the wallpaper: `wall <image>` (or SUPER+W) sets it and re-themes Hyprland,
the Quickshell bar, pop-ups and notifications, kitty, rofi, btop, cava, fastfetch,
Spotify (spicetify) and Discord (Vesktop), yazi, GTK and Qt apps, the cursor,
and (with `sudo boot-theme`) the boot and login screens. JetBrains Mono is the
font everywhere.

Colours: `wall` picks the palette with `palette-pick` (the same picker the demo
and `boot-theme` use), writes it to `~/.cache/rice/palette.json` for Quickshell,
and feeds it to every wallust template through `wallust cs`. Red, green, yellow
and magenta keep their meaning for errors and success, lightened until they are
readable.

## Install

Arch Linux and Arch-based distros (EndeavourOS, CachyOS, ...). It needs
Hyprland 0.57+ and Quickshell. Read `install.sh` before running it: it uses sudo,
runs a full system upgrade (`pacman -Syu`), and builds AUR packages (yay, the
core AUR packages and any AUR apps you pick) without showing their PKGBUILDs.

    git clone https://github.com/creedweb3/dotfiles ~/dotfiles && cd ~/dotfiles
    ./install.sh

In a terminal it checks the system, offers the optional apps and a starting
preset in menus, shows a summary to confirm, then installs with a progress line
per step (full output in `~/.cache/rice-install.log`). The menus use
[gum](https://github.com/charmbracelet/gum), installed first if missing.
Existing configs are moved to `~/.config/rice-backup-<date>` first.

| Option | Does |
|---|---|
| `--apps=id,id` | pick optional apps by id, e.g. `--apps=brave,steam,vlc` |
| `--all-apps` | pick every optional app |
| `--yes` | no menus or questions (for scripts and reinstalls) |
| `--demo` | walk through the screens without installing or changing anything |
| `wallpaper` | start from this image instead of a preset wallpaper |

Package lists live in `packages/`:

- `core.pacman` - the rice's packages from the official repos (pacman)
- `core.aur` - the few from the AUR (yay, set up if missing)
- `apps.conf` - the optional apps: id, source (`pacman` or `aur`), package,
  category, name. Add a line to offer another app.

Optional apps: Brave, Vesktop (Discord), Spotify, Spicetify, Tidal, VS Code,
Claude, Claude Code, Steam (needs the multilib repo), qBittorrent, VLC and 7-Zip.
None are installed unless picked.

SUPER+B and the browser special workspace start Brave. Without it, change
`browser` in `hypr/hyprland.lua` (and `web:` in `~/.config/rice/deck.conf`)
to the browser you use.

Other distros are not supported by the script; `packages/` lists the
dependencies to find there.

## Keys

| Keys | Action |
|---|---|
| SUPER+/ | every shortcut; type to search, enter runs one |
| SUPER+T | terminal (kitty; Settings > Default apps) |
| tap SUPER | launcher: apps, `>` rice commands, `=` calculator, `:` emoji, `;` clipboard, `@` power |
| SUPER+E / B | yazi (files) / browser |
| SUPER+S | settings |
| SUPER+X | quick panel |
| SUPER+W | pick a wallpaper (arrows preview, enter applies) and re-theme |
| SUPER+Q | close window |
| SUPER+F / SUPER+ALT+Space | fullscreen / float |
| SUPER+V | clipboard history |
| SUPER+1..9, 0 / SUPER+ALT+1..9, 0 / SUPER+SHIFT+1..9, 0 | workspaces / move window and follow / move window, stay here |
| SUPER+M / C | music / chat special workspace |
| SUPER+SHIFT+B / SUPER+` | browser / system monitor (btop) special workspace; started the first time |
| SUPER+U | mute the microphone |
| SUPER+L | lock |
| SUPER+SHIFT+S | screenshot a region to the clipboard |
| SUPER+SHIFT+C | colour picker |

These are the defaults. To change one, open Settings > Shortcuts, click it and
press the new keys (esc cancels; with no modifier held, SUPER is added). A key
that is already taken is refused. Changes go to `~/.config/hypr/rice-keys.lua`
and apply at once (`hyprctl reload`); the SUPER+/ sheet shows them too. "reset
shortcuts" puts them all back. While it records, Hyprland is in an empty submap
so the old shortcut does not run; if Quickshell dies mid-recording, press
CTRL+ALT+Escape (or run `hyprctl dispatch 'hl.dsp.submap("reset")'`). Workspace numbers, arrows, mouse
and media keys can't be changed there. Symbol keys assume a US layout.

Apps that ask for admin rights show the rice's own password prompt (Quickshell
is the polkit agent).

## Quick panel

SUPER+X, or click the bar's centre. Tabs: Dashboard, Media, System, Deck and Theme.

- **Deck**: twelve buttons (screenshot, record, colour picker, terminal, files, browser,
  mute mic, game mode, clipboard, emoji, calculator, stay awake). Each runs its line from
  `~/.config/rice/deck.conf`; install.sh copies `rice/deck.conf` there once, then never
  touches it. Toggles light up from a `key?:` check line (exit 0 = on). Game mode turns
  off animations and blur until pressed again or logout; stay awake stops hypridle.
- **Theme**: the current wallpaper with previous / next arrows, the palette, the presets
  as tiles, and the panel dim and graph strength sliders. The rest is in Settings.

## Notifications and bar pop-ups

Quickshell is the notification daemon (no mako; if mako is installed, remove it with
`sudo pacman -Rns mako`, or it can grab notifications before Quickshell starts). Pop-ups stack under the bar on the
right, newest on top, at most three plus "+N more"; the line along the bottom is the
time left and pauses while you point at one. Critical ones stay until dismissed.
Settings > Panels > notifications picks a wallpaper tint or neutral.

Click the clock for the notification centre: the date, a month calendar with week
numbers, focus mode (no pop-ups, critical ones still show) and the history with
dismiss and clear all. The clock counts what came in since you last opened it.
`qs -c rice ipc call notifs toggleDnd` and `... notifs clear` do the same from scripts.

The bar's sound, Bluetooth and Wi-Fi icons open small pop-ups on click (volume and
output, openTHX on / off; devices; networks), each with "more settings". Right click
still mutes or turns off; scroll on sound changes the volume. While a special
workspace shows (SUPER+M / C), the workspace numbers turn into its icons.

## Settings

SUPER+S opens settings: theme, bar, windows, panels, lock screen, graphs,
shortcuts, sound, Wi-Fi, wired, VPN, Bluetooth, monitors, night light, power
and default apps. Look options are saved in `~/.config/rice/prefs.json`.
Display, night light, power and lock options are saved in
`~/.config/hypr/rice-monitors.lua`, `rice-night.conf`, `rice-idle.conf` and
`rice-lock.conf`; hyprland.lua, hyprsunset, hypridle and hyprlock read them.
Monitor changes revert after 15 s unless kept.

Each look option shows ✓ when it is at its default. Otherwise ↺ puts it back and
☆ makes the current value your default (saved in `~/.config/rice/defaults.json`).
"reset ‹page›" under a page and "reset all" in the side menu go back to your
defaults; "factory reset" forgets them and goes back to the rice's own look.

The power button (Settings > Power) can open the power menu, shut down, sleep or
do nothing. Hyprland handles it, so logind must leave the key alone. Run this
once (it needs sudo, so install.sh does not do it):

    sudo mkdir -p /etc/systemd/logind.conf.d
    printf '[Login]\nHandlePowerKey=ignore\n' | sudo tee /etc/systemd/logind.conf.d/rice-power-key.conf
    sudo systemctl kill -s HUP systemd-logind

Sound > Input > noise suppression writes an rnnoise filter to
`~/.config/pipewire/pipewire.conf.d/99-rice-rnnoise.conf`, restarts PipeWire and
makes "Noise suppressed mic" the input.

Brightness of external monitors (DDC/CI) needs the `i2c-dev` module and your
user in the `i2c` group; install.sh does not change that.

## Lock screen

SUPER+L (and the idle timer) locks with the manga lock, drawn by Quickshell:
real manga panels printed in the theme's ink, the clock, date, music and a
notification count. Fetch the frames once from Settings > Lock screen > fetch
new frames, or by hand:

    manga-frames [pages] [preset]    # into ~/.cache/rice/manga
    manga-frames panels              # re-cut downloaded pages

Pages stay in your cache and are never part of this repo. hyprlock is the
fallback (Settings > Lock screen > lock with). If the lock ever crashes, the
screen stays locked. Switch to a text console (Ctrl+Alt+F2), log in and run:

    hyprctl --instance 0 eval 'hl.config({ misc = { allow_session_lock_restore = true } })'
    hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'

then unlock with hyprlock and turn the option off again (or log out and back in).
It stays off normally because, while on, any program could replace a running lock.

## Boot screens

    sudo boot-theme

Draws the GRUB menu, the Plymouth splash and the disk-password screen from the
current wallpaper (blurred backdrop, the preset symbol in the accent) and
installs them. Boot files cannot change live, so run it again after picking a
new wallpaper. It only sets `GRUB_THEME` and `GRUB_GFXMODE` in
`/etc/default/grub` (the original is kept as `grub.rice-backup`). For the splash,
install `plymouth`, add the `plymouth` hook and the `splash` kernel option; the
command tells you if they are missing.

It also installs the SDDM login screen (`/usr/share/sddm/themes/rice`, selected
in `/etc/sddm.conf.d/rice.conf`): the lock screen's manga page, with the user,
the password and sleep / restart / shut down in the time panel. It always starts
Hyprland. SDDM cannot read your home folder, so boot-theme copies in the panel
images (your fetched manga frames, else the preset's wallpapers), the colours and
the Settings > Lock screen choices: run it again after changing any of them.
SDDM is installed but not enabled; turn it on with `sudo systemctl enable sddm`.

Extras: `tty-clock -c -C 4 -b` for the big clock, `cava` for the visualiser,
`btop` for the monitor. In Vesktop, enable the "wallust" theme once in
Settings > Themes.

## Layout

- `hypr/hyprland.lua` - compositor, gaps, blur, opacity, keys (Hyprland 0.57+ reads only Lua)
- `hypr/hyprlock.conf`, `hypr/hypridle.conf` - lock screen and idle timeouts
- `quickshell/` - bar, quick panel, OSD, shortcuts sheet, launcher, wallpaper picker,
  settings and password prompt; linked to `~/.config/quickshell/rice`, run as `qs -c rice`
- `wallust/` - palette settings and one template per app
- `kitty/`, `rofi/`, `fastfetch/` - app configs (colours come from wallust)
- `fontconfig/` - JetBrains Mono as the default sans, serif and monospace font
- `scripts/wall` - wallpaper + re-theme command
- `scripts/palette-pick` - the palette from a wallpaper
- `scripts/cursor-theme` - the "dart" cursor (XCursor and hyprcursor), links in the accent
- `scripts/boot-theme` - GRUB, Plymouth and SDDM themes from the wallpaper (run with sudo)
- `sddm/` - the login screen theme
- `rice/deck.conf` - default commands for the quick panel's deck buttons
- `packages/` - what install.sh installs: core packages and the optional apps

## License

Code: GPL-3.0 (`LICENSE`). Wallpapers and preset symbols belong to their
artists and rights holders; sources are in `CREDITS.md`.
