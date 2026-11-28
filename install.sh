#!/bin/bash
# Install the rice on Arch Linux: packages, configs (symlinked, old ones
# backed up), the `wall` command and a first theme from a wallpaper.
# Usage: ./install.sh [--apps=id,id,...] [--all-apps] [--yes] [--demo] [wallpaper-image]
#   --apps     optional apps by id (see packages/apps.conf); in a terminal they are also offered in a menu
#              (--brave, --vesktop and --spicetify still work as short forms)
#   --yes      no menus or questions: install what the flags say
#   --demo     walk through the installer screens without installing or changing anything
# In a terminal the menus and progress use gum (installed first if missing);
# without a terminal, or with --yes, it prints plain lines.
set -euo pipefail
cd "$(dirname "$0")"
here=$(pwd)

# ---------------------------------------------------------------- package lists (packages/)
list() { sed 's/#.*//; s/[[:space:]]*$//' "$1" | grep -v '^$'; }   # names in a list file, no comments
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
mapfile -t pkgs < <(list packages/core.pacman)
mapfile -t aur_core < <(list packages/core.aur)
# apps.conf: one app per row as parallel arrays (index = row)
app_id=() app_src=() app_pkg=() app_cat=() app_name=() app_about=()
while IFS='|' read -r c1 c2 c3 c4 c5 c6; do
    app_id+=("$(trim "$c1")"); app_src+=("$(trim "$c2")"); app_pkg+=("$(trim "$c3")")
    app_cat+=("$(trim "$c4")"); app_name+=("$(trim "$c5")"); app_about+=("$(trim "$c6")")
    case "${app_src[-1]}" in pacman|aur) ;; *) echo "packages/apps.conf: ${app_id[-1]}: source must be pacman or aur" >&2; exit 1 ;; esac
done < <(list packages/apps.conf)
app_index() {  # app_index <id>: its row, or fail
    local i; for i in "${!app_id[@]}"; do [ "${app_id[i]}" = "$1" ] && { echo "$i"; return 0; }; done
    return 1
}

extra=()   # chosen app ids
img=""
yes=0
demo=0
for arg in "$@"; do
    case "$arg" in
        --brave|--vesktop|--spicetify) extra+=("${arg#--}") ;;
        --apps=*)
            IFS=, read -ra ids <<< "${arg#--apps=}"
            for id in "${ids[@]}"; do
                app_index "$id" >/dev/null || { echo "unknown app: $id (see packages/apps.conf)" >&2; exit 1; }
                extra+=("$id")
            done ;;
        --all-apps)  extra=("${app_id[@]}") ;;
        --yes)       yes=1 ;;
        --demo)      demo=1 ;;
        -*)          echo "unknown option: $arg" >&2; exit 1 ;;
        *)           img="$arg" ;;
    esac
done

# targets install.sh replaces; existing real files there are moved to the backup
targets=(hypr/hyprland.lua hypr/hyprlock.conf hypr/hypridle.conf quickshell/rice kitty/kitty.conf
         rofi/config.rasi fastfetch/logo.txt wallust fontconfig/fonts.conf
         gtk-3.0/gtk.css gtk-4.0/gtk.css yazi/theme.toml qt6ct/qt6ct.conf
         cava/config fastfetch/config.jsonc btop/btop.conf)
backup="$HOME/.config/rice-backup-$(date +%Y%m%d-%H%M%S)"
log="$HOME/.cache/rice-install.log"
notes="$HOME/.cache/rice-install.notes"
preset=""

# ---------------------------------------------------------------- ui
fancy=0
[ -t 0 ] && [ -t 1 ] && [ "$yes" = 0 ] && fancy=1
accent="15"   # black and white: bright white for highlights, faint for the rest
if [ -t 1 ]; then ok=$'\e[1m✓\e[0m'; bad=$'\e[1m✗\e[0m'; warn=$'\e[1m!\e[0m'; dim=$'\e[2m'; off=$'\e[0m'
else ok="ok"; bad="FAIL"; warn="!"; dim=""; off=""; fi

say()  { printf '  %s %s\n' "$1" "$2"; }
note() { echo "$*" >> "$notes"; }
die()  { say "$bad" "$*"; exit 1; }
mmss() { printf '%d:%02d' $(($1 / 60)) $(($1 % 60)); }

