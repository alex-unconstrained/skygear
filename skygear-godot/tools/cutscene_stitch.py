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

## A SHOT THAT HAD TO BE ROLLED AGAIN, AND WHICH TAKE WON.
##
## Shot 3 take 1 put a flat SEA HORIZON under the bow rail. SkyGear is a sky
## game — the ship is miles up and there is no ocean in this world at all — and
## nothing in the prompt had forbidden one, so H3 invented the most obvious
## thing to put under a ship. Take 2 was rolled after a byte-identical world
## rule went into all ten prompts ("NO sea, NO ocean, NO water... any horizon is
## a bank of cloud, never a waterline") and shot 3's own body gained a cloud
## floor; it came back with the storm seen from above, which is what the film
## needed all along.
##
## SHOT 6 WENT THE SAME WAY, and it is the reason the audit method is written
## down in docs/CUTSCENE-PIPELINE.md. The first water check cropped the BOTTOM
## THIRD of ONE frame per shot; shot 6's sea is a breaking wave on the LEFT at
## mid-height that does not appear until about frame 40, so that crop could not
## have found it — the owner did. Re-audited at three full frames per shot
## across all nine: 3 and 6 were the only two.
##
## Shot 6 needed more than the world rule. Its body now states positively what
## is beyond the rails ("thousands of feet up... only violet storm cloud and
## open sky"), because a negative alone did not stop the model reaching for the
## most obvious thing to put beside a ship.
##
## AN OVERRIDE RATHER THAN AN OVERWRITE. Copying take 2 over take 1 would erase
## the evidence of what was wrong and why, and the next person to re-roll a shot
## would have no example of how. One line per rolled shot, and the reason above.
TAKE_OVERRIDE = {3: 2, 6: 2}

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


class Cue:
    """One sound on the timeline, with a START **and an END**.

    THE END IS THE WHOLE POINT, and its absence was the bug the owner heard.
    The first version of this file carried a `fade_out` in every row and never
    applied it — the value was unpacked from the tuple and then simply not used
    — so nothing in the mix ever stopped. `combat_low` entered at 4.7 s,
    `combat_high` at 22.3 and `boss_loop` at 38.5, and from 38.5 to the end of
    the film **all three fight tracks were playing at once**, over two ambience
    beds. That is exactly "music seems to play overlapping", and it was not a
    balance problem: it was three songs.

    A cue now owns a window. The source is trimmed to that window, faded at both
    ends of it, and only then delayed into place — so a track that must stop
    stops, and two tracks can only overlap where a crossfade says they may.
    """

    def __init__(self, path: str, start: float, end: float, gain: float,
                 fade_in: float = 0.0, fade_out: float = 0.0, why: str = ""):
        if end <= start:
            sys.exit("cue %s ends (%.2f) before it starts (%.2f)"
                     % (path, end, start))
        self.path, self.start, self.end = path, start, end
        self.gain, self.fade_in, self.fade_out = gain, fade_in, fade_out
        self.why = why

    @property
    def dur(self) -> float:
        return self.end - self.start

    def is_music(self) -> bool:
        return "/music/" in self.path


def one_shot(path: str, at: float, gain: float, why: str = "",
             tail: float = 6.0) -> Cue:
    """A cue that simply plays out. `tail` is a ceiling, not a length — the
    source ends when it ends; this only stops a stray file running for ever."""
    return Cue(path, at, at + tail, gain, 0.0, 0.0, why)


