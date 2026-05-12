// Qt Quick NumberAnimation BezierSpline: n segments, each 6 values
// (c1x, c1y, c2x, c2y, endX, endY); first segment starts at (0,0).
// Progress 0..1 is split equally across segments; within a segment u = frac * n - segIndex.

function lerp(a, b, t) {
    return a + (b - a) * t;
}

function cubicPoint(p0, p1, p2, p3, u) {
    const o = 1 - u;
    const o2 = o * o;
    const o3 = o2 * o;
    const u2 = u * u;
    const u3 = u2 * u;
    return {
        x: o3 * p0.x + 3 * o2 * u * p1.x + 3 * o * u2 * p2.x + u3 * p3.x,
        y: o3 * p0.y + 3 * o2 * u * p1.y + 3 * o * u2 * p2.y + u3 * p3.y
    };
}

function parseSegments(flat) {
    if (!flat || flat.length < 6 || flat.length % 6 !== 0)
        return [];
    const segs = [];
    let px = 0;
    let py = 0;
    for (let i = 0; i < flat.length; i += 6) {
        const p0 = { x: px, y: py };
        const p1 = { x: flat[i], y: flat[i + 1] };
        const p2 = { x: flat[i + 2], y: flat[i + 3] };
        const p3 = { x: flat[i + 4], y: flat[i + 5] };
        segs.push({ p0, p1, p2, p3 });
        px = p3.x;
        py = p3.y;
    }
    return segs;
}

function serializeSegments(segments) {
    const out = [];
    for (let s = 0; s < segments.length; s++) {
        const g = segments[s];
        out.push(g.p1.x, g.p1.y, g.p2.x, g.p2.y, g.p3.x, g.p3.y);
    }
    return out;
}

function evalY(progress, flat) {
    const segs = parseSegments(flat);
    if (!segs.length)
        return progress;
    const n = segs.length;
    const p = Math.max(0, Math.min(1, progress));
    const idx = Math.min(n - 1, Math.max(0, Math.floor(p * n)));
    const u = p * n - idx;
    const s = segs[idx];
    return cubicPoint(s.p0, s.p1, s.p2, s.p3, u).y;
}

function splitCubicAt(p0, p1, p2, p3, t) {
    const u1 = { x: lerp(p0.x, p1.x, t), y: lerp(p0.y, p1.y, t) };
    const u2 = { x: lerp(p1.x, p2.x, t), y: lerp(p1.y, p2.y, t) };
    const u3 = { x: lerp(p2.x, p3.x, t), y: lerp(p2.y, p3.y, t) };
    const v1 = { x: lerp(u1.x, u2.x, t), y: lerp(u1.y, u2.y, t) };
    const v2 = { x: lerp(u2.x, u3.x, t), y: lerp(u2.y, u3.y, t) };
    const w1 = { x: lerp(v1.x, v2.x, t), y: lerp(v1.y, v2.y, t) };
    return {
        left: { p0, p1: u1, p2: v1, p3: w1 },
        right: { p0: w1, p1: v2, p2: u3, p3 }
    };
}

function subdivideSegment(flat, segIndex, t) {
    const segs = parseSegments(flat);
    if (segIndex < 0 || segIndex >= segs.length || t <= 1e-4 || t >= 1 - 1e-4)
        return flat.slice();
    const s = segs[segIndex];
    const sp = splitCubicAt(s.p0, s.p1, s.p2, s.p3, t);
    const newSegs = [];
    for (let i = 0; i < segs.length; i++) {
        if (i !== segIndex) {
            newSegs.push(segs[i]);
        } else {
            newSegs.push(sp.left);
            newSegs.push(sp.right);
        }
    }
    return serializeSegments(newSegs);
}

function appendSegmentTowardOne(flat) {
    const segs = parseSegments(flat);
    if (!segs.length)
        return [0.25, 0.1, 0.75, 0.9, 1, 1];
    const last = segs[segs.length - 1];
    const ex = last.p3.x;
    const ey = last.p3.y;
    if (Math.abs(ex - 1) < 1e-4 && Math.abs(ey - 1) < 1e-4)
        return subdivideSegment(flat, segs.length - 1, 0.5);
    const mx = lerp(ex, 1, 0.45);
    const my = lerp(ey, 1, 0.45);
    const c1x = lerp(ex, mx, 0.35);
    const c1y = lerp(ey, my, 0.15);
    const c2x = lerp(mx, 1, 0.35);
    const c2y = lerp(my, 1, 0.65);
    const extra = [c1x, c1y, c2x, c2y, 1, 1];
    return flat.concat(extra);
}

function removeLastSegment(flat) {
    if (!flat || flat.length <= 6)
        return flat.slice();
    return flat.slice(0, flat.length - 6);
}

function distance2(ax, ay, bx, by) {
    const dx = ax - bx;
    const dy = ay - by;
    return dx * dx + dy * dy;
}

