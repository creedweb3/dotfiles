.pragma library
// The manga lock's page, ported from the demo (.test/make_demo.py: mgLayout, mgInset, mgArea, mgLock).
// The screen is split recursively by lines (straight for grid, slanted for the others); every leaf is a
// convex panel, shrunk by half the gutter so all gutters are even. The time panel is the big panel
// nearest the middle (or the reserved centre panel for more than 12 frames).

var STYLES = ["grid", "slant", "diagonal", "shatter", "cutoff"]

// Per preset: the hint line's quote and the chapter label (as the demo's PRESETS).
var PRESETS = {
    naruto: { label: "Naruto", quote: "Dattebayo." },
    bleach: { label: "Bleach", quote: "Bankai." },
    onepiece: { label: "One Piece", quote: "I'm gonna be King of the Pirates!" }
}

function area(p) {
    var a = 0
    for (var i = 0; i < p.length; i++) {
        var q = p[i], r = p[(i + 1) % p.length]
        a += q[0] * r[1] - r[0] * q[1]
    }
    return Math.abs(a / 2)
}

function inset(poly, dd) {
    var p = poly.filter(function (q, i) {
        var r = poly[(i + 1) % poly.length]
        return Math.hypot(q[0] - r[0], q[1] - r[1]) > .5
    })
    var n = p.length
    if (n < 3) return []
    var cx = 0, cy = 0
    p.forEach(function (q) { cx += q[0] / n; cy += q[1] / n })
    var L = []
    for (var i = 0; i < n; i++) {
        var P = p[i], Q = p[(i + 1) % n], l = Math.hypot(Q[0] - P[0], Q[1] - P[1])
        var v = [(Q[0] - P[0]) / l, (Q[1] - P[1]) / l], nn = [-v[1], v[0]]
        if (nn[0] * (cx - P[0]) + nn[1] * (cy - P[1]) < 0) nn = [-nn[0], -nn[1]]
        L.push([[P[0] + nn[0] * dd, P[1] + nn[1] * dd], v])
    }
    return L.map(function (ln, i) {
        var q = ln[0], w = ln[1], prev = L[(i - 1 + n) % n], pp = prev[0], v = prev[1]
        var c = v[0] * w[1] - v[1] * w[0]
        if (Math.abs(c) < 1e-9) return q
        var t = ((q[0] - pp[0]) * w[1] - (q[1] - pp[1]) * w[0]) / c
        return [pp[0] + v[0] * t, pp[1] + v[1] * t]
    })
}

