.pragma library
// Helpers for the network settings pages: nmcli's terse output and input checks.

// One line of `nmcli -t` output split into fields. nmcli escapes ':' and '\' inside values with '\'.
function fields(line) {
    const out = []
    let cur = ""
    for (let i = 0; i < line.length; i++) {
        const c = line[i]
        if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
        if (c === ":") { out.push(cur); cur = ""; continue }
        cur += c
    }
    out.push(cur)
    return out
}

// `nmcli -t -f key,key connection show <id>` prints "key:value" lines; values are not escaped there.
function keyValues(text) {
    const kv = {}
    for (const line of text.split("\n")) {
        const i = line.indexOf(":")
        if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1).trim()
    }
    return kv
}

function isIpv4(s) {
    const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(s)
    return !!m && m.slice(1).every(n => Number(n) <= 255)
}

// "192.168.1.20/24", or a bare address (taken as /24). Returns "" when invalid.
function cidr(s) {
    s = s.trim()
    const [ip, prefix, extra] = s.split("/")
    if (!isIpv4(ip) || extra !== undefined) return ""
    if (prefix === undefined) return ip + "/24"
    return /^\d{1,2}$/.test(prefix) && Number(prefix) <= 32 ? ip + "/" + prefix : ""
}

// DNS servers separated by spaces or commas; "" when any is invalid.
function dnsList(s) {
    const list = s.split(/[\s,]+/).filter(x => x)
    return list.length && list.every(isIpv4) ? list.join(",") : ""
}

function speed(mbps) {
    if (!mbps) return "–"
    return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s"
}

// Signal 0..1 as 1..4 bars.
function bars(strength) { return Math.max(1, Math.min(4, Math.ceil(strength * 4))) }

// WifiSecurityType values (Quickshell v0.3): 0 Wpa3SuiteB192, 1 Sae, 2 Wpa2Eap, 3 Wpa2Psk,
// 4 WpaEap, 5 WpaPsk, 6 StaticWep, 7 DynamicWep, 8 Leap, 9 Owe, 10 Open, 11 Unknown.
function security(t) {
    return ["WPA3 enterprise", "WPA3", "WPA2 enterprise", "WPA2", "WPA enterprise", "WPA",
        "WEP", "WEP", "LEAP", "open", "open", "unknown"][t] || "unknown"
}
function isOpen(t) { return t === 9 || t === 10 }
// Security types that take a plain password (Quickshell's connectWithPsk).
function takesPsk(t) { return t === 1 || t === 3 || t === 5 }
