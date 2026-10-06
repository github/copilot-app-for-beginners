#!/usr/bin/env node
// Build index.html for the course overview video from video.config.json.
//
//   node scripts/build.mjs
//
// The script calculates every scene time, screenshot camera move, and canvas
// card position, then writes one self-contained HyperFrames composition. It
// inlines src/styles.css and src/motion.js. Do not edit index.html by hand.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const cfg = JSON.parse(read("video.config.json"));
const W = cfg.meta.width;
const H = cfg.meta.height;
const SHOT_W = 1920;
const SHOT_H = 1080;
const OVERLAP = 0.5;
const warnings = [];

// ---------- helpers ----------
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const round = (n, d = 3) => Math.round(n * 10 ** d) / 10 ** d;

function mulberry32(seed) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20261005);

const iconCache = new Map();
function icon(name, cls = "") {
  if (!iconCache.has(name)) {
    const file = path.join(root, "assets/icons", `${name}-24.svg`);
    if (!fs.existsSync(file)) throw new Error(`Missing icon: ${file}. Copy it from @primer/octicons build/svg.`);
    const body = fs.readFileSync(file, "utf8").replace(/^<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
    iconCache.set(name, body);
  }
  return `<svg class="icon ${cls}" viewBox="0 0 24 24" aria-hidden="true">${iconCache.get(name)}</svg>`;
}

// Split text into masked words. Gradient words get a shared gradient offset.
function words(text, { grad = false } = {}) {
  const parts = text.split(" ");
  return parts
    .map((word, i) => {
      const style = grad ? ` style="--gs:${parts.length * 100}%;--gp:${parts.length === 1 ? 0 : round((i / (parts.length - 1)) * 100, 1)}%"` : "";
      return `<span class="w"><span class="wi"${style}>${esc(word)}</span></span>`;
    })
    .join(" ");
}

const FRAMES = cfg.meta.framesDir || "assets/frames";
function shotFile(name) {
  return path.join(root, FRAMES, `${name}.webp`);
}
function resolveShot(name, fallback) {
  if (name && fs.existsSync(shotFile(name))) return name;
  if (fallback && fs.existsSync(shotFile(fallback))) {
    warnings.push(`Shot "${name}" is missing. Using fallback "${fallback}".`);
    return fallback;
  }
  warnings.push(`Shot "${name}" is missing and has no usable fallback.`);
  return null;
}
const shotSrc = (name) => `${FRAMES}/${name}.webp`;

// Camera that fits a focus box inside a card of size cw x ch.
function camera(cw, ch, focus, ringOverride, maxZoom = 2.0) {
  const s0 = cw / SHOT_W;
  const base = { x: 0, y: 0, s: round(s0, 5) };
  if (!focus) return { from: base, to: base, ring: null };
  const [l, t, r, b] = focus;
  const rw = r - l;
  const rh = b - t;
  let z = Math.min((0.84 * cw) / (rw * s0), (0.84 * ch) / (rh * s0), maxZoom);
  z = Math.max(z, 1);
  const s1 = s0 * z;
  const cx = (l + r) / 2;
  const cy = (t + b) / 2;
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  const x = clamp(cw / 2 - cx * s1, cw - SHOT_W * s1, 0);
  const y = clamp(ch / 2 - cy * s1, ch - SHOT_H * s1, 0);
  const pad = 14;
  const box = (bl, bt, br, bb) => ({ left: bl - pad, top: bt - pad, width: br - bl + pad * 2, height: bb - bt + pad * 2 });
  // "ring": false hides the ring, an array draws it on that box, and no value
  // draws it on the focus box when the focus box is small.
  let ring = null;
  if (Array.isArray(ringOverride)) ring = box(...ringOverride);
  else if (ringOverride !== false && rw * rh < 0.3 * SHOT_W * SHOT_H) ring = box(l, t, r, b);
  return { from: base, to: { x: round(x, 2), y: round(y, 2), s: round(s1, 5) }, ring };
}

// ---------- timing ----------
let cursor = 0;
const T = {};
for (const key of ["hook", "studio", "reveal", "values", "tracklist"]) {
  T[key] = { start: cursor, dur: cfg[key].duration };
  cursor += cfg[key].duration;
}
const chaptersStart = cursor;
const chapterTotal = cfg.chapters.reduce((sum, c) => sum + c.duration, 0);
T.chapters = { start: chaptersStart, dur: chapterTotal };
cursor += chapterTotal;
for (const key of ["control", "end"]) {
  T[key] = { start: cursor, dur: cfg[key].duration };
  cursor += cfg[key].duration;
}
const TOTAL = round(cursor, 3);

// ---------- chapters plan ----------
const STAGE_W = 960;
const STAGE_H = 540;
const TRACK_W = W - 240;
const SEG_GAP = 8;

let chCursor = chaptersStart;
const chapters = cfg.chapters.map((c, i) => {
  const start = round(chCursor);
  chCursor += c.duration;
  const id = `ch${i}`;
  const plan = { id, start, dur: c.duration, shots: [], steps: c.steps ? c.steps.length : 0, floats: (c.float || []).length };
  if (c.shots) {
    const usable = c.shots
      .map((s) => ({ ...s, file: resolveShot(s.src, s.fallback) }))
      .filter((s) => s.file);
    // A shot can set its own "duration". The rest share the remaining time.
    const fixed = usable.reduce((sum, s) => sum + (s.duration || 0), 0);
    const flexible = usable.filter((s) => !s.duration).length;
    const share = flexible ? (c.duration - fixed) / flexible : 0;
    let shotCursor = start;
    usable.forEach((s, k) => {
      const cam = camera(STAGE_W, STAGE_H, s.focus, s.ring);
      const len = s.duration || share;
      const video = s.video && fs.existsSync(path.join(root, s.video)) ? s.video : null;
      if (s.video && !video) warnings.push(`Clip "${s.video}" is missing. Using the still "${s.file}".`);
      // Optional camera moves: [{ "at": seconds into the shot, "focus": [l, t, r, b], "dur": seconds }].
      const moves = (s.moves || []).map((m) => ({ at: round(shotCursor + m.at), dur: m.dur || 1, to: camera(STAGE_W, STAGE_H, m.focus, false).to }));
      plan.shots.push({
        id: `${id}-s${k}`,
        file: s.file,
        video,
        mediaStart: s.mediaStart || 0,
        rate: s.rate || 1,
        t0: round(shotCursor),
        t1: round(shotCursor + len),
        step: s.step ?? null,
        from: cam.from,
        to: cam.to,
        ring: cam.ring,
        moves,
      });
      shotCursor += len;
    });
  }
  if (c.canvas) plan.canvas = canvasPlan(c.canvas, id, start, c.duration);
  return plan;
});

function canvasPlan(cv, id, start, dur) {
  const cols = cv.columns.length;
  const padX = 24;
  const gap = 16;
  const colW = (STAGE_W - padX * 2 - gap * (cols - 1)) / cols;
  const colX = (c) => padX + c * (colW + gap);
  const cardTop = 88 + 46;
  const cardH = 92;
  const cardGap = 12;
  const stepsCount = Math.max(...cv.cards.map((card) => card.path.length));
  const positions = cv.cards.map(() => []);
  for (let step = 0; step < stepsCount; step++) {
    const stack = new Array(cols).fill(0);
    cv.cards.forEach((card, k) => {
      const col = card.path[Math.min(step, card.path.length - 1)];
      positions[k].push({ x: round(colX(col) + 10), y: cardTop + stack[col] * (cardH + cardGap), col });
      stack[col]++;
    });
  }
  const stepTimes = [];
  for (let step = 1; step < stepsCount; step++) stepTimes.push(round(start + 0.7 + (step * (dur - 1.0)) / stepsCount));
  return {
    colW: round(colW, 2),
    cols: cv.columns.map((name, c) => ({ name, x: round(colX(c), 2) })),
    cards: cv.cards.map((card, k) => ({ id: `${id}-cv${k}`, text: card.text, tag: card.tag, pos: positions[k], done: cv.columns.length - 1 })),
    stepTimes,
  };
}

// DAW segments are proportional to chapter durations.
let segCursor = 0;
const segments = cfg.chapters.map((c, i) => {
  const left = (segCursor / chapterTotal) * TRACK_W;
  segCursor += c.duration;
  const width = (c.duration / chapterTotal) * TRACK_W - SEG_GAP;
  const bars = Math.max(4, Math.floor((width - 20) / 7));
  const heights = Array.from({ length: bars }, (_, b) => {
    const env = 0.55 + 0.45 * Math.sin((b / bars) * Math.PI);
    return Math.round((18 + rand() * 82) * env);
  });
  return { i, left: round(left, 2), width: round(width, 2), heights, start: chapters[i].start, dur: c.duration };
});

const studioBars = Array.from({ length: 96 }, (_, b) => {
  const env = 0.25 + 0.75 * Math.pow(Math.sin(((b + 0.5) / 96) * Math.PI), 1.4);
  return Math.round((24 + rand() * 150) * env);
});

// Hook agents: a grid position, plus a scattered position and an off-screen start.
const AG = cfg.hook.agents || { cols: 8, rows: 3, size: 104, gap: 24, top: 600 };
const agW = AG.cols * AG.size + (AG.cols - 1) * AG.gap;
const agents = [];
for (let r = 0; r < AG.rows; r++) {
  for (let col = 0; col < AG.cols; col++) {
    const i = r * AG.cols + col;
    const gx = (W - agW) / 2 + col * (AG.size + AG.gap);
    const gy = AG.top + r * (AG.size + AG.gap);
    const sx = 60 + rand() * (W - 120 - AG.size);
    const sy = 40 + rand() * (H - 80 - AG.size);
    const ang = rand() * Math.PI * 2;
    agents.push({
      id: `ag${i}`, r, col, gx: round(gx), gy: round(gy),
      sx: round(sx - gx), sy: round(sy - gy),
      ox: round(sx - gx + Math.cos(ang) * 1500), oy: round(sy - gy + Math.sin(ang) * 1100),
      rot0: round((rand() - 0.5) * 160), rot1: round((rand() - 0.5) * 50),
      order: rand(), fill: round(0.8 + rand() * 0.6, 2),
    });
  }
}

// Studio: the hook agents move up into the live room window and get smaller.
const ROOM = cfg.studio.room || { left: 360, top: 280, width: 1200, height: 330 };
const agGridH = AG.rows * AG.size + (AG.rows - 1) * AG.gap;
const agOriginY = AG.top + agGridH / 2;
const studioAgents = { scale: cfg.studio.agentScale || 0.75, x: round(ROOM.left + ROOM.width / 2 - W / 2), y: round(ROOM.top + ROOM.height / 2 + 14 - agOriginY), originY: round(agOriginY) };
const channels = cfg.studio.channels || ["Interactive", "Plan", "Autopilot"];
const agentHtml = (a, prefix) =>
  `<div class="agent" id="${prefix}${a.id}" style="left:${a.gx}px;top:${a.gy}px"><span class="agent-ic">${icon("copilot")}</span><span class="agent-bar"><span class="agent-fill" id="${prefix}${a.id}-f"></span></span><span class="agent-ok" id="${prefix}${a.id}-ok">${icon("check")}</span></div>`;

const particles = Array.from({ length: 64 }, (_, i) => ({
  id: `pt${i}`,
  x: round(rand() * W, 1),
  y: round(rand() * H, 1),
  size: round(1.4 + rand() * 2.6, 2),
  op: round(0.12 + rand() * 0.45, 3),
  dy: round(60 + rand() * 140, 1),
  tw: round(1.6 + rand() * 2.8, 2),
}));

const plan = {
  total: TOTAL,
  T,
  chapters,
  segments: segments.map(({ heights, ...rest }) => rest),
  trackW: TRACK_W,
  particles,
  sweeps: [T.studio.start, T.reveal.start, T.values.start, T.tracklist.start, T.control.start, T.end.start],
  heroScale: round(1120 / SHOT_W, 5),
  overlap: OVERLAP,
  urlChars: cfg.meta.url.length,
  studioBars: studioBars.length,
  agents: agents.map(({ id, r, col, sx, sy, ox, oy, rot0, rot1, order, fill }) => ({ id, r, col, sx, sy, ox, oy, rot0, rot1, order, fill })),
  studioAgents,
  channels: channels.length,
  floatsFor: cfg.chapters.map((ch) => (ch.float || []).length),
};

// ---------- markup ----------
const tileFiles = cfg.reveal.wall.map((n) => resolveShot(n, "home")).filter(Boolean);
const wallRows = [0, 1, 2, 3].map((r) => {
  const row = Array.from({ length: 5 }, (_, k) => tileFiles[(r * 5 + k) % tileFiles.length]);
  return `<div class="wall-row" id="wr${r}">${row.map((f) => `<div class="tile"><img src="${shotSrc(f)}" alt=""></div>`).join("")}</div>`;
});

const heroFile = resolveShot(cfg.reveal.hero, "home");

function chapterHtml(c, p) {
  const [l1, l2] = c.headline;
  const head = `<span class="line">${words(l1)}</span><span class="line grad">${words(l2, { grad: true })}</span>`;
  let inner = "";
  if (p.canvas) {
    const cv = p.canvas;
    inner = `<div class="cv"><div class="cv-bar">${icon("project")}<span>${esc(c.canvas.title)}</span><span class="cv-tag mono">canvas</span></div>
      ${cv.cols.map((col) => `<div class="cv-col" style="left:${col.x}px;width:${cv.colW}px"><span class="cv-col-h mono">${esc(col.name)}</span></div>`).join("")}
      ${cv.cards.map((card) => `<div class="cv-card" id="${card.id}" style="width:${round(cv.colW - 20, 2)}px"><div class="cv-card-t">${esc(card.text)}</div><span class="cv-card-g">${esc(card.tag)}</span><span class="cv-done" id="${card.id}-done">${icon("check")}</span></div>`).join("")}
    </div>`;
  } else {
    inner = p.shots
      .map(
        (s) => `<div class="shot" id="${s.id}"><div class="shot-inner" id="${s.id}-in">${s.video ? "" : `<img src="${shotSrc(s.file)}" alt="">`}${
          s.ring ? `<div class="ring" id="${s.id}-ring" style="left:${s.ring.left}px;top:${s.ring.top}px;width:${s.ring.width}px;height:${s.ring.height}px"></div>` : ""
        }</div></div>`
      )
      .join("");
  }
  const floats = (c.float || []).length
    ? `<div class="floats">${c.float.map((f, k) => `<span class="pill" id="${p.id}-f${k}">${esc(f)}</span>`).join("")}</div>`
    : "";
  const steps = c.steps
    ? `<div class="steps">${c.steps
        .map((s, k) => `${k ? '<span class="step-link"></span>' : ""}<span class="step" id="${p.id}-st${k}"><span class="step-on" id="${p.id}-st${k}-on"></span><span class="step-t">${esc(s)}</span></span>`)
        .join("")}</div>`
    : "";
  return `<section id="${p.id}" class="clip scene" data-start="${p.start}" data-duration="${round(p.dur + OVERLAP)}" data-track-index="${3 + (p.id.slice(2) % 2)}">
    <div class="ch-text" id="${p.id}-text">
      <div class="ch-label mono"><span class="ch-num">Track ${esc(c.num)}</span><span class="ch-name">${esc(c.studio)}</span></div>
      <h2 class="ch-head">${head}</h2>
      <p class="ch-sub">${esc(c.sub)}</p>
    </div>
    <div class="persp stage" id="${p.id}-stage">
      <div class="card-wrap" id="${p.id}-wrap"><div class="card" id="${p.id}-card">${inner}<div class="sheen" id="${p.id}-sheen" data-layout-allow-overflow></div></div>${floats}</div>
    </div>
    ${steps}
  </section>`;
}

// Video shots live in a root-level copy of the chapter card. A <video> must not
// sit inside an element that has data-start, so this card is not a timed clip.
// motion.js moves it with the chapter card and fades it in for its shot.
function videoOverlayHtml(p) {
  const vids = p.shots.filter((s) => s.video);
  if (!vids.length) return "";
  return `<div class="persp stage" id="${p.id}-vstage"><div class="card-wrap" id="${p.id}-vwrap">${vids
    .map((s, k) => {
      const last = s === p.shots[p.shots.length - 1];
      const start = round(s.t0 - 0.3);
      const dur = round(s.t1 - s.t0 + 0.3 + (last ? 0.2 : 0.3));
      return `<div class="card vcard" id="${s.id}-vcard"><div class="shot"><div class="shot-inner" id="${s.id}-vin"><video id="${s.id}-video" class="clip-video" src="${esc(s.video)}" muted playsinline data-start="${start}" data-duration="${dur}" data-track-index="${7 + k}"${s.mediaStart ? ` data-media-start="${s.mediaStart}"` : ""}${s.rate !== 1 ? ` data-playback-rate="${s.rate}"` : ""}></video></div></div></div>`;
    })
    .join("")}</div></div>`;
}

const dawHtml = `<div id="daw" class="clip layer" data-start="${T.tracklist.start}" data-duration="${round(T.tracklist.dur + T.chapters.dur + OVERLAP)}" data-track-index="6">
  <div class="daw-title" id="daw-title"><span>${words(cfg.tracklist.title[0])}</span> <span class="grad">${words(cfg.tracklist.title[1], { grad: true })}</span></div>
  <div class="daw-inner" id="daw-inner">
    <div class="daw-head mono"><span class="rec-dot"></span><span>Course tracklist · ${cfg.chapters.length} tracks</span><span class="tc" id="daw-tc">00:00:00:00</span></div>
    <div class="daw-track">
      ${segments
        .map((s) => {
          const c = cfg.chapters[s.i];
          const bars = s.heights.map((h) => `<i style="height:${h}%"></i>`).join("");
          return `<div class="seg" id="seg${s.i}" style="left:${s.left}px;width:${s.width}px"><div class="wave">${bars}</div><div class="seg-fill" id="seg${s.i}-fill" style="width:0px" data-layout-allow-overflow><div class="seg-fill-in" style="width:${s.width}px"></div><div class="wave" style="width:${round(s.width - 20, 2)}px">${bars}</div></div></div>
          <div class="seg-label mono" id="seg${s.i}-label" style="left:${s.left + 2}px"><b>${esc(c.num)}</b>${esc(c.short)}</div>`;
        })
        .join("")}
      <div class="playhead" id="playhead"><div class="ph-cap"></div></div>
    </div>
  </div>
</div>`;

// One <audio> per music segment (see scripts/add-music.mjs for the format).
function musicHtml(music) {
  if (!music || !music.src) return "<!-- No music yet. Set music.src in video.config.json, or run scripts/add-music.mjs after render. -->";
  const segs = Array.isArray(music.segments) && music.segments.length ? music.segments : [{ at: 0, trackAt: music.start || 0 }];
  const xf = music.crossfade ?? 0.3;
  const fadeIn = music.fadeIn ?? 0.4;
  const fadeOut = music.fadeOut ?? 2.5;
  return segs
    .map((seg, i) => {
      const first = i === 0;
      const last = i === segs.length - 1;
      let v0 = first ? 0 : seg.at - xf / 2;
      const v1 = last ? TOTAL : segs[i + 1].at + xf / 2;
      let ts = v0 - seg.at + seg.trackAt;
      if (ts < 0) {
        v0 -= ts;
        ts = 0;
      }
      const len = round(v1 - v0);
      const a = first ? Math.min(fadeIn, len) : xf;
      const z = last ? fadeOut : xf;
      const points = [{ t: 0, v: 0 }, { t: round(a), v: 1 }, { t: round(len - z), v: 1 }, { t: len, v: 0 }];
      return `<audio id="music${i ? i + 1 : ""}" src="${esc(music.src)}" data-start="${round(v0)}" data-duration="${len}" data-track-index="${9 + i}" data-volume="${music.volume ?? 0.9}"${
        ts ? ` data-media-start="${round(ts)}"` : ""
      } data-automation='${JSON.stringify({ version: 1, lanes: [{ target: "volume", points }] })}'></audio>`;
    })
    .join("\n");
}

const c = cfg;
const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=${W}, height=${H}">
<title>${esc(c.meta.title)} ${esc(c.meta.subtitle)} | Course overview video</title>
<!-- Generated by scripts/build.mjs from video.config.json. Do not edit by hand. -->
<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
<style>
${read("src/styles.css")}
</style>
</head>
<body>
<div id="root" data-composition-id="main" data-start="0" data-duration="${TOTAL}" data-width="${W}" data-height="${H}">

<div id="bg" class="clip layer" data-start="0" data-duration="${TOTAL}" data-track-index="0">
  <div class="aurora a1" id="a1"></div><div class="aurora a2" id="a2"></div><div class="aurora a3" id="a3"></div>
  <div class="dotgrid" id="dotgrid"></div>
  <div class="vignette"></div>
  <div id="particles">${particles.map((p) => `<span class="pt" id="${p.id}" style="left:${p.x}px;top:${p.y}px;width:${p.size}px;height:${p.size}px;opacity:0"></span>`).join("")}</div>
</div>

<section id="s-hook" class="clip scene" data-start="${T.hook.start}" data-duration="${T.hook.dur}" data-track-index="1">
  <div class="agents" id="agents">${agents.map((a) => agentHtml(a, "")).join("")}</div>
  <div class="hook-wrap" id="hook-wrap">
    <div class="hook-l1" id="hook-l1">${words(c.hook.lines[0])}</div>
    <div class="hook-l2" id="hook-l2">${words(c.hook.lines[1])}</div>
    <div class="hook-l3 grad" id="hook-l3">${words(c.hook.lines[2], { grad: true })}</div>
  </div>
</section>

<section id="s-studio" class="clip scene" data-start="${T.studio.start}" data-duration="${T.studio.dur}" data-track-index="2">
  <div class="studio-lines"><div class="studio-l1" id="studio-l1">${words(c.studio.lines[0])}</div><div class="studio-l2 grad" id="studio-l2">${words(c.studio.lines[1], { grad: true })}</div></div>
  <div class="live-room" id="live-room" style="left:${ROOM.left}px;top:${ROOM.top}px;width:${ROOM.width}px;height:${ROOM.height}px"><span class="live-label mono" id="live-label"><span class="live-dot"></span>${esc(c.studio.roomLabel || "Live room")}</span></div>
  <div class="st-agents" id="st-agents" style="transform-origin:${W / 2}px ${studioAgents.originY}px">${agents.map((a) => agentHtml(a, "st-")).join("")}</div>
  <div class="live-glass" id="live-glass" style="left:${ROOM.left}px;top:${ROOM.top}px;width:${ROOM.width}px;height:${ROOM.height}px"><span class="glass-streak gs1"></span><span class="glass-streak gs2"></span><span class="glass-sweep" id="glass-sweep"></span></div>
  <div class="console-persp"><div class="console" id="console">
    <div class="console-screen"><div class="studio-wave" id="studio-wave">${studioBars.map((h, i) => `<i id="sb${i}" style="height:${Math.round(h * 0.42)}px"></i>`).join("")}</div></div>
    ${channels
      .map(
        (name, k) => `<div class="strip" style="left:${60 + k * 340}px"><span class="strip-label mono">${esc(name)}</span><span class="fader-track"></span><span class="fader-knob" id="fk${k}"></span><span class="meter"><span class="meter-fill" id="mf${k}"></span></span>${[0, 1, 2]
          .map((j) => `<span class="knob" style="left:${140 + j * 52}px"><i id="kn${k}${j}"></i></span>`)
          .join("")}</div>`
      )
      .join("")}
  </div></div>
  ${c.studio.roles
    .map((r, i) => `<div class="role role${i}" id="role${i}"><span class="role-line"></span><span class="role-ic">${icon(r.icon)}</span><span class="role-t"><span class="role-pre">${esc(r.pre)}</span><b class="grad-text role-word">${esc(r.word)}</b></span></div>`)
    .join("")}
</section>

<section id="s-reveal" class="clip scene" data-start="${T.reveal.start}" data-duration="${T.reveal.dur}" data-track-index="2">
  <div class="wall-persp"><div class="wall" id="wall">${wallRows.join("")}</div></div>
  <div class="wall-scrim" id="wall-scrim"></div>
  <div class="reveal-kicker" id="reveal-kicker"><div>${words(c.reveal.kicker)}</div></div>
  <div class="lockup-kicker" id="lockup-kicker">${words(c.reveal.introducing || "Introducing")}</div>
  <div class="lockup" id="lockup">
    <div class="lockup-icon" id="lockup-icon">${icon("copilot")}</div>
    <div class="lockup-text"><div>${words(c.meta.title)}</div><div class="grad">${words(c.meta.subtitle, { grad: true })}</div></div>
  </div>
  <div class="persp hero-persp"><div class="card-wrap" id="hero"><div class="card"><div class="shot"><div class="shot-inner" id="hero-in"><img src="${shotSrc(heroFile)}" alt=""></div></div><div class="sheen" id="hero-sheen" data-layout-allow-overflow></div></div></div></div>
</section>

<section id="s-values" class="clip scene" data-start="${T.values.start}" data-duration="${T.values.dur}" data-track-index="1">
  <div class="values-words" id="values-words">${c.values.words
    .map((w, i) => `<span class="vword ${i === c.values.words.length - 1 ? "grad" : ""}" id="vw${i}">${words(w, { grad: i === c.values.words.length - 1 })}${i === c.values.words.length - 1 ? '<span class="v-underline" id="v-underline"></span>' : ""}</span>`)
    .join("")}</div>
  <div class="chips" id="chips">${c.values.chips.map((ch, i) => `<span class="pill" id="chip${i}">${icon(ch.icon)}<span>${esc(ch.text)}</span></span>`).join("")}</div>
</section>

${cfg.chapters.map((ch, i) => chapterHtml(ch, chapters[i])).join("\n")}
${chapters.map(videoOverlayHtml).join("\n")}

${dawHtml}

<section id="s-control" class="clip scene" data-start="${T.control.start}" data-duration="${T.control.dur}" data-track-index="2">
  <div class="ctl-lines"><div class="ctl-l1" id="ctl-l1">${words(c.control.lines[0])}</div><div class="ctl-l2 grad" id="ctl-l2">${words(c.control.lines[1], { grad: true })}</div></div>
  <div class="ctl-steps" id="ctl-steps">
    <div class="ctl-line"><div class="ctl-line-fill" id="ctl-line-fill"></div></div>
    ${c.control.steps.map((s, i) => `<div class="ctl-step" id="ctl${i}"><div class="ctl-ic"><span class="ctl-ic-on" id="ctl${i}-on"></span>${icon(s.icon)}<span class="ctl-check" id="ctl${i}-ok">${icon("check")}</span></div><div class="ctl-t">${esc(s.text)}</div></div>`).join("")}
  </div>
</section>

<section id="s-end" class="clip scene" data-start="${T.end.start}" data-duration="${T.end.dur}" data-track-index="1">
  <div class="end-wrap">
    <div class="end-icon" id="end-icon"><span class="end-ring" id="end-ring"></span>${icon("copilot")}</div>
    <div class="end-title"><span class="line">${words(c.meta.title)}</span><span class="line grad">${words(c.meta.subtitle, { grad: true })}</span></div>
    <div class="end-badges">${c.end.badges.map((b, i) => `<span class="pill" id="badge${i}">${icon(b.icon)}<span>${esc(b.text)}</span></span>`).join("")}</div>
    <div class="end-url" id="end-url"><span class="gh" id="end-gh">${icon("mark-github")}</span><span class="url-text">${[...c.meta.url].map((ch, i) => `<span id="u${i}">${esc(ch)}</span>`).join("")}</span><span class="url-underline" id="url-underline"></span></div>
    <div class="end-cta" id="end-cta">${esc(c.end.cta)}</div>
  </div>
</section>

<div id="fx" class="clip layer" data-start="0" data-duration="${TOTAL}" data-track-index="8">
  <div class="sweep-band" id="sweep"></div>
  <div class="grain" id="grain"></div>
  <div class="fade-black" id="fade-black"></div>
</div>
${musicHtml(c.music)}
</div>
<script>
window.__PLAN__ = ${JSON.stringify(plan)};
${read("src/motion.js")}
</script>
</body>
</html>
`;

fs.writeFileSync(path.join(root, "index.html"), html);
console.log(`index.html written: ${TOTAL}s, ${chapters.length} chapters, ${chapters.reduce((n, ch) => n + ch.shots.length, 0)} chapter shots.`);
for (const w of warnings) console.warn(`warning: ${w}`);
