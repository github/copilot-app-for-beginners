# Course overview video

A 98.5-second, 1920x1080 overview video for **GitHub Copilot app for Beginners**.
It is built with [HyperFrames](https://hyperframes.heygen.com) (HTML + GSAP,
rendered frame by frame to MP4).

To rebuild it, or to update it when the course changes, use the repo skill
[`/overview-video`](../../.github/skills/overview-video/SKILL.md).

## Quick start

From `videos/overview`:

```bash
npm run build      # trim screenshots into assets/frames, then write index.html
npm run check      # build, then HyperFrames lint and check
npm run dev        # build, then open HyperFrames Studio to preview
npm run render     # build, then render renders/video.mp4
npm run music      # add the music in video.config.json to the render
npm run export     # write the committed web copy: ../copilot-app-for-beginners-overview.mp4
```

The finished video is committed at
[`videos/copilot-app-for-beginners-overview.mp4`](../copilot-app-for-beginners-overview.mp4).
`npm run export` makes it from `renders/video-with-music.mp4` (H.264 CRF 20,
about 21 MB, visually the same as the render). Renders are not committed.

You need Node.js 22+, ffmpeg, and ImageMagick (`magick`). HyperFrames runs with
`npx`, so you do not install it.

## Files

| Path | What it is |
|---|---|
| `video.config.json` | **Edit this.** Copy, chapters, durations, screenshots, focus boxes, music |
| `scripts/build.mjs` | Calculates timing and camera moves, then writes `index.html` |
| `scripts/prepare-shots.mjs` | Removes the 2px course border from screenshots → `assets/frames/` |
| `scripts/add-music.mjs` | Adds a music track to the render (trim, fades, −14 LUFS) |
| `src/styles.css`, `src/motion.js` | Look and motion. The build puts them into `index.html` |
| `assets/shots/` | Dark-mode app captures (lossless WebP) from the `demo` persona |
| `assets/clips/` | Screen recordings (MP4, no audio) used as video shots |
| `assets/fonts/`, `assets/icons/` | Mona Sans (SIL OFL 1.1) and Primer Octicons (MIT) |
| `frame.md`, `BRIEF.md` | Design system and creative brief |
| `index.html` | Generated. Do not edit by hand |

## Scenes

| Time | Scene | Content |
|---|---|---|
| 0–7 s | Hook | "What if you could direct a team of AI agents while staying focused?" Agent tiles fly in scattered, then line up in rows and finish their work |
| 7–15.5 s | Studio | "Think of the app as your recording studio." The hook's agents move into a glass live room (the band), and a mixing console with Interactive, Plan, and Autopilot channels rises below it (the producer) |
| 15.5–21.5 s | Reveal | 3D wall of app screens → "All in one desktop app." → "Introducing" the title and hero screen |
| 21.5–26 s | Values | "Free. Hands-on. Open source." and course facts |
| 26–29 s | Tracklist | "8 tracks. 1 course." The tracklist moves down to the bottom of the frame |
| 29–87 s | Chapters | One card for each chapter: studio name, app-feature headline, one plain line, and screens. Chapter 03 shows Plan → a Pick & Polish screen recording → Pull request |
| 87–92 s | Control | "You stay in control." Review the plan, read the diff, run the tests, approve the merge |
| 92–98.5 s | End | Title, badges, and the course URL |

The recording-studio analogy is explained once, in the Studio scene. After
that, each chapter label shows its studio name in small text (for example,
"Track 02 · Recording booths"), and the headline uses plain app terms.

## Music

The video renders without sound. To add music, do one of these:

- Run `npm run music -- <file> --start <seconds>` after `npm run render`. This
  is fast and does not render the video again.
- Set `music.src` (and `music.start`) in `video.config.json`, then run
  `npm run render`.

A track at about 120 BPM lines up with the 0.5 s cut grid. Use `--start` to
skip a quiet intro.

The current track, `assets/music/futuristic-dawn.mp3` (2:23, 120 BPM), is
longer than the video, so `music.segments` edits it on the beat:

- 0:00–1:20 plays the track's opening, delayed 0.128 s so its beats land on
  the video's 0.5 s grid.
- At 1:20 (a downbeat), it crossfades to the track's finale (track 2:03.7).
  The track's 2:05.4 hit lands on the Chapter 07 cut (1:21.5), its four-hit
  drum fill lines up with the four checks, and the final section starts with
  the end card.

`--start` on the command line ignores `segments`.
