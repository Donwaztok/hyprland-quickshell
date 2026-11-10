.pragma library

// Re-indents single-line (minified) JSON by rewriting only the whitespace between tokens, so numbers,
// strings and duplicate keys stay byte-for-byte. Anything else (multi-line, invalid) comes back unchanged.
function reindentMinified(src, unit) {
    const text = String(src || "");
    if (text.replace(/\s+$/, "").indexOf("\n") >= 0) // no trimEnd in the QML JS engine
        return text;
    try {
        JSON.parse(text); // validator only: its result would lose big ints and duplicate keys
    } catch (e) {
        return text;
    }
    const ws = " \t\n\r";
    const n = text.length;
    let out = "";
    let depth = 0;
    let i = 0;
    const nl = () => "\n" + unit.repeat(depth);
    while (i < n) {
        const c = text[i];
        if (c === "\"") {
            let j = i + 1;
            while (text[j] !== "\"")
                j += text[j] === "\\" ? 2 : 1;
            out += text.slice(i, j + 1);
            i = j + 1;
        } else if (ws.indexOf(c) >= 0) {
            ++i;
        } else if (c === "{" || c === "[") {
            let j = i + 1;
            while (j < n && ws.indexOf(text[j]) >= 0)
                ++j;
            if (text[j] === (c === "{" ? "}" : "]")) {
                out += c + text[j];
                i = j + 1;
            } else {
                ++depth;
                out += c + nl();
                ++i;
            }
        } else if (c === "}" || c === "]") {
            --depth;
            out += nl() + c;
            ++i;
        } else if (c === ",") {
            out += "," + nl();
            ++i;
        } else if (c === ":") {
            out += ": ";
            ++i;
        } else {
            let j = i;
            while (j < n && ",:{}[]\" \t\n\r".indexOf(text[j]) < 0)
                ++j;
            out += text.slice(i, j);
            i = j;
        }
    }
    return out + "\n";
}
