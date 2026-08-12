# Making a game intro on the local ComfyUI — a portable handoff

**What this is.** Everything one project learned building a 53-second opening
cinematic out of its own 2D art, on a local ComfyUI install, for free. It is
written to be handed to a *different* project on the same machine. Nothing here
is SkyGear-specific except the examples, which are labelled as examples.

**What you get if you follow it.** A single video file, cut and mixed, that
plays inside your game engine, in your game's own art style, with your own
characters staying recognisably themselves from shot to shot.

**What it costs.** Nothing per generation — the weights are local. Roughly
**5–7 minutes of GPU per 5-second shot** on an RTX 5080. A nine-shot film is
about an hour of wall-clock, during which the GPU is unavailable for anything
else (see §9).

**The single most important thing in this document** is §5, the identity lock.
Everything else is plumbing. §5 is why the character in shot 9 is the same
person as in shot 3.

---

## 1 · What is on this machine, and how to check

```bash
# ComfyUI itself — expect a JSON blob with comfyui_version
curl -s http://127.0.0.1:8188/system_stats

# The local MiniMax H3 weights (~60 GB). All five must be present.
ls /c/ComfyUI-models/diffusion_models/   # minimax_h3_ref2va_pruned_int8_convrot.safetensors
                                         # minimax_h3_fl2va_pruned_int8_convrot.safetensors
ls /c/ComfyUI-models/text_encoders/      # qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
ls /c/ComfyUI-models/vae/                # minimax_h3_video_vae_fp16.safetensors
                                         # minimax_h3_audio_vae_fp32.safetensors

# The node must exist. If this 404s you are about to use the PAID cloud nodes.
curl -s http://127.0.0.1:8188/object_info/MiniMaxH3ReferenceToVideo
```

ComfyUI lives at `~/Documents/GitHub/ComfyUI` and is launched with
`--use-sage-attention`. The models live **outside** it in `C:/ComfyUI-models/`
via `extra_model_paths`.

**ffmpeg is NOT on PATH on this machine.** Do not assume it. Every script below
finds it like this, and it works because the `imageio-ffmpeg` wheel ships a full
ffmpeg 7.1 with `libtheora`, `libvorbis`, `libx264`:

```python
def ffmpeg() -> str:
    import shutil
    on_path = shutil.which("ffmpeg")
    if on_path:
        return on_path
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()
```

---

## 2 · The generator, and the settings that work

**MiniMax H3 `ref2va`** — reference-images-to-video-and-audio. You give it up to
**nine reference images** and a prose prompt; it gives you video *with a
generated soundtrack*. The references are what make it usable for a game: you
are not describing your character, you are showing it.

These settings were arrived at by trial and are **not to be re-derived**:

| | |
|---|---|
| Node | `MiniMaxH3ReferenceToVideo`, `ref_image_size: "match"` |
| Guidance | **`BasicGuider` — guidance-free. NO `KSampler`, no cfg value.** A cfg produced a cooked, over-contrasted look. |
| Sampler | `KSamplerSelect: res_multistep` |
| Schedule | `BasicScheduler: simple, 20 steps, denoise 1.0` |
| Noise | `RandomNoise` → `SamplerCustomAdvanced` |
| Sigma shift | **none** — do not add `MiniMaxH3SigmaShift` |
| Resolution | **1344×768** native (7:4) |
| Frame rate | 24 |

**Frame counts sit on a grid: `(length - 5) % 17 == 0`.** Minimum 124 frames
(~5.17 s), trained range ~124–362. Off-grid lengths do not error — they produce
garbage. Useful values: **124** (5.17 s), **141** (5.88 s), **158**, **175**.

`ref_image_size: "match"` scales references to the generation's pixel area.
`"max"` uses a 2048px short edge for better identity fidelity and is *several
times slower*, because reference tokens ride through every sampling step. Nine
shots at `"max"` is most of a day. `"match"` was enough.

---

## 3 · Driving it from code, not from the canvas

Build the graph in code and POST it to `/prompt`. The reason is not convenience:
a film is a set of shots that must hold **one look**, and the only thing that
should differ between them is the prompt. Hand-editing widgets between shots is
how shot 6 ends up 20 steps and shot 7 ends up 18.

