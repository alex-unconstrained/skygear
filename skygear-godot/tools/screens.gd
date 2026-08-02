extends RefCounted

## PRELOADED, not `class_name`. Nothing under `tools/` is in the global class
## cache — that is populated by an editor import scan and these scripts are only
## ever run headless with `--script`, so a `class_name` here parses in the editor
## and fails on the command line. Both callers `preload` it.

## THE POSING MOVED (board SG-44). It lived here while the only callers were the
## text audit and the batch camera; then the owner asked to edit screens
## INTERACTIVELY and the F4 editor — `scripts/hud.gd`, which may not depend on
## `tools/` — needed the same poses. So the list, the sizes and `pose()` now
## live in `scripts/screen_poser.gd`, and this file is the tools' thin door to
## them. It stays so that every existing tool invocation and preload keeps
## working, and so that anything new under `tools/` has an obvious place to
## reach the poser from.
##
## ONE poser. The screens the audit measures, the batch page photographs and the
## F4 picker poses are the same dictionaries by construction — the harness
## asserts this file's list IS the poser's (`editor · the picker poses the batch
## tool's own screens — one list`). Do not grow a second list here.

const Poser := preload("res://scripts/screen_poser.gd")

const SCREENS := Poser.SCREENS
const SIZES := Poser.SIZES


static func find(name: String) -> Dictionary:
	return Poser.find(name)


static func slug(name: String) -> String:
	return Poser.slug(name)


static func pose(tree: SceneTree, game, hud, screen: Dictionary,
		size: Vector2) -> void:
	await Poser.pose(tree, game, hud, screen, size)
