.pragma library
// The launcher's calculator: numbers, + - * / % ^ and brackets. A small parser, so typed text is never run as code.
// evaluate("2(3+4)^2") -> 98; anything it cannot read gives null.

function evaluate(src) {
    const s = String(src).replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-")
    if (!s || !/^[\d+\-*/().%^]+$/.test(s) || !/\d/.test(s)) return null
    let i = 0
    const peek = () => s[i]
    function number() {
        const m = /^\d*\.?\d+|^\d+\./.exec(s.slice(i))
        if (!m) throw 0
        i += m[0].length
        return parseFloat(m[0])
    }
    function atom() {
        let v
        if (peek() === "(") {
            i++
            v = sum()
            if (peek() !== ")") throw 0
            i++
        } else {
            v = number()
        }
        return v
    }
    function power() {
        const b = atom()
        if (peek() === "^") { i++; return Math.pow(b, unary()) }
        return b
    }
    function unary() {  // -2^2 is -(2^2)
        if (peek() === "-") { i++; return -unary() }
        if (peek() === "+") { i++; return unary() }
        return power()
    }
    function product() {
        let v = unary()
        while (peek() === "*" || peek() === "/" || peek() === "%" || peek() === "(") {
            const op = peek() === "(" ? "*" : s[i++], r = unary()  // 2(3+4) multiplies
            v = op === "*" ? v * r : op === "/" ? v / r : v % r
        }
        return v
    }
    function sum() {
        let v = product()
        while (peek() === "+" || peek() === "-") {
            const op = s[i++], r = product()
            v = op === "+" ? v + r : v - r
        }
        return v
    }
    try {
        const v = sum()
        if (i !== s.length || !isFinite(v)) return null
        return +v.toFixed(10)
    } catch (e) {
        return null
    }
}

// A real sum, not a lone number: worth keeping in the history.
function isSum(src) {
    const x = String(src).replace(/\s/g, "")
    return /[+*/%^(]|.-/.test(x)
}

// How a sum reads on the display.
function pretty(x) {
    return String(x).replace(/\*/g, " × ").replace(/\//g, " ÷ ").replace(/(\d|\))-/g, "$1 − ").replace(/\+/g, " + ")
}
