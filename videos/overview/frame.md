# frame.md: course overview video design system

The look is a dark, cinematic control room that matches the GitHub Copilot app
in dark mode. Motion is smooth and confident, with no bounce.

## Color

| Token | Value | Use |
|---|---|---|
| `--bg` | `#05060A` | Canvas |
| `--app` | `#0E1116` | Screenshot card fill (matches the app background) |
| `--ink` | `#F2F5FA` | Primary text |
| `--muted` | `#8B95A7` | Labels, secondary text |
| `--g1` → `--g2` → `--g3` | `#D2A8FF` → `#8F7BFF` → `#4FA3FF` | Copilot gradient for key words, underlines, active states |
| `--green` | `#3FB950` | Done checks only |

Background: violet and blue aurora fields, a faint dot grid, slow particles,
moving film grain, and a vignette.

## Type

- Display and body: **Mona Sans** variable (`assets/fonts/MonaSansVF.woff2`).
  Display weight 800–840, tracking −0.035em to −0.04em.
- Labels and timecode: **Mona Sans Mono**, uppercase, tracking 0.08em.
- Signature move: words rise out of a mask while the `wdth` axis settles from
  118–125 to 100.

## Components

- **Screenshot card**: 18px radius, 1px light border, deep shadow plus a violet
  glow. Fades in with a small 3D settle (`rotateY −12° → −5°`), drifts to −2°,
  and fades out. Each screen holds at full view (1.3 s) before the camera push.
  Several screens in one chapter change by crossfade, not by swipe.
- **Focus ring**: violet border with glow, drawn on the control the chapter is
  about, after the camera push.
- **Floating pills**: mono text, near the top-right corner of the card.
- **Studio scene**: a glass "live room" holds the agent tiles; a dark mixing
  console with one channel strip per session mode (fader, meter, knobs) and a
  waveform screen. Agent progress bars move like level meters.
- **Course tracklist**: DAW-style track bar with waveform segments for each
  chapter, a playhead, and a timecode. The Studio scene and the
  "8 tracks. 1 course." intro explain it before the chapters start.

## Motion

- Eases: `expo.out` for entrances, `power2.in` for exits, `power2.inOut` for
  camera pushes, `sine.inOut` for drift. No `back` or `elastic` eases.
- Light sweep at each major scene change.
- Cuts sit on a 0.5 s grid, so a 120 BPM track lines up with them.
