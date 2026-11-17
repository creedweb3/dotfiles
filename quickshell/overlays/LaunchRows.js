.pragma library
// The launcher's "smart input" helpers (demo smartRows): what kind of thing was typed or pasted into the
// app search (a path, a link, a colour, a shell command) and the clipboard row icons. Pure functions only:
// nothing here runs anything, Launcher.qml does that with argument lists.

// a path: starts with /, ~ or ./ (../ too)
function isPath(t) { return /^(~|\.{1,2})?\//.test(t) || t === "~" }

// one spelling per place: /home/<user> and ./ both mean ~; a lone ~ is ~/
function normPath(t, home) {
    if (home && (t === home || t.startsWith(home + "/"))) t = "~" + t.slice(home.length)
    t = t.replace(/^\.\//, "~/")
    return t === "~" ? "~/" : t
}
function absPath(p, home) { return p.startsWith("~") ? home + p.slice(1) : p }
function dirOf(p) { return p.slice(0, p.lastIndexOf("/") + 1) }

function isUrl(t) {
    return /^(https?:\/\/|www\.)\S+$/i.test(t) || /^[\w-]+(\.[\w-]+)*\.(com|org|net|io|dev|gg|app|moe|tv|wiki)(\/\S*)?$/i.test(t)
}
function fullUrl(t) { return /^https?:/i.test(t) ? t : "https://" + t }

function isHex(t) { return /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(t) }
function hexRgb(h) {
    h = h.slice(1)
    if (h.length === 3) h = h.split("").map(c => c + c).join("")
    const n = parseInt(h, 16)
    return [n >> 16, n >> 8 & 255, n & 255]
}
function rgbHsl(rgb) {
    const r = rgb[0] / 255, g = rgb[1] / 255, b = rgb[2] / 255
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, dl = mx - mn
    let h = 0, s = 0
    if (dl) {
        s = dl / (1 - Math.abs(2 * l - 1))
        h = mx === r ? ((g - b) / dl) % 6 : mx === g ? (b - r) / dl + 2 : (r - g) / dl + 4
        h = Math.round(h * 60 + 360) % 360
    }
    return [h, Math.round(s * 100), Math.round(l * 100)]
}
// [hex, rgb(), hsl()] spellings of a typed colour
function colourForms(t) {
    const rgb = hexRgb(t), hsl = rgbHsl(rgb)
    return ["#" + rgb.map(v => (v < 16 ? "0" : "") + v.toString(16)).join("").toUpperCase(),
        "rgb(" + rgb.join(", ") + ")", "hsl(" + hsl[0] + ", " + hsl[1] + "%, " + hsl[2] + "%)"]
}

// a shell command: a known command word, with arguments (sudo alone counts)
const CMDWORDS = /^(sudo|git|cd|ls|yay|paru|pacman|npm|pnpm|python3?|cargo|systemctl|journalctl|nvim|vim|curl|wget|make|chmod|mkdir|rm|mv|cp|grep|ssh|docker)$/
function isCommand(t) {
    const w = t.split(/\s+/)
    return CMDWORDS.test(w[0]) && (w.length > 1 || w[0] === "sudo")
}

// theme icon for a file by its extension
function fileIcon(f) {
    return /\.(png|jpe?g|webp|gif)$/i.test(f) ? "image-x-generic"
        : /\.(flac|mp3|ogg|wav|opus)$/i.test(f) ? "audio-x-generic"
        : /\.(zip|iso|tar|gz|xz|zst|7z)$/i.test(f) ? "package-x-generic"
        : /\.(md|txt|conf|sh|pdf|lua|qml|json)$/i.test(f) ? "text-x-generic"
        : "text-x-generic"
}

// clipboard rows show what was copied: "swatch" (a colour), "link", "command", "image" or "text"
function clipKind(t) {
    if (/^#[0-9a-f]{6}$/i.test(t)) return "swatch"
    if (/^\[\[ binary data/.test(t)) return "image"
    if (/^https?:\/\//.test(t)) return "link"
    if (/^(sudo|git|cd|ls|yay|paru|pacman|npm|python3?|cargo)\b/.test(t)) return "command"
    return "text"
}
const CLIP_ICONS = {link: "insert-link", command: "utilities-terminal", image: "image-x-generic", text: "text-x-generic"}

// "now", "2 min ago", "3 h ago", "yesterday", "4 days ago"
function ago(ms) {
    const m = Math.floor(ms / 60000)
    if (m < 1) return "now"
    if (m < 60) return m + " min ago"
    const h = Math.floor(m / 60)
    if (h < 24) return h + " h ago"
    const d = Math.floor(h / 24)
    return d === 1 ? "yesterday" : d + " days ago"
}