## THE MIX, and every time in it is COMPUTED from `shot_start()` rather than
## typed, so a re-timed shot cannot silently desync its own sound.
def mix_plan() -> list[Cue]:
    end = total_seconds()
    return [
        ## --- the beds -------------------------------------------------------
        ## Under everything, the whole way. They are the only cues that are
        ## allowed to run the length of the film, because they are the room.
        Cue(f"{A}/sfx/world/amb_storm.ogg", 0.0, end, -16.0, 1.5, 2.0,
            "the storm, from frame one"),
        Cue(f"{A}/sfx/world/amb_ship.ogg", shot_start(2), end, -20.0, 2.0, 2.0,
            "the ship arrives under it"),

        ## --- music: one track at a time, joined by named crossfades ----------
        ## `combat_low` carries the three quiet shots and hands over ON the
        ## hulk's impact; `combat_high` carries the fight and hands over ON the
        ## Colossus. Each hand-over is a 0.8 s overlap and nothing else in the
        ## film has two tracks in it.
        Cue(f"{A}/music/combat_low.mp3", shot_start(2), shot_start(5) + 0.8,
            -13.0, 2.5, 0.8, "enters with the ship, out on the hulk"),
        Cue(f"{A}/music/combat_high.mp3", shot_start(5), shot_start(8) + 0.8,
            -11.0, 0.6, 0.8, "the fight, out on the Colossus"),
        Cue(f"{A}/music/boss_loop.mp3", shot_start(8), end, -9.0, 0.4, 2.5,
            "slams in on the giant and rings out under the card"),

        ## --- 2 · THE SHIP ---------------------------------------------------
        one_shot(f"{A}/sfx/lane/crossing.ogg", shot_start(2) + 0.4, -24.0,
                 "the camera's glide along her flank, felt not heard"),

        ## --- 4 · THE BOILER -------------------------------------------------
        ## "steam sighing from a valve" is the storyboard's own phrase, and
        ## `player/vent.ogg` IS that sound — the captain's vent is a pressure
        ## release. Reused here at a level where it reads as machinery.
        one_shot(f"{A}/sfx/player/vent.ogg", shot_start(4) + 1.1, -20.0,
                 "the Boiler breathes"),
        one_shot(f"{A}/sfx/lane/crew_attack_1.ogg", shot_start(4) + 2.6, -22.0,
                 "the crewman's shovel"),
        one_shot(f"{A}/sfx/player/vent.ogg", shot_start(4) + 4.3, -22.0,
                 "and again, slower — a pulse, like the grate"),
        ## THE STAKES, SAID BY THE PERSON THEY BELONG TO (SG-247).
        ## The storyboard's rule — "the captain is not a narrator" — is right
        ## for the opening three shots and left shot 4, the WHY of the whole
        ## film, silent. The only statement of motive in the cut was the
        ## ENEMY'S, at 41 s, which is very late in a 53 s film. One line, on
        ## the shot that is about the thing it names. Newly recorded in the
        ## cast's pinned captain voice (`tools/vo_line.py`).
        Cue(f"{A}/voice/captain/cine_boiler_1.ogg", shot_start(4) + 1.8,
            shot_start(4) + 3.5, -1.0, 0.0, 0.15,
            "VO: She's the only thing holding us up."),

        ## --- 5 · THE HULK · the loudest cut in the film ----------------------
        one_shot(f"{A}/sfx/lane/hulk_grapple.ogg", shot_start(5), -3.0,
                 "frame one IS the impact — the storyboard cuts on it"),
        one_shot(f"{A}/sfx/lane/hulk_break.ogg", shot_start(5) + 1.1, -6.0,
                 "the plates hinge open on the red core"),
        one_shot(f"{A}/sfx/enemy/climb.ogg", shot_start(5) + 2.0, -9.0,
                 "the first of them over the gunwale"),
        one_shot(f"{A}/sfx/enemy/climb.ogg", shot_start(5) + 2.9, -11.0,
                 "and the rest"),
        one_shot(f"{A}/sfx/lane/crossing.ogg", shot_start(5) + 3.6, -12.0,
                 "the surge toward camera"),
        ## VO 1 of 5. "They're over the rail." — first_board take 1 speaks the
        ## brief's first line; `gen_voice` picks `lines[i]` for take i+1.
        Cue(f"{A}/voice/captain/first_board_1.ogg", shot_start(5) + 2.3,
            shot_start(5) + 4.5, -1.0, 0.0, 0.15, "VO: They're over the rail."),

        ## --- 6 · THE FIGHT --------------------------------------------------
        one_shot(f"{A}/sfx/player/shape_cleave.ogg", shot_start(6) + 0.15, -6.0,
                 "the arc opens the shot"),
        one_shot(f"{A}/sfx/player/hit_1.ogg", shot_start(6) + 0.55, -8.0,
                 "first automaton"),
        one_shot(f"{A}/sfx/player/hit_3.ogg", shot_start(6) + 0.85, -8.0,
                 "second, on the same swing"),
        one_shot(f"{A}/sfx/player/elem_ember.ogg", shot_start(6) + 0.6, -16.0,
                 "the blade is ember — the element rides on top, quietly"),
        one_shot(f"{A}/sfx/enemy/death_light_1.ogg", shot_start(6) + 1.2, -9.0,
                 "one comes apart"),
        one_shot(f"{A}/sfx/lane/crew_attack_2.ogg", shot_start(6) + 2.4, -14.0,
                 "the crew charging up the lane behind him"),
        ## VO 2 of 5. "With you, Captain!" — muster take 2.
        Cue(f"{A}/voice/crew/muster_2.ogg", shot_start(6) + 1.9,
            shot_start(6) + 3.7, -2.0, 0.0, 0.15, "VO: With you, Captain!"),
        one_shot(f"{A}/sfx/lane/cannon_fire_1.ogg", shot_start(6) + 3.45, -5.0,
                 "the muzzle flash the shot cuts on"),
        one_shot(f"{A}/sfx/player/crit_2.ogg", shot_start(6) + 4.3, -9.0,
                 "the wave breaking against him"),
        one_shot(f"{A}/sfx/enemy/death_light_3.ogg", shot_start(6) + 4.9, -11.0,
                 "and another"),

        ## --- 7 · THE HEAVY --------------------------------------------------
        one_shot(f"{A}/sfx/enemy/telegraph.ogg", shot_start(7) + 0.5, -7.0,
                 "the axe winds up — the game's own tell, in the film"),
        one_shot(f"{A}/sfx/player/dash.ogg", shot_start(7) + 2.1, -6.0,
                 "he goes under it"),
        ## VO 3 of 5, and the only wordless one: a dash grunt. The brief records
        ## that these are effort, not speech, so it does not read as a line.
        Cue(f"{A}/voice/captain/dash_effort_2.ogg", shot_start(7) + 2.15,
            shot_start(7) + 2.9, -6.0, 0.0, 0.1, "VO: the effort of the dash"),
        one_shot(f"{A}/sfx/enemy/slam.ogg", shot_start(7) + 2.75, -3.0,
                 "the axe into the planking where he was"),
        one_shot(f"{A}/sfx/player/vent.ogg", shot_start(7) + 3.0, -10.0,
                 "the steam burst the cut hides inside"),

        ## --- 8 · THE COLOSSUS -----------------------------------------------
        one_shot(f"{A}/sfx/enemy/boss_roar.ogg", shot_start(8) + 0.25, -4.0,
                 "as it crests the bow"),
        one_shot(f"{A}/sfx/enemy/slam.ogg", shot_start(8) + 2.0, -4.0,
                 "the anchor-clawed foot plants on the deck"),
        one_shot(f"{A}/sfx/world/boiler_hurt.ogg", shot_start(8) + 2.2, -14.0,
                 "everything on the ship shudders with it"),
        ## VO 4 of 5, and the reason the film exists. `arrive_2`, NOT `arrive_1`
        ## — the brief lists "YOUR DECK IS SCRAP." first and "GIVE ME THE
        ## ENGINE." second, and take N speaks line N. The shipped mix used
        ## take 1 and therefore said the wrong sentence.
        Cue(f"{A}/voice/boss/arrive_2.ogg", shot_start(8) + 3.2,
            shot_start(8) + 5.8, 0.0, 0.0, 0.2, "VO: GIVE ME THE ENGINE."),

        ## --- 9 · THE STAND --------------------------------------------------
        ## THE ANSWER, ACROSS THE CUT (SG-247). The Colossus demands the engine
        ## at 41.7 s and the film used to reply "Hold the deck." — which is a
        ## fine order and is not a REPLY. This is: the demand lands on shot 8,
        ## the refusal opens shot 9, and only then does he give the order. Three
        ## beats where there were two, and the middle one is newly recorded.
        Cue(f"{A}/voice/captain/cine_answer_1.ogg", shot_start(9) + 0.5,
            shot_start(9) + 1.8, -1.0, 0.0, 0.12,
            "VO: Then come and take her."),
        one_shot(f"{A}/sfx/player/ready.ogg", shot_start(9) + 2.0, -9.0,
                 "the cutlass comes up on the refusal"),
        ## ...and the order, which is the game's own line for the start of a
        ## wave — so the film ends on the sentence the player will hear again.
        Cue(f"{A}/voice/captain/wave_start_3.ogg", shot_start(9) + 3.3,
            shot_start(9) + 4.3, -1.0, 0.0, 0.12, "VO: Hold the deck."),
        one_shot(f"{A}/sfx/world/wave_start.ogg", shot_start(9) + 4.5, -7.0,
                 "and the cut to black"),
    ]


