import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../common"
import "Ui.js" as Ui

// Settings window (SUPER+S): sections on the left, the page on the right, as in the demo.
// Sections follow the demo's settings; each page only offers what the real rice can change.
//   qs -c rice ipc call settings toggle
//   qs -c rice ipc call settings openPage keys
Scope {
    id: root

    property string page: "theme"
    readonly property var nav: [
        ["Appearance", [["theme", "Theme"], ["bar", "Bar"], ["windows", "Windows"], ["panels", "Panels"],
            ["lockv", "Lock screen"], ["graphs", "Graphs"]]],
        ["Keybinds", [["keys", "Shortcuts"]]],
        ["Sound", [["out", "Output"], ["inp", "Input"], ["mix", "Apps"]]],
        ["Network", [["wifi", "Wi-Fi"], ["wired", "Wired"], ["vpn", "VPN"]]],
        ["Bluetooth", [["bt", "Devices"]]],
        ["Display", [["mon", "Monitor"], ["night", "Night light"]]],
        ["System", [["power", "Power"], ["dapps", "Default apps"], ["about", "About"]]]]
    readonly property var group: nav.find(g => g[1].some(p => p[0] === page)) || nav[0]
    // the Prefs keys each page owns, for its "reset" button (as the demo's OWN); Windows resets
    // its own file (rice-settings.lua) and has its own button
    readonly property var own: ({
        bar: ["marker", "gap", "anim", "sysic"],
        panels: ["wstyle", "rst", "ricon", "rsel", "rmatch", "mstyle", "vtex", "slook", "plook", "ntone", "pk", "depth", "sblur", "sdim"],
        lockv: ["locker", "mfr", "mpg", "mpick", "mink", "macc", "mday", "mdt", "mhint", "mmus",
            "mlsym", "mlday", "mldate", "mlquote", "mlmusic", "mlnotif", "mlhint"],
        graphs: ["gstyle", "gs"],
        power: ["pbtn"],
        dapps: ["dterm", "dmusic", "dchat"]
    })
    // ---- hyprlock fallback: the options it can show, as variables hyprlock.conf sources
    readonly property var dateFormats: ({ long: "%-d %B", short: "%a %-d %b", num: "%d.%m.%Y", iso: "%F" })
    readonly property string weekday: "<span letter_spacing='4096'>$(date +%A | tr '[:lower:]' '[:upper:]')</span>"
    readonly property string kanji: "$(date +%u | sed 's/1/月/;s/2/火/;s/3/水/;s/4/木/;s/5/金/;s/6/土/;s/7/日/;s/$/曜日/')"
    // a binding on Prefs, kept here (always loaded) rather than in the Lock page, so changes from any
    // page, "back to default" and the resets rewrite it too
    readonly property string hyprText: {
        const day = Prefs.mday === "kanji" ? kanji : Prefs.mday === "mix" ? weekday + "  " + kanji : weekday
        const flag = (k, p) => "$show_" + k + " = " + (Prefs[p] === "on" ? "1" : "") + "\n"
        return "# Written by the rice settings window (Appearance > Lock screen); hyprlock.conf sources it.\n"
            + flag("sym", "mlsym") + flag("day", "mlday") + flag("date", "mldate") + flag("music", "mlmusic") + flag("hint", "mlhint")
            + "$day_text = cmd[update:60000] echo \"" + day + "\"\n"
            + "$date_text = cmd[update:60000] date +'" + dateFormats[Prefs.mdt] + "' | tr '[:upper:]' '[:lower:]'\n"
    }
    onHyprTextChanged: saveHyprlock()
    function saveHyprlock() { hyprFile_.setText(hyprText) }
    FileView { id: hyprFile_; path: Quickshell.env("HOME") + "/.config/hypr/rice-lock.conf"; printErrors: false }

    readonly property string pageTitle: ([].concat(...Array.from(nav).map(g => Array.from(g[1]))).find(p => p[0] === page) || ["", ""])[1]

    // hyprland.lua reads sblur, dterm and the Windows file: reload it after a reset. The reload waits
    // a moment so prefs.json is written first; a full reset also removes the Windows file, in the
    // same shell, so the reload cannot run before the rm.
    property bool dropGlass: false
    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: {
            if (root.dropGlass)
                Quickshell.execDetached(["sh", "-c", 'rm -f "$1"; hyprctl reload', "sh",
                    Quickshell.env("HOME") + "/.config/hypr/rice-settings.lua"])
            else
                Quickshell.execDetached(["hyprctl", "reload"])
            root.dropGlass = false
        }
    }
    function afterReset() { reloadTimer.restart() }
    function resetAll() {
        Prefs.resetAll()
        dropGlass = true
        afterReset()
    }
    function factoryReset() {
        Prefs.factoryReset()
        dropGlass = true
        afterReset()
    }
    // "reset all" and "factory reset" ask first: the first click arms one for 3 s, a second click runs it
    property string armed: ""
    Timer { id: armTimer; interval: 3000; onTriggered: root.armed = "" }
    function arm(k, run) {
        if (armed === k) { armed = ""; armTimer.stop(); run(); return }
        armed = k
        armTimer.restart()
    }

    function show(p) {
        if (p && nav.some(g => g[1].some(x => x[0] === p))) page = p
        win.show()
        Qt.callLater(() => frame.forceActiveFocus())
    }
    function hide() { win.open = false }
    function toggle() { win.open ? hide() : show() }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle() }
        function openPage(page: string): void { root.show(page) }
    }

    OverlayWindow {
        id: win
        name: "settings"
        dim: 0.25
        onDismissed: root.hide()

        Rectangle {
            id: frame
            anchors.centerIn: parent
            width: 800
            height: 560
            color: Theme.glass
            border.color: Theme.muted
            focus: true
            Keys.onEscapePressed: root.hide()
            MouseArea { anchors.fill: parent; onClicked: frame.forceActiveFocus() }

            RowLayout {
                anchors { fill: parent; margins: 1 }
                spacing: 0

                ColumnLayout {
                    // fillWidth on the items below would otherwise spread up to this column
                    Layout.fillWidth: false
                    Layout.preferredWidth: 190
                    Layout.maximumWidth: 190
                    Layout.fillHeight: true
                    spacing: 0
                    Flickable {  // section list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: navCol.implicitHeight + 20
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: navCol
                            y: 10
                            width: parent.width
                            Repeater {
                                model: root.nav
                                Column {
                                    id: navGroup
                                    required property var modelData
                                    readonly property bool open: root.group[0] === modelData[0]
                                    width: navCol.width
                                    NavItem {
                                        text: navGroup.modelData[0]
                                        bold: true
                                        tint: navGroup.open ? Theme.accent : Theme.fg
                                        onClicked: root.page = navGroup.modelData[1][0][0]
                                    }
                                    Repeater {
                                        model: navGroup.open ? navGroup.modelData[1] : []
                                        NavItem {
                                            required property var modelData
                                            text: modelData[1]
                                            indent: 28
                                            size: 11.5
                                            on: root.page === modelData[0]
                                            onClicked: root.page = modelData[0]
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // as the demo: reset every setting to your defaults, or forget those too
                    NavItem {
                        Layout.fillWidth: true
                        text: root.armed === "all" ? "click again to reset all" : "reset all"
                        on: root.armed === "all"
                        onClicked: root.arm("all", root.resetAll)
                    }
                    NavItem {
                        Layout.fillWidth: true
                        text: root.armed === "factory" ? "click again to factory reset" : "factory reset"
                        on: root.armed === "factory"
                        onClicked: root.arm("factory", root.factoryReset)
                    }
                    Item { Layout.preferredHeight: 8 }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.muted }

                Flickable {  // the page
                    id: body
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: pageCol.implicitHeight + 36
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: pageCol
                        x: 22; y: 18
                        width: body.width - 44
                        spacing: 12
                        Loader {
                            id: pageLoader
                            width: parent.width
                            active: win.open
                            sourceComponent: ({theme: themePage, windows: windowsPage, keys: keysPage, out: outPage, inp: inpPage,
                                mix: mixPage, dapps: appsPage, about: aboutPage, bar: barPage, panels: panelsPage, lockv: lockPage,
                                graphs: graphsPage, wifi: wifiPage, wired: wiredPage, vpn: vpnPage, bt: btPage, mon: monPage,
                                night: nightPage, power: powerPage})[root.page]
                            onLoaded: body.contentY = 0
                        }
                        Rectangle {  // "reset ‹page›": this page's settings back to your defaults
                            visible: !!root.own[root.page]
                            width: resetText.implicitWidth + 24
                            height: resetText.implicitHeight + 12
                            color: "transparent"
                            border.color: resetArea.containsMouse ? Theme.accent : Theme.muted
                            Text {
                                id: resetText
                                anchors.centerIn: parent
                                text: "reset " + root.pageTitle.toLowerCase()
                                font { family: Theme.fontFamily; pixelSize: 12 }
                                color: Theme.fg
                            }
                            MouseArea {
                                id: resetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { Prefs.resetKeys(root.own[root.page]); root.afterReset() }
                            }
                        }
                    }
                }
            }
        }
    }

    component NavItem: Rectangle {
        id: item
        property string text
        property bool bold: false
        property bool on: false
        property int indent: 14
        property real size: 13
        property color tint: on ? Theme.accent : area.containsMouse ? Theme.fg : Theme.dim
        signal clicked()
        width: parent ? parent.width : 0
        height: label.implicitHeight + 14
        color: on ? Ui.alpha(Theme.accent, 0.18) : area.containsMouse ? Ui.alpha(Theme.accent, 0.12) : "transparent"
        Text {
            id: label
            x: item.indent
            anchors.verticalCenter: parent.verticalCenter
            text: item.text
            font { family: Theme.fontFamily; pixelSize: item.size; bold: item.bold }
            color: item.tint
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: item.clicked() }
    }

    Component { id: themePage; SettingsTheme {} }
    Component { id: windowsPage; SettingsWindows {} }
    Component { id: keysPage; SettingsKeys { onClose: root.hide() } }
    Component { id: outPage; SettingsSound { kind: "out" } }
    Component { id: inpPage; SettingsSound { kind: "inp" } }
    Component { id: mixPage; SettingsSound { kind: "mix" } }
    Component { id: appsPage; SettingsApps {} }
    Component { id: aboutPage; SettingsAbout {} }
    Component { id: barPage; SettingsBar {} }
    Component { id: panelsPage; SettingsPanels {} }
    Component { id: lockPage; SettingsLock {} }
    Component { id: graphsPage; SettingsGraphs {} }
    Component { id: wifiPage; SettingsWifi {} }
    Component { id: wiredPage; SettingsWired {} }
    Component { id: vpnPage; SettingsVpn {} }
    Component { id: btPage; SettingsBluetooth {} }
    Component { id: monPage; SettingsMonitor {} }
    Component { id: nightPage; SettingsNight {} }
    Component { id: powerPage; SettingsPower {} }
}