```python
import requests

COMFY = "http://127.0.0.1:8188"
WIDTH, HEIGHT, FPS = 1344, 768, 24

def graph(prompt: str, frames: int, ref_names: list[str], seed: int) -> dict:
    if (frames - 5) % 17 != 0:
        raise SystemExit("frame count %d is off the 17k+5 grid" % frames)
    g = {
        "127": {"class_type": "UNETLoader", "inputs": {
            "unet_name": "minimax_h3_ref2va_pruned_int8_convrot.safetensors",
            "weight_dtype": "default"}},
        "128": {"class_type": "CLIPLoader", "inputs": {
            "clip_name": "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors",
            "type": "minimax", "device": "default"}},
        "119": {"class_type": "VAELoader", "inputs": {
            "vae_name": "minimax_h3_video_vae_fp16.safetensors"}},
        "120": {"class_type": "VAELoader", "inputs": {
            "vae_name": "minimax_h3_audio_vae_fp32.safetensors"}},
        "136": {"class_type": "MiniMaxH3ReferenceToVideo", "inputs": {
            "clip": ["128", 0], "vae": ["119", 0], "audio_vae": ["120", 0],
            "prompt": prompt, "width": WIDTH, "height": HEIGHT,
            "length": frames, "ref_image_size": "match"}},
        "129": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "126": {"class_type": "BasicGuider", "inputs": {
            "model": ["127", 0], "conditioning": ["136", 0]}},
        "123": {"class_type": "KSamplerSelect", "inputs": {
            "sampler_name": "res_multistep"}},
        "124": {"class_type": "BasicScheduler", "inputs": {
            "model": ["127", 0], "scheduler": "simple",
            "steps": 20, "denoise": 1.0}},
        "125": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["129", 0], "guider": ["126", 0], "sampler": ["123", 0],
            "sigmas": ["124", 0], "latent_image": ["136", 1]}},
        "122": {"class_type": "VAEDecode", "inputs": {
            "samples": ["125", 0], "vae": ["119", 0]}},
        "121": {"class_type": "VAEDecodeAudio", "inputs": {
            "samples": ["125", 0], "vae": ["120", 0]}},
        "130": {"class_type": "CreateVideo", "inputs": {
            "images": ["122", 0], "audio": ["121", 0], "fps": FPS, "quality": 8}},
        "92":  {"class_type": "SaveVideo", "inputs": {
            "video": ["130", 0], "filename_prefix": "yourgame/cutscene",
            "format": "auto", "codec": "auto"}},
    }
    # THE DOTTED KEYS. See trap 1.
    for i, name in enumerate(ref_names):
        nid = "200%d" % i
        g[nid] = {"class_type": "LoadImage",
                  "inputs": {"image": name, "type": "image"}}
        g["136"]["inputs"]["ref_images.ref_image_%d" % i] = [nid, 0]
    return g
```

Upload references first; `LoadImage` takes a name in ComfyUI's input folder:

```python
def upload(path):
    with open(path, "rb") as fh:
        r = requests.post(COMFY + "/upload/image",
                          files={"image": (path.name, fh, "image/png")},
                          data={"overwrite": "true", "subfolder": "yourgame"},
                          timeout=120)
    r.raise_for_status()
    d = r.json()
    sub = d.get("subfolder") or ""
    return ("%s/%s" % (sub, d["name"])) if sub else d["name"]
```

Then POST, poll `/history/<id>`, and pull the file from `/view`:

```python
pid = requests.post(COMFY + "/prompt", json={"prompt": g}).json()["prompt_id"]
while True:
    time.sleep(5)
    h = requests.get(COMFY + "/history/" + pid).json()
    if pid in h:
        break
    # A queue that has gone empty with no history is a CRASH, not a wait.
    q = requests.get(COMFY + "/queue").json()
    if not q["queue_running"] and not q["queue_pending"]:
        raise SystemExit("vanished from the queue — check the ComfyUI console")
```

---

## 4 · The five traps, each of which cost real time

**1 · Autogrow reference keys are DOTTED.** It is
`ref_images.ref_image_0`, never `ref_image_0`. The bare form **passes `/prompt`
validation and then dies at `execute()`** — so a clean queue response proves
nothing. *Symptom:* the job vanishes and `/history` never fills.

**2 · `Minimax*Hailuo*` nodes are PAID cloud API calls.** Only the
`MiniMaxH3*` family touches the local weights. *Symptom:* it works, it is fast,
and you get a bill. Assert the local node exists before you queue anything.

**3 · Reference indices drift silently.** Prompts address references by
position — *"Use ref_image_3 for the crew"* — so adding one reference re-points
every sentence after it. Nothing errors; you just get the wrong picture used for
the wrong thing. **Guard it:**

```python
named = {int(m) for m in re.findall(r"ref_image_(\d)", prompt_body)}
have  = set(range(len(refs)))
assert not (named - have), "prompt names a reference that is not wired"
assert not (have - named), "a wired reference the prompt never addresses"
```