## The longest two music tracks may sound together — a hand-over, not a pile-up.
MAX_CROSSFADE = 1.2

## Measured, not chosen — see the master chain in `stitch()`.
MASTER_GAIN_DB = 6.0


def assert_mix_sane(plan: list[Cue]) -> None:
    """Refuse to encode a mix that would sound wrong, before spending 4 minutes.

    THE OWNER HAD TO HEAR THIS BUG, which means nothing in the pipeline was
    looking. Three fight tracks played simultaneously for the last fifteen
    seconds of the film and every automated step passed: the ffmpeg exited 0, the
    file was the right length, the picture was correct. Sound has no containment
    audit and no harness — so it gets this instead, and it runs before the
    encode rather than after.

    Two teeth, both from real failures:
      * NO TWO MUSIC TRACKS OVERLAP by more than a declared crossfade. This is
        the exact defect.
      * NOTHING RUNS PAST THE FILM. A cue starting after the last frame is a cue
        nobody will ever hear, which is how a cue sheet rots silently while
        looking complete.
    """
    end = total_seconds()
    music = sorted([c for c in plan if c.is_music()], key=lambda c: c.start)
    for a, b in zip(music, music[1:]):
        overlap = a.end - b.start
        if overlap > MAX_CROSSFADE + 1e-6:
            sys.exit(
                "MIX: %s and %s play together for %.2fs — that is a pile-up, not "
                "a crossfade (ceiling %.2fs).\n  %s runs %.2f-%.2f\n  %s runs "
                "%.2f-%.2f" % (Path(a.path).name, Path(b.path).name, overlap,
                               MAX_CROSSFADE, Path(a.path).name, a.start, a.end,
                               Path(b.path).name, b.start, b.end))
    late = [c for c in plan if c.start >= end - 0.05]
    if late:
        sys.exit("MIX: %d cue(s) start at or after the last frame (%.2fs): %s"
                 % (len(late), end, ", ".join(Path(c.path).name for c in late)))

    voice = sorted([c for c in plan if "/voice/" in c.path], key=lambda c: c.start)
    for a, b in zip(voice, voice[1:]):
        if b.start < a.start + 1.4:
            sys.exit("MIX: two spoken lines %.2fs apart (%s then %s) — they will "
                     "talk over each other" % (b.start - a.start,
                                               Path(a.path).name, Path(b.path).name))


