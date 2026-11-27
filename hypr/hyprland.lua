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
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "soft", style = "popin 97%" })
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
hl.bind(K("launcher", mod .. " + D"), hl.dsp.exec_cmd(qs .. "launcher toggle"))
hl.bind(K("terminal", mod .. " + Return"), hl.dsp.exec_cmd(terminal))
hl.bind(K("files", mod .. " + E"), hl.dsp.exec_cmd(files))
hl.bind(K("browser", mod .. " + B"), hl.dsp.exec_cmd(browser))
hl.bind(K("settings", mod .. " + S"), hl.dsp.exec_cmd(qs .. "settings toggle"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd(home .. "/.local/bin/openthx-ctl pick"))

-- Windows
hl.bind(K("close", mod .. " + Q"), hl.dsp.window.close())
hl.bind(K("fullscreen", mod .. " + F"), hl.dsp.window.fullscreen({ action = "toggle" }))
-- Float: a window made floating opens at 60% x 70% of the screen, centred, instead of keeping
-- its tiled (often full-screen) size and sliding under the bar.
hl.bind(K("float", mod .. " + V"), function()
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
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(K("music", mod .. " + M"), hl.dsp.workspace.toggle_special("music"))
hl.bind(K("chat", mod .. " + X"), hl.dsp.workspace.toggle_special("chat"))
-- browser and system monitor: rice-special starts the window the first time, then toggles it
hl.bind(K("browserspecial", mod .. " + SHIFT + B"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-special browser"))
hl.bind(K("sysmon", mod .. " + grave"), hl.dsp.exec_cmd(home .. "/.local/bin/rice-special sysmon"))

-- System
hl.bind(K("panel", mod .. " + C"), hl.dsp.exec_cmd(qs .. "panel toggle"))
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
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+"), held)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"), held)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind(K("micmute", mod .. " + U"), hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 5%+"), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), held)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
