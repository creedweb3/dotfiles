-- Hyprland: tinted, translucent tiling desktop that matches the demo.
-- Hyprland 0.57+ reads this Lua file; hyprland.conf is no longer loaded.
-- Colours come from the wallpaper: `wall <image>` makes wallust write
-- ~/.config/hypr/colors.lua, then reloads Hyprland.

local home = os.getenv("HOME")

-- dofile (not require) so `hyprctl reload` rereads the colours after `wall`.
local fallback = {
    accent = "rgba(e8e8e8ee)",
    accent2 = "rgba(9e9e9eee)",
    muted = "rgba(59595966)",
    shadow = "rgba(000000cc)",
}
local ok, colors = pcall(dofile, home .. "/.config/hypr/colors.lua")
if not ok or type(colors) ~= "table" then
    colors = fallback
end

-- A few Quickshell settings (~/.config/rice/prefs.json) matter here too. Flat JSON, so a pattern
-- finds them; values are checked against the choices before use.
local function pref(key, allowed, default)
    local f = io.open(home .. "/.config/rice/prefs.json")
    if not f then return default end
    local text = f:read("a")
    f:close()
    local v = text:match('"' .. key .. '"%s*:%s*"?([%w%-]+)"?')
    if v == nil then return default end
    for _, a in ipairs(allowed) do
        if v == a then return v end
    end
    return default
end

-- Settings > Default apps > terminal
local terminal = pref("dterm", { "kitty", "foot", "alacritty" }, "kitty")
local files = "kitty -e yazi"
local browser = "brave"
local qs = "qs -c rice ipc call "
local mod = "SUPER"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- Settings > Display > Monitor writes rice-monitors.lua: a list of hl.monitor tables, one per output.
local okM, monitors = pcall(dofile, home .. "/.config/hypr/rice-monitors.lua")
if okM and type(monitors) == "table" then
    for _, m in ipairs(monitors) do
        if type(m) == "table" and type(m.output) == "string" then
            hl.monitor(m)
        end
    end
end

-- Dart cursor (scripts/cursor-theme); `wall --restore` below rebuilds it in the current accent.
hl.env("XCURSOR_THEME", "rice-dart")
hl.env("XCURSOR_SIZE", "26")
hl.env("HYPRCURSOR_THEME", "rice-dart")
hl.env("HYPRCURSOR_SIZE", "26")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 0.5 && " .. home .. "/.local/bin/wall --restore")
    -- rice-shell starts `qs -c rice` at the ui size from Settings > Bar
    hl.exec_cmd(home .. "/.local/bin/rice-shell")
    hl.exec_cmd("hypridle")
    -- Night light (Settings > Display > Night light) if it was left on.
    hl.exec_cmd('f="$HOME/.config/hypr/rice-night.conf"; grep -q "^# rice: enabled=1" "$f" 2>/dev/null && hyprsunset -c "$f"')
    -- No polkit-gnome: Quickshell (overlays/PolkitPopup.qml) is the polkit agent.
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- Tray applet doubles as the Bluetooth pairing agent (PIN / passkey prompts).
    hl.exec_cmd("blueman-applet")
    -- Brave's first launch after login was slow (cold start: reading ~0.7GB, GPU and profile setup).
    -- Start it hidden at login, so SUPER+B only opens a window in the running Brave (~0.3s).
    hl.exec_cmd("command -v " .. browser .. " >/dev/null && sleep 5 && " .. browser .. " --no-startup-window")
end)

-- Demo look: 6px between windows (the demo's 12px is two gaps_in), 14px to
-- the screen edge, square corners, a 2px border lit in the accent.
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 2,
        col = {
            active_border = colors.accent,
            inactive_border = colors.muted,
        },
        layout = "dwindle",
        resize_on_border = true,
    },
    decoration = {
        rounding = 0,
        active_opacity = 0.94,
        inactive_opacity = 0.88,
        -- The demo darkens the rest of the screen by half behind a special workspace.
        dim_special = 0.5,
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            noise = 0.02,
            vibrancy = 0.2,
        },
        -- Flat windows, no shadow and no glow, as in the demo.
        shadow = { enabled = false },
        glow = { enabled = false },
    },
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- allow_session_lock_restore stays off (default): with it on, any client can take over a live
        -- session lock and unlock it. If the Quickshell lock dies, recover from a TTY (lockdead screen).
    },
})

