.pragma library

function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function absUrl(url, dir) {
    const u = String(url || "").trim();
    if (!u.length)
        return u;
    if (/^(https?:|file:|data:|qrc:)/i.test(u))
        return u;
    if (u.startsWith("/"))
        return "file://" + u;
    const base = String(dir || "").replace(/\/+$/, "");
    return "file://" + (base ? base + "/" : "") + u.replace(/^\.\//, "");
}

function linkHtml(label, url, t, dir) {
    const href = esc(absUrl(url, dir));
    return `<a href="${href}"><span style="color:${t.link};">${esc(label)}</span></a>`;
}

function markedInline(text, t, dir) {
    let s = String(text || "");
    const stash = [];
    const hold = html => {
        const id = "§MD" + stash.length + "§";
        stash.push({
            id: id,
            html: html
        });
        return id;
    };
    s = s.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_, alt, url) => hold(`<img src="${esc(absUrl(url, dir))}" alt="${esc(alt)}"/>`));
    s = s.replace(/<a\s+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi, (_, url, label) => hold(linkHtml(String(label).replace(/<[^>]+>/g, ""), url, t, dir)));
    s = s.replace(/<(https?:\/\/[^>\s]+)>/g, (_, url) => hold(linkHtml(url, url, t, dir)));
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, url) => hold(linkHtml(label, url, t, dir)));
    s = s.replace(/~~([^~]+)~~/g, (_, x) => hold(`<s>${esc(x)}</s>`));
    s = s.replace(/\*\*([^*]+)\*\*/g, (_, x) => hold(`<b>${esc(x)}</b>`));
    s = s.replace(/__([^_]+)__/g, (_, x) => hold(`<b>${esc(x)}</b>`));
    s = s.replace(/\*([^*\n]+)\*/g, (_, x) => hold(`<i>${esc(x)}</i>`));
    s = s.replace(/(^|[^_a-zA-Z0-9])_([^_\n]+)_(?!_)/g, (_, p, x) => p + hold(`<i>${esc(x)}</i>`));
    s = esc(s);
    for (let i = 0; i < stash.length; ++i)
        s = s.split(stash[i].id).join(stash[i].html);
    return s;
}

