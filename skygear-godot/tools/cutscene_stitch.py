"""Cut the nine rendered shots into the opening cinematic, and mix its sound.

    python tools/cutscene_stitch.py                 take 1 -> assets/video/opening.ogv
    python tools/cutscene_stitch.py --take 2
    python tools/cutscene_stitch.py --preview       mp4 beside it, for auditioning

`tools/cutscene_render.py` makes the pictures; this makes the film. Every cut
below is the storyboard's (`docs/cutscene/README.md` §1 and §2), which chose
each transition to hide a specific discontinuity — this file executes that plan
and decides nothing on its own.

THE OUTPUT IS OGG THEORA, and that is not a taste call: Godot's built-in
`VideoStreamPlayer` plays Theora and nothing else. An .mp4 in `assets/` is a
file the engine cannot open. `--preview` writes an h264 copy for looking at,
which is the format every player on this machine actually has.

WHY THE H3 AUDIO IS DROPPED. The storyboard marks it "mute" on six of the nine
shots and "audition" on the other three. Auditioning needs ears; nobody has
listened to these. A generative soundtrack that might contain mumbled speech
under a scene whose whole motive is one recorded line is a risk with no upside,
so the mix here is built from the game's own music, SFX and VO — which is also
what makes the film sound like the thing it is advertising.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FPS = 24

## The storyboard's own table. `frames` must agree with `cutscene_render.SHOTS`;
## `stitch` asserts it rather than trusting it.
SHOTS = [
    (1, 124), (2, 141), (3, 141), (4, 141), (5, 124),
    (6, 141), (7, 124), (8, 141), (9, 124),
]

## The one dissolve in the film. 1 -> 2 hides the change in the ship's rendered
## scale, because shot 2 opens on the same ship much closer; every other join is
## a hard cut placed on an event (a head turn, an impact, a charge, a muzzle
## flash, a steam burst, an eye flare) and a dissolve would soften exactly the
## thing the cut is there to sharpen.
DISSOLVE_AFTER = {1: 12}

TITLE_CARD_S = 4.0

## --- the mix -----------------------------------------------------------------
## Times are seconds from the top of the film, computed from the shot lengths
## rather than typed, so a re-timed shot cannot silently desync the sound.


def shot_start(n: int) -> float:
    """Seconds to the first frame of shot `n`, accounting for the dissolve."""
    t = 0.0
    for num, frames in SHOTS:
        if num == n:
            return t
        t += frames / FPS
        t -= DISSOLVE_AFTER.get(num, 0) / FPS
    raise KeyError(n)


def total_seconds() -> float:
    t = sum(f for _, f in SHOTS) / FPS
    t -= sum(DISSOLVE_AFTER.values()) / FPS
    return t + TITLE_CARD_S


A = "assets/audio"

## (path, start seconds, gain dB, fade-in, fade-out). The music cues are the
## storyboard's: `combat_low` enters with the ship, `combat_high` takes over on
## the hulk's impact, `boss_loop` slams in on the Colossus.
def mix_plan() -> list[tuple[str, float, float, float, float]]:
    return [
        ## The bed, under everything, from frame one.
        (f"{A}/sfx/world/amb_storm.ogg", 0.0, -16.0, 1.5, 2.0),
        (f"{A}/sfx/world/amb_ship.ogg", shot_start(2), -20.0, 2.0, 2.0),
        ## Music.
        (f"{A}/music/combat_low.mp3", shot_start(2), -13.0, 2.5, 1.0),
        (f"{A}/music/combat_high.mp3", shot_start(5), -11.0, 0.6, 1.0),
        (f"{A}/music/boss_loop.mp3", shot_start(8), -9.0, 0.4, 3.0),
        ## The cuts that carry a sound. Each lands ON the frame the storyboard
        ## places it on, which is why these are computed and not eyeballed.
        (f"{A}/sfx/lane/hulk_grapple.ogg", shot_start(5), -4.0, 0.0, 0.2),
        (f"{A}/sfx/enemy/climb.ogg", shot_start(5) + 1.6, -10.0, 0.1, 0.4),
        (f"{A}/sfx/lane/cannon_fire_1.ogg", shot_start(6) + 3.4, -7.0, 0.0, 0.3),
        (f"{A}/sfx/enemy/telegraph.ogg", shot_start(7) + 0.6, -9.0, 0.1, 0.3),
        (f"{A}/sfx/enemy/slam.ogg", shot_start(7) + 2.9, -5.0, 0.0, 0.3),
        (f"{A}/sfx/enemy/boss_roar.ogg", shot_start(8) + 0.3, -5.0, 0.0, 0.5),
        ## THE FILM'S WHOLE MOTIVE, said by the enemy, in a take that already
        ## exists: "GIVE ME THE ENGINE." Nothing here is newly recorded — the
        ## storyboard found the motive in the game's own material rather than
        ## inventing lore, and this is the line it found.
        (f"{A}/voice/boss/arrive_1.ogg", shot_start(8) + 2.2, -1.0, 0.0, 0.2),
        ## The captain's answer, on the reverse.
        (f"{A}/voice/captain/wave_start_1.ogg", shot_start(9) + 2.4, -2.0, 0.0, 0.2),
        (f"{A}/sfx/world/wave_start.ogg", shot_start(9) + 4.4, -6.0, 0.0, 0.4),
    ]


# ---------------------------------------------------------------- ffmpeg

def ffmpeg() -> str:
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    ## No ffmpeg on PATH on this machine; `imageio_ffmpeg` ships a full one
    ## inside its wheel. Same door `tools/demo_encode.py` uses (board SG-239).
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        sys.exit("no ffmpeg, and imageio_ffmpeg is not installed")


def run(args: list[str]) -> None:
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        sys.exit("ffmpeg failed:\n" + p.stderr[-3000:])


def title_card(dst: Path, w: int, h: int) -> None:
    """SKYGEAR in the game's own display face, brass on black."""
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new("RGB", (w, h), (5, 4, 8))
    d = ImageDraw.Draw(im)
    face = ROOT / "assets" / "fonts" / "Oswald.ttf"
    try:
        big = ImageFont.truetype(str(face), int(h * 0.16))
        small = ImageFont.truetype(str(face), int(h * 0.042))
    except OSError:
        big = ImageFont.load_default()
        small = ImageFont.load_default()
    ## `#e8c376` — the same brass `hud.gd` paints the title screen's name in, so
    ## the card and the screen it cuts to are the same object.
    _centre(d, im, "SKYGEAR", big, (0xE8, 0xC3, 0x76), h * 0.42)
    _centre(d, im, "STORM-DUSK", small, (0x37, 0xF0, 0xC8), h * 0.56)
    im.save(dst)


