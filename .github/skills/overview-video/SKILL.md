---
name: overview-video
description: Rebuild or update the course overview video (about 98 seconds) for this course in videos/overview. Use when running /overview-video, or when asked to refresh the course overview video, add a chapter or feature to it, retake its dark-mode app screenshots, change its copy or timing, add music, or render a new MP4.
---

# Course Overview Video

The project in `videos/overview` makes a 1920x1080 overview video of about 98 seconds
for the course. It is a HyperFrames project (HTML + GSAP, rendered to MP4).
`video.config.json` controls all of the copy, timing, and screenshots.
`scripts/build.mjs` generates `index.html` from it. Never edit `index.html`
by hand.

Read `videos/overview/README.md` for the file map and scene list, and
`videos/overview/frame.md` for the design system.

## Requirements

- Node.js 22+, ffmpeg and ffprobe, and ImageMagick (`magick`).
- HyperFrames runs with `npx --yes hyperframes@0.8.134`. You do not install it.
- For new screenshots: macOS, the signed-in `demo` persona, and the
  [`github-copilot-app-automation`](../github-copilot-app-automation/SKILL.md)
  skill.

## Workflow

Work from `videos/overview`.

1. **Decide the change.** Read the course `README.md` and the chapter READMEs
   to find what changed (new chapter, renamed feature, new app UI). Keep the
   total near 90–100 s: when you add time in one place, remove it from
   another. Keep
   durations on a 0.5 s grid. Think like a beginner: give each chapter at
   least 5.5 s and each screen at least 3 s, and cut content before you
   shorten them.
2. **Update `video.config.json`.**
   - A chapter needs `num`, `short` (tracklist label), `studio` (the chapter's
     "From the Studio" name), `headline` (two lines of about 17 characters
     or fewer, the second is shown in the gradient), `sub` (one plain line),
     `duration`, and either `shots` or `canvas`.
   - Headlines name the app feature (for example, "Put it on repeat / with
     automations."). Use the studio analogy only in `studio` labels. Do not
     use jargon such as "worktree" or "MCP" without a plain `sub` line.
   - A shot is `{ "src": "<name>", "focus": [left, top, right, bottom] }` in
     1920x1080 screenshot pixels. The camera pushes in to the focus box.
     A focus ring is drawn when the box is small. Use `"ring": false` to hide
     the ring, or `"ring": [l, t, r, b]` to draw it on another box. Use
     `"fallback": "<name>"` when a shot can be missing.
   - Several shots in one chapter share its duration and change by crossfade.
     Use no more than three shots in one chapter. A shot can set its own
     `"duration"`.
   - A shot can play a screen recording: add `"video": "assets/clips/<name>.mp4"`
     (1920x1080, H.264, no audio). `src` is the still that shows when the clip
     is missing. Optional: `"mediaStart"` (seconds to skip) and `"rate"`.
   - `"moves": [{ "at": 1.5, "focus": [l, t, r, b], "dur": 1.2 }]` replaces the
     default push with timed camera moves (`at` is seconds into the shot).
     Use it to follow the action in a video shot.
     Use `steps` with a `step` index on each shot to light a step rail.
   - `float` adds mono pills near the card (for example, mode names). Use it
     only when it helps a beginner read the screen.
3. **Retake screenshots when the app UI changes.** Follow the
   `github-copilot-app-automation` skill with these rules:
   - Run the persona on the laptop screen: export
     `COPILOT_CAPTURE_DISPLAY=builtin` in every command that runs
     `prepare-persona.sh` or `capture-window.sh`.
   - Switch the persona to a dark theme in **Settings > Themes** before you
     capture, and set the original theme again when you finish.
   - Do not add `--callout`, `--box`, `--arrow`, or `--crop`. Video cards must
     be clean.
   - Save to `videos/overview/assets/shots/<name>.png` (the script also
     writes `.webp`). Only the WebP files are committed.
   - Do not set `TMPDIR` to a folder in the repository.
   - Agent-at-work shots (`session-plan`, `session-working`,
     `session-diff-live`, `browser-preview`) need a real session in the
     persona. Get the user's approval before you send a prompt. Use a new
     worktree and Plan mode. Do not push, open a PR, or merge. Archive the
     session when you finish.
   - Find focus boxes from a half-size preview of each shot, then double the
     coordinates.
   - Screen recordings are not sanitized. Hide the sidebar while you record,
     check frames every 0.5 s for names, handles, and paths, and cover any
     that show.
4. **Build and check.**
   ```bash
   npm run check
   ```
   Lint must report 0 errors, and check must pass. The structure warnings
   (`nested_structure_needs_subcomposition`, `timeline_track_too_dense`) are
   expected for this generated, single-file composition. If
   `composition_heavy_overlay_count_high` shows, remove blur, radial-gradient,
   or clip-path elements until it goes away. Otherwise, the render can show
   black frames.
5. **Inspect frames.**
   ```bash
   npm run snapshot
   ```
   Open `snapshots/contact-sheet-*.jpg`. Check every headline at its settled
   time with `--zoom "#<id> .ch-head"` (and the hook, studio, lockup, and end
   titles): no letter may be cut off at the edges or below the baseline
   (`?`, `g`, `s`, and `y` are the usual problems). Also take snapshots 0.1 s before and
   0.2 s after each cut that you changed (`npx --yes hyperframes@0.8.134
   snapshot --no-end --at ...`). Look for tight word spacing, text that
   overflows, empty frames, and cluttered card crossovers.
6. **Preview, then render.** Run `npm run dev` for Studio. Render only after
   the user approves:
   ```bash
   npm run render                                   # renders/video.mp4
   npm run music -- path/to/track.mp3 --start 8     # renders/video-with-music.mp4
   ```
7. **Music.** When a track is longer than the video, find its tempo and
   beat phase and its big hits and quiet parts (for example, with numpy
   on a mono decode). Then set `music.segments` so beats land on the 0.5 s
   cut grid and the big hits land on key cuts: the reveal, Chapter 07, and the
   end card. Make each edit on a downbeat in a section of similar loudness.
   Check the result: the level change at each edit should be within normal
   beat-to-beat change, and the loudness about -14 LUFS.
8. **Export.** Run `npm run export` to replace the committed web copy at
   `videos/copilot-app-for-beginners-overview.mp4`. Keep it under 50 MB
   (GitHub warns above that; the repo does not use Git LFS).
9. **Report** the MP4 paths, the final duration, and any shot that used a
   fallback (`build.mjs` prints a warning for each).

## Rules

- Keep every visual in the video's own dark style. Do not drop in the
  course's cartoon illustrations; they look out of place.
- Keep the copy short and true to the course. Do not claim features that the
  chapters do not teach.
- Keep motion professional: no `back`, `elastic`, or bounce eases, and no
  infinite loops.
- Keep timing deterministic: no `Math.random`, clocks, or network data at
  render time (the build uses a seeded random generator).
- Screenshots must come from the sanitized persona. Before you commit, check
  each one for private names, paths, or tokens.
- `renders/` and `snapshots/` are not committed.