function inlineParts(text, t, dir) {
    const raw = String(text || "");
    const parts = [];
    const re = /`([^`]+)`/g;
    let last = 0;
    let m;
    while ((m = re.exec(raw))) {
        if (m.index > last) {
            const html = markedInline(raw.slice(last, m.index), t, dir);
            if (html)
                parts.push({
                    type: "text",
                    html: html
                });
        }
        parts.push({
            type: "code",
            text: m[1]
        });
        last = re.lastIndex;
    }
    if (last < raw.length) {
        const html = markedInline(raw.slice(last), t, dir);
        if (html)
            parts.push({
                type: "text",
                html: html
            });
    }
    if (!parts.length)
        parts.push({
            type: "text",
            html: markedInline(raw, t, dir)
        });
    return parts;
}

function inlineMd(text, t, dir) {
    return inlineParts(text, t, dir).map(p => {
        if (p.type === "code")
            return `<span style="font-family:'${t.mono}';font-weight:600;color:${t.codeFg};">${esc(p.text)}</span>`;
        return p.html;
    }).join("");
}

function fenceLine(line) {
    const m = String(line || "").match(/^(\s{0,3})(`{3,}|~{3,})\s*([^\s`]*)\s*$/);
    if (!m)
        return null;
    return {
        mark: m[2][0],
        len: m[2].length,
        lang: m[3] || ""
    };
}

function isHr(line) {
    return /^\s{0,3}(?:(?:-\s*){3,}|(?:\*\s*){3,}|(?:_\s*){3,})\s*$/.test(line);
}

function headingLine(line) {
    const m = String(line || "").match(/^(#{1,6})\s+(.*)$/);
    if (!m)
        return null;
    return {
        level: m[1].length,
        text: m[2].replace(/\s+#+\s*$/, "")
    };
}

function listLine(line) {
    const m = String(line || "").match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/);
    if (!m)
        return null;
    const rest = m[3];
    const task = rest.match(/^\[([ xX])\]\s+(.*)$/);
    return {
        indent: m[1].length,
        ordered: /\d/.test(m[2]),
        task: task ? task[1].toLowerCase() === "x" : null,
        text: task ? task[2] : rest
    };
}

function tableSplit(line) {
    let s = String(line || "").trim();
    if (s.startsWith("|"))
        s = s.slice(1);
    if (s.endsWith("|"))
        s = s.slice(0, -1);
    return s.split("|").map(c => c.trim());
}

function isTableSep(line) {
    const cells = tableSplit(line);
    if (cells.length < 2)
        return false;
    return cells.every(c => /^:?-{3,}:?$/.test(c));
}

function mdToBlocks(src, theme, opts) {
    const t = theme || {};
    const dir = opts && opts.dir ? opts.dir : "";
    const mdx = !!(opts && opts.mdx);
    const lines = String(src || "").replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    const out = [];
    let i = 0;

    if (lines[0] === "---") {
        let j = 1;
        while (j < lines.length && lines[j] !== "---")
            j++;
        if (j < lines.length) {
            out.push({
                type: "code",
                lang: "frontmatter",
                text: lines.slice(1, j).join("\n")
            });
            i = j + 1;
        }
    }

    function flushPara(buf) {
        if (!buf.length)
            return;
        const raw = buf.join("\n").replace(/\\\n/g, "\n").replace(/  \n/g, "\n");
        out.push({
            type: "p",
            parts: inlineParts(raw.replace(/\n/g, " "), t, dir)
        });
        buf.length = 0;
    }

    const para = [];
    while (i < lines.length) {
        const line = lines[i];
        const trim = line.trim();

        if (mdx && /^(import|export)\s+/.test(trim)) {
            flushPara(para);
            const chunk = [];
            while (i < lines.length && /^(import|export)\s+/.test(lines[i].trim())) {
                chunk.push(lines[i]);
                i++;
            }
            out.push({
                type: "code",
                lang: "mdx",
                text: chunk.join("\n")
            });
            continue;
        }

        const fence = fenceLine(line);
        if (fence) {
            flushPara(para);
            i++;
            const body = [];
            while (i < lines.length) {
                const close = fenceLine(lines[i]);
                if (close && close.mark === fence.mark && close.len >= fence.len && !close.lang)
                    break;
                body.push(lines[i]);
                i++;
            }
            if (i < lines.length)
                i++;
            out.push({
                type: "code",
                lang: fence.lang,
                text: body.join("\n")
            });
            continue;
        }

        if (isHr(line) || /^\s{0,3}=+\s*$/.test(line)) {
            if (para.length === 1) {
                const level = /^\s{0,3}=+\s*$/.test(line) ? 1 : 2;
                const title = para[0];
                para.length = 0;
                out.push({
                    type: "h",
                    level: level,
                    parts: inlineParts(title, t, dir)
                });
                i++;
                continue;
            }
            flushPara(para);
            if (isHr(line)) {
                out.push({
                    type: "hr"
                });
                i++;
                continue;
            }
        }

        if (!para.length && /^(?:    |\t)/.test(line) && !listLine(line)) {
            const body = [];
            while (i < lines.length && (/^(?:    |\t)/.test(lines[i]) || (body.length && !lines[i].trim()))) {
                body.push(lines[i].replace(/^    /, "").replace(/^\t/, ""));
                i++;
            }
            while (body.length && !body[body.length - 1].trim())
                body.pop();
            out.push({
                type: "code",
                lang: "",
                text: body.join("\n")
            });
            continue;
        }

        const head = headingLine(line);
        if (head) {
            flushPara(para);
            out.push({
                type: "h",
                level: head.level,
                parts: inlineParts(head.text, t, dir)
            });
            i++;
            continue;
        }

        if (trim.startsWith(">")) {
            flushPara(para);
            const q = [];
            while (i < lines.length && lines[i].trim().startsWith(">")) {
                q.push(lines[i].replace(/^\s*>\s?/, ""));
                i++;
            }
            out.push({
                type: "quote",
                parts: inlineParts(q.join(" "), t, dir)
            });
            continue;
        }

        const item = listLine(line);
        if (item) {
            flushPara(para);
            const ordered = item.ordered;
            const items = [];
            while (i < lines.length) {
                const it = listLine(lines[i]);
                if (!it || it.ordered !== ordered)
                    break;
                items.push(it);
                i++;
                while (i < lines.length && lines[i].match(/^\s{2,}\S/) && !listLine(lines[i]) && !headingLine(lines[i]) && !fenceLine(lines[i])) {
                    items[items.length - 1].text += " " + lines[i].trim();
                    i++;
                }
            }
            out.push({
                type: "list",
                ordered: ordered,
                items: items.map(it => ({
                    parts: inlineParts(it.text, t, dir),
                    task: it.task
                }))
            });
            continue;
        }

        if (line.indexOf("|") >= 0 && i + 1 < lines.length && isTableSep(lines[i + 1])) {
            flushPara(para);
            const heads = tableSplit(line);
            i += 2;
            const rows = [];
            while (i < lines.length && lines[i].indexOf("|") >= 0 && !isHr(lines[i])) {
                rows.push(tableSplit(lines[i]));
                i++;
            }
            out.push({
                type: "table",
                heads: heads.map(c => inlineMd(c, t, dir)),
                rows: rows.map(r => heads.map((_, c) => inlineMd(r[c] || "", t, dir)))
            });
            continue;
        }

        if (!trim.length) {
            flushPara(para);
            i++;
            continue;
        }

        if (mdx && /^<\/?[A-Z]/.test(trim)) {
            flushPara(para);
            const jsx = [];
            const open = trim.match(/^<([A-Z][\w.]*)/);
            const name = open ? open[1] : "";
            jsx.push(line);
            i++;
            if (name && !/\/>\s*$/.test(trim) && trim.indexOf(`</${name}>`) < 0) {
                while (i < lines.length) {
                    jsx.push(lines[i]);
                    const done = lines[i].indexOf(`</${name}>`) >= 0;
                    i++;
                    if (done)
                        break;
                }
            }
            out.push({
                type: "code",
                lang: "jsx",
                text: jsx.join("\n")
            });
            continue;
        }

        para.push(line);
        i++;
    }
    flushPara(para);
    return out;
}