**4 · Cut-outs on transparency read unpredictably.** Most game sprites are PNGs
with alpha. H3 does something arbitrary with it. **Flatten every reference onto
a solid dark colour sampled from your own art** before uploading:

```python
flat = Image.new("RGB", im.size, (0x14, 0x10, 0x20))
flat.paste(im, (0, 0), im)
```

**5 · The model will invent whatever you did not forbid.** A shot of an airship
came back with an **ocean** under it, because nothing said the world had no sea.
Write your world's negative rules as a **byte-identical clause in every prompt**,
the same way you write the style rules. Example:

> *World rule, absolute: this is a SKY world and the ship is an AIRSHIP miles
> above the ground. There is NO sea, NO ocean, NO water, NO waves, NO shoreline
> and NO land anywhere in frame. Below and beyond the ship there is only open
> air, cloud and storm; any horizon is a bank of cloud, never a waterline.*

---

## 5 · The identity lock — the part that actually matters

A character who changes face between shots destroys the film. This is the whole
method:

**a. One anchor reference in every single shot.** Pick the one image that defines
your palette and painting style — a painted backdrop works well — and make it
`ref_image_0` of *every* prompt, always introduced with the **same sentence**.

**b. Every shot a character appears in carries ALL of that character's
references — not one.** If you have an idle sprite and an action sprite, both go
in, every time, even when the shot only needs one. Reference tokens cost render
time; consistency is what they buy.

**c. The costume description is a fixed string.** Do not paraphrase it between
shots. Write it once and paste it:

> *"the same young man in every detail: a red brass-buckled greatcoat with a
> gold-starred hem, brass goggles pushed up into spiked brown hair, an ornate
> brass clockwork gauntlet, a large curved cutlass. Same face, same proportions
> as the references, no drifting features."*

**d. Style and proportion are a locked clause, byte-identical everywhere.** If
your game is stylised, say so explicitly and forbid the model's default drift
toward realism:

> *"Proportions are locked to the character references: stylized chibi build — a
> large expressive head, compact heroic body roughly three and a half heads
> tall, small hands and feet, oversized weapon. Keep the references' painterly
> brushwork and fine detailing at that scale. Do NOT restyle anyone to realistic
> adult proportions."*

**e. Make the tool refuse to break it.** Not a convention — a check:

```python
CHARACTER_SHOTS = (3, 4, 6, 7, 9)
for s in CHARACTER_SHOTS:
    refs = SHOTS[s]["refs"]
    missing = [r for r in ("HERO_IDLE", "HERO_ACTION") if r not in refs]
    if missing:
        raise SystemExit("shot %02d has the hero in it and is missing %s" % (s, missing))
    if "ANCHOR" not in refs:
        raise SystemExit("shot %02d has no style anchor" % s)
```

**f. Reference your HAND-AUTHORED ART, never gameplay screenshots.** Screenshots
carry HUD, flat lighting and engine artefacts, and they dragged an early attempt
to mediocrity. The aesthetic target is the art the game was designed from.

**g. Audition ONE shot before committing to the other eight.** Render the shot
with the hardest identity requirement first, look at four frames of it, and only
then queue the rest. This is a 6-minute check that protects an hour.

---

## 6 · Writing the shots

Structure the prompt file as a **header of instructions to yourself** and a
**body that is the literal prompt**, split by a rule:

```
# SHOT 03 — THE CAPTAIN — 141 frames (5.88 s) @ 24 fps, 1344x768
# Grid check: (141 - 5) % 17 == 0  OK
# ref_images.ref_image_0 = ANCHOR  sky_backdrop.png
# ref_images.ref_image_1 = HERO_IDLE   corsair_front_idle.png (flattened)
# ref_images.ref_image_2 = HERO_ACTION corsair_front_attack.png (flattened)
----
Use ref_image_0 for the exact sky, palette and painting style: ...
Use ref_image_1 and ref_image_2 for the exact character and costume — ...

The video: <what happens, in plain prose, present tense>

<motion constraints> No text, no watermark, no photorealism.

<the locked style clause>

<the locked world rule>
```

**Prompt style is DIRECTIVE.** Tell the model what each reference is *for* before
you describe the shot. "Use ref_image_1 for the exact character and costume" beats
any amount of adjective.

**Plan the cuts before you generate.** Decide what hides each join, and put the
cut on an *event* — a head turn, an impact, a charge, a muzzle flash, a steam
burst. A cut on an event hides a discontinuity; a dissolve softens it and is
therefore usually wrong. One real example set:

