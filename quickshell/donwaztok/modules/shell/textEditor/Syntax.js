.pragma library

function escapeHtml(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function span(color, raw) {
    if (!raw.length)
        return "";
    return `<span style="color:${color}">${escapeHtml(raw)}</span>`;
}

function readString(src, i, quote) {
    const n = src.length;
    let j = i + 1;
    while (j < n) {
        const ch = src[j];
        if (ch === "\\") {
            j += 2;
            continue;
        }
        if (ch === quote)
            return j + 1;
        if (ch === "\n" && quote === "'")
            return j;
        j++;
    }
    return n;
}

function isIdentStart(ch) {
    return (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") || ch === "_" || ch === "$";
}

function isIdent(ch) {
    return isIdentStart(ch) || (ch >= "0" && ch <= "9") || ch === "-" || ch === ".";
}

function skipWs(src, i) {
    const n = src.length;
    while (i < n) {
        const ch = src[i];
        if (ch !== " " && ch !== "\t" && ch !== "\r" && ch !== "\n")
            break;
        i++;
    }
    return i;
}

function highlightJson(src, c) {
    const n = src.length;
    let out = "";
    let i = 0;
    while (i < n) {
        const ch = src[i];
        if (ch === "\"" || ch === "'") {
            const end = readString(src, i, ch);
            const raw = src.slice(i, end);
            const k = skipWs(src, end);
            const isKey = k < n && src[k] === ":";
            out += span(isKey ? c.key : c.string, raw);
            i = end;
            continue;
        }
        if (ch === "/" && src[i + 1] === "/") {
            let j = i + 2;
            while (j < n && src[j] !== "\n")
                j++;
            out += span(c.comment, src.slice(i, j));
            i = j;
            continue;
        }
        if (ch === "/" && src[i + 1] === "*") {
            const j = src.indexOf("*/", i + 2);
            const end = j < 0 ? n : j + 2;
            out += span(c.comment, src.slice(i, end));
            i = end;
            continue;
        }
        if (ch === "#" && (i === 0 || src[i - 1] === "\n" || src[i - 1] === " ")) {
            let j = i + 1;
            while (j < n && src[j] !== "\n")
                j++;
            out += span(c.comment, src.slice(i, j));
            i = j;
            continue;
        }
        if ((ch >= "0" && ch <= "9") || (ch === "-" && src[i + 1] >= "0" && src[i + 1] <= "9")) {
            let j = i + 1;
            while (j < n && /[0-9.eE+\-]/.test(src[j]))
                j++;
            out += span(c.number, src.slice(i, j));
            i = j;
            continue;
        }
        if (src.substr(i, 4) === "true" && !isIdent(src[i + 4] || "")) {
            out += span(c.keyword, "true");
            i += 4;
            continue;
        }
        if (src.substr(i, 5) === "false" && !isIdent(src[i + 5] || "")) {
            out += span(c.keyword, "false");
            i += 5;
            continue;
        }
        if (src.substr(i, 4) === "null" && !isIdent(src[i + 4] || "")) {
            out += span(c.keyword, "null");
            i += 4;
            continue;
        }
        if ("{}[]:,".indexOf(ch) >= 0) {
            out += span(c.punct, ch);
            i++;
            continue;
        }
        out += escapeHtml(ch);
        i++;
    }
    return out;
}

function highlightIni(src, c) {
    const n = src.length;
    let out = "";
    let i = 0;
    let lineStart = true;
    while (i < n) {
        const ch = src[i];
        if (ch === "\n") {
            out += "\n";
            i++;
            lineStart = true;
            continue;
        }
        if (lineStart && (ch === " " || ch === "\t")) {
            out += escapeHtml(ch);
            i++;
            continue;
        }
        if (lineStart && (ch === "#" || ch === ";")) {
            let j = i + 1;
            while (j < n && src[j] !== "\n")
                j++;
            out += span(c.comment, src.slice(i, j));
            i = j;
            lineStart = false;
            continue;
        }
        if (lineStart && ch === "[") {
            let j = i + 1;
            while (j < n && src[j] !== "]" && src[j] !== "\n")
                j++;
            if (j < n && src[j] === "]")
                j++;
            out += span(c.section, src.slice(i, j));
            i = j;
            lineStart = false;
            continue;
        }
        if (ch === "\"" || ch === "'") {
            const end = readString(src, i, ch);
            out += span(c.string, src.slice(i, end));
            i = end;
            lineStart = false;
            continue;
        }
        if (lineStart && isIdentStart(ch)) {
            let j = i + 1;
            while (j < n && (isIdent(src[j]) || src[j] === "[" || src[j] === "]"))
                j++;
            const key = src.slice(i, j);
            let k = j;
            while (k < n && (src[k] === " " || src[k] === "\t"))
                k++;
            out += span(c.key, key);
            i = j;
            lineStart = false;
            continue;
        }
        if (ch === "=" || ch === ":") {
            out += span(c.punct, ch);
            i++;
            lineStart = false;
            continue;
        }
        if ((ch >= "0" && ch <= "9") || (ch === "-" && src[i + 1] >= "0" && src[i + 1] <= "9")) {
            let j = i + 1;
            while (j < n && /[0-9.eE+\-]/.test(src[j]))
                j++;
            out += span(c.number, src.slice(i, j));
            i = j;
            lineStart = false;
            continue;
        }
        const word4 = src.substr(i, 4).toLowerCase();
        const word5 = src.substr(i, 5).toLowerCase();
        if ((word4 === "true" || word4 === "none" || word4 === "null" || word4 === "yes") && !isIdent(src[i + 4] || "")) {
            out += span(c.keyword, src.slice(i, i + 4));
            i += 4;
            lineStart = false;
            continue;
        }
        if ((word5 === "false") && !isIdent(src[i + 5] || "")) {
            out += span(c.keyword, src.slice(i, i + 5));
            i += 5;
            lineStart = false;
            continue;
        }
        out += escapeHtml(ch);
        i++;
        if (ch !== " " && ch !== "\t")
            lineStart = false;
    }
    return out;
}

function highlightYaml(src, c) {
    const n = src.length;
    let out = "";
    let i = 0;
    let lineStart = true;
    while (i < n) {
        const ch = src[i];
        if (ch === "\n") {
            out += "\n";
            i++;
            lineStart = true;
            continue;
        }
        if (lineStart && (ch === " " || ch === "\t")) {
            out += escapeHtml(ch);
            i++;
            continue;
        }
        if (ch === "#" && (lineStart || src[i - 1] === " ")) {
            let j = i + 1;
            while (j < n && src[j] !== "\n")
                j++;
            out += span(c.comment, src.slice(i, j));
            i = j;
            lineStart = false;
            continue;
        }
        if (lineStart && ch === "-" && (src[i + 1] === " " || src[i + 1] === "\n" || src[i + 1] === undefined)) {
            out += span(c.punct, "-");
            i++;
            lineStart = false;
            continue;
        }
        if (ch === "\"" || ch === "'") {
            const end = readString(src, i, ch);
            out += span(c.string, src.slice(i, end));
            i = end;
            lineStart = false;
            continue;
        }
        if ((lineStart || src[i - 1] === " " || src[i - 1] === "-") && isIdentStart(ch)) {
            let j = i + 1;
            while (j < n && (isIdent(src[j]) || src[j] === "/"))
                j++;
            let k = j;
            while (k < n && (src[k] === " " || src[k] === "\t"))
                k++;
            if (k < n && src[k] === ":") {
                out += span(c.key, src.slice(i, j));
                i = j;
                lineStart = false;
                continue;
            }
        }
        if (ch === ":" || ch === "," || ch === "{" || ch === "}" || ch === "[" || ch === "]") {
            out += span(c.punct, ch);
            i++;
            lineStart = false;
            continue;
        }
        if ((ch >= "0" && ch <= "9") || (ch === "-" && src[i + 1] >= "0" && src[i + 1] <= "9")) {
            let j = i + 1;
            while (j < n && /[0-9.eE+\-]/.test(src[j]))
                j++;
            out += span(c.number, src.slice(i, j));
            i = j;
            lineStart = false;
            continue;
        }
        const w4 = src.substr(i, 4);
        const w5 = src.substr(i, 5);
        if ((w4 === "true" || w4 === "null" || w4 === "True" || w4 === "NULL") && !isIdent(src[i + 4] || "")) {
            out += span(c.keyword, src.slice(i, i + 4));
            i += 4;
            lineStart = false;
            continue;
        }
        if ((w5 === "false" || w5 === "False") && !isIdent(src[i + 5] || "")) {
            out += span(c.keyword, src.slice(i, i + 5));
            i += 5;
            lineStart = false;
            continue;
        }
        out += escapeHtml(ch);
        i++;
        if (ch !== " " && ch !== "\t")
            lineStart = false;
    }
    return out;
}

function highlightMdInline(src, i, end, c, mdx) {
    let out = "";
    while (i < end) {
        const ch = src[i];
        if (ch === "`") {
            let j = i + 1;
            while (j < end && src[j] === "`")
                j++;
            const ticks = j - i;
            const close = src.indexOf("`".repeat(ticks), j);
            const stop = close >= 0 && close < end ? close + ticks : end;
            out += span(c.string, src.slice(i, stop));
            i = stop;
            continue;
        }
        if (ch === "[" || (ch === "!" && src[i + 1] === "[")) {
            const start = i;
            if (ch === "!")
                i++;
            const rb = src.indexOf("]", i);
            if (rb >= 0 && rb < end && src[rb + 1] === "(") {
                const rp = src.indexOf(")", rb + 2);
                if (rp >= 0 && rp < end) {
                    out += span(c.key, src.slice(start, rb + 1));
                    out += span(c.punct, "(");
                    out += span(c.keyword, src.slice(rb + 2, rp));
                    out += span(c.punct, ")");
                    i = rp + 1;
                    continue;
                }
            }
            i = start;
        }
        if (ch === "*" || ch === "_") {
            const run = ch + (src[i + 1] === ch ? ch : "");
            const close = src.indexOf(run, i + run.length);
            if (close >= 0 && close < end) {
                out += span(c.section, src.slice(i, close + run.length));
                i = close + run.length;
                continue;
            }
        }
        if (mdx && ch === "<" && isIdentStart(src[i + 1] || "")) {
            let j = i + 1;
            while (j < end && src[j] !== ">" && src[j] !== "\n")
                j++;
            if (src[j] === ">")
                j++;
            out += span(c.keyword, src.slice(i, j));
            i = j;
            continue;
        }
        if (mdx && ch === "{") {
            let j = i + 1;
            let depth = 1;
            while (j < end && depth > 0 && src[j] !== "\n") {
                if (src[j] === "{")
                    depth++;
                else if (src[j] === "}")
                    depth--;
                j++;
            }
            out += span(c.number, src.slice(i, j));
            i = j;
            continue;
        }
        out += escapeHtml(ch);
        i++;
    }
    return out;
}

function highlightMarkdown(src, c, mdx) {
    const n = src.length;
    let out = "";
    let i = 0;
    let fence = false;
    while (i < n) {
        if (src[i] === "\n") {
            out += "\n";
            i++;
            continue;
        }
        const col0 = i === 0 || src[i - 1] === "\n";
        let lineEnd = src.indexOf("\n", i);
        if (lineEnd < 0)
            lineEnd = n;
        if (fence) {
            if (col0 && src.substr(i, 3) === "```") {
                out += span(c.punct, src.slice(i, lineEnd));
                fence = false;
            } else {
                out += span(c.string, src.slice(i, lineEnd));
            }
            i = lineEnd;
            continue;
        }
        if (col0 && src.substr(i, 3) === "```") {
            out += span(c.punct, src.slice(i, lineEnd));
            fence = true;
            i = lineEnd;
            continue;
        }
        if (col0 && (src.substr(i, 3) === "---" || src.substr(i, 3) === "***" || src.substr(i, 3) === "___") && lineEnd <= i + 6) {
            out += span(c.punct, src.slice(i, lineEnd));
            i = lineEnd;
            continue;
        }
        if (col0 && src[i] === "#") {
            let j = i;
            while (j < lineEnd && src[j] === "#")
                j++;
            if (j < lineEnd && (src[j] === " " || src[j] === "\t")) {
                out += span(c.section, src.slice(i, lineEnd));
                i = lineEnd;
                continue;
            }
        }
        if (col0 && src[i] === ">") {
            out += span(c.punct, ">");
            out += highlightMdInline(src, i + 1, lineEnd, c, mdx);
            i = lineEnd;
            continue;
        }
        if (mdx && col0 && (src.substr(i, 7) === "import " || src.substr(i, 7) === "export ")) {
            out += span(c.keyword, src.slice(i, lineEnd));
            i = lineEnd;
            continue;
        }
        if (col0) {
            const m = src.slice(i, lineEnd).match(/^(\s*)([-*+]|\d+\.)(\s+)/);
            if (m) {
                out += escapeHtml(m[1]) + span(c.punct, m[2]) + escapeHtml(m[3]);
                out += highlightMdInline(src, i + m[0].length, lineEnd, c, mdx);
                i = lineEnd;
                continue;
            }
        }
        out += highlightMdInline(src, i, lineEnd, c, mdx);
        i = lineEnd;
    }
    return out;
}

function highlight(src, lang, colors) {
    const text = String(src || "");
    if (!text.length)
        return "";
    if (text.length > 400000)
        return escapeHtml(text);
    const c = colors || {};
    let body = "";
    if (lang === "json")
        body = highlightJson(text, c);
    else if (lang === "yaml")
        body = highlightYaml(text, c);
    else if (lang === "md" || lang === "mdx")
        body = highlightMarkdown(text, c, lang === "mdx");
    else
        body = highlightIni(text, c);
    return `<pre style="margin:0;white-space:pre;">${body}</pre>`;
}
