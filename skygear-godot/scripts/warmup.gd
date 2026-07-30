class_name SkyGearWarmup
extends Node

## Compile every shader before the player can see it.
##
## The first benchmark of this port found a **150 ms worst frame during warmup**
## against an 8.5 ms steady state. That is not the game being slow; it is Godot
## compiling a shader pipeline the first time a material is actually drawn. In a
## fight it lands as a hitch precisely when something new happens — the first
## keg, the first Frost hit, the first time a boarder is silhouetted — which is
## the worst possible moment, because it is the moment the player is reacting to.
##
## Nothing about it shows up in an average. It is one frame, once, per material,
## and it is the single largest number the profiler has produced.
##
## The fix is to draw everything once, tiny and off to the side, before the run
## starts. Godot has no "compile this material" call — a pipeline is created when
## something is rendered with it — so the only honest way is to render it.
##
## Deliberately not `ubershader`/`shader_cache` settings: those help across runs
## on the same machine and do nothing on a first launch, which is when a person
## is deciding whether the game is smooth.

## Where the warm-up happens: below the hull, behind the camera, one frame.
const HIDE_AT := Vector3(0.0, -40.0, 0.0)
const HOLD_FRAMES := 3

var _props: Array[Node3D] = []
var _done := false


## Draw one of everything. Called by the renderer once its own materials exist,
## so this warms the ACTUAL materials rather than lookalikes — a pipeline is
## keyed on the material, and a copy with the same settings is a different
## pipeline and a second hitch.
func warm(view: SkyGearView3D) -> void:
	if _done:
		return
	_done = true

	## Every ground decal shape, at every blend the renderer uses. These are the
	## most common thing on screen and the most varied.
	for texture in [view._ring_texture(), view._streak_texture(), view._blob_texture(),
			view._spark_texture(), view._fan_texture(1.7, false),
			view._fan_texture(0.9, true), view._crate_texture(), view._grille_texture()]:
		for glowing in [true, false]:
			var decal := Decal.new()
			decal.texture_albedo = texture
			decal.texture_emission = view._glow_map(texture) if glowing else null
			decal.emission_energy = 1.0 if glowing else 0.0
			decal.albedo_mix = 1.0
			decal.size = Vector3(0.4, 0.4, 0.4)
			decal.position = HIDE_AT
			view.add_child(decal)
			_props.append(decal)

	## Every painted plate the fight uses, through the same billboard path.
	for path in ["res://assets/art/heroes/corsair_front_idle.png",
			"res://assets/art/enemies/automaton_front_idle.png",
			"res://assets/art/props/barrel.png",
			"res://assets/art/fx/burst_impact.png"]:
		var texture := view._texture(path)
		if texture == null:
			continue
		var sprite := Sprite3D.new()
		sprite.texture = texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.pixel_size = 0.0002
		sprite.position = HIDE_AT
		view.add_child(sprite)
		_props.append(sprite)

	## And one particle from each emitter. The particle shader is compiled on
	## first emission, not on creation, so an emitter that has never fired is an
	## emitter that will hitch the first time something dies.
	for family in view._sparks.keys():
		var emitter: GPUParticles3D = view._sparks[family]
		emitter.emit_particle(Transform3D(Basis(), HIDE_AT), Vector3.ZERO,
			Color.WHITE, Color.WHITE, GPUParticles3D.EMIT_FLAG_POSITION)


## Take it all down again. Called a few frames later — the pipelines are built
## and cached by then, and leaving forty invisible decals under the hull is
## forty decals in every frame for the rest of the run.
func cool() -> void:
	for node in _props:
		if is_instance_valid(node):
			node.queue_free()
	_props.clear()


func pending() -> int:
	return _props.size()
