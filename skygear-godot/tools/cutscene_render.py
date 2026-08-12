"""Render the opening cinematic's nine shots on the local MiniMax H3 ref2va.

SG-238 specced the film and SG-242 executes it. Everything this tool knows about
the generator comes from `docs/cutscene/README.md` §0 — the settings block the
owner confirmed — and everything it knows about each shot comes from
`docs/cutscene/prompts/shot_NN.txt`. It re-derives nothing.

    python tools/cutscene_render.py --shot 1          one shot, for auditioning
    python tools/cutscene_render.py --all             the whole film
    python tools/cutscene_render.py --all --take 2    a second take of everything

Output lands in `.shots/cutscene/take<N>/shot_NN.mp4` (gitignored working
files); `tools/cutscene_stitch.py` assembles them.

WHY A SCRIPT AND NOT THE COMFYUI CANVAS. Nine shots that must hold one palette
and one face across five of them is a job where the ONLY safe variable is the
prompt. Building the graph in code means the twenty settings that carry the look
cannot drift between shot 3 and shot 9 by hand-editing a widget.

THE TWO TRAPS, both of which cost real time before they were written down:
  * autogrow reference keys are DOTTED — `ref_images.ref_image_0`. The bare
    `ref_image_0` passes /prompt validation and dies at execute(), so a clean
    queue response proves nothing. `_graph()` builds the dotted form only.
  * the `Minimax*Hailuo*` node family is a PAID cloud call. Only `MiniMaxH3*`
    touches the local weights in C:/ComfyUI-models. This tool names the local
    nodes explicitly and asserts they exist before it queues anything.
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import time
import urllib.parse
from pathlib import Path

import requests
from PIL import Image

COMFY = "http://127.0.0.1:8188"
ROOT = Path(__file__).resolve().parent.parent          # skygear-godot/
PROMPTS = ROOT / "docs" / "cutscene" / "prompts"
PREPPED = ROOT / "docs" / "cutscene" / "refs" / "prepped"
OUTDIR = ROOT / ".shots" / "cutscene"

## The manifest's flatten colour: sampled from sky_backdrop.png's upper cloud
## field. H3 reads transparency unpredictably and every sprite below is a
## cut-out, so a transparent ref is a coin flip on what it decides the
## background was.
SLATE = (0x14, 0x10, 0x20)

## docs/cutscene/refs/README.md, by ID. Values are (path, prep) where prep is
## "flatten" or "flatten+crop" or None.
REFS = {
    "R0":  ("assets/art/env/sky_backdrop.png", None),
    "R1a": ("assets/art/heroes/corsair_front_idle.png", "flatten"),
    "R1b": ("assets/art/heroes/corsair_front_attack.png", "flatten"),
    "R1c": ("assets/art/heroes/corsair_back_idle.png", "flatten"),
    "R2":  ("assets/art/allies/crew_front_attack.png", "flatten"),
    "R3":  ("assets/art/env/airship_distant.png", "flatten+crop"),
    "R4":  ("assets/art/env/bow_prow.png", "flatten"),
    "R6a": ("assets/art/props/boarding_hulk_sealed.png", "flatten"),
    "R6b": ("assets/art/props/boarding_hulk_open.png", "flatten"),
    "R7":  ("assets/art/enemies/automaton_front_attack.png", "flatten"),
    "R8":  ("assets/art/props/cannon_deck.png", "flatten"),
    "R9":  ("assets/art/enemies/furnace_knight_front_attack.png", "flatten"),
    "R9b": ("assets/art/enemies/furnace_knight_front_idle.png", "flatten"),
    "R10": ("assets/art/enemies/colossus_front_idle.png", "flatten"),
}

## The storyboard's own table, as data. Frames sit on the 17k+5 grid; the tool
## refuses anything that does not, because H3 silently produces garbage off it.
## THE CAPTAIN'S IDENTITY LOCK. He appears in shots 3, 4, 6, 7 and 9, and every
## one of those carries BOTH `R1a` (the face at rest) and `R1b` (the definitive
## costume read) — not one or the other. The owner's ask, 2026-08-11: *"I just
## want cutscenes to honor the reference images and assets created for the
## protagonist so it's consistent."* Reference tokens ride through every
## sampling step, so this costs render time; consistency is what it buys, and
## the owner named consistency as the requirement.
SHOTS = {
    1: {"frames": 124, "refs": ["R0", "R3"]},
    2: {"frames": 141, "refs": ["R0", "R3", "R4"]},
    3: {"frames": 141, "refs": ["R0", "R1a", "R1b"]},
    4: {"frames": 141, "refs": ["R0", "R1a", "R1b", "R2"]},
    5: {"frames": 124, "refs": ["R0", "R6b", "R6a", "R7"]},
    6: {"frames": 141, "refs": ["R0", "R1a", "R1b", "R7", "R2", "R8"]},
    7: {"frames": 124, "refs": ["R0", "R1a", "R1b", "R9", "R9b"]},
    8: {"frames": 141, "refs": ["R0", "R10", "R4"]},
    9: {"frames": 124, "refs": ["R0", "R1a", "R1b", "R1c", "R10"]},
    ## --- NOT PART OF THE FILM ------------------------------------------------
    ## SHOT 10 IS A PORTRAIT PLATE, not a shot: a slow push onto the captain's
    ## face, generated so a single frame can be cropped out of it as
    ## `assets/art/ui/portrait_corsair.png` (board SG-228 / SG-105).
    ##
    ## WHY A CLIP FOR A STILL. That portrait is the LAST piece of the gender fix
    ## — casting, voice and text all shipped, and the art is still a red-haired
    ## woman in a blue coat who matches neither the sprite, nor the model, nor
    ## the owner's ruling — and it is the ONLY portrait in the project, which is
    ## why the Boilerwright wears it too. The Loom is not on this machine, so
    ## there is no image generator here; H3 is. A 124-frame push gives 124
    ## candidate faces at full 1344x768, which is more head-pixels than cropping
    ## the 512px sprite could ever produce, and it is the same character in the
    ## same style as the film by construction.
    10: {"frames": 124, "refs": ["R0", "R1a", "R1b"]},
    ## SHOT 11 IS THE SECOND HERO'S PLATE, and it is the one prompt in this
    ## folder that uses the corsair references for STYLE rather than IDENTITY.
    ## The Boilerwright has no 2D art anywhere in the project — three corsair
    ## files and nothing else — so the only way to draw him in the same hand as
    ## the captain is to show H3 the captain and tell it, twice, not to copy
    ## him. `assert_identity_lock` deliberately does NOT list 11 as a captain
    ## shot for that reason.
    11: {"frames": 124, "refs": ["R0", "R1a", "R1b"]},
}

## The film itself. `--all` means these nine and only these nine; a plate is
## opt-in, because it is not in the edit and must not silently join it.
FILM = tuple(range(1, 10))

## Which shots the captain stands in. `--all` refuses to run if any of these
## has lost its face reference, because a silent drop is exactly the failure
## that would not be visible until the film was cut together.
CAPTAIN_SHOTS = (3, 4, 6, 7, 9)

WIDTH, HEIGHT, FPS = 1344, 768, 24


# ---------------------------------------------------------------- preparation

def prep_ref(ref_id: str) -> Path:
    """Flatten (and where the manifest says so, crop) one reference. Cached."""
    rel, prep = REFS[ref_id]
    src = ROOT / rel
    if not src.exists():
        sys.exit("missing reference %s -> %s" % (ref_id, rel))
    PREPPED.mkdir(parents=True, exist_ok=True)
    dst = PREPPED / ("%s_%s" % (ref_id, Path(rel).name))
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return dst
    im = Image.open(src).convert("RGBA")
    if prep:
        flat = Image.new("RGB", im.size, SLATE)
        flat.paste(im, (0, 0), im)
        im = flat
        if "crop" in prep:
            ## The manifest: the painted ship occupies roughly the top 55% of
            ## airship_distant's canvas. Cropping the dead band makes the ref
            ## the ship rather than the empty space under it.
            im = im.crop((0, 0, im.width, int(im.height * 0.55)))
    else:
        im = im.convert("RGB")
    im.save(dst)
    return dst


def upload(path: Path) -> str:
    """Put a prepped ref in ComfyUI's input folder; return the name LoadImage wants."""
    with path.open("rb") as fh:
        r = requests.post(
            COMFY + "/upload/image",
            files={"image": (path.name, fh, "image/png")},
            data={"overwrite": "true", "subfolder": "skygear_cutscene"},
            timeout=120,
        )
    r.raise_for_status()
    d = r.json()
    sub = d.get("subfolder") or ""
    return ("%s/%s" % (sub, d["name"])) if sub else d["name"]