-- Settings > Windows (Quickshell) writes rice-settings.lua and runs hyprctl reload.
-- The quick panel's Theme tab writes the same file. window_tint (the demo's accent in the glass) has
-- no Hyprland equivalent and is not applied.
local okS, rs = pcall(dofile, home .. "/.config/hypr/rice-settings.lua")
if not okS or type(rs) ~= "table" then
    rs = {}
end
hl.config({
    general = { border_size = rs.border_size },
    decoration = { active_opacity = rs.active_opacity, inactive_opacity = rs.inactive_opacity, blur = { size = rs.blur_size } },
})

-- Border tint (0-1, default 0.4 as the demo): how much accent is mixed into the unfocused border.
local function rgba(c)
    local h = type(c) == "string" and c:match("^rgba%((%x%x%x%x%x%x%x%x)%)$")
    if not h then return nil end
    return { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), tonumber(h:sub(7, 8), 16) }
end
local tint = tonumber(rs.border_tint) or 0.4
tint = math.max(0, math.min(1, tint))
local a, m = rgba(colors.accent), rgba(colors.muted)
if a and m then
    local mix = {}
    for i = 1, 4 do
        mix[i] = math.floor(m[i] + (a[i] - m[i]) * tint + 0.5)
    end
    hl.config({ general = { col = { inactive_border = string.format("rgba(%02x%02x%02x%02x)", mix[1], mix[2], mix[3], mix[4]) } } })
end

-- Demo motion: views slide with cubic-bezier(.3, 0, .2, 1) over 0.45s; a
-- special workspace fades in while it grows from 97%.
hl.curve("soft", { type = "bezier", points = { { 0.3, 0 }, { 0.2, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 1.5, bezier = "soft", style = "popin 97%" })
-- Moves and resizes start fast and settle: the soft curve's slow start read as lag when windows
-- make room for the bar or a new window (Brave above all) splits the workspace. 150ms.
hl.curve("snap", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, bezier = "snap" })
-- Opening windows grow from 85% over 120ms and fade in over 80ms on the snap curve: most of the
-- motion is in the first frames, so a new window visibly animates in yet shows at once.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.2, bezier = "snap", style = "popin 85%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.8, bezier = "snap" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "layers", enabled = true, speed = 2.5, bezier = "soft", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "soft", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "soft", style = "fade" })

-- Special workspaces: music and chat open as one big centred window over the
-- current workspace (76% x 78%, as in the demo). The same key hides them again.
-- browser and sysmon are rice-started windows (scripts/rice-special) with their own class, so the
-- normal browser (SUPER+B) and terminals stay on the workspaces.
local special = {
    music = "^(Spotify|spotify|tidal-hifi|TIDAL|rice-music)$",   -- rice-music: ncmpcpp for mpd
    chat = "^(vesktop|discord|org\\.telegram\\.desktop|telegram-desktop)$",
    browser = "^(rice-browser)$",
    sysmon = "^(rice-sysmon)$",
}
for name, class in pairs(special) do
    hl.window_rule({
        name = "special-" .. name,
        match = { class = class },
        workspace = "special:" .. name .. " silent",
        float = true,
        size = { "monitor_w * 0.76", "monitor_h * 0.78" },
        center = true,
        opacity = "0.96 0.96",
    })
end
-- Apps (kitty among them) ask to open maximized, which on a busy workspace looked like a new terminal
-- opening fullscreen. Ignore the request: windows tile; SUPER+F / SUPER+ALT+F still maximize on demand.
hl.window_rule({ name = "no-maximize-request", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "float-tools",
    match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|openthx|dev\\.openthx\\.openthx)$" },
    float = true,
})