- 1→2 **dissolve**, because the ship's rendered scale changes
- 2→3 **cut on camera motion**, hiding painted-ship → deck-detail
- 3→4 **motivated eyeline cut** — he turns, and 4 is what he is looking at
- 4→5 **cut on impact**, so calm and violence never share a lighting state
- 7→8 **cut inside a steam burst**, hiding a scale jump to a giant

**No two adjacent shots should depend on the model matching motion across a
cut.** Only palette and identity, which the references carry.

---

## 7 · Cutting and mixing it

Concatenate with ffmpeg `concat` for hard cuts and `xfade` for dissolves.
Normalise every source first — `xfade` and `concat` both refuse mismatched
inputs:

```
[i:v]scale=W:H,fps=24,format=yuv420p,setsar=1[vi]
```

### Drop the generated audio, usually

H3 produces a soundtrack with the video. It is synced by construction, which is
tempting — but it may contain **mumbled pseudo-speech**, and under a scene whose
whole point is one real recorded line that is a risk with no upside. Build the
mix from your game's own music, SFX and VO. That also makes the film sound like
the thing it is advertising.

### The bug you will otherwise ship

**Every cue needs an END, not just a start.** A mix expressed as
*(file, start, gain, fade_in, fade_out)* invites you to forget to apply the
fade-out, and then nothing ever stops. One project shipped a film where three
music tracks played simultaneously for the last fifteen seconds and two of them
overlapped for **31 seconds**, because `fade_out` was unpacked from the tuple and
never used. The picture was correct, the file length was correct, ffmpeg exited
0, and every automated step passed.

Model a cue as a **window**, and get the filter order right:

```python
# atrim+asetpts   clip to the window and rebase the clock to zero, so every
#                 time below is relative to the CUE, not to the film
# afade in/out    both, always; the out is placed from the END of the window
# volume          after the fades
# adelay          and only NOW into place on the timeline (milliseconds/channel)
# apad            so a short cue does not shorten the sum
leg = ("[%d:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,"
       "atrim=0:%.3f,asetpts=PTS-STARTPTS,"
       "afade=t=in:st=0:d=%.3f,"
       "afade=t=out:st=%.3f:d=%.3f,"
       "volume=%.2fdB,adelay=%d|%d,apad[a%d]")
```

then `amix=inputs=N:duration=first:normalize=0` with the **longest** cue first
(an ambience bed running the whole film), `atrim` to length, and `alimiter`.

### Gate it before you encode

Sound has no containment audit and no test harness. Write the gate yourself and
run it *before* the 4-minute encode:

```python
def assert_mix_sane(plan, film_len, max_crossfade=1.2):
    music = sorted([c for c in plan if c.is_music()], key=lambda c: c.start)
    for a, b in zip(music, music[1:]):
        if a.end - b.start > max_crossfade:
            raise SystemExit("%s and %s play together for %.2fs — a pile-up, "
                             "not a crossfade" % (a.name, b.name, a.end - b.start))
    if any(c.start >= film_len - 0.05 for c in plan):
        raise SystemExit("a cue starts after the last frame")
    voice = sorted([c for c in plan if c.is_voice()], key=lambda c: c.start)
    for a, b in zip(voice, voice[1:]):
        if b.start < a.start + 1.4:
            raise SystemExit("two lines %.2fs apart — they will talk over each other")
```

**Prove the gate against the broken mix before you trust it.** Reconstruct the
old plan, run the gate, and confirm it names the fault.

### Compute every cue time; never type one

```python
def shot_start(n):          # seconds to the first frame of shot n
    t = 0.0
    for num, frames in SHOTS:
        if num == n:
            return t
        t += frames / FPS
        t -= DISSOLVE_AFTER.get(num, 0) / FPS
```

Then every cue is `shot_start(6) + 3.45`, and re-timing a shot cannot desync its
own sound.

### Master it

Measure, do not guess:

```bash
ffmpeg -i film.mp4 -af ebur128=peak=true -f null -
```

A first mix came back at **-25.9 LUFS** — quiet enough that a player reaches for
the volume dial during the title sequence. A **static** `volume=6dB` landed it at
-19.9 LUFS with a -1.8 dBFS true peak. Use a fixed gain, **not single-pass
`loudnorm`**: loudnorm normalises dynamically and will flatten a deliberate
dynamic arc (near-silent cold open → something landing on the deck).

---

## 8 · Getting it into the engine

### Godot 4 — three facts that will cost you an evening

1. **`VideoStreamPlayer` plays Ogg Theora and nothing else.** An `.mp4` in
   `assets/` is a file the engine cannot open. Encode with
   `-c:v libtheora -q:v 6 -c:a libvorbis -q:a 4`.