def read_prompt(shot: int) -> str:
    """Everything below the `----` rule; the header is instructions to us.

    Also the one place index drift can be caught. Prompts address references by
    position (`Use ref_image_3 for the crew`), so adding a reference to a shot
    silently re-points every sentence after it. This asserts that every index
    the prose names actually exists, and that nothing in the list is unused.
    """
    txt = (PROMPTS / ("shot_%02d.txt" % shot)).read_text(encoding="utf-8")
    if "----" not in txt:
        sys.exit("shot_%02d.txt has no ---- rule" % shot)
    body = txt.split("----", 1)[1].strip()
    named = {int(m) for m in re.findall(r"ref_image_(\d)", body)}
    have = set(range(len(SHOTS[shot]["refs"])))
    if named - have:
        sys.exit("shot %02d prompt names ref_image_%s but only %d references "
                 "are wired" % (shot, sorted(named - have), len(have)))
    if have - named:
        sys.exit("shot %02d wires reference(s) %s that the prompt never uses — "
                 "an unaddressed reference is a silent index shift"
                 % (shot, sorted(have - named)))
    return body


# ---------------------------------------------------------------- the graph

def graph(prompt: str, frames: int, ref_names: list[str], seed: int) -> dict:
    """The API-format graph, node for node from the confirmed settings block.

    Guidance-free: BasicGuider, never KSampler with a cfg. res_multistep.
    BasicScheduler simple/20/1.0. No sigma-shift node. These are the owner's,
    verbatim, and this function is the only place they are written down in code.
    """
    if (frames - 5) % 17 != 0:
        sys.exit("frame count %d is off the 17k+5 grid" % frames)

    g: dict = {
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
            "images": ["122", 0], "audio": ["121", 0], "fps": FPS,
            "quality": 8}},
        "92": {"class_type": "SaveVideo", "inputs": {
            "video": ["130", 0], "filename_prefix": "skygear/cutscene",
            "format": "auto", "codec": "auto"}},
    }
    ## DOTTED autogrow keys. This loop is the trap's only cure.
    for i, name in enumerate(ref_names):
        nid = "200%d" % i
        g[nid] = {"class_type": "LoadImage",
                  "inputs": {"image": name, "type": "image"}}
        g["136"]["inputs"]["ref_images.ref_image_%d" % i] = [nid, 0]
    return g