-- The Quickshell bar and pop-ups sit on blurred glass.
-- ignore_alpha above 0 keeps the see-through gaps between bar boxes unblurred.
-- Hyprland matches the whole namespace, so the pattern ends in .* (rice-bar, rice-settings, ...).
-- Settings > Panels > behind blur: 0 turns it off; higher values also make the glass more see-through
-- (Theme.glassAlpha). Hyprland has one blur size, shared with windows.
local sblur = tonumber(pref("sblur", { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12" }, "9"))
hl.layer_rule({ match = { namespace = "(quickshell|rice|rofi).*" }, blur = sblur > 0, ignore_alpha = 0.05 })

-- Settings > Shortcuts writes rice-keys.lua: { ["id"] = "SUPER + K", ... } for each shortcut moved
-- off its default (ids match quickshell/overlays/Keymap.js). K(id, default) picks the key to bind.
local okK, rk = pcall(dofile, home .. "/.config/hypr/rice-keys.lua")
local function K(id, default)
    if okK and type(rk) == "table" and type(rk[id]) == "string" and rk[id] ~= "" then return rk[id] end
    return default
end

-- While Settings > Shortcuts records new keys it switches to this empty submap, so the keys reach
-- the settings window instead of running their old shortcut; it switches back to "reset" when done.
-- Stuck in it (Quickshell died mid-recording)? CTRL+ALT+Escape leaves it, as does
-- hyprctl dispatch 'hl.dsp.submap("reset")'. Plain Escape stays free: the page uses it to cancel.
-- pcall: if this Hyprland lacks hl.define_submap, recording still works for keys not yet bound.
pcall(hl.define_submap, "rice-record", function()
    hl.bind("CTRL + ALT + Escape", hl.dsp.submap("reset"))
end)

-- Apps
-- Tap SUPER on its own (release: only when no other key was pressed with it), as in Caelestia.
hl.bind(K("launcher", mod .. " + SUPER_L"), hl.dsp.exec_cmd(qs .. "launcher toggle"), { release = true })
hl.bind(K("terminal", mod .. " + T"), hl.dsp.exec_cmd(terminal))
hl.bind(K("files", mod .. " + E"), hl.dsp.exec_cmd(files))
hl.bind(K("browser", mod .. " + B"), hl.dsp.exec_cmd(browser))
hl.bind(K("settings", mod .. " + S"), hl.dsp.exec_cmd(qs .. "settings toggle"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd(home .. "/.local/bin/openthx-ctl pick"))

-- Windows
hl.bind(K("close", mod .. " + Q"), hl.dsp.window.close())
hl.bind(K("fullscreen", mod .. " + F"), hl.dsp.window.fullscreen({ action = "toggle" }))
-- Float: a window made floating opens at 60% x 70% of the screen, centred, instead of keeping
-- its tiled (often full-screen) size and sliding under the bar.
hl.bind(K("float", mod .. " + ALT + space"), function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    local w = hl.get_active_window()
    if not (w and w.floating) then
        return
    end
    local m = hl.get_active_monitor()
    local mw, mh = 1920, 1080
    if m then
        mw, mh = m.width / (m.scale or 1), m.height / (m.scale or 1)
    end
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(mw * 0.6), y = math.floor(mh * 0.7) }))
    hl.dispatch(hl.dsp.window.center())
end)
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspaces 1-10 (key 0 is workspace 10)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
-- music and chat: rice-special starts the app if it isn't running, then toggles the workspace
hl.bind(K("music", mod .. " + M"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-special music"))
hl.bind(K("chat", mod .. " + C"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-special chat"))
-- browser and system monitor: rice-special starts the window the first time, then toggles it
hl.bind(K("browserspecial", mod .. " + SHIFT + B"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-special browser"))
hl.bind(K("sysmon", mod .. " + grave"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-special sysmon"))

-- System
hl.bind(K("panel", mod .. " + X"), hl.dsp.exec_cmd(qs .. "panel toggle"))
hl.bind(K("wallpaper", mod .. " + W"), hl.dsp.exec_cmd(qs .. "wallpaper toggle"))
hl.bind(K("screenshot", mod .. " + SHIFT + S"), hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(K("picker", mod .. " + SHIFT + C"), hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(K("lock", mod .. " + L"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-lock"))
hl.bind(K("sheet", mod .. " + slash"), hl.dsp.exec_cmd(qs .. "cheatsheet toggle"))
-- Power button (Settings > Power), read when pressed. logind must leave the key alone
-- (HandlePowerKey=ignore, see README), or it shuts down before this runs.
hl.bind("XF86PowerOff", hl.dsp.exec_cmd([[sh -c 'case "$(jq -r ".pbtn // \"menu\"" "$HOME/.config/rice/prefs.json" 2>/dev/null || echo menu)" in
    off) systemctl poweroff ;; sleep) systemctl suspend ;; nothing) ;; *) qs -c rice ipc call launcher open power ;; esac']]))

-- Volume, mic, brightness, media (they also work on the lock screen)
local held = { locked = true, repeating = true }
-- Changing the volume unmutes first, so a muted sink doesn't silently climb.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind(K("micmute", mod .. " + U"), hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), held)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(K("playpause", "CTRL + " .. mod .. " + space"), hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind(K("next", "CTRL + " .. mod .. " + equal"), hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind(K("prev", "CTRL + " .. mod .. " + minus"), hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(K("audio", "CTRL + ALT + V"), hl.dsp.exec_cmd("pavucontrol"))

-- Extra shortcuts picked from Caelestia (caelestia-dots/caelestia hypr/hyprland/keybinds.lua).
-- Alt-tab: cycle windows on the workspace and raise the one picked.
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { repeating = true })
hl.bind("SHIFT + ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end, { repeating = true })

-- Resize the focused window by 10% of its size; SHIFT for height. Held keys repeat.
local function grow(x, y)
    return function()
        local w = hl.get_active_window()
        if not (w and w.size) then return end
        hl.dispatch(hl.dsp.window.resize({ x = math.floor(w.size.x * x / 100), y = math.floor(w.size.y * y / 100), relative = true }))
    end
end
hl.bind(mod .. " + minus", grow(-10, 0), { repeating = true })
hl.bind(mod .. " + equal", grow(10, 0), { repeating = true })
hl.bind(mod .. " + SHIFT + minus", grow(0, -10), { repeating = true })
hl.bind(mod .. " + SHIFT + equal", grow(0, 10), { repeating = true })

-- Previous / next workspace, and send a window to a workspace without following it.
hl.bind("CTRL + " .. mod .. " + left", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("CTRL + " .. mod .. " + right", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
for i = 1, 10 do
    hl.bind(mod .. " + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Window extras
hl.bind(K("maximize", mod .. " + ALT + F"), hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(K("pin", mod .. " + P"), hl.dsp.window.pin())
hl.bind(K("center", "CTRL + " .. mod .. " + backslash"), hl.dsp.window.center())
-- Picture-in-picture: float, shrink to a quarter of the screen height, park bottom-right, pin.
local function pip_actions(w)
    local m = w.monitor or hl.get_active_monitor()
    local s = m and m.mode
    if not (s and w.size) then return {} end
    local k = (s.height / 4) / w.size.y
    local ww, wh = math.floor(math.max(200, w.size.x * k)), math.floor(math.max(150, w.size.y * k))
    local off = math.min(s.width, s.height) * 0.03
    return {
        hl.dsp.window.resize({ x = ww, y = wh, window = w }),
        hl.dsp.window.move({ x = math.floor(m.x + s.width - ww - off), y = math.floor(m.y + s.height - wh - off), relative = false, window = w }),
        hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true", window = w }),
    }
end
hl.bind(K("pip", mod .. " + ALT + backslash"), function()
    local w = hl.get_active_window()
    if not w then return end
    if not w.floating then hl.dispatch(hl.dsp.window.float()) end
    for _, d in ipairs(pip_actions(w)) do hl.dispatch(d) end
    hl.dispatch(hl.dsp.window.pin({ action = "on", window = "address:" .. w.address }))
end)

-- Tools: launcher modes, screenshots, recording, notifications, sleep
hl.bind(K("clipboard", mod .. " + V"), hl.dsp.exec_cmd(qs .. "launcher open clip"))
hl.bind(K("emoji", mod .. " + period"), hl.dsp.exec_cmd(qs .. "launcher open emoji"))
hl.bind(K("session", "CTRL + ALT + Delete"), hl.dsp.exec_cmd(qs .. "launcher open power"))
hl.bind(K("screenfull", "Print"), hl.dsp.exec_cmd(
    'f="$HOME/Pictures/Screenshots/shot-$(date +%Y%m%d-%H%M%S).png"; mkdir -p "${f%/*}"; ' ..
    'grim -o "$(hyprctl monitors -j | jq -r \'.[] | select(.focused) | .name\')" "$f" && wl-copy < "$f" && notify-send screenshot "saved and copied"'),
    { locked = true })
hl.bind(K("record", "CTRL + ALT + R"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-record"))
hl.bind(K("recordregion", mod .. " + SHIFT + ALT + R"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-record region"))
hl.bind(K("clearnotifs", "CTRL + ALT + C"), hl.dsp.exec_cmd(qs .. "notifs clear"), { locked = true })
-- hypridle locks before sleeping (before_sleep_cmd), so this wakes to the lock screen.
hl.bind(K("sleep", mod .. " + SHIFT + L"), hl.dsp.exec_cmd("systemctl suspend"))

-- Touchpad: three-finger swipe left/right changes workspace.
pcall(hl.gesture, { fingers = 3, direction = "horizontal", action = "workspace" })

-- Browser picture-in-picture windows float, stay pinned and keep their shape, bottom-right.
hl.window_rule({
    name = "pip",
    match = { title = "^Picture(-| )in(-| )[Pp]icture$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = { "monitor_w * 0.25", "monitor_h * 0.25" },
    move = { "monitor_w * 0.98 - window_w", "monitor_h * 0.97 - window_h" },
})