2. **Theora is inefficient.** Measured on 53 s at 1344×768: `-q:v 8` → 59.6 MB,
   `-q:v 6` → 30 MB, `-q:v 5` → 23 MB. Compare the *busiest* frame against the
   source before choosing; 6 was indistinguishable here.
3. **`VideoStreamPlayer` has NO `stretch_mode`.** It is not a `TextureRect`; its
   only sizing lever is `expand`, which fills and distorts. Setting
   `stretch_mode` throws at runtime, the node is never added, and **the film is
   silently absent**. Hold aspect with an `AspectRatioContainer`:

```gdscript
var fit := AspectRatioContainer.new()
fit.set_anchors_preset(Control.PRESET_FULL_RECT)
fit.ratio = 1344.0 / 768.0
fit.stretch_mode = AspectRatioContainer.STRETCH_FIT
add_child(fit)

var player := VideoStreamPlayer.new()
player.stream = load("res://assets/video/opening.ogv")
player.expand = true
player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
player.size_flags_vertical = Control.SIZE_EXPAND_FILL
fit.add_child(player)
```

### Three rules for the player itself

- **Skippable from the first frame**, any key, any click. A trailer you cannot
  escape is the first thing a player holds against the game.
- **Plays once**, with the flag in whatever file already persists preferences —
  and mark it seen when it **starts**, not when it ends. Someone who skipped at
  second three has decided.
- **A missing film is not a failure.** If the file is absent, free the node on
  the first frame and boot normally. The film is content, not a dependency.
- Give it a way back (a `WATCH THE OPENING` row in settings), or the only way to
  see it again is deleting a config file.

### Smoke-test it in a REAL window

A headless test cannot see any of this — a headless build has no video decoder,
so the whole path is invisible to it. That is exactly how the `stretch_mode` bug
survived a green test suite. Boot the real scene, wait, and assert the decoder
**advanced**:

```gdscript
await get_tree().process_frame          # x12
var vp := film.find_children("*", "VideoStreamPlayer", true, false)[0]
assert(vp.is_playing() and vp.stream_position > 0.05)
await RenderingServer.frame_post_draw   # grab AFTER the renderer is done
get_root().get_texture().get_image().save_png("res://.shots/in_game_frame.png")
```

---

## 9 · The one operational rule

**Video generation and engine screen-capture contend hard for the single GPU.**
Running a ComfyUI render and a Godot capture pass at once froze this machine
badly enough to corrupt a git operation. Serialise them. Plan an hour of film
rendering as an hour in which you do source work only, and do the visual
verification afterwards.

---

## 10 · The checklist

```
[ ] /system_stats answers, MiniMaxH3ReferenceToVideo exists in /object_info
[ ] frame counts all satisfy (n - 5) % 17 == 0
[ ] every reference flattened onto opaque dark; alpha nowhere
[ ] anchor reference is ref_image_0 of EVERY prompt, same sentence each time
[ ] every character shot carries ALL that character's references
[ ] costume string, style clause and world rule are byte-identical everywhere
[ ] ref_image_N indices verified against the wired list, both directions
[ ] ONE shot auditioned and eyeballed before the rest are queued
[ ] cut plan written: what event hides each join
[ ] every cue time computed from shot_start(), none typed
[ ] every cue has an END; assert_mix_sane proven against a deliberately broken plan
[ ] loudness measured with ebur128, static gain applied, re-measured
[ ] encoded Theora for Godot; quality chosen by comparing the busiest frame
[ ] smoke-tested in a REAL window, decoder position asserted > 0
[ ] skippable, plays once, missing file degrades gracefully, a way to replay
```

---

## 11 · The working scripts

The three tools this was extracted from are in `skygear-godot/tools/` and are
readable as reference implementations. They are ~900 lines total and heavily
commented with the reasoning:

| file | what it does |
|---|---|
| `cutscene_render.py` | reference prep, upload, graph build, queue, poll, fetch; identity-lock and index-drift assertions |
| `cutscene_stitch.py` | cut assembly, the `Cue` window model, `assert_mix_sane`, the title card, Theora/h264 encode |
| `film_smoke.gd` | boots the real scene and proves the film decodes and advances |

Copy them and change the tables at the top — `REFS`, `SHOTS`, `mix_plan()`. The
structure is the part worth keeping.

---

*Written 2026-08-11 from the SkyGear opening cinematic: nine shots, 53.5 s,
generated locally at no cost, from the game's own hand-painted art.*