def describe_mix() -> str:
    """The mix as a readable timeline, so it can be checked without listening."""
    rows = []
    for c in sorted(mix_plan(), key=lambda c: c.start):
        kind = "MUSIC" if c.is_music() else (
            "VOICE" if "/voice/" in c.path else "sfx")
        rows.append("%5.2f-%5.2f  %-5s %-34s %+6.1fdB  %s"
                    % (c.start, c.end, kind, Path(c.path).name, c.gain, c.why))
    return "\n".join(rows)


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
    ## `#e8c376` and `#37f0c8` — the same brass and teal `hud.gd` paints the
    ## title screen's two lines in, so the card and the screen it cuts to are
    ## the same object.
    ##
    ## STACKED FROM MEASURED HEIGHTS, not from two fractions of the canvas. The
    ## first version placed them at 0.42h and 0.56h, and at a display size of
    ## 0.16h the name is 0.16 tall — so STORM-DUSK was printed through the
    ## bottom of SKYGEAR. The same class of bug as SG-161, in a different file,
    ## caught the same way: by looking at it.
    gap = h * 0.035
    name_h = _height(d, "SKYGEAR", big)
    sub_h = _height(d, "STORM-DUSK", small)
    top = (h - (name_h + gap + sub_h)) * 0.5
    _centre(d, im, "SKYGEAR", big, (0xE8, 0xC3, 0x76), top)
    _centre(d, im, "STORM-DUSK", small, (0x37, 0xF0, 0xC8), top + name_h + gap)
    im.save(dst)


def _height(d, text: str, font) -> float:
    box = d.textbbox((0, 0), text, font=font)
    return box[3] - box[1]


def _centre(d, im, text: str, font, fill, y: float) -> None:
    box = d.textbbox((0, 0), text, font=font)
    d.text(((im.width - (box[2] - box[0])) * 0.5 - box[0], y - box[1]), text,
           font=font, fill=fill)


