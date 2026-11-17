//@ pragma IconTheme Papirus-Dark
// (install.sh installs Papirus; naming it here keeps icons working without qt6ct)
import QtQuick
import Quickshell
import "bar"
import "panel"
import "osd"
import "overlays"
import "lock"

// The rice's desktop shell (Quickshell). Installed to ~/.config/quickshell/rice and
// started by Hyprland with `qs -c rice`.
//   bar/       top bar, one per screen
//   panel/     quick panel and mini player       ipc: panel toggle
//              notification centre, sound / Bluetooth / Wi-Fi pop-ups (SideHost)
//   osd/       volume / mic / brightness pill, notification toasts
//              (the notification daemon is common/Notifs.qml)  ipc: notifs toggleDnd|clear
//   overlays/  cheatsheet, settings, wallpaper picker, launcher, polkit prompt
//   lock/      the manga lock screen                ipc: lock lock
//   common/    theme (palette.json), system state, icons
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    PanelHost {}
    SideHost {}
    Osd {}
    Toasts {}

    Cheatsheet {}
    Settings {}
    WallPicker {}
    Launcher {}
    PolkitPopup {}
    Lock {}
}
