"""Cloth photos cropped to the cloth alone, with no floor, table or wall round it.

It reads original photos and writes each crop under the same name in --out; it never writes over its input. The crop
is lossless: jpegtran (libjpeg-turbo) cuts the original JPEG's blocks, so nothing is decoded and saved again. Its left
and top edges move inward to the JPEG block grid, so the cut takes a few pixels more, never fewer. No photo is scaled.

Two ways to find the cloth:

- By default, rembg's birefnet-general model masks the cloth; the mask is shrunk by 2% of the photo's short side, so
  loose threads and the soft edge fall outside, and the crop is the largest upright rectangle inside what is left. For a
  photo of a cloth lying on the floor.
- --trim, for a photo already cropped close with a sliver of floor at an edge or corner, where the model cannot tell
  cloth from floor. The cloth's colours are 6 k-means centres (CIELAB) of the photo's centre half. A pixel more than
  TRIM_DISTANCE from all of them, lightness counted at half (a fold's shadow is still cloth, the floor differs in hue),
  is not cloth. The border line with the largest share of such pixels is peeled, one line at a time, until none has
  more than TRIM_SHARE; then TRIM_MARGIN px more come off each side. A photo in TRIM_FIXED gets a fixed trim read
  from its border profiles instead; its comment says why the colour model did not do.

A crop that would keep less than half the photo's short side, or a mask with no cloth in it, is refused.

32 of the 47 photos in test/fixtures/start-cloth/ (the same files kantha.app's home page serves) were made by running
this, in studio/, on the originals in commit 2e9d682 (pip install -r tool/crop_cloth_requirements.txt); the other 15
were already cloth alone:

  mkdir -p /tmp/kf && git archive 2e9d682 test/fixtures/start-cloth | tar -x -C /tmp/kf --strip-components=3
  python3 tool/crop_cloth.py --out test/fixtures/start-cloth /tmp/kf/KF-{35..48}.jpg
  python3 tool/crop_cloth.py --trim --out test/fixtures/start-cloth \\
    /tmp/kf/KF-{3,4,6,7,8,10,12,13,18,19,20,21,23,27,28,31,32,33}.jpg

stdout carries one tab-separated line per photo written: its name, the pixels taken off the left, top, right and
bottom, and its new size. Messages go to stderr. Exit 0 when every photo was written, 1 when any was refused.
"""
import math
import shutil
import subprocess
import sys
from pathlib import Path

import click

SHRINK = 0.02
MIN_KEPT = 0.5
TRIM_DISTANCE, TRIM_SHARE, TRIM_MARGIN, TRIM_LIMIT = 10.0, 0.02, 2, 0.25
# Pixels off (left, top, right, bottom), read from the mean colour of each border's rows and columns, each TRIM_MARGIN
# past the floor. KF-33: floor (red above green) in rows 0-8 at the right, so top 9 + 2; floor from x 208, so right
# 12 + 2; a floor corner in x 0-7 from y 198 down, taken from the left (8 + 2) because 22 rows from the bottom cost more.
# Its bottom edge is cloth across its whole width, so nothing comes off there. KF-6: the colour model's trim (21, 13,
# 17, 14) left a 4-row band at the bottom going from the cloth's red-brown towards the floor's grey-brown (mean RGB
# 108,55,49 to 113,70,63), under its 2% share; so 4 + 2 rows more at the bottom.
TRIM_FIXED = {"KF-33.jpg": (10, 11, 14, 0), "KF-6.jpg": (21, 13, 17, 20)}


class Refused(Exception):
    pass


def largest_rectangle(inside):
    """The largest-area rectangle of True cells, as (left, top, right, bottom); a histogram per row and a stack."""
    import numpy as np

    h, w = inside.shape
    heights = np.zeros(w, dtype=int)
    best, box = 0, None
    for y in range(h):
        heights = np.where(inside[y], heights + 1, 0)
        stack: list[int] = []
        for x in range(w + 1):
            cur = heights[x] if x < w else 0
            while stack and heights[stack[-1]] >= cur:
                top = int(heights[stack.pop()])
                left = stack[-1] + 1 if stack else 0
                if top * (x - left) > best:
                    best, box = top * (x - left), (left, y - top + 1, x, y + 1)
            stack.append(x)
    return box


def mask_box(img, session):
    import numpy as np
    from PIL import ImageFilter
    from rembg import remove

    mask = remove(img, session=session, only_mask=True, post_process_mask=True)
    size = max(3, round(min(img.size) * SHRINK) * 2 + 1)
    inside = np.array(mask.filter(ImageFilter.MinFilter(size))) > 127
    box = largest_rectangle(inside) if inside.any() else None
    if box is None:
        raise Refused("the model found no cloth in it")
    return box


