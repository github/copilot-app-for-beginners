// Motion runtime for the course overview video. scripts/build.mjs inlines this file
// into index.html after window.__PLAN__. All tween positions are global seconds.
// Motion rules: smooth expo/power eases, no overshoot, no infinite loops.
(function () {
  const P = window.__PLAN__;
  const $ = (id) => document.getElementById(id);
  const q = (sel, rootEl) => Array.from((rootEl || document).querySelectorAll(sel));

  function pad(n) {
    return String(n).padStart(2, "0");
  }
  function timecode(t) {
    const frames = Math.floor((t % 1) * 30);
    const s = Math.floor(t);
    return `00:${pad(Math.floor(s / 60))}:${pad(s % 60)}:${pad(frames)}`;
  }

  // Masked words rise into place while the width axis settles to 100.
  function riseWords(tl, container, at, opts = {}) {
    const items = q(".wi", container);
    tl.fromTo(
      items,
      { yPercent: 115, "--wd": opts.fromWidth ?? 120 },
      { yPercent: 0, "--wd": 100, duration: opts.duration ?? 0.85, ease: "expo.out", stagger: opts.stagger ?? 0.07 },
      at
    );
    return items.length;
  }

  function sweep(tl, at) {
    const band = $("sweep");
    tl.fromTo(band, { x: -900, rotation: 18 }, { x: 2500, rotation: 18, duration: 1.2, ease: "power2.inOut" }, at - 0.55);
    tl.fromTo(band, { opacity: 0 }, { opacity: 1, duration: 0.45, ease: "sine.out" }, at - 0.55);
    tl.to(band, { opacity: 0, duration: 0.5, ease: "sine.in" }, at + 0.15);
  }

  // Shrink a chapter headline when its longest line is wider than the column.
  function fitHeadlines() {
    for (const head of q(".ch-head")) {
      const max = head.clientWidth;
      const widest = Math.max(...q(".line", head).map((line) => line.scrollWidth));
      if (widest > max) {
        const size = parseFloat(getComputedStyle(head).fontSize);
        head.style.fontSize = `${Math.floor((size * max) / widest)}px`;
      }
    }
  }

  function build() {
    fitHeadlines();
    const tl = gsap.timeline({ paused: true });
    const T = P.T;

    // ---------- Background ----------
    tl.fromTo("#a1", { x: 0, y: 0 }, { x: 180, y: 110, duration: 15, ease: "sine.inOut", yoyo: true, repeat: 3 }, 0);
    tl.fromTo("#a2", { x: 0, y: 0 }, { x: -200, y: -90, duration: 12, ease: "sine.inOut", yoyo: true, repeat: 4 }, 0);
    tl.fromTo("#a3", { x: -120, y: 60, scale: 0.9, opacity: 0.55 }, { x: 140, y: -40, scale: 1.1, opacity: 0.8, duration: 10, ease: "sine.inOut", yoyo: true, repeat: 4 }, 0);
    tl.fromTo("#dotgrid", { x: 0, y: 0 }, { x: -40, y: -40, duration: P.total, ease: "none" }, 0);
    tl.fromTo("#grain", { x: 0, y: 0 }, { x: 256, y: 128, duration: P.total, ease: `steps(${Math.round(P.total * 12)})` }, 0);
    for (const p of P.particles) {
      tl.fromTo(`#${p.id}`, { y: 0 }, { y: -p.dy, duration: P.total, ease: "none" }, 0);
      const loops = Math.max(1, Math.floor(P.total / p.tw) - 1);
      tl.fromTo(`#${p.id}`, { opacity: p.op * 0.25 }, { opacity: p.op, duration: p.tw / 2, ease: "sine.inOut", yoyo: true, repeat: loops * 2 - 1 }, (p.tw * 7) % 1.7);
    }
    for (const at of P.sweeps) sweep(tl, at);

    // One clock drives both timecode readouts.
    const clock = { t: 0 };
    const dawTc = $("daw-tc");
    tl.fromTo(
      clock,
      { t: 0 },
      {
        t: P.total,
        duration: P.total,
        ease: "none",
        onUpdate: () => {
          dawTc.textContent = timecode(clock.t);
        },
      },
      0
    );

    // ---------- Hook ----------
    // Agents fly in scattered, then move into neat rows while
    // "while staying focused?" appears. Then each one shows progress and a check.
    {
      const s = T.hook.start;
      riseWords(tl, $("hook-l1"), s + 0.3, { stagger: 0.07 });
      riseWords(tl, $("hook-l2"), s + 0.9, { stagger: 0.08, fromWidth: 118, duration: 0.95 });
      for (const a of P.agents) {
        const el = `#${a.id}`;
        const fly = s + 1.3 + a.order * 1.1;
        tl.fromTo(el, { x: a.ox, y: a.oy, rotation: a.rot0, scale: 0.7, opacity: 0 }, { x: a.sx, y: a.sy, rotation: a.rot1, scale: 0.82, opacity: 0.5, duration: 1.0, ease: "power3.out" }, fly);
        const organize = s + 3.25 + (a.r * 8 + a.col) * 0.018;
        tl.to(el, { x: 0, y: 0, rotation: 0, scale: 1, opacity: 1, duration: 1.1, ease: "power3.inOut" }, organize);
        const fillAt = s + 4.5 + a.col * 0.07 + a.r * 0.05;
        tl.fromTo(`${el}-f`, { scaleX: 0 }, { scaleX: 1, duration: a.fill, ease: "power1.inOut" }, fillAt);
        tl.fromTo(`${el}-ok`, { opacity: 0, scale: 0.5 }, { opacity: 1, scale: 1, duration: 0.35, ease: "power3.out" }, fillAt + a.fill - 0.05);
      }
      riseWords(tl, $("hook-l3"), s + 3.2, { stagger: 0.08, fromWidth: 124, duration: 1.0 });
      // Only the text leaves. The agents continue into the studio scene, where an
      // identical set ("st-" ids) takes over at the cut.
      tl.to("#hook-wrap", { opacity: 0, y: -24, filter: "blur(10px)", duration: 0.55, ease: "power2.in" }, s + T.hook.dur - 0.6);
    }

    // ---------- Reveal ----------
    {
      const s = T.reveal.start;
      tl.fromTo("#wall", { rotationX: 34, rotationZ: -13, scale: 1.7, opacity: 0, z: 0 }, { rotationX: 30, rotationZ: -12, scale: 1.12, opacity: 1, duration: 1.9, ease: "expo.out" }, s);
      for (let r = 0; r < 4; r++) {
        const dir = r % 2 ? 1 : -1;
        tl.fromTo(`#wr${r}`, { x: -dir * 180 }, { x: dir * 180, duration: T.reveal.dur, ease: "none" }, s);
      }
      tl.fromTo("#wall-scrim", { opacity: 0 }, { opacity: 1, duration: 0.8, ease: "sine.out" }, s + 0.3);
      riseWords(tl, $("reveal-kicker"), s + 0.55, { stagger: 0.08, fromWidth: 122 });
      tl.to("#reveal-kicker", { opacity: 0, y: -40, filter: "blur(10px)", duration: 0.45, ease: "power2.in" }, s + 2.7);
      tl.to("#wall", { scale: 2.5, opacity: 0, filter: "blur(14px)", duration: 1.1, ease: "power2.in" }, s + 2.85);
      tl.to("#wall-scrim", { opacity: 0, duration: 0.8 }, s + 3.15);

      tl.fromTo("#hero-in", { x: 0, y: 0, scale: P.heroScale }, { x: 0, y: 0, scale: P.heroScale, duration: 0.01 }, s);
      tl.fromTo("#hero", { y: 620, rotationX: 58, scale: 0.78, opacity: 0 }, { y: 0, rotationX: 10, scale: 1, opacity: 1, duration: 1.6, ease: "expo.out" }, s + 3.0);
      tl.to("#hero", { rotationX: 3, duration: 1.4, ease: "sine.inOut" }, s + 4.4);
      tl.fromTo("#hero-sheen", { xPercent: -120, opacity: 1 }, { xPercent: 330, opacity: 1, duration: 1.2, ease: "power2.inOut" }, s + 3.9);
      riseWords(tl, $("lockup-kicker"), s + 3.45, { stagger: 0.05, duration: 0.8 });
      tl.fromTo("#lockup-icon", { scale: 0.6, opacity: 0, y: 20 }, { scale: 1, opacity: 1, y: 0, duration: 0.9, ease: "expo.out" }, s + 3.6);
      riseWords(tl, $("lockup"), s + 3.7, { stagger: 0.06, fromWidth: 124 });
      tl.to([$("hero"), $("lockup"), $("lockup-kicker")], { opacity: 0, y: (i) => (i ? -30 : 60), filter: "blur(8px)", duration: 0.45, ease: "power2.in" }, s + T.reveal.dur - 0.45);
    }

    // ---------- Values ----------
    {
      const s = T.values.start;
      q("#values-words .vword").forEach((el, k) => riseWords(tl, el, s + 0.02 + k * 0.42, { stagger: 0.05, fromWidth: 100, duration: 0.8 }));
      tl.fromTo("#v-underline", { scaleX: 0 }, { scaleX: 1, duration: 0.7, ease: "power3.inOut" }, s + 1.45);
      tl.fromTo(q("#chips .pill"), { y: 26, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6, ease: "power3.out", stagger: 0.09 }, s + 1.8);
      tl.to(["#values-words", "#chips"], { y: -36, opacity: 0, filter: "blur(8px)", duration: 0.45, ease: "power2.in", stagger: 0.05 }, s + T.values.dur - 0.5);
    }

    // ---------- Studio ----------
    // The agents from the hook move up into the live room (the band), then a
    // mixing console rises below them (the producer's desk).
    {
      const s = T.studio.start;
      const end = s + T.studio.dur;
      const SA = P.studioAgents;
      riseWords(tl, $("studio-l1"), s + 0.25, { stagger: 0.06 });
      riseWords(tl, $("studio-l2"), s + 0.75, { stagger: 0.08, fromWidth: 124, duration: 1.0 });

      // Hand-off state: matches the last hook frame (all bars full, all checks on).
      for (const a of P.agents) {
        tl.fromTo(`#st-${a.id}-f`, { scaleX: 1 }, { scaleX: 1, duration: 0.01 }, s);
        tl.fromTo(`#st-${a.id}-ok`, { opacity: 1, scale: 1 }, { opacity: 0, scale: 0.6, duration: 0.4, ease: "power2.in" }, s + 0.3 + a.order * 0.3);
      }
      tl.fromTo("#st-agents", { x: 0, y: 0, scale: 1 }, { x: SA.x, y: SA.y, scale: SA.scale, duration: 1.5, ease: "power3.inOut" }, s + 0.15);

      // The room and its glass build around the agents.
      tl.fromTo("#live-room", { opacity: 0, scale: 1.04 }, { opacity: 1, scale: 1, duration: 1.0, ease: "power3.out" }, s + 0.9);
      tl.fromTo("#live-glass", { opacity: 0, scale: 1.04 }, { opacity: 1, scale: 1, duration: 1.0, ease: "power3.out" }, s + 0.9);
      tl.fromTo("#live-label", { opacity: 0, x: -12 }, { opacity: 1, x: 0, duration: 0.6, ease: "power3.out" }, s + 1.5);
      tl.fromTo("#glass-sweep", { x: -300, opacity: 1 }, { x: 1400, opacity: 1, duration: 1.4, ease: "power2.inOut" }, s + 1.6);

      // The band plays: each agent's bar moves like a level meter until the end.
      for (const a of P.agents) {
        const at = s + 1.4 + a.order * 0.4;
        const half = 0.18 + a.fill * 0.12;
        const repeats = Math.ceil((end - at) / half);
        tl.fromTo(`#st-${a.id}-f`, { scaleX: 1 }, { scaleX: 0.25 + a.order * 0.45, duration: half, ease: "sine.inOut", yoyo: true, repeat: repeats }, at);
      }

      // The console rises, then the faders come up and the meters move.
      tl.fromTo("#console", { y: 260, rotationX: 40, opacity: 0 }, { y: 0, rotationX: 16, opacity: 1, duration: 1.3, ease: "expo.out" }, s + 2.5);
      const n = P.studioBars;
      for (let i = 0; i < n; i++) {
        const fromCenter = Math.abs(i - (n - 1) / 2) / ((n - 1) / 2);
        const at = s + 2.9 + fromCenter * 0.6;
        tl.fromTo(`#sb${i}`, { scaleY: 0.05 }, { scaleY: 1, duration: 0.7, ease: "expo.out" }, at);
        const low = 0.3 + ((i * 37) % 23) / 60;
        const half = 0.21 + ((i * 53) % 17) / 120;
        tl.fromTo(`#sb${i}`, { scaleY: 1 }, { scaleY: low, duration: half, ease: "sine.inOut", yoyo: true, repeat: Math.ceil((end - at - 0.7) / half) }, at + 0.7);
      }
      const faderTo = [-58, -70, -46];
      for (let k = 0; k < P.channels; k++) {
        const at = s + 3.3 + k * 0.18;
        tl.fromTo(`#fk${k}`, { y: 0 }, { y: faderTo[k % 3], duration: 0.9, ease: "power3.inOut" }, at);
        tl.fromTo(`#mf${k}`, { scaleY: 0.05 }, { scaleY: 0.85, duration: 0.6, ease: "power2.out" }, at + 0.2);
        const half = 0.19 + k * 0.04;
        tl.fromTo(`#mf${k}`, { scaleY: 0.85 }, { scaleY: 0.45 + k * 0.08, duration: half, ease: "sine.inOut", yoyo: true, repeat: Math.ceil((end - at - 0.8) / half) }, at + 0.8);
        for (let j = 0; j < 3; j++) {
          tl.fromTo(`#kn${k}${j}`, { rotation: -120 }, { rotation: -60 + ((k * 3 + j) * 47) % 150, duration: 0.9, ease: "power3.inOut" }, at + 0.1 + j * 0.06);
        }
      }

      // Roles: the band first (with the room), then the producer (with the desk).
      tl.fromTo("#role1", { x: 30, opacity: 0 }, { x: 0, opacity: 1, duration: 0.8, ease: "expo.out" }, s + 2.0);
      tl.fromTo("#role0", { x: 30, opacity: 0 }, { x: 0, opacity: 1, duration: 0.8, ease: "expo.out" }, s + 3.9);

      tl.to([q(".studio-lines")[0], $("live-room"), $("st-agents"), $("live-glass"), $("console"), $("role0"), $("role1")], { y: "-=24", opacity: 0, filter: "blur(8px)", duration: 0.55, ease: "power2.in", stagger: 0.03 }, end - 0.65);
    }

    // ---------- Tracklist intro and chapters ----------
    {
      const tr = T.tracklist;
      const daw = T.chapters;
      const lift = -400;
      tl.fromTo("#daw-inner", { y: lift + 40, opacity: 0 }, { y: lift, opacity: 1, duration: 0.9, ease: "expo.out" }, tr.start + 0.05);
      riseWords(tl, $("daw-title"), tr.start + 0.2, { stagger: 0.07, fromWidth: 120 });
      for (const sg of P.segments) {
        const at = tr.start + 0.55 + sg.i * 0.1;
        tl.fromTo(`#seg${sg.i}`, { borderColor: "rgba(255,255,255,0.08)" }, { borderColor: "rgba(163,113,247,0.7)", duration: 0.25, ease: "sine.out", yoyo: true, repeat: 1 }, at);
        tl.fromTo(`#seg${sg.i}-label`, { opacity: 0.35 }, { opacity: 1, duration: 0.3, ease: "sine.out" }, at);
      }
      tl.to("#daw-title", { y: -40, opacity: 0, filter: "blur(8px)", duration: 0.5, ease: "power2.in" }, tr.start + tr.dur - 0.9);
      tl.to("#daw-inner", { y: 0, duration: 0.9, ease: "power3.inOut" }, tr.start + tr.dur - 0.85);

      tl.fromTo("#playhead", { x: 0 }, { x: P.trackW, duration: daw.dur, ease: "none" }, daw.start);
      for (const sg of P.segments) {
        tl.fromTo(`#seg${sg.i}-fill`, { width: 0 }, { width: sg.width, duration: sg.dur, ease: "none" }, sg.start);
        tl.to(`#seg${sg.i}`, { borderColor: "rgba(163,113,247,0.75)", boxShadow: "0 0 24px rgba(124,108,255,0.35)", duration: 0.3 }, sg.start);
        tl.to(`#seg${sg.i}`, { borderColor: "rgba(255,255,255,0.12)", boxShadow: "0 0 0 rgba(0,0,0,0)", duration: 0.4 }, sg.start + sg.dur);
        tl.fromTo(`#seg${sg.i}-label`, { color: "#8b95a7" }, { color: "#f2f5fa", duration: 0.3 }, sg.start);
      }
      tl.to("#daw-inner", { y: 40, opacity: 0, duration: 0.45, ease: "power2.in" }, daw.start + daw.dur - 0.05);

      for (const ch of P.chapters) {
        const s = ch.start;
        const end = s + ch.dur;
        const text = $(`${ch.id}-text`);
        tl.fromTo(q(".ch-label", text), { x: -20, opacity: 0 }, { x: 0, opacity: 1, duration: 0.6, ease: "power3.out" }, s + 0.2);
        riseWords(tl, q(".ch-head", text)[0], s + 0.3, { stagger: 0.06, fromWidth: 116, duration: 0.9 });
        tl.fromTo(q(".ch-sub", text), { y: 16, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7, ease: "power3.out" }, s + 0.85);
        tl.to(text, { y: -16, opacity: 0, filter: "blur(4px)", duration: 0.4, ease: "power2.in" }, end - 0.4);

        // Calm card change: fade and settle in, fade and drift out.
        // A chapter with a video shot has a second, root-level card that moves with it.
        const wrap = [$(`${ch.id}-wrap`), $(`${ch.id}-vwrap`)].filter(Boolean);
        tl.fromTo(wrap, { x: 70, rotationY: -12, scale: 1.02, opacity: 0 }, { x: 0, rotationY: -5, scale: 1, opacity: 1, duration: 1.1, ease: "power3.out" }, s + 0.05);
        tl.to(wrap, { rotationY: -2, duration: Math.max(0.5, ch.dur - 1.6), ease: "sine.inOut" }, s + 1.15);
        tl.to(wrap, { x: -50, scale: 0.97, opacity: 0, duration: 0.5, ease: "power2.in" }, end - 0.4);
        tl.fromTo(`#${ch.id}-sheen`, { xPercent: -120, opacity: 1 }, { xPercent: 330, opacity: 1, duration: 1.2, ease: "power2.inOut" }, s + 0.7);

        for (let k = 0; k < ch.floats; k++) {
          tl.fromTo(`#${ch.id}-f${k}`, { y: 16, opacity: 0 }, { y: 0, opacity: 1, duration: 0.6, ease: "power3.out" }, s + 1.0 + k * 0.15);
        }

        // Each screen holds at full view first, so viewers can read it, then
        // the camera pushes in to the focus box. Screens change by crossfade.
        ch.shots.forEach((sh, k) => {
          const inner = [$(`${sh.id}-in`), $(`${sh.id}-vin`)].filter(Boolean);
          const sliceDur = sh.t1 - sh.t0;
          const last = k === ch.shots.length - 1;
          const hold = k === 0 ? 1.3 : 0.9;
          const tail = last ? 0.9 : 0.5;
          const pushDur = Math.max(0.8, sliceDur - hold - tail);
          tl.fromTo(inner, { x: sh.from.x, y: sh.from.y, scale: sh.from.s }, { x: sh.from.x, y: sh.from.y, scale: sh.from.s, duration: 0.01 }, Math.max(0, sh.t0 - 0.7));
          if (sh.moves.length) {
            for (const m of sh.moves) tl.to(inner, { x: m.to.x, y: m.to.y, scale: m.to.s, duration: m.dur, ease: "power2.inOut" }, m.at);
          } else {
            tl.to(inner, { x: sh.to.x, y: sh.to.y, scale: sh.to.s, duration: pushDur, ease: "power2.inOut" }, sh.t0 + hold);
          }
          if (sh.video) {
            tl.fromTo(`#${sh.id}-vcard`, { opacity: 0 }, { opacity: 1, duration: 0.6, ease: "sine.inOut" }, sh.t0 - 0.3);
            if (!last) tl.to(`#${sh.id}-vcard`, { opacity: 0, duration: 0.6, ease: "sine.inOut" }, sh.t1 - 0.3);
          }
          if (sh.ring) {
            tl.fromTo(`#${sh.id}-ring`, { opacity: 0, scale: 1.06, transformOrigin: "50% 50%" }, { opacity: 1, scale: 1, duration: 0.5, ease: "power3.out" }, sh.t0 + hold + pushDur * 0.7);
          }
          if (k > 0) {
            tl.fromTo(`#${sh.id}`, { opacity: 0 }, { opacity: 1, duration: 0.6, ease: "sine.inOut" }, sh.t0 - 0.3);
          }
          if (sh.step !== null && ch.steps) {
            tl.to(`#${ch.id}-st${sh.step}-on`, { opacity: 1, duration: 0.4, ease: "sine.out" }, sh.t0);
            tl.to(`#${ch.id}-st${sh.step}`, { color: "#ffffff", duration: 0.4 }, sh.t0);
            if (k > 0) tl.to(`#${ch.id}-st${ch.shots[k - 1].step}-on`, { opacity: 0.28, duration: 0.4 }, sh.t0);
          }
        });
        if (ch.steps) {
          tl.fromTo(q(`#${ch.id} .steps > *`), { y: 14, opacity: 0 }, { y: 0, opacity: 1, duration: 0.5, ease: "power3.out", stagger: 0.05 }, s + 0.6);
          tl.to(q(`#${ch.id} .steps`), { opacity: 0, y: 12, duration: 0.4, ease: "power2.in" }, end - 0.4);
        }

        // Canvas board: cards move across columns, then show a done check.
        if (ch.canvas) {
          const cv = ch.canvas;
          cv.cards.forEach((card, idx) => {
            const p0 = card.pos[0];
            tl.fromTo(`#${card.id}`, { x: p0.x, y: p0.y + 16, opacity: 0 }, { x: p0.x, y: p0.y, opacity: 1, duration: 0.5, ease: "power3.out" }, s + 0.5 + idx * 0.08);
            cv.stepTimes.forEach((at, step) => {
              const p = card.pos[step + 1];
              const prev = card.pos[step];
              if (p.x !== prev.x || p.y !== prev.y) {
                tl.to(`#${card.id}`, { x: p.x, y: p.y, duration: 0.7, ease: "power3.inOut" }, at);
              }
              if (p.col === card.done && prev.col !== card.done) {
                tl.fromTo(`#${card.id}-done`, { opacity: 0, scale: 0.5 }, { opacity: 1, scale: 1, duration: 0.4, ease: "power3.out" }, at + 0.6);
              }
            });
            if (p0.col === card.done) tl.set(`#${card.id}-done`, { opacity: 1 }, s + 0.5);
          });
        }
      }
    }

    // ---------- Control ----------
    {
      const s = T.control.start;
      riseWords(tl, $("ctl-l1"), s + 0.3, { stagger: 0.06 });
      riseWords(tl, $("ctl-l2"), s + 0.85, { stagger: 0.08, fromWidth: 125, duration: 1.0 });
      tl.fromTo(q("#ctl-steps .ctl-step"), { y: 34, opacity: 0 }, { y: 0, opacity: 1, duration: 0.7, ease: "expo.out", stagger: 0.09 }, s + 1.45);
      tl.fromTo("#ctl-line-fill", { scaleX: 0 }, { scaleX: 1, duration: 2.3, ease: "none" }, s + 1.95);
      q("#ctl-steps .ctl-step").forEach((el, k) => {
        const at = s + 2.0 + k * 0.72;
        tl.to(`#ctl${k}-on`, { opacity: 1, duration: 0.35, ease: "sine.out" }, at);
        tl.to(q(".ctl-ic", el), { color: "#ffffff", duration: 0.35 }, at);
        tl.fromTo(`#ctl${k}-ok`, { opacity: 0, scale: 0.5 }, { opacity: 1, scale: 1, duration: 0.4, ease: "power3.out" }, at + 0.1);
      });
      tl.to([q(".ctl-lines")[0], $("ctl-steps")], { y: -30, opacity: 0, filter: "blur(8px)", duration: 0.45, ease: "power2.in", stagger: 0.05 }, s + T.control.dur - 0.5);
    }

    // ---------- End ----------
    {
      const s = T.end.start;
      tl.fromTo("#a3", { opacity: 0.8, scale: 1.1 }, { opacity: 1, scale: 1.35, duration: 1.6, ease: "sine.inOut" }, Math.max(s, 50));
      tl.fromTo("#end-icon", { scale: 0.7, opacity: 0, y: 24 }, { scale: 1, opacity: 1, y: 0, duration: 1.0, ease: "expo.out" }, s + 0.15);
      tl.fromTo("#end-ring", { scale: 1, opacity: 0.9 }, { scale: 1.6, opacity: 0, duration: 1.3, ease: "power2.out" }, s + 0.55);
      riseWords(tl, q("#s-end .end-title")[0], s + 0.5, { stagger: 0.06, fromWidth: 122 });
      tl.fromTo(q("#s-end .end-badges .pill"), { y: 22, opacity: 0 }, { y: 0, opacity: 1, duration: 0.55, ease: "power3.out", stagger: 0.09 }, s + 1.45);
      tl.fromTo("#end-gh", { opacity: 0, x: -14 }, { opacity: 1, x: 0, duration: 0.5, ease: "power3.out" }, s + 2.1);
      tl.fromTo(q("#end-url .url-text span"), { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.28, ease: "power2.out", stagger: 0.022 }, s + 2.2);
      tl.fromTo("#url-underline", { scaleX: 0 }, { scaleX: 1, duration: 0.8, ease: "power3.inOut" }, s + 2.25 + P.urlChars * 0.022);
      tl.fromTo("#end-cta", { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 0.6, ease: "power3.out" }, s + 3.6);
      tl.fromTo("#fade-black", { opacity: 0 }, { opacity: 1, duration: 0.7, ease: "sine.in" }, P.total - 0.7);
    }

    return tl;
  }

  document.fonts.ready.then(() => {
    window.__timelines["main"] = build();
  });
})();
