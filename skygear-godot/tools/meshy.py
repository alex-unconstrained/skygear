#!/usr/bin/env python3
"""Generate 3D props through the Meshy API, from a manifest, resumably.

The melee animation pack swings a weapon the captain does not own. Modelling
one by hand is a day; Meshy's text-to-3D turns a written description into a
textured GLB in about four minutes, which is the right trade for a prop that is
a hundred and eighty pixels tall and mostly seen in motion.

This follows tools/forge.py and tools/ingest_model.py rather than inventing a
third shape:

  * every prompt lives in the ASSETS manifest below, in version control, next
    to the key it fills. Nothing is typed into a box and lost, so "why does
    this one look different" has an answer;
  * state lives in tools/meshy-state.json, so a crashed or interrupted run
    resumes against the task ids it already paid for instead of paying twice;
  * results land in assets/models/<key>/, next to the ingested captain.

  python tools/meshy.py list                    # manifest, task ids, what is on disk
  python tools/meshy.py balance                 # credits left
  python tools/meshy.py run sword --dry         # print exactly what would be sent
  python tools/meshy.py run sword               # generate the whole batch and download
  python tools/meshy.py run all --only sword_cutlass
  python tools/meshy.py fetch sword             # re-poll and download, submit nothing
  python tools/meshy.py show sword_cutlass      # raw task JSON from the API

THE API, as of the docs at docs.meshy.ai (checked before this was written):

  base            https://api.meshy.ai
  auth            Authorization: Bearer <key>          (no other scheme offered)
  text-to-3D      POST /openapi/v2/text-to-3d          two-stage: preview, then refine
  image-to-3D     POST /openapi/v1/image-to-3d         also multi-image, smart-topology
  text-to-image   POST /openapi/v1/text-to-image       nano-banana / gpt-image-2
  retexture       POST /openapi/v1/retexture           re-skin an existing mesh
  also            remesh, convert, resize, uv-unwrap, rigging, animation, printability
  balance         GET  /openapi/v1/balance             -> {"balance": <int>}
  create returns  {"result": "<task-id>"}              — the id, not the task
  poll            GET  /openapi/v2/text-to-3d/<id>     (or .../<id>/stream for SSE)
  states          PENDING -> IN_PROGRESS -> SUCCEEDED | FAILED | CANCELED
  prompt length   800 characters, hard 400 on the create call. The docs say 600.
  formats         model_urls: glb, fbx, obj+mtl, usdz, stl, 3mf — ask via target_formats
  PBR             refine with enable_pbr: true -> texture_urls[]: base_color,
                  metallic, normal, roughness (+ emission on meshy-6)
  rate limits     20 req/s; 10-100 concurrent generation tasks depending on plan.
                  429 = RateLimitExceeded (per second) or NoMoreConcurrentTasks.
  cost            meshy-6 preview 20 credits, refine 10 (2k/4k) or 15 (8k).
                  meshy-5 preview is 5. So one finished asset here is 30 credits.

The key is read from $MESHY_API_KEY, falling back to tools/.meshy_key, which is
gitignored. It is never written to state, never printed, and never committed.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = Path(__file__).resolve().parent / "meshy-state.json"
KEYFILE = Path(__file__).resolve().parent / ".meshy_key"
API = "https://api.meshy.ai"


# --- the house style, translated for a 3D generator --------------------------
# The source is tools/forge.py's STYLE constant and its CONCEPT frame, which was
# written for the same weapon batch as 2D reference sheets. This is not a paste.
# What changed, and why:
#
#  * DROPPED the two-source lighting clause ("steel-blue moon rim from the
#    upper-left, warm amber lantern fill from the lower-right"). A 3D generator
#    bakes described light into the albedo map, and then Godot lights the mesh
#    again — you would get the lantern twice, from the wrong side, forever. We
#    ask for flat unlit albedo instead, and say the same thing again in a field:
#    `remove_lighting` on the refine call.
#  * DROPPED "crisp near-black ink outlines". An outline painted into a texture
#    is only correct from the angle it was painted at. This game's cel outline
#    comes from the shader, on every silhouette, at every angle.
#  * DROPPED "no photorealism, no 3D render". It is the one clause that cannot
#    survive the trip: to this API a 3D render is the deliverable. The cel look
#    is asked for here as a MATERIAL property — broad flat colour areas, low
#    micro-detail — which is what actually makes a mesh sit next to the painted
#    billboards without looking imported.
#  * DROPPED every framing clause in CONCEPT — "92% of the canvas width", "blade
#    pointing left and pommel right", "no background scene", the chroma key.
#    There is no canvas. The mesh equivalents replace them: one object, no
#    stand, no scabbard, no hand, closed silhouette, blade along one axis.
#  * KEPT, close to verbatim, the only part that is genuinely the house style:
#    the material and palette vocabulary. Blackened steel, brass fittings,
#    riveted plates, oxblood leather, honest wear, indigo/teal/brass. Changing
#    that here would put this prop out of step with thirty painted assets.
#  * SHORTENED, hard. The 2D Loom takes prompts of any length and forge.py's
#    frames run to 400 words. This API rejects anything over MAX_PROMPT with a
#    400 and no partial credit — the first run from this file died on exactly
#    that. So every clause here has to earn its place, and the redundant
#    negatives that are cheap in a 2D prompt ("no pedestal" AND "no base" AND
#    "no ground plane") are collapsed to one.
# TWO WORDS IN HERE COST US THE FURNACE KNIGHT AND THE COLOSSUS.
#
# "verdigris teal accents" was read by the refine pass as GLOWING teal rather
# than as oxidised copper — so the one colour in the palette that means "cold and
# old" became the one that means "powered", and both furnaces came back green.
#
# And the trailing "no glow" flatly contradicted the per-asset clause asking for
# a glowing orange furnace grate, which is the only thing in this art direction
# that is SUPPOSED to emit. A prompt that contains both instructions resolves
# whichever way it likes; ours resolved against the furnace twice.
#
# The negative it was trying to express is "do not bake a bloom into the albedo",
# which "flat albedo, no baked lighting" already says.
PALETTE = (
    "blackened steel, riveted brass "
    "fittings, oxblood leather, oxidised copper accents, honest wear at the "
    "edges. Chunky readable forms and broad flat colour areas, not photoreal, "
    "no micro-detail. Flat albedo, no baked lighting, no baked shadow."
)

# Two nouns, one vocabulary. Split out when the boarders arrived: calling a
# character a "prop" got Meshy to hand back a suit of armour on a display stand
# rather than a knight. The palette sentence is deliberately shared and
# deliberately not re-typed — it is the one clause that has to stay identical
# across thirty painted assets and everything generated beside them.
STYLE_3D = "Stylised game-ready steampunk airship prop: " + PALETTE
STYLE_FIGURE = "Stylised game-ready steampunk airship character: " + PALETTE

# The frame every weapon in this manifest is generated in. CONCEPT's job in the
# 2D tool was to keep the reference sheet legible; this one's job is to keep the
# mesh clean — a stand or a scabbard is geometry you then have to delete, and a
# hand is geometry you cannot.
PROP = (
    "One weapon alone, upright, blade up. No stand, no base, no scabbard, no "
    "hand, no duplicate, no text, no gems. Blade, guard, grip and pommel "
    "clearly separated. " + STYLE_3D
)

# The texture pass gets its own prompt. The refine stage is only painting an
# existing mesh, so geometry words ("no stand", "symmetrical") are wasted tokens
# there — it takes colour and material direction instead.
SURFACE = (
    "Hand-painted stylised game texture: blackened gunmetal, warm polished brass, "
    "deep oxblood leather, dull oxidised-copper patina settled in the recesses, "
    "bare worn metal along the working edges. Any furnace, grate, vent or ember "
    "is hot orange; nothing else emits light. Broad flat colour areas, no baked "
    "lighting, no baked shadow, no text, no logos."
)

# The one boarder that is not made of metal. SURFACE names five metals and no
# skin, and a texture prompt that never says "skin" paints the gremlin as a
# small brass statue — which is a different enemy.
SURFACE_SKIN = (
    "Hand-painted stylised game texture: mottled green skin, worn oxblood "
    "leather, warm polished brass, faded crimson cloth, dull oxidised-copper "
    "patina in the recesses. Any furnace, grate, vent or ember is hot orange; "
    "nothing else emits light. Broad flat colour areas, no baked lighting, no "
    "baked shadow, no text, no logos."
)


# The frame for a boarder. PROP's clauses are all about a single object on no
# stand; a character needs the opposite half of the same argument — one figure,
# both feet down, arms out of the torso's silhouette. That last clause is the
# one that matters at this camera: the deck is seen from 41 degrees and an arm
# folded across the chest disappears into the body at that angle.
FIGURE = (
    "One character alone, standing upright, facing forward, feet flat on the "
    "ground, arms clear of the body. No base, no plinth, no ground plane, no "
    "scenery, no duplicate, no text. " + STYLE_FIGURE
)

# The gunner is the one boarder with nothing to stand on. Telling a flying
# machine its feet are flat on the ground is how you get feet.
FLYER = (
    "One flying machine alone, hovering level, facing forward, symmetrical. No "
    "legs, no feet, no base, no stand, no ground plane, no scenery, no "
    "duplicate, no text. " + STYLE_FIGURE
)


# --- what to make -----------------------------------------------------------
# key         directory under assets/models/ and the state key
# subject     the only part that changes between assets
# texture     subject line for the refine pass; SURFACE is appended
# batch       what `run <batch>` selects
# polycount   a weapon held by a 176-unit character; 30k (the API default) is
#             three times more triangles than the silhouette can show
# frame       the shared clauses appended to `subject`: PROP, FIGURE or FLYER
# surface     the shared clauses appended to `texture`: SURFACE or SURFACE_SKIN
def A(key, subject, texture, batch, polycount=12000, frame=None, surface=None):
    return dict(key=key, subject=subject, texture=texture, batch=batch,
                polycount=polycount, frame=frame or PROP,
                surface=surface or SURFACE)


ASSETS = [
    # --- swords -------------------------------------------------------------
    # Two, because the point is choosing. The captain's right arm carries a
    # heavy brass gauntlet, so both grips are called out as sized for it — a
    # normal grip reads as too small the moment the melee pack puts her hand
    # on it.
    A("sword_cutlass",
      "A sky-pirate airship captain's cutlass: a broad, slightly curved "
      "single-edged blackened steel blade with a brass fuller and a bright worn "
      "edge; a heavy riveted brass knuckle-bow guard curving from crossguard to "
      "pommel; a long oxblood leather grip sized for a heavy gauntleted hand; a "
      "geared brass pommel cap.",
      "Blackened gunmetal blade, polished brass fuller and knuckle-bow, deep "
      "oxblood leather grip wrap, verdigris settled in the recesses of the "
      "guard, bare bright steel along the cutting edge.",
      "sword"),

    # v2. The first generation of this one came back wrong and is worth
    # recording, because the failures were all in the prompt rather than the
    # model: "an exposed brass gear train along its spine" produced a SECOND
    # crossguard halfway up the blade, and "a valve-shaped counterweight
    # pommel" produced something the size of a sledgehammer head. Both are the
    # same mistake — naming a mechanism the generator has no image of, which it
    # then resolves into the nearest big familiar shape. v2 names ordinary
    # sword parts and puts the machinery on as small detail instead.
    A("sword_gearblade",
      "A steampunk mechanical sword: one straight slim tapering single-edged "
      "blackened steel blade, with three narrow vents cut through the flat "
      "near the base and small brass cogs inset beside them; exactly one short "
      "riveted brass crossguard and no second guard higher up; a long oxblood "
      "leather grip for a gauntleted hand; a small round brass pommel.",
      "Blackened steel blade with brass gears and chain along the spine, dark "
      "iron vents, brass crossguard and valve pommel, worn oxblood leather "
      "grip binding, verdigris around the rivets.",
      "sword"),

    # --- axe ----------------------------------------------------------------
    # The melee pack animates an axe OR a sword. Kept in the manifest so the
    # other half of that choice is one command away, but not in the `sword`
    # batch, so it is not paid for by accident.
    A("axe_boarding",
      "A boarding axe for an airship crew. A broad blackened steel head with a "
      "brass-reinforced cheek plate and a heavy back-spike, mounted on a short "
      "riveted haft wrapped in oxblood leather, with a brass butt cap.",
      "Blackened steel head with a brass cheek plate, oxblood leather haft "
      "wrap, brass butt cap, bare worn steel along the cutting edge.",
      "axe"),

    # --- the five boarders ----------------------------------------------------
    # These are not new characters. Every one of them already exists as a
    # painted billboard in assets/art/enemies/, the player has been fighting
    # them for twelve waves, and the ONLY job of these prompts is to describe
    # the picture that is already on disk well enough that the mesh reads as the
    # same enemy. So each subject is written off the billboard, feature by
    # feature, and the distinguishing feature is named first: the player tells a
    # scrapper from a swarm at a locked 41-degree camera by the silhouette and
    # one colour, not by the rivets.
    #
    # The key is the enemy kind in lower case, because that is what
    # SkyGearView3D.model_path() looks for. Renaming one of these silently turns
    # its boarder back into a billboard.
    #
    # Polycount is up from the weapons' 12k: these are 165 to 330 ground units
    # tall against a sword's 95, and the boss is the one thing on the deck the
    # camera ever gets close to.
    # v2. The first one came back a spindly red spider-legged thing with two
    # amber eyes, and all three failures were in the prompt:
    #
    #   * "one large exposed cog set into the chest" became a SECOND glowing
    #     lens. A round thing on the chest, described one clause after a round
    #     glowing thing on the head, is read as a matching pair. Same mistake as
    #     sword_gearblade's second crossguard: the generator resolves an
    #     unfamiliar part into the nearest familiar shape, and the nearest
    #     familiar shape was the one in the previous sentence. The cog is gone —
    #     it was never how you tell a scrapper from anything else.
    #   * "boarding hooks" alone became small crab pincers. v1 of this line said
    #     "instead of hands" and it was cut to get under 800 characters, which
    #     is the single clause that was doing the work. One hook, per arm,
    #     instead of a hand.
    #   * proportion was described once, at the front, and lost. "Hunched" and
    #     "stubby" against the frame's "standing upright" is one word against
    #     two; it now leads and is repeated as mass rather than as posture.
    A("scrapper",
      "A hunched, top-heavy steampunk salvage automaton. A huge riveted "
      "spherical brass and steel torso; the head sunk low between the "
      "shoulders, a small dome with a single amber lens and no other light; two "
      "long thick arms, each ending in one big curved steel boarding hook "
      "instead of a hand; short thick legs and wide flat feet.",
      "Blackened steel plating with warm polished brass rivets, a hot amber "
      "glass lens, verdigris in the seams, bare worn steel on the hooks.",
      "boarders", 15000, FIGURE),

    A("gunner",
      "A small steampunk airship drone: a riveted brass disc-shaped body with "
      "one round glowing pale blue lens in the centre of its face; four short "
      "arms, one on top and one to each side and one below, each ending in a "
      "two-blade brass propeller in a ring mount; two short chains hanging "
      "underneath with pointed iron weights.",
      "Polished brass shell with blackened steel banding, a cool pale blue "
      "glass lens, verdigris in the recesses, dark iron chains and weights.",
      "boarders", 15000, FLYER),

    A("armored",
      "A huge armoured steampunk furnace knight: heavy riveted plate armour "
      "over a barrel chest with a glowing orange furnace grate in it; a domed "
      "helmet with a slotted visor and a spike on top; a brass chimney stack "
      "rising from the right shoulder; a pressure gauge on the left pauldron; a "
      "big double-bladed axe held across the body.",
      "Blackened steel plate with warm brass trim and rivets, a hot orange "
      "furnace grate, oxblood leather straps, verdigris on the chimney, bare "
      "worn steel on the axe heads.",
      "boarders", 18000, FIGURE),

    A("swarm",
      "A small scrawny green goblin sky-pirate: huge pointed ears, a worn "
      "leather flight cap with brass goggles pushed up on it, a torn crimson "
      "hood and short cape, one riveted brass shoulder plate, a little brass "
      "pressure tank strapped to its back, bare clawed feet, and an oversized "
      "brass pipe wrench gripped in both hands.",
      "Mottled green skin, worn oxblood leather cap and straps, faded crimson "
      "cloth hood, warm polished brass goggles and wrench, verdigris on the "
      "brass.",
      "boarders", 15000, FIGURE, SURFACE_SKIN),

    A("boss",
      "A colossal steampunk siege mech: a vast riveted brass and iron barrel "
      "torso with a glowing orange furnace grate at its centre; a tiny domed "
      "head with one amber lens; two enormous cannon barrels over the shoulders "
      "angled up and outward; huge oversized armoured fists on short arms; "
      "thick armoured legs with anchor-shaped feet.",
      "Blackened iron plate with heavy polished brass banding and rivets, a hot "
      "orange furnace grate, verdigris teal in the seams, bare worn steel "
      "around the cannon mouths.",
      "boarders", 20000, FIGURE),
]

BATCHES = ["sword", "axe", "boarders"]

# Generation settings. meshy-6 costs 20 credits at preview against meshy-5's 5,
# and is the difference between a sword and a sword-shaped lump at this
# polycount. 2k maps: the captain's own albedo is downscaled to 1024 by
# ingest_model.py because she is 176 pixels tall, and the sword is smaller.
AI_MODEL = "meshy-6"
TEXTURE_RESOLUTION = "2k"
TARGET_FORMATS = ["glb", "fbx"]

# The docs say 600. The API actually enforces 800 and returns
#   400 {"message":"Invalid values: Prompt must be a maximum of 800 characters"}
# with nothing generated and nothing charged. Checked here instead, because
# finding out from a 400 halfway through a batch is a worse way to find out.
MAX_PROMPT = 800


# --- plumbing ---------------------------------------------------------------
class MeshyError(RuntimeError):
    def __init__(self, code: int, detail: str):
        super().__init__("HTTP %d: %s" % (code, detail))
        self.code = code
        self.detail = detail


def api_key() -> str:
    key = os.environ.get("MESHY_API_KEY", "").strip()
    if key:
        return key
    if KEYFILE.exists():
        key = KEYFILE.read_text(encoding="utf-8").strip()
        if key:
            return key
    raise SystemExit(
        "no Meshy API key. Set MESHY_API_KEY, or put the key in %s "
        "(that path is gitignored)." % KEYFILE)


def api(method: str, path: str, body: dict | None = None, timeout: int = 60) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + api_key())
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise MeshyError(e.code, e.read().decode("utf-8", "replace")[:500]) from None


def load_state() -> dict:
    if STATE.exists():
        return json.loads(STATE.read_text(encoding="utf-8"))
    return {}


def save_state(st: dict) -> None:
    STATE.write_text(json.dumps(st, indent=1), encoding="utf-8")


def outdir(key: str) -> Path:
    return ROOT / "assets" / "models" / key


def delivered(key: str) -> bool:
    return (outdir(key) / (key + ".glb")).exists()


def select(batch: str, only: str) -> list[dict]:
    rows = [x for x in ASSETS if batch in ("all", x["batch"])]
    if only:
        want = [s.strip() for s in only.split(",") if s.strip()]
        rows = [x for x in rows if x["key"] in want]
    return rows


def bounded(text: str, key: str, field: str) -> str:
    if len(text) > MAX_PROMPT:
        raise SystemExit("%s: %s is %d characters, limit is %d. Shorten the "
                         "subject line in ASSETS, not the shared frame."
                         % (key, field, len(text), MAX_PROMPT))
    return text


def prompt_for(a: dict) -> str:
    return bounded(a["subject"] + " " + a["frame"], a["key"], "prompt")


def texture_prompt_for(a: dict) -> str:
    return bounded(a["texture"] + " " + a["surface"], a["key"], "texture_prompt")


# --- tasks ------------------------------------------------------------------
def submit_preview(a: dict) -> str:
    return api("POST", "/openapi/v2/text-to-3d", {
        "mode": "preview",
        "prompt": prompt_for(a),
        "ai_model": AI_MODEL,
        "topology": "triangle",
        "target_polycount": a["polycount"],
        "should_remesh": True,
        # No symmetry_mode: it exists in older Meshy versions but is not in the
        # current v2 text-to-3d schema, and an unknown field is a 400.
        "target_formats": TARGET_FORMATS,
    })["result"]


def submit_refine(a: dict, preview_id: str) -> str:
    return api("POST", "/openapi/v2/text-to-3d", {
        "mode": "refine",
        "preview_task_id": preview_id,
        "ai_model": AI_MODEL,
        "enable_pbr": True,               # we want metallic/normal/roughness, not one albedo
        "texture_resolution": TEXTURE_RESOLUTION,
        "texture_prompt": texture_prompt_for(a),
        "remove_lighting": True,          # the engine lights this, not the map
        "target_formats": TARGET_FORMATS,
    })["result"]


def poll(task_id: str, label: str, timeout: int = 1800, gap: int = 10) -> dict:
    """Wait for one task. Reports progress; returns the terminal task object."""
    t0 = time.time()
    last = -1
    while time.time() - t0 < timeout:
        try:
            task = api("GET", "/openapi/v2/text-to-3d/" + task_id)
        except MeshyError as e:
            if e.code == 429:
                time.sleep(15)
                continue
            raise
        status = task.get("status", "?")
        progress = int(task.get("progress") or 0)
        if progress != last or status in ("PENDING",):
            queued = task.get("preceding_tasks")
            note = "  (%d ahead)" % queued if queued else ""
            print("    %-8s %-12s %3d%%%s" % (label, status, progress, note))
            last = progress
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return task
        time.sleep(gap)
    return {"status": "TIMEOUT", "id": task_id}


def download(url: str, dest: Path) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as r:
        data = r.read()
    dest.write_bytes(data)
    return len(data)


def collect(a: dict, task: dict) -> list[str]:
    """Pull the mesh, the maps and the thumbnail down beside each other."""
    out = outdir(a["key"])
    got = []
    for fmt, url in (task.get("model_urls") or {}).items():
        if not url or fmt not in ("glb", "fbx", "obj", "mtl", "usdz"):
            continue
        dest = out / ("%s.%s" % (a["key"], fmt))
        print("    %-28s %6.2f MB" % (dest.name, download(url, dest) / 1e6))
        got.append(dest.name)
    for i, maps in enumerate(task.get("texture_urls") or []):
        for role, url in (maps or {}).items():
            if not url or not isinstance(url, str):
                continue
            suffix = "" if i == 0 else "_%d" % i
            dest = out / ("%s_%s%s.png" % (a["key"], role, suffix))
            print("    %-28s %6.2f MB" % (dest.name, download(url, dest) / 1e6))
            got.append(dest.name)
    if task.get("thumbnail_url"):
        dest = out / ("%s_thumb.png" % a["key"])
        download(task["thumbnail_url"], dest)
        got.append(dest.name)
    return got


def write_sidecar(a: dict, st: dict) -> None:
    """Everything needed to explain or repeat this asset, minus the key."""
    rec = st[a["key"]]
    (outdir(a["key"]) / "meshy.json").write_text(json.dumps({
        "key": a["key"],
        "ai_model": AI_MODEL,
        "prompt": prompt_for(a),
        "texture_prompt": texture_prompt_for(a),
        "target_polycount": a["polycount"],
        "texture_resolution": TEXTURE_RESOLUTION,
        "preview_task": rec.get("preview"),
        "refine_task": rec.get("refine"),
        "credits": rec.get("credits"),
        "files": rec.get("files", []),
    }, indent=2), encoding="utf-8")


# --- commands ---------------------------------------------------------------
def cmd_balance(args) -> int:
    print("%d credits" % api("GET", "/openapi/v1/balance")["balance"])
    return 0


def cmd_list(args) -> int:
    st = load_state()
    for b in BATCHES:
        rows = [x for x in ASSETS if x["batch"] == b]
        print("%-8s %d assets, %d on disk" % (b, len(rows),
                                              sum(1 for x in rows if delivered(x["key"]))))
        for x in rows:
            rec = st.get(x["key"], {})
            mark = "OK " if delivered(x["key"]) else ("job" if rec.get("preview") else "   ")
            print("   %s %-16s preview=%-38s refine=%-38s %s credits"
                  % (mark, x["key"], rec.get("preview") or "-",
                     rec.get("refine") or "-", rec.get("credits") or "-"))
    return 0


def cmd_show(args) -> int:
    st = load_state()
    rec = st.get(args.key)
    if not rec:
        raise SystemExit("nothing generated for %r yet" % args.key)
    tid = rec.get("refine") or rec.get("preview")
    print(json.dumps(api("GET", "/openapi/v2/text-to-3d/" + tid), indent=2))
    return 0


def run_one(a: dict, st: dict, args) -> bool:
    key = a["key"]
    rec = st.setdefault(key, {})
    print("== %s" % key)

    # --- preview: geometry ---------------------------------------------------
    if not rec.get("preview"):
        rec["preview"] = submit_preview(a)
        save_state(st)          # written BEFORE the wait, so a crash mid-poll
        print("    preview  -> %s" % rec["preview"])   # does not re-submit it
    else:
        print("    preview  resuming %s" % rec["preview"])
    task = poll(rec["preview"], "preview", args.timeout)
    if task.get("status") != "SUCCEEDED":
        print("    FAILED at preview: %s %s"
              % (task.get("status"), (task.get("task_error") or {}).get("message", "")))
        return False
    credits = int(task.get("consumed_credits") or 0)

    # --- refine: texture -----------------------------------------------------
    if not rec.get("refine"):
        rec["refine"] = submit_refine(a, rec["preview"])
        save_state(st)
        print("    refine   -> %s" % rec["refine"])
    else:
        print("    refine   resuming %s" % rec["refine"])
    task = poll(rec["refine"], "refine", args.timeout)
    if task.get("status") != "SUCCEEDED":
        print("    FAILED at refine: %s %s"
              % (task.get("status"), (task.get("task_error") or {}).get("message", "")))
        return False
    credits += int(task.get("consumed_credits") or 0)

    rec["credits"] = credits
    rec["files"] = collect(a, task)
    save_state(st)
    write_sidecar(a, st)
    print("    %d credits, %d files in assets/models/%s/" % (credits, len(rec["files"]), key))
    return True


def cmd_run(args) -> int:
    st = load_state()
    rows = [x for x in select(args.batch, args.only)
            if args.force or not delivered(x["key"])]
    if not rows:
        print("nothing to generate in '%s' (use --force to redo)" % args.batch)
        return 0

    # --force means "this generation came back wrong, do it again". Without
    # clearing the ids it would do the opposite: run_one resumes any task
    # already in state, so --force would re-download the very result you are
    # trying to replace and charge nothing while appearing to work.
    if args.force and not args.dry:
        for a in rows:
            st.pop(a["key"], None)
        save_state(st)

    if args.dry:
        for a in rows:
            p, t = prompt_for(a), texture_prompt_for(a)
            print("\n=== %s  (%s, %d tris, %s PBR) ===" %
                  (a["key"], AI_MODEL, a["polycount"], TEXTURE_RESOLUTION))
            print("-- prompt (%d/%d) --\n%s" % (len(p), MAX_PROMPT, p))
            print("-- texture_prompt (%d/%d) --\n%s" % (len(t), MAX_PROMPT, t))
        print("\n%d assets, roughly %d credits" % (len(rows), 30 * len(rows)))
        return 0

    try:
        print("balance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    except MeshyError as e:
        raise SystemExit("cannot reach the Meshy API: %s" % e)

    failed = []
    for a in rows:
        try:
            if not run_one(a, st, args):
                failed.append(a["key"])
        except MeshyError as e:
            # 402 and 401 are not worth retrying against the next asset.
            print("    ERROR %s" % e)
            failed.append(a["key"])
            if e.code in (401, 402):
                break
    print("\nbalance %d credits" % api("GET", "/openapi/v1/balance")["balance"])
    if failed:
        print("failed: %s" % ", ".join(failed))
        return 1
    return 0


def cmd_fetch(args) -> int:
    """Download from tasks already submitted. Never spends anything."""
    st = load_state()
    rc = 0
    for a in select(args.batch, args.only):
        rec = st.get(a["key"], {})
        tid = rec.get("refine") or rec.get("preview")
        if not tid:
            continue
        print("== %s" % a["key"])
        task = poll(tid, "fetch", args.timeout)
        if task.get("status") != "SUCCEEDED":
            print("    not ready: %s" % task.get("status"))
            rc = 1
            continue
        rec["credits"] = rec.get("credits") or int(task.get("consumed_credits") or 0)
        rec["files"] = collect(a, task)
        save_state(st)
        write_sidecar(a, st)
    return rc


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list").set_defaults(fn=cmd_list)
    sub.add_parser("balance").set_defaults(fn=cmd_balance)

    s = sub.add_parser("show")
    s.add_argument("key")
    s.set_defaults(fn=cmd_show)

    for name, fn in (("run", cmd_run), ("fetch", cmd_fetch)):
        p = sub.add_parser(name)
        p.add_argument("batch", choices=BATCHES + ["all"])
        p.add_argument("--only", default="", help="comma-separated keys")
        p.add_argument("--timeout", type=int, default=1800, help="seconds per task")
        if name == "run":
            p.add_argument("--dry", action="store_true", help="print, send nothing")
            p.add_argument("--force", action="store_true", help="regenerate and pay again")
        p.set_defaults(fn=fn)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
