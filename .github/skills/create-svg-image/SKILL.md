---
name: create-svg-image
description: Wrap a raster image in an SVG and overlay a numbered red "step" circle for course screenshots. Use when running /create-svg-image, or when asked to add a numbered callout badge to an image (e.g. a red circle with a "1" pointing at a UI control) that must still render on a GitHub README.
---

# Create SVG Image (Numbered Step Badge)

Use this skill to take a screenshot or image and produce an **SVG** that shows the
image with a **numbered red circle** placed on top of it. This is for adding
"step 1 / step 2" call-out badges that point at a specific UI control in a course
screenshot.

The caller always provides three things:

1. **The image to use** — a `.webp`, `.png`, or `.jpg` file in the repo.
2. **The location of the numbered circle** — where on the image the circle goes,
   in the image's native pixel coordinates (X from the left, Y from the top).
3. **The number to apply** — the digit/short text shown inside the circle.

Optional inputs: circle `--radius`, fill `--color`, `--text-color`, and `--out`
path.

## Why This Produces an SVG (Not Inline HTML or a Plain Image Edit)

GitHub renders an SVG referenced from Markdown (`![](file.svg)`) inside a
**sandboxed `<img>`**. In that mode GitHub:

- **strips inline `<svg>`** from README HTML, so you cannot paste raw `<svg>`
  markup into the Markdown, and
- **refuses to fetch an external/relative** `<image href="photo.webp">`, so an SVG
  that merely points at the raster shows a blank photo.

The reliable approach is therefore an SVG file that **embeds the raster as a
`data:` base64 URI** and draws the `<circle>` + `<text>` on top. The photo renders
on GitHub and the badge stays editable as plain SVG markup. (Baking the number
into the PNG/webp with an image editor also works, but then the number is no
longer editable text — prefer the SVG.)

## Helper Script

[`sample_codes/create-svg-badge.sh`](sample_codes/create-svg-badge.sh) does the
whole job: detects the image size and mime type, base64-encodes the raster, writes
the SVG, validates it with `xmllint`, and renders a PNG preview you can view to
confirm placement.

```bash
# Required: --image, --x, --y, --number
bash .github/skills/create-svg-image/sample_codes/create-svg-badge.sh \
  --image 02-sessions-worktrees-context/assets/app-create-from-icon.webp \
  --x 710 --y 72 --number 1
# -> writes assets/app-create-from-icon-step1.svg and prints a PREVIEW png path
```

Useful options: `--radius` (defaults to ~2.5% of the image width so badges stay a
consistent on-screen size, see below), `--color "#d1242f"` (GitHub danger red),
`--out PATH`, `--grid` (coordinate finder, below), `--no-preview`.

## Workflow

1. **Find the circle coordinates** if the caller gave an approximate spot ("left of
   the Create from icon") rather than exact pixels. Run the script in `--grid`
   mode, which overlays a labeled coordinate grid on the image and renders a
   preview **without writing anything to the repo**:

   ```bash
   bash .github/skills/create-svg-image/sample_codes/create-svg-badge.sh \
     --image <path> --number 1 --grid
   ```

   View the printed `GRID_PREVIEW` PNG, read the green (X) and magenta (Y) labels
   to pick the target pixel, then continue. Coordinates are in the image's native
   pixel space (the SVG `viewBox` equals the image's pixel dimensions).

2. **Generate the badged SVG** with the chosen `--x`, `--y`, and `--number`:

   ```bash
   bash .github/skills/create-svg-image/sample_codes/create-svg-badge.sh \
     --image <path> --x <N> --y <N> --number <N>
   ```

3. **Verify by viewing the preview.** Open the printed `PREVIEW` PNG with the image
   view tool and confirm the circle sits where the caller wanted. Note: macOS
   `qlmanage` pads the preview to a square canvas — only the top strip (the image's
   real height) is the actual image; the white area below is padding, not output.

4. **Adjust if needed.** Nudge by re-running with new values: smaller `--x` moves
   the circle left, larger `--x` right; `--y` moves it up/down; `--radius` resizes
   it (the font scales automatically). Iterate until the placement is right.

5. **Wire it into the chapter** (only when the caller asks for the README change):
   reference the new `.svg` instead of the original raster, keeping descriptive alt
   text:

   ```markdown
   ![Create from branch](assets/app-create-from-icon-step1.svg)
   ```

## Conventions

- Default output lives **next to the source image** as
  `<stem>-step<number>.svg`, matching this repo's per-chapter `assets/` layout.
- Keep the **original raster** in the repo as the editable source; it stays the
  input even though the README now points at the `.svg`.
- Default badge style: solid GitHub danger red `#d1242f`, white number, thin white
  outline so it reads on light or dark screenshots.
- **Keep the badge diameter consistent across every generated SVG.** The radius
  defaults to **~2.5% of the image width** (the white outline and number scale with
  it). Because GitHub scales each screenshot to the README column width, this makes
  every badge render at the same apparent size regardless of the capture's
  resolution. This is why a `radius 24` badge on a 936px-wide capture and a
  `radius 56` badge on a 2240px-wide capture look identical. Only pass `--radius`
  for a deliberate one-off; otherwise let the default keep things uniform.
- One circle per file matches the required inputs (image + one location + one
  number). For a multi-step figure, either generate separate `-step1`, `-step2`
  files or hand-add extra `<circle>`/`<text>` pairs to the SVG.

## Safety and Notes

- Renders previews to a temp dir (`$TMPDIR/create-svg-badge`), never into the repo.
- `--grid` writes nothing to the repo; it is purely a coordinate-finding preview.
- Screenshots may contain account names, private repo names, or paths — describe
  the UI generically and don't surface private data when reporting placement.
- Only edit a chapter README to swap in the `.svg` when the user asks; generating
  the asset and changing the Markdown are separate steps.

## Related Skills

- **comic-strip-site** — builds a full webcomic-style site by wrapping
  AI-generated character panels in inline SVG (comic frame, tailed speech
  bubbles, terminal command bar). Shares this skill's SVG-over-raster technique
  and the `--grid` coordinate-finding workflow, but for storytelling panels and
  recurring cartoon characters rather than single numbered step badges.