# ---------------------------------------------------------------- running

def assert_local_nodes() -> None:
    r = requests.get(COMFY + "/object_info/MiniMaxH3ReferenceToVideo", timeout=30)
    if r.status_code != 200 or "MiniMaxH3ReferenceToVideo" not in r.json():
        sys.exit("MiniMaxH3ReferenceToVideo is not installed — refusing to "
                 "fall back to the paid Hailuo nodes")


def assert_identity_lock() -> None:
    """No captain shot may lose his face or costume reference."""
    for s in CAPTAIN_SHOTS:
        refs = SHOTS[s]["refs"]
        missing = [r for r in ("R1a", "R1b") if r not in refs]
        if missing:
            sys.exit("shot %02d has the captain in it and is missing %s — the "
                     "identity lock is the point of this film" % (s, missing))
        if "R0" not in refs:
            sys.exit("shot %02d has no sky reference; the palette anchor is "
                     "R0 in every shot" % s)


def render(shot: int, take: int, seed: int) -> Path:
    spec = SHOTS[shot]
    names = [upload(prep_ref(r)) for r in spec["refs"]]
    g = graph(read_prompt(shot), spec["frames"], names, seed)

    r = requests.post(COMFY + "/prompt", json={"prompt": g}, timeout=120)
    if r.status_code != 200:
        sys.exit("shot %02d rejected: %s" % (shot, r.text[:1500]))
    pid = r.json()["prompt_id"]
    print("shot %02d queued  %d frames  seed %d  prompt_id %s"
          % (shot, spec["frames"], seed, pid), flush=True)

    started = time.time()
    while True:
        time.sleep(5)
        h = requests.get(COMFY + "/history/" + pid, timeout=60).json()
        if pid in h:
            entry = h[pid]
            status = entry.get("status", {})
            if status.get("status_str") == "error" or not status.get("completed", True):
                for m in status.get("messages", []):
                    if m[0] in ("execution_error", "execution_interrupted"):
                        sys.exit("shot %02d failed: %s" % (shot, json.dumps(m[1])[:1500]))
                sys.exit("shot %02d failed: %s" % (shot, json.dumps(status)[:1500]))
            return _fetch(entry, shot, take, started)
        ## A queue that has gone quiet without producing history is a crash.
        q = requests.get(COMFY + "/queue", timeout=30).json()
        busy = q["queue_running"] or q["queue_pending"]
        if not busy and time.time() - started > 60:
            sys.exit("shot %02d vanished from the queue with no history — "
                     "check the ComfyUI console" % shot)
        if int(time.time() - started) % 60 < 5:
            print("   ... %ds" % int(time.time() - started), flush=True)


def _fetch(entry: dict, shot: int, take: int, started: float) -> Path:
    for node_out in entry.get("outputs", {}).values():
        for key in ("video", "videos", "gifs", "images"):
            for item in node_out.get(key, []) or []:
                q = urllib.parse.urlencode({
                    "filename": item["filename"],
                    "subfolder": item.get("subfolder", ""),
                    "type": item.get("type", "output")})
                data = requests.get(COMFY + "/view?" + q, timeout=600).content
                dst = OUTDIR / ("take%d" % take)
                dst.mkdir(parents=True, exist_ok=True)
                out = dst / ("shot_%02d%s" % (shot, Path(item["filename"]).suffix))
                out.write_bytes(data)
                print("shot %02d -> %s  (%.1f MB, %ds)"
                      % (shot, out, len(data) / 1e6, int(time.time() - started)),
                      flush=True)
                return out
    sys.exit("shot %02d produced no video output" % shot)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", type=int, action="append", help="1-9, repeatable")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--take", type=int, default=1)
    ap.add_argument("--seed", type=int, default=0,
                    help="base seed; each shot adds its number so a take is reproducible")
    a = ap.parse_args()

    shots = list(FILM) if a.all else sorted(a.shot or [])
    if not shots:
        sys.exit("nothing to do — pass --shot N or --all")

    assert_local_nodes()
    assert_identity_lock()
    base = a.seed or (770000 + a.take * 1000)
    for s in shots:
        render(s, a.take, base + s)
    print("done: %d shot(s) in %s" % (len(shots), OUTDIR / ("take%d" % a.take)))


if __name__ == "__main__":
    main()
