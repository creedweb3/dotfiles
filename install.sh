#!/bin/bash
# Install the rice on Arch Linux: packages, configs (symlinked, old ones
# backed up), the `wall` command and a first theme from a wallpaper.
# Usage: ./install.sh [--brave] [--vesktop] [--spicetify] [--all-apps] [wallpaper-image]
# The flags add optional apps; without them only the rice itself is installed.
set -euo pipefail
cd "$(dirname "$0")"
here=$(pwd)

extra=()
img=""
for arg in "$@"; do
    case "$arg" in
        --brave)     extra+=(brave-bin) ;;
        --vesktop)   extra+=(vesktop-bin) ;;
        --spicetify) extra+=(spicetify-cli) ;;
        --all-apps)  extra+=(brave-bin vesktop-bin spicetify-cli) ;;
        -*)          echo "unknown option: $arg" >&2; exit 1 ;;
        *)           img="$arg" ;;
    esac
done

pkgs=(hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk kitty rofi awww
      fastfetch btop cava yazi ffmpegthumbnailer socat jq python-pillow tesseract tesseract-data-eng
      pipewire wireplumber pavucontrol playerctl brightnessctl
      grim slurp wl-clipboard libnotify qt6ct
      network-manager-applet blueman ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
      papirus-icon-theme adw-gtk-theme librsvg xorg-xcursorgen hyprcursor sddm
      hyprlock hypridle hyprpicker quickshell
      hyprsunset upower bluez bluez-utils networkmanager
      cliphist unicode-emoji pacman-contrib xdg-utils
      nm-connection-editor networkmanager-openvpn power-profiles-daemon noto-fonts-cjk ddcutil qt6-shadertools
      noise-suppression-for-voice sound-theme-freedesktop wf-recorder)
aur=(wallust tty-clock ${extra[@]+"${extra[@]}"})

echo ":: packages"
sudo pacman -S --needed --noconfirm "${pkgs[@]}"
if ! command -v yay >/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d); git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
fi
yay -S --needed --noconfirm "${aur[@]}"

echo ":: configs"
backup="$HOME/.config/rice-backup-$(date +%Y%m%d-%H%M%S)"
link() {  # link <source in repo> <target>
    local src="$here/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then mkdir -p "$backup"; mv "$dst" "$backup/"; fi
    ln -sfn "$src" "$dst"
}
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
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css yazi/theme.toml; do
    dst="$HOME/.config/$f"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then mkdir -p "$backup/$(dirname "$f")"; mv "$dst" "$backup/$f"; fi
done
mkdir -p "$HOME/.config/"{gtk-3.0,gtk-4.0,yazi,qt6ct/colors}
fc-cache -f >/dev/null

# Qt 6 apps: Fusion style, the wallust palette, JetBrains Mono.
qt="$HOME/.config/qt6ct/qt6ct.conf"
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
gs() { gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null || echo "   (could not set $1; run install.sh again from inside Hyprland)"; }
gs gtk-theme 'adw-gtk3-dark'
gs color-scheme 'prefer-dark'
gs icon-theme 'Papirus-Dark'
gs font-name 'JetBrainsMono Nerd Font 10'
gs document-font-name 'JetBrainsMono Nerd Font 10'
gs monospace-font-name 'JetBrainsMono Nerd Font 10'
mkdir -p "$HOME/.config/btop"
grep -q '^color_theme' "$HOME/.config/btop/btop.conf" 2>/dev/null &&
    sed -i 's/^color_theme.*/color_theme = "wallust"/' "$HOME/.config/btop/btop.conf" ||
    echo 'color_theme = "wallust"' >> "$HOME/.config/btop/btop.conf"
install -Dm755 scripts/wall "$HOME/.local/bin/wall"
install -Dm755 scripts/cursor-theme "$HOME/.local/bin/cursor-theme"
install -Dm755 scripts/manga-frames "$HOME/.local/bin/manga-frames"
install -Dm755 scripts/rice-lock "$HOME/.local/bin/rice-lock"
install -Dm755 scripts/rice-special "$HOME/.local/bin/rice-special"
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

echo ":: services"
# Settings > Bluetooth and Power need these daemons running.
sudo systemctl enable --now bluetooth.service power-profiles-daemon.service
# Quickshell is the notification daemon now. An installed mako can still be started by D-Bus
# before Quickshell is up and then keeps the notification service, so ask for it to go.
if pacman -Qq mako >/dev/null 2>&1; then
    echo "   mako is installed and would compete with the rice's notifications; remove it: sudo pacman -Rns mako"
fi

echo ":: first theme"
# Default preset; templates/symbol.svg picks the symbol wallust colours in.
[ -e wallust/templates/symbol.svg ] || ln -sfn ../../presets/naruto/symbol.svg wallust/templates/symbol.svg
[ -z "$img" ] && img=$(find "$HOME/Pictures/wallpapers" -type f -print -quit)
if [ -n "$img" ]; then
    mkdir -p "$HOME/.cache/wall"; realpath "$img" > "$HOME/.cache/wall/current"
    "$HOME/.local/bin/wall" --colours "$img"
fi
[ -n "$backup" ] && [ -d "$backup" ] && echo "old configs moved to $backup"
echo "done: log in to Hyprland; SUPER+W picks a wallpaper and re-themes everything"
echo "boot screens: run \`sudo boot-theme\` to draw GRUB, the Plymouth splash and the SDDM login from the wallpaper"
echo "login screen: SDDM is installed but not enabled; to use it: sudo systemctl enable sddm"