// Panels for a W x H page: a list of polygons ([[x, y], ...]); .ti is the time panel's index.
function layout(W, H, style, n, extra) {
    var sd = (Array.from(style).reduce(function (a, c) { return a * 31 + c.charCodeAt(0) }, n * 977) + (extra || 0)) % 2147483647 || 7
    function rnd() { sd = sd * 16807 % 2147483647; return sd / 2147483647 }
    var m = style === "cutoff" ? 0 : 22, g = 14, out = []
    function cr(a, b, p) { return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) }
    function cut(poly, a, b, side) {
        var r = []
        for (var i = 0; i < poly.length; i++) {
            var P = poly[i], Q = poly[(i + 1) % poly.length], sp = cr(a, b, P) * side, sq = cr(a, b, Q) * side
            if (sp >= 0) r.push(P)
            if ((sp >= 0) !== (sq >= 0)) {
                var t = sp / (sp - sq)
                r.push([P[0] + (Q[0] - P[0]) * t, P[1] + (Q[1] - P[1]) * t])
            }
        }
        return r
    }
    function box(p) {
        var xs = p.map(function (q) { return q[0] }), ys = p.map(function (q) { return q[1] })
        return [Math.min.apply(null, xs), Math.min.apply(null, ys), Math.max.apply(null, xs), Math.max.apply(null, ys)]
    }
    function split(poly, k, d) {
        if (k < 2) { out.push(poly); return }
        var b = box(poly), x0 = b[0], y0 = b[1], x1 = b[2], y1 = b[3], w = x1 - x0, h = y1 - y0
        var vert = w > h * (0.8 + rnd() * 0.5)
        var k1 = Math.max(1, Math.min(k - 1, Math.round(k * (0.35 + rnd() * 0.3))))
        var t = Math.min(.75, Math.max(.25, k1 / k * (0.85 + rnd() * 0.3)))
        var len = vert ? h : w, sg = rnd() < .5 ? -1 : 1, tilt = 0
        if (style === "slant" || style === "cutoff") tilt = vert ? sg * (0.08 + rnd() * 0.22) * len : 0
        else if (style === "shatter") tilt = sg * (0.06 + rnd() * 0.22) * len
        else if (style === "diagonal") tilt = d === 0 ? sg * 0.55 * len : (vert ? sg * (0.06 + rnd() * 0.16) * len : 0)
        var a = vert ? [x0 + t * w - tilt / 2, y0 - 5] : [x0 - 5, y0 + t * h - tilt / 2]
        var e = vert ? [x0 + t * w + tilt / 2, y1 + 5] : [x1 + 5, y0 + t * h + tilt / 2]
        split(cut(poly, a, e, 1), k1, d + 1)
        split(cut(poly, a, e, -1), k - k1, d + 1)
    }
    function finish(list) {
        return list.map(function (p) { return inset(p, g / 2) }).filter(function (p) { return p.length > 2 })
    }
    var page = [[m, m], [W - m, m], [W - m, H - m], [m, H - m]]
    if (n <= 12) {
        split(page, n, 0)
        var res = finish(out)
        res.ti = timePanel(res, W, H)
        return res
    }
    var tv = style === "grid" ? 0 : (rnd() < .5 ? -1 : 1) * (0.04 + rnd() * .08) * H
    var th = style === "shatter" || style === "diagonal" ? (rnd() < .5 ? -1 : 1) * (0.05 + rnd() * .08) * W : 0
    var xa = W * .335, xb = W * .665, ya = H * .27, yb = H * .73
    function v(x, s2) { return [[x - tv / 2 * s2, -5], [x + tv / 2 * s2, H + 5]] }
    function hz(y, s2) { return [[-5, y - th / 2 * s2], [W + 5, y + th / 2 * s2]] }
    var va = v(xa, 1), vb = v(xb, -1), ha = hz(ya, 1), hb = hz(yb, -1)
    var left = cut(page, va[0], va[1], 1), rest = cut(page, va[0], va[1], -1)
    var right = cut(rest, vb[0], vb[1], -1), col = cut(rest, vb[0], vb[1], 1)
    var top = cut(col, ha[0], ha[1], -1), r2 = cut(col, ha[0], ha[1], 1)
    var time = cut(r2, hb[0], hb[1], -1), bot = cut(r2, hb[0], hb[1], 1)
    var parts = [left, right, top, bot], tot = parts.reduce(function (a, q) { return a + area(q) }, 0)
    var left2 = n - 1
    var counts = parts.map(function (q, i) {
        var c = i === 3 ? left2 : Math.max(1, Math.round((n - 1) * area(q) / tot))
        left2 -= c
        return c
    })
    parts.forEach(function (q, i) { split(q, Math.max(1, counts[i]), 1) })
    var res2 = finish(out)
    res2.push(inset(time, g / 2))
    res2.ti = res2.length - 1
    return res2
}

// For QML: {panels, ti} (a JS array's extra .ti does not survive a QML var property).
function page(W, H, style, n, extra) {
    var p = layout(W, H, style, n, extra)
    return { panels: p.slice(), ti: p.ti }
}

// Of the big panels (at least half the largest), the one nearest the middle of the page.
function timePanel(panels, W, H) {
    var big = Math.max.apply(null, panels.map(area)), best = -1, bestD = 0
    panels.forEach(function (p, i) {
        if (area(p) < big * .5) return
        var cx = 0, cy = 0
        p.forEach(function (q) { cx += q[0] / p.length; cy += q[1] / p.length })
        var d = Math.hypot(cx - W / 2, cy - H / 2)
        if (best < 0 || d < bestD) { best = i; bestD = d }
    })
    return best
}

function bbox(p) {
    if (!p || !p.length) return { x: 0, y: 0, w: 0, h: 0 }  // a panel list being rebuilt
    var xs = p.map(function (q) { return q[0] }), ys = p.map(function (q) { return q[1] })
    var x0 = Math.min.apply(null, xs), y0 = Math.min.apply(null, ys)
    return { x: x0, y: y0, w: Math.max.apply(null, xs) - x0, h: Math.max.apply(null, ys) - y0 }
}