banner() {
    if [ "$fancy" = 1 ]; then
        gum style --border rounded --border-foreground "$accent" --padding "0 3" --margin "1 2" \
            "$(gum style --foreground "$accent" --bold '▲  rice installer')" \
            "$(gum style --faint 'Hyprland · Quickshell · wallust')"
    else
        echo; echo "  rice installer: Hyprland, Quickshell, wallust"; echo
    fi
}

# ---------------------------------------------------------------- checks
preflight() {
    if command -v pacman >/dev/null; then say "$ok" "Arch Linux detected"
    elif [ "$demo" = 1 ]; then say "$warn" "not Arch Linux (fine for the demo)"
    else die "this installer needs Arch Linux (pacman not found)"; fi

    if [ "$demo" = 0 ] && [ "$(id -u)" = 0 ]; then die "run as your user, not root (sudo is asked for when needed)"; fi

    if curl -sI --max-time 5 https://archlinux.org >/dev/null 2>&1; then say "$ok" "internet connection"
    else [ "$demo" = 1 ] && say "$warn" "no internet (fine for the demo)" || die "no internet connection"; fi

    if [ "$demo" = 0 ]; then
        command -v sudo >/dev/null || die "sudo not found"
        say "$ok" "sudo available"
    fi

    local found=() t
    for t in "${targets[@]}"; do
        [ -e "$HOME/.config/$t" ] && [ ! -L "$HOME/.config/$t" ] && found+=("${t%%/*}")
    done
    if [ ${#found[@]} -gt 0 ]; then
        say "$warn" "existing configs found: $(printf '%s\n' "${found[@]}" | sort -u | paste -sd, | sed 's/,/, /g')  ${dim}(will be backed up)${off}"
    fi
    echo
}

need_gum() {
    [ "$fancy" = 1 ] || return 0
    command -v gum >/dev/null && return 0
    [ "$demo" = 1 ] && die "the demo needs gum: sudo pacman -S gum"
    say "$warn" "installing gum for the installer menus"
    sudo pacman -S --needed --noconfirm gum >/dev/null || die "could not install gum"
}

# ---------------------------------------------------------------- menus
# shared look: indented like the rest of the output, our own one-line hint instead of gum's footer
menu=(--header "" --no-show-help --padding "0 2" --cursor "› " --cursor.foreground "$accent")
menu_title() {  # menu_title <title> <hint>
    printf '  \e[1m%s\e[0m\n  %s%s%s\n' "$1" "$dim" "$2" "$off"
}
pick_apps() {
    [ "$fancy" = 1 ] || return 0
    local items=() sel="" i choice
    for i in "${!app_id[@]}"; do   # name · category · about, in apps.conf order
        items+=("$(printf '%-13s %-9s %s' "${app_name[i]}" "${app_cat[i]}" "${app_about[i]}")")
        case " ${extra[*]-} " in *" ${app_id[i]} "*) sel+="${items[i]}," ;; esac
    done
    menu_title "Optional apps" "x toggle · ↑ ↓ move · enter confirm"
    choice=$(gum choose "${menu[@]}" --no-limit --height "${#items[@]}" --selected.foreground "$accent" \
        --cursor-prefix "○ " --unselected-prefix "○ " --selected-prefix "● " \
        --selected "${sel%,}" "${items[@]}") || exit 130
    extra=()
    for i in "${!app_id[@]}"; do   # gum prints the chosen rows as shown
        printf '%s\n' "$choice" | grep -Fxq "${items[i]}" && extra+=("${app_id[i]}")
    done
    return 0
}

# steam lives in multilib; without it pacman would fail the apps step, so drop it with a note
check_multilib() {
    case " ${extra[*]-} " in *" steam "*) ;; *) return 0 ;; esac
    grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null && return 0
    local keep=() id
    for id in "${extra[@]}"; do [ "$id" = steam ] || keep+=("$id"); done
    extra=(${keep[@]+"${keep[@]}"})
    say "$warn" "Steam skipped: enable [multilib] in /etc/pacman.conf, then: sudo pacman -S steam"
    echo
}

