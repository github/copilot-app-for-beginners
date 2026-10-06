---
workflow: product-launch-video
flow: automation
storyboard: no
message: "Learn to direct AI coding agents from one desktop app. Free, hands-on, open source."
destination: youtube
aspect: 1920x1080
language: en
length: 98.5s
angle: feature-cascade
audience: Developers and students who are new to agentic development
---

## Intent

An overview video of about 98 seconds for the free course **GitHub Copilot app for Beginners**.
It shows real app screenshots, what learners do in each chapter, and the key
reasons to start. The feel is "wow" but professional: cinematic, confident, and
smooth. It is less bouncy than the reference video
(<https://x.com/JamesMontemagno/status/2106894755900834195>).

## Assets

- assets/shots/*.png — clean, dark-mode screenshots of the GitHub Copilot app,
  captured from the sanitized `demo` persona with the
  `github-copilot-app-automation` skill (no tutorial callouts).
- assets/fonts/ — Mona Sans and Mona Sans Mono (GitHub, SIL OFL 1.1).
- assets/icons/ — Primer Octicons (GitHub, MIT).
- Music — supplied by the user later. The video renders without music, and
  `scripts/add-music.mjs` adds the track without a new video render.

## Customizations

- Data-driven: chapter cards, value chips, and the end card come from
  `video.config.json`, so a new chapter or feature needs a config change and a
  rebuild only.
- Hook: "What if you could direct a team of AI agents while staying focused?"
  Agent tiles fly in scattered, then line up and finish their work.
- Recording-studio analogy (the course theme), explained once after the hook.
  The same agents move into a glass live room, and a mixing console with
  Interactive, Plan, and Autopilot channels rises below it. Built in the
  video's own style (no course illustrations, which looked out of place):
  the app is your studio, you are the producer, and AI agents are the band.
  "8 tracks. 1 course." introduces the DAW-style tracklist. Chapter labels show
  the studio name in small text; headlines use plain app terms.
- Beginner pacing: one headline and one plain line per chapter, a hold on each
  screen before the camera moves, and crossfades instead of swipes.
- End on availability (free, open source) and the course URL.

## Notes

- No voice-over. Music only.
- Do not show private data. Screenshots must come from the sanitized persona.
- Reproduce with the repo skill `.github/skills/overview-video/`.