def stitch(take: int, preview: bool) -> Path:
    import sys as _s
    _s.path.insert(0, str(ROOT / "tools"))
    import cutscene_render as cr

    base = ROOT / ".shots" / "cutscene"
    clips = []
    for num, frames in SHOTS:
        if cr.SHOTS[num]["frames"] != frames:
            sys.exit("shot %02d: this file says %d frames, the renderer says %d"
                     % (num, frames, cr.SHOTS[num]["frames"]))
        from_take = TAKE_OVERRIDE.get(num, take)
        path = base / ("take%d" % from_take) / ("shot_%02d.mp4" % num)
        if not path.exists():
            sys.exit("missing %s — run tools/cutscene_render.py --shot %d%s"
                     % (path, num, "" if from_take == take
                        else " --take %d" % from_take))
        if from_take != take:
            print("shot %02d from take %d (override)" % (num, from_take))
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
    plan = mix_plan()
    assert_mix_sane(plan)
    for cue in plan:
        full = ROOT / cue.path
        if not full.exists():
            ## A missing cue is silent, and silence is indistinguishable from a
            ## cue nobody asked for — the exact failure that hid card_hover.ogg
            ## for the life of the port (board SG-212). Loud, here.
            sys.exit("mix: missing %s" % cue.path)
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

    ## THE MIX. One leg per cue, and the ORDER OF THE FILTERS IS THE FIX.
    ##
    ##   atrim + asetpts  clip the source to the cue's own window and rebase its
    ##                    timestamps to zero, so every time below is relative to
    ##                    the CUE rather than to the film. The old version faded
    ##                    in at an absolute film time on an undelayed stream,
    ##                    which is why `st=` was already suspect even before the
    ##                    fade-out went missing entirely.
    ##   afade in/out     both, always. The out is placed from the END of the
    ##                    window — this is the line whose absence let three
    ##                    music tracks stack on top of each other.
    ##   volume           after the fades, so a fade is a fade of the mixed level.
    ##   adelay           and only NOW into place on the timeline. Milliseconds,
    ##                    one value per channel.
    ##   apad             so a short cue does not shorten the sum.
    ##
    ## `duration=first` on the amix then takes its length from leg zero, which is
    ## `amb_storm` running the whole film — chosen deliberately as the first cue
    ## for exactly that reason.
    legs = []
    for j, cue in enumerate(mix_plan()):
        i = n_video + j
        ms = int(round(cue.start * 1000.0))
        leg = "a%d" % j
        f = ("[%d:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,"
             "atrim=0:%.3f,asetpts=PTS-STARTPTS" % (i, cue.dur))
        if cue.fade_in > 0.0:
            f += ",afade=t=in:st=0:d=%.3f" % cue.fade_in
        if cue.fade_out > 0.0:
            f += ",afade=t=out:st=%.3f:d=%.3f" % (
                max(0.0, cue.dur - cue.fade_out), cue.fade_out)
        f += ",volume=%.2fdB,adelay=%d|%d,apad[%s]" % (cue.gain, ms, ms, leg)
        chains.append(f)
        legs.append("[%s]" % leg)
    total = total_seconds()
    ## THE MASTER, AND WHY THERE IS A FIXED GAIN ON IT.
    ##
    ## Measured on the first correct mix: integrated **-25.9 LUFS**, true peak
    ## -7.8 dBFS. That is far too quiet for something that plays the instant the
    ## game opens — a player who has to reach for the volume dial during the
    ## title sequence has already been taken out of it. `+6 dB` lands it near
    ## -20 LUFS with the peak at about -1.8 dBFS, which the limiter below then
    ## guards.
    ##
    ## STATIC, NOT `loudnorm`. Single-pass loudnorm normalises DYNAMICALLY, and
    ## this film has a deliberate dynamic arc — a near-silent cold open, then a
    ## hulk landing on the rail. Levelling that is undoing the edit. A fixed
    ## number moves everything and changes nothing about the shape.
    chains.append("%samix=inputs=%d:duration=first:dropout_transition=0:normalize=0,"
                  "volume=%.1fdB,atrim=0:%.3f,afade=t=out:st=%.3f:d=1.2,"
                  "alimiter=level_in=1:level_out=0.92[aout]"
                  % ("".join(legs), len(legs), MASTER_GAIN_DB, total, total - 1.2))

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
        ## Theora, because that is what Godot plays.
        ##
        ## q:v 6, MEASURED rather than picked. Theora is a 2004 codec and it is
        ## far less efficient than the h264 the preview uses: the same 53 s came
        ## out at 59.6 MB on q:v 8, 30 MB on 6 and 23 MB on 5. Frame 780 — the
        ## captain mid-swing against a firing cannon, the busiest frame in the
        ## film — was compared against the source at 6 and holds the face, the
        ## coat's gold trim and the muzzle flash. 30 MB on a ~234 MB exe is a
        ## download people will finish; 60 MB for a difference nobody can see is
        ## not a trade.
        args += ["-c:v", "libtheora", "-q:v", "6",
                 "-c:a", "libvorbis", "-q:a", "4"]
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