def trim_box(img):
    import numpy as np
    from PIL import ImageFilter
    from scipy.cluster.vq import kmeans2
    from skimage.color import rgb2lab

    lab = rgb2lab(np.asarray(img.filter(ImageFilter.MedianFilter(3)), dtype=float) / 255)
    h, w = lab.shape[:2]
    centre = lab[h // 4:3 * h // 4, w // 4:3 * w // 4].reshape(-1, 3)
    colours, _ = kmeans2(centre, 6, seed=1, minit="++")
    diff = (lab[:, :, None, :] - colours[None, None]) * (0.5, 1, 1)
    off = np.min(np.linalg.norm(diff, axis=3), axis=2) > TRIM_DISTANCE
    l, t, r, b = 0, 0, w, h
    while True:
        lines = {"l": off[t:b, l].mean(), "r": off[t:b, r - 1].mean(), "t": off[t, l:r].mean(), "b": off[b - 1, l:r].mean()}
        side = max(lines, key=lines.get)
        if lines[side] <= TRIM_SHARE:
            break
        l, t, r, b = l + (side == "l"), t + (side == "t"), r - (side == "r"), b - (side == "b")
        if max(l, w - r) > w * TRIM_LIMIT or max(t, h - b) > h * TRIM_LIMIT:
            raise Refused(f"more than {TRIM_LIMIT:.0%} of a side is not cloth; add it to TRIM_FIXED")
    m = TRIM_MARGIN
    return (l + m, t + m, r - m, b - m)


def block_size(img) -> tuple[int, int]:
    """The JPEG's block (iMCU) width and height: 8 px times the largest sampling factor."""
    return 8 * max(c[1] for c in img.layer), 8 * max(c[2] for c in img.layer)


def crop(src: Path, out: Path, trim: bool, session) -> str:
    from PIL import Image

    original = Image.open(src)
    if original.format != "JPEG":
        raise Refused("it is not a JPEG")
    img = original.convert("RGB")
    w, h = img.size
    fixed = TRIM_FIXED.get(src.name) if trim else None
    if fixed:
        box = (fixed[0], fixed[1], w - fixed[2], h - fixed[3])
    else:
        box = trim_box(img) if trim else mask_box(img, session)
    bw, bh = block_size(original)
    l, t = math.ceil(box[0] / bw) * bw, math.ceil(box[1] / bh) * bh
    r, b = box[2], box[3]
    if min(r - l, b - t) < MIN_KEPT * min(w, h):
        raise Refused(f"the crop {r - l}x{b - t} keeps less than {MIN_KEPT:.0%} of its short side ({min(w, h)} px)")
    dst = out / src.name
    subprocess.run(["jpegtran", "-crop", f"{r - l}x{b - t}+{l}+{t}", "-perfect", "-copy", "none", "-optimize",
                    "-outfile", str(dst), str(src)], check=True)
    return f"{src.name}\t{l}\t{t}\t{w - r}\t{h - b}\t{r - l}x{b - t}"


@click.command(context_settings={"help_option_names": ["-h", "--help"]}, epilog="""\b
Examples:
  crop_cloth.py --out cropped photos/KF-35.jpg photos/KF-36.jpg
  crop_cloth.py --trim --out cropped photos/KF-10.jpg""")
@click.option("--trim", is_flag=True, help="Trim slivers of floor off a photo that is already cropped close.")
@click.option("--out", required=True, type=click.Path(file_okay=False, path_type=Path),
              help="Directory the crops are written to, under each photo's own name. Made if missing.")
@click.argument("photos", nargs=-1, required=True, type=click.Path(exists=True, dir_okay=False, path_type=Path))
def main(trim: bool, out: Path, photos: tuple[Path, ...]) -> None:
    """Crop cloth photos (JPEG) to the cloth alone, losslessly, into --out."""
    if shutil.which("jpegtran") is None:
        raise click.ClickException("jpegtran is not installed; it comes with libjpeg-turbo (brew install jpeg-turbo)")
    out.mkdir(parents=True, exist_ok=True)
    clash = [p for p in photos if (out / p.name).resolve() == p.resolve()]
    if clash:
        raise click.UsageError(f"--out would write over {clash[0]}; give a directory that does not hold the originals")
    session = None
    if not trim:
        from rembg import new_session
        session = new_session("birefnet-general")
    refused = 0
    for p in photos:
        try:
            click.echo(crop(p, out, trim, session))
        except Refused as e:
            refused += 1
            click.echo(f"{p}: refused, {e}", err=True)
    if refused:
        sys.exit(1)


if __name__ == "__main__":
    main()