function closestOnSegment(p0, p1, p2, p3, gx, gy, samples) {
    let bestU = 0.5;
    let bestD = 1e18;
    const n = samples || 48;
    for (let i = 0; i <= n; i++) {
        const u = i / n;
        const pt = cubicPoint(p0, p1, p2, p3, u);
        const d = distance2(pt.x, pt.y, gx, gy);
        if (d < bestD) {
            bestD = d;
            bestU = u;
        }
    }
    return { u: bestU, dist2: bestD };
}

function pickHandle(gx, gy, flat, hitR) {
    const segs = parseSegments(flat);
    const r2 = hitR * hitR;
    let best = null;
    for (let si = 0; si < segs.length; si++) {
        const s = segs[si];
        const pts = [
            { kind: "p1", seg: si, pt: s.p1 },
            { kind: "p2", seg: si, pt: s.p2 },
            { kind: "p3", seg: si, pt: s.p3 }
        ];
        for (let k = 0; k < pts.length; k++) {
            const d2 = distance2(pts[k].pt.x, pts[k].pt.y, gx, gy);
            if (d2 <= r2 && (!best || d2 < best.d2))
                best = { kind: pts[k].kind, seg: pts[k].seg, d2 };
        }
    }
    return best;
}

function moveHandle(flat, pick, nx, ny) {
    const segs = parseSegments(flat);
    if (!segs.length || !pick)
        return flat.slice();
    const si = pick.seg;
    const s = segs[si];
    const g = {
        p0: { x: s.p0.x, y: s.p0.y },
        p1: { x: s.p1.x, y: s.p1.y },
        p2: { x: s.p2.x, y: s.p2.y },
        p3: { x: s.p3.x, y: s.p3.y }
    };
    const minX = g.p0.x + 1e-4;
    const maxX = g.p3.x - 1e-4;
    const clampX = v => Math.max(minX, Math.min(maxX, v));
    const clampY = v => Math.max(0, Math.min(1, v));
    if (pick.kind === "p1") {
        g.p1.x = clampX(nx);
        g.p1.y = clampY(ny);
        if (g.p1.x > g.p2.x - 1e-3)
            g.p1.x = g.p2.x - 1e-3;
    } else if (pick.kind === "p2") {
        g.p2.x = clampX(nx);
        g.p2.y = clampY(ny);
        if (g.p2.x < g.p1.x + 1e-3)
            g.p2.x = g.p1.x + 1e-3;
    } else if (pick.kind === "p3") {
        g.p3.x = Math.max(g.p2.x + 1e-3, Math.min(1, nx));
        g.p3.y = clampY(ny);
    }
    segs[si] = g;
    for (let j = si + 1; j < segs.length; j++) {
        const prev = segs[j - 1].p3;
        const cur = segs[j];
        let p1 = { x: cur.p1.x, y: cur.p1.y };
        let p2 = { x: cur.p2.x, y: cur.p2.y };
        if (p1.x < prev.x + 0.02)
            p1 = { x: prev.x + 0.02, y: p1.y };
        if (p2.x < p1.x + 0.02)
            p2 = { x: p1.x + 0.02, y: p2.y };
        if (cur.p3.x < p2.x + 0.02)
            cur.p3.x = p2.x + 0.02;
        segs[j] = {
            p0: { x: prev.x, y: prev.y },
            p1,
            p2,
            p3: { x: cur.p3.x, y: cur.p3.y }
        };
    }
    return serializeSegments(segs);
}

function snapEndToOne(flat) {
    const segs = parseSegments(flat);
    if (!segs.length)
        return flat;
    const last = segs[segs.length - 1];
    last.p3.x = 1;
    last.p3.y = 1;
    segs[segs.length - 1] = last;
    return serializeSegments(segs);
}

function closestSegmentAndU(gx, gy, flat) {
    const segs = parseSegments(flat);
    let best = { seg: 0, u: 0.5, dist2: 1e18 };
    for (let i = 0; i < segs.length; i++) {
        const s = segs[i];
        const c = closestOnSegment(s.p0, s.p1, s.p2, s.p3, gx, gy, 72);
        if (c.dist2 < best.dist2)
            best = { seg: i, u: c.u, dist2: c.dist2 };
    }
    return best;
}

function validateFlat(flat) {
    if (!flat || flat.length < 6 || flat.length % 6 !== 0)
        return false;
    const segs = parseSegments(flat);
    let px = 0;
    let py = 0;
    for (let i = 0; i < segs.length; i++) {
        const s = segs[i];
        if (Math.abs(s.p0.x - px) > 1e-3 || Math.abs(s.p0.y - py) > 1e-3)
            return false;
        if (s.p1.x < s.p0.x - 1e-3 || s.p2.x < s.p1.x - 1e-3 || s.p3.x < s.p2.x - 1e-3)
            return false;
        px = s.p3.x;
        py = s.p3.y;
    }
    return Math.abs(px - 1) < 0.02 && Math.abs(py - 1) < 0.02;
}