pick_preset() {
    [ "$fancy" = 1 ] && [ -z "$img" ] || return 0
    local rows=() d n
    for d in presets/*/; do
        d=${d%/}; n=$(find "$d/wallpapers" -type f | wc -l)
        rows+=("$(printf '%-10s %s wallpapers' "${d#presets/}" "$n")")
    done
    echo
    menu_title "Starting preset" "↑ ↓ move · enter pick"
    preset=$(gum choose "${menu[@]}" "${rows[@]}") || exit 130
    preset=${preset%% *}
}

confirm() {
    local chosen="none" id names=()
    for id in "${extra[@]+"${extra[@]}"}"; do names+=("${app_name[$(app_index "$id")]}"); done
    [ ${#names[@]} -gt 0 ] && chosen=$(printf '%s\n' "${names[@]}" | paste -sd, | sed 's/,/, /g')
    local start="${img:-${preset:-first preset wallpaper}}"
    local summary
    summary=$(printf '%-12s %s\n' \
        packages "${#pkgs[@]} from pacman, ${#aur_core[@]} from AUR" \
        apps "$chosen" \
        theme "$start" \
        backup "${backup/#$HOME/\~}")
    if [ "$fancy" = 1 ]; then
        echo
        gum style --border normal --border-foreground "$accent" --padding "0 2" --margin "0 2" \
            "$(gum style --bold 'Ready to install')" "" "$summary"
        gum confirm --padding "0 2" --no-show-help --prompt.foreground "$accent" --selected.background "$accent" --selected.foreground 0 "Continue?" || { echo "  cancelled"; exit 0; }
    else
        echo "$summary" | sed 's/^/  /'
    fi
    echo
}

# ---------------------------------------------------------------- steps
step_packages() {
    # -Syu: a fresh sync database and a full upgrade (a sync without upgrade risks a partial upgrade)
    sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
}

step_aur() {
    if ! command -v yay >/dev/null; then
        sudo pacman -S --needed --noconfirm git base-devel
        local tmp; tmp=$(mktemp -d); git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay"
        (cd "$tmp/yay" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi
    yay -S --needed --noconfirm "${aur_core[@]}"
}

# Optional apps, each with its own manager: official-repo apps with pacman first,
# so a failing AUR build cannot stop them, then AUR apps with yay.
step_extras() {
    local id i repo=() aur=()
    for id in "${extra[@]+"${extra[@]}"}"; do
        i=$(app_index "$id")
        if [ "${app_src[i]}" = pacman ]; then repo+=("${app_pkg[i]}"); else aur+=("${app_pkg[i]}"); fi
    done
    [ ${#repo[@]} -eq 0 ] || sudo pacman -S --needed --noconfirm "${repo[@]}"
    [ ${#aur[@]} -eq 0 ] || yay -S --needed --noconfirm "${aur[@]}"
}

link() {  # link <source in repo> <target>
    local src="$here/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then mkdir -p "$backup"; mv "$dst" "$backup/"; fi
    ln -sfn "$src" "$dst"
}

step_configs() {
    # Hyprland 0.57+ reads only hyprland.lua; hyprlock and hypridle still use .conf.
    link hypr/hyprland.lua      "$HOME/.config/hypr/hyprland.lua"
    link hypr/hyprlock.conf     "$HOME/.config/hypr/hyprlock.conf"
    link hypr/hypridle.conf     "$HOME/.config/hypr/hypridle.conf"
    link quickshell            "$HOME/.config/quickshell/rice"
    link kitty/kitty.conf       "$HOME/.config/kitty/kitty.conf"
    link rofi/config.rasi       "$HOME/.config/rofi/config.rasi"
    link fastfetch/logo.txt     "$HOME/.config/fastfetch/logo.txt"
    link wallust                "$HOME/.config/wallust"
    link fontconfig/fonts.conf  "$HOME/.config/fontconfig/fonts.conf"
    # wallust writes these from the wallpaper; move any hand-made ones out of the way first.
    local f dst
    # cava and fastfetch configs are wallust outputs too; btop.conf is edited below.
    for f in gtk-3.0/gtk.css gtk-4.0/gtk.css yazi/theme.toml cava/config fastfetch/config.jsonc; do
        dst="$HOME/.config/$f"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then mkdir -p "$backup/$(dirname "$f")"; mv "$dst" "$backup/$f"; fi
    done
    mkdir -p "$HOME/.config/"{gtk-3.0,gtk-4.0,yazi,qt6ct/colors}
    fc-cache -f >/dev/null
}

step_theming() {
    # Qt 6 apps: Fusion style, the wallust palette, JetBrains Mono.
    local qt="$HOME/.config/qt6ct/qt6ct.conf"
    if [ -e "$qt" ] && [ ! -L "$qt" ]; then mkdir -p "$backup/qt6ct"; mv "$qt" "$backup/qt6ct/"; fi
    cat > "$qt" <<EOT
[Appearance]
custom_palette=true
color_scheme_path=$HOME/.config/qt6ct/colors/wallust.conf
icon_theme=Papirus-Dark
standard_dialogs=default
style=Fusion

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
general="JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
EOT

    # GTK apps: adw-gtk3 (so GTK 3 matches libadwaita), dark, JetBrains Mono, Papirus icons.
    local gtk_failed=0
    gs() { gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null || gtk_failed=1; }
    gs gtk-theme 'adw-gtk3-dark'
    gs color-scheme 'prefer-dark'
    gs icon-theme 'Papirus-Dark'
    gs font-name 'JetBrainsMono Nerd Font 10'
    gs document-font-name 'JetBrainsMono Nerd Font 10'
    gs monospace-font-name 'JetBrainsMono Nerd Font 10'
    [ "$gtk_failed" = 0 ] || note "GTK settings were not saved: run install.sh again from inside Hyprland"
    mkdir -p "$HOME/.config/btop"
    if [ -f "$HOME/.config/btop/btop.conf" ] && [ ! -L "$HOME/.config/btop/btop.conf" ]; then
        mkdir -p "$backup/btop"; cp "$HOME/.config/btop/btop.conf" "$backup/btop/"
    fi
    grep -q '^color_theme' "$HOME/.config/btop/btop.conf" 2>/dev/null &&
        sed -i 's/^color_theme.*/color_theme = "wallust"/' "$HOME/.config/btop/btop.conf" ||
        echo 'color_theme = "wallust"' >> "$HOME/.config/btop/btop.conf"
    install -Dm755 scripts/wall "$HOME/.local/bin/wall"
    install -Dm755 scripts/cursor-theme "$HOME/.local/bin/cursor-theme"
    install -Dm755 scripts/manga-frames "$HOME/.local/bin/manga-frames"
    install -Dm755 scripts/rice-lock "$HOME/.local/bin/rice-lock"
    install -Dm755 scripts/rice-special "$HOME/.local/bin/rice-special"
    install -Dm755 scripts/rice-shell "$HOME/.local/bin/rice-shell"
    install -Dm755 scripts/rice-record "$HOME/.local/bin/rice-record"
    # manga-frames reads the preset list from here when run from ~/.local/bin.
    sudo install -d /usr/local/share/rice && sudo cp -r presets /usr/local/share/rice/
    # boot-theme runs as root (sudo boot-theme), so it lives where sudo finds it; it loads palette-pick beside it.
    sudo install -Dm755 -t /usr/local/bin scripts/boot-theme scripts/palette-pick
    sudo install -Dm644 -t /usr/local/share/rice/sddm sddm/Main.qml sddm/metadata.desktop sddm/theme.conf \
        quickshell/lock/Manga.js quickshell/lock/InkPanel.qml quickshell/lock/ink.frag
    mkdir -p "$HOME/Pictures/wallpapers"
    # the presets' wallpapers, plus any of your own dropped in wallpapers/ (not tracked)
    cp -n presets/*/wallpapers/* wallpapers/* "$HOME/Pictures/wallpapers/" 2>/dev/null || true

    # Spotify theme (if Spotify is installed): colours come from wallust.
    if command -v spicetify >/dev/null && [ -d "$HOME/.config/spicetify" ]; then
        mkdir -p "$HOME/.config/spicetify/Themes/wallust"
        spicetify config current_theme wallust color_scheme Base >/dev/null || true
    fi

    # Quick panel > Deck commands: a starting copy, never overwritten (it is yours to edit).
    [ -e "$HOME/.config/rice/deck.conf" ] || install -Dm644 rice/deck.conf "$HOME/.config/rice/deck.conf"

    # Settings pages write these; hyprlock, hypridle, hyprsunset and hyprland.lua read them, so start them empty.
    touch "$HOME/.config/hypr/"{rice-idle,rice-lock,rice-night}.conf "$HOME/.config/hypr/rice-keys.lua"
}

step_services() {
    # Settings > Bluetooth and Power need these daemons running.
    sudo systemctl enable --now bluetooth.service power-profiles-daemon.service
    # Quickshell is the notification daemon now. An installed mako can still be started by D-Bus
    # before Quickshell is up and then keeps the notification service, so ask for it to go.
    if pacman -Qq mako >/dev/null 2>&1; then
        note "mako would compete with the rice's notifications; remove it: sudo pacman -Rns mako"
    fi
}

step_theme() {
    # templates/symbol.svg picks the symbol wallust colours in.
    if [ -n "$preset" ]; then
        ln -sfn "../../presets/$preset/symbol.svg" wallust/templates/symbol.svg
        [ -z "$img" ] && img="$HOME/Pictures/wallpapers/$(basename "$(find "presets/$preset/wallpapers" -type f -print -quit)")"
    fi
    [ -e wallust/templates/symbol.svg ] || ln -sfn ../../presets/naruto/symbol.svg wallust/templates/symbol.svg
    [ -z "$img" ] && img=$(find "$HOME/Pictures/wallpapers" -type f -print -quit)
    if [ -n "$img" ]; then
        mkdir -p "$HOME/.cache/wall"; realpath "$img" > "$HOME/.cache/wall/current"
        "$HOME/.local/bin/wall" --colours "$img"
    fi
}

steps=(packages "packages" aur "AUR packages" extras "apps" configs "configs" theming "theming"
       services "services" theme "first theme")
total=$((${#steps[@]} / 2))

run_step() {  # run_step <index> <name> <title>
    local i=$1 fn="step_$2" title=$3 t0=$SECONDS rc=0 label
    label=$(printf '[%d/%d] %-16s' "$i" "$total" "$title")
    echo "==== $title" >> "$log"
    # In the background so set -e still stops the step at its first failing command
    # (it is ignored inside a function called as `fn || ...`).
    if [ "$demo" = 1 ]; then sleep $((1 + RANDOM % 3)) & else "$fn" >> "$log" 2>&1 & fi
    local pid=$!
    if [ "$fancy" = 1 ]; then
        gum spin --spinner dot --spinner.foreground "$accent" --title "$label" -- \
            sh -c "while kill -0 $pid 2>/dev/null; do sleep 0.2; done"
    fi
    wait "$pid" || rc=$?
    if [ "$rc" = 0 ]; then
        printf '  %s %s %s\n' "$label" "$ok" "$dim$(mmss $((SECONDS - t0)))$off"
        return 0
    fi
    printf '  %s %s\n\n' "$label" "$bad"
    tail -n 8 "$log" | sed 's/^/    /'
    echo; say "" "full log: $log"
    [ "$i" -le 3 ] && say "" "nothing was linked yet, so your configs are untouched"
    [ "$i" -ge 4 ] && [ -d "$backup" ] && say "" "configs replaced so far were moved to ${backup/#$HOME/\~}"
    exit 1
}

finish() {
    local t=$SECONDS
    echo
    say "$ok" "Rice installed in $(mmss "$t")$([ "$demo" = 1 ] && echo ' (demo: nothing was changed)')"
    [ -d "$backup" ] && say "" "old configs moved to ${backup/#$HOME/\~}"
    if [ -s "$notes" ]; then echo; while read -r n; do say "$warn" "$n"; done < "$notes"; fi
    local next
    next=$(printf '%s\n' \
        "Next" \
        "  1. Log out and choose Hyprland" \
        "  2. SUPER+W   pick a wallpaper" \
        "  3. SUPER+/   see every shortcut" \
        "" \
        "Optional" \
        "  · sudo boot-theme              GRUB, Plymouth, login screen" \
        "  · sudo systemctl enable sddm   use the themed login screen")
    echo
    if [ "$fancy" = 1 ]; then gum style --margin "0 2" "$next"; else echo "$next" | sed 's/^/  /'; fi
    echo
}

# ---------------------------------------------------------------- main
mkdir -p "$(dirname "$log")"; : > "$log"; : > "$notes"
need_gum
banner
preflight
pick_apps
check_multilib
pick_preset
confirm
if [ "$demo" = 0 ]; then
    sudo -v || die "sudo failed"
    # Ctrl-C stops the running step too (background jobs ignore SIGINT); on exit, end the keepalive below.
    trap 'echo; say "$bad" "cancelled (log: $log)"; trap - INT TERM; kill 0' INT TERM
    trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
    # keep sudo's timestamp fresh while steps run behind the spinner
    while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done &
fi
SECONDS=0
for ((s = 0; s < ${#steps[@]}; s += 2)); do run_step $((s / 2 + 1)) "${steps[s]}" "${steps[s + 1]}"; done
finish