def _centre(d, im, text: str, font, fill, y: float) -> None:
    box = d.textbbox((0, 0), text, font=font)
    d.text(((im.width - (box[2] - box[0])) * 0.5 - box[0], y), text,
           font=font, fill=fill)


def stitch(take: int, preview: bool) -> Path:
    import sys as _s
    _s.path.insert(0, str(ROOT / "tools"))
    import cutscene_render as cr

    src = ROOT / ".shots" / "cutscene" / ("take%d" % take)
    clips = []
    for num, frames in SHOTS:
        if cr.SHOTS[num]["frames"] != frames:
            sys.exit("shot %02d: this file says %d frames, the renderer says %d"
                     % (num, frames, cr.SHOTS[num]["frames"]))
        path = src / ("shot_%02d.mp4" % num)
        if not path.exists():
            sys.exit("missing %s — run tools/cutscene_render.py --all" % path)
        clips.append(path)

    work = ROOT / ".shots" / "cutscene" / "work"
    work.mkdir(parents=True, exist_ok=True)
    card = work / "title_card.png"
    title_card(card, cr.WIDTH, cr.HEIGHT)

    ff = ffmpeg()
    args: list[str] = [ff, "-y", "-loglevel", "error"]
    for c in clips:
        args += ["-i", str(c)]
    args += ["-loop", "1", "-t", str(TITLE_CARD_S), "-i", str(card)]
    for path, *_ in mix_plan():
        full = ROOT / path
        if not full.exists():
            sys.exit("mix: missing %s" % path)
        args += ["-i", str(full)]

    n_video = len(clips) + 1                      ## clips + the title card
    chains: list[str] = []

    ## Every source normalised first: same size, same rate, same pixel format.
    ## `xfade` and `concat` both refuse mismatched inputs, and the title card is
    ## a still being stretched to four seconds.
    for i in range(n_video):
        chains.append(
            "[%d:v]scale=%d:%d,fps=%d,format=yuv420p,setsar=1[v%d]"
            % (i, cr.WIDTH, cr.HEIGHT, FPS, i))

    ## THE ASSEMBLY. `xfade` where the storyboard asks for a dissolve, plain
    ## concatenation everywhere else — a hard cut IS the absence of a filter.
    cur = "v0"
    elapsed = SHOTS[0][1] / FPS
    for idx in range(1, n_video):
        nxt = "v%d" % idx
        prev_shot = SHOTS[idx - 1][0] if idx - 1 < len(SHOTS) else None
        frames = DISSOLVE_AFTER.get(prev_shot, 0) if prev_shot else 0
        out = "x%d" % idx
        if frames:
            dur = frames / FPS
            chains.append("[%s][%s]xfade=transition=fade:duration=%.4f:offset=%.4f[%s]"
                          % (cur, nxt, dur, elapsed - dur, out))
            elapsed += (SHOTS[idx][1] / FPS if idx < len(SHOTS) else TITLE_CARD_S) - dur
        else:
            ## A cut to black before the title card, because shot 9 ends on one.
            chains.append("[%s][%s]concat=n=2:v=1:a=0[%s]" % (cur, nxt, out))
            elapsed += (SHOTS[idx][1] / FPS if idx < len(SHOTS) else TITLE_CARD_S)
        cur = out

    ## THE MIX. Each cue delayed to its own place on the timeline, faded, and
    ## summed. `adelay` wants milliseconds per channel; `apad` keeps a short cue
    ## from ending the stream it is mixed into.
    legs = []
    for j, (path, start, gain, fin, fout) in enumerate(mix_plan()):
        i = n_video + j
        ms = int(round(start * 1000.0))
        leg = "a%d" % j
        f = ("[%d:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,"
             "adelay=%d|%d,volume=%.2fdB" % (i, ms, ms, gain))
        if fin > 0.0:
            f += ",afade=t=in:st=%.3f:d=%.3f" % (start, fin)
        f += ",apad"
        f += "[%s]" % leg
        chains.append(f)
        legs.append("[%s]" % leg)
    total = total_seconds()
    chains.append("%samix=inputs=%d:duration=first:dropout_transition=0:normalize=0,"
                  "atrim=0:%.3f,afade=t=out:st=%.3f:d=1.2,"
                  "alimiter=level_in=1:level_out=0.92[aout]"
                  % ("".join(legs), len(legs), total, total - 1.2))

    out_dir = ROOT / "assets" / "video"
    out_dir.mkdir(parents=True, exist_ok=True)
    dst = (ROOT / ".shots" / "cutscene" / "opening_preview.mp4") if preview \
        else (out_dir / "opening.ogv")

    args += ["-filter_complex", ";".join(chains),
             "-map", "[%s]" % cur, "-map", "[aout]",
             "-t", "%.3f" % total]
    if preview:
        args += ["-c:v", "libx264", "-preset", "medium", "-crf", "20",
                 "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k"]
    else:
        ## Theora, because that is what Godot plays. q:v 8 of 10 holds the
        ## painted brushwork; the whole film is under 60 s so the file size this
        ## buys is worth more than the bitrate it costs.
        args += ["-c:v", "libtheora", "-q:v", "8",
                 "-c:a", "libvorbis", "-q:a", "5"]
    args += [str(dst)]
    run(args)
    return dst


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--take", type=int, default=1)
    ap.add_argument("--preview", action="store_true",
                    help="write an h264 mp4 for auditioning instead of the .ogv")
    a = ap.parse_args()
    dst = stitch(a.take, a.preview)
    print("%s  (%.2f s, %.1f MB)"
          % (dst, total_seconds(), dst.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