// ---- inks: how the pages pick up the theme (the demo's mink and macc)
// Colours are [r, g, b] in 0..1.
function rgb(c) { return [c.r, c.g, c.b] }
function mix(a, b, f) { return a.map(function (v, i) { return v * f + b[i] * (1 - f) }) }

// Returns {shadow, highlight, gutter, line, time, timeStroke, spotShadow, spotHighlight, ink (#f6f3ec or accent: --mga), colour}
// shadow / highlight map a grey panel (black -> shadow, white -> highlight); colour = show pages as they are.
function inks(ink, macc, A, A2, BG) {
    var N = [.62, .62, .64]
    var Ap = macc === "soft" ? mix(A, N, .4) : (macc === "borders" || macc === "time") ? N : A
    var Ab = macc === "soft" ? mix(A, N, .4) : (macc === "panels" || macc === "time") ? N : A
    var paper = [.957, .949, .925], k0 = [.067, .067, .067], w1 = [1, 1, 1]
    function table(Ac) {
        var duo = [mix(Ac, [.04, .04, .05], .16), mix(Ac, paper, .28)], rk = mix(Ac, [0, 0, 0], .55)
        var t = {
            mono: [k0, w1, paper, k0, k0], accent: [k0, w1, paper, k0, k0], spot: [k0, w1, paper, k0, k0],
            gutter: [k0, w1, Ac, k0, k0], colour: [null, null, paper, k0, k0],
            duo: [duo[0], duo[1], mix(Ac, paper, .14), duo[0], duo[0]],
            riso: [rk, mix(macc === "full" ? A2 : Ac, paper, .3), mix(A2, paper, .18), rk, rk],
            night: [mix(Ac, w1, .4), mix(Ac, BG, .05), BG, mix(Ac, BG, .4), mix(BG, [0, 0, 0], .5)]
        }
        return t[ink] || t.mono
    }
    var tP = table(Ap), tB = table(Ab), spot = [mix(Ap, [.04, .04, .05], .16), mix(Ap, paper, .28)]
    return {
        colour: ink === "colour",
        shadow: tP[0] || k0, highlight: tP[1] || w1,
        gutter: tB[2], line: tB[3], time: tB[4],
        timeStroke: ink === "mono" ? paper : A,
        spotShadow: spot[0], spotHighlight: spot[1],
        mono: ink === "mono"
    }
}

// The day label (mday) and the date line (mdt). d: a JS Date.
var KANJI = "日月火水木金土"
var MONTHS = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
var DAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
function pad(n) { return (n < 10 ? "0" : "") + n }
function dateText(d, fmt) {
    if (fmt === "short") return DAYS[d.getDay()].slice(0, 3) + " " + d.getDate() + " " + MONTHS[d.getMonth()].slice(0, 3)
    if (fmt === "num") return pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear()
    if (fmt === "iso") return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    return d.getDate() + " " + MONTHS[d.getMonth()]
}
function weekday(d) { return DAYS[d.getDay()].toUpperCase() }
function kanjiDay(d) { return KANJI[d.getDay()] + "曜日" }

// Frame image paths from the manga store's pages.json for one preset.
// Entries are {file, panels?, score?, chapter}; paths are "manga/<preset>/<name>" (relative to the store's parent).
// action: the fightiest ~45% of the panels (by score), as the demo's mpick.
function framePaths(manifest, preset, store, pick) {
    var pages = (manifest && manifest[preset]) || []
    var all = []
    pages.forEach(function (x) {
        if (x.panels && x.panels.length) x.panels.forEach(function (f, i) { all.push([f, (x.score || [])[i] || 0]) })
        else if (x.file) all.push([x.file, 0])
    })
    all.sort(function (a, b) { return b[1] - a[1] })
    if (pick === "action") all = all.slice(0, Math.max(12, Math.ceil(all.length * .45)))
    return all.map(function (x) { return "file://" + store + "/" + String(x[0]).replace(/^manga\//, "") })
}
function chapterAt(manifest, preset, minute) {
    var pages = (manifest && manifest[preset]) || []
    if (!pages.length) return ""
    var pg = pages[minute % pages.length]
    return pg && pg.chapter ? String(pg.chapter) : ""
}
