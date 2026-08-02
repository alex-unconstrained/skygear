class_name LabMath
extends RefCounted

## Pure, headless-testable math and parsing for the model lab (tools/model_lab.gd).
##
## It lives OUTSIDE the tool on purpose. The lab is a windowed SceneTree and the
## screenshot/readback path hangs under `--headless` on this machine (board
## SG-29), so the tool itself cannot be driven by the harness. The two things
## SG-39 had to get right — rotation nudges that stay distinct at the gimbal
## singularity, and a typed-input parser that accepts and refuses correctly —
## are arithmetic, and arithmetic can be pulled out to a `class_name` the harness
## loads and asserts directly. That is what this file is.


## The Euler order `Node3D.rotation` uses by default — measured `= EULER_ORDER_YXZ`
## (2) on 4.7.1 — and therefore the order `SkyGearRig3D.hold` applies a fit's
## stored `rotation` array in (it writes `holder.rotation = Vector3(...)`). Every
## basis<->euler conversion here MUST use it, or a fit saved as a basis loads to a
## different pose than it saved from.
const FIT_EULER_ORDER := EULER_ORDER_YXZ


## A weapon fit's stored `rotation` [x, y, z] in DEGREES -> the Basis that
## `hold()` builds from it. This is exactly what the old lab produced when it
## passed the Euler triple straight through.
static func fit_basis(rotation_deg: Vector3) -> Basis:
	return Basis.from_euler(Vector3(
		deg_to_rad(rotation_deg.x),
		deg_to_rad(rotation_deg.y),
		deg_to_rad(rotation_deg.z)), FIT_EULER_ORDER)


## A Basis back to a fit's stored `rotation` [x, y, z] in DEGREES. Used at SAVE
## time so the file format stays Euler and existing weapons.json reads unchanged.
static func fit_euler_deg(basis: Basis) -> Vector3:
	var e := basis.get_euler(FIT_EULER_ORDER)
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))


## Rotate a basis about ONE of the weapon's OWN live local axes
## (0 = X / PITCH, 1 = Y / YAW, 2 = Z / ROLL) by `degrees`.
##
## THE GIMBAL-COLLAPSE FIX. Near a +/-90 Euler pitch the stored yaw and roll axes
## coincide, so incrementing the Euler yaw component and incrementing the Euler
## roll component build the SAME basis — measured identical to 1.6e-8 at pitch
## -90, which is the "yaw and roll do the same thing" the owner reported. The
## live local X, Y and Z of the basis, by contrast, are always mutually
## perpendicular, so a rotation about each is always a visibly different result
## (measured 0.59 apart at that same pitch). Composing the axis rotation onto the
## current basis — never touching an Euler field — is what keeps the three rows
## distinct at every orientation. Orthonormalized so repeated nudges never let
## float error drift the basis off the rotation group.
static func rotate_local(basis: Basis, axis: int, degrees: float) -> Basis:
	var local := (basis * axis_unit(axis)).normalized()
	return basis.rotated(local, deg_to_rad(degrees)).orthonormalized()


## The unit vector for a local axis index. X = (1,0,0), Y = (0,1,0), Z = (0,0,1).
static func axis_unit(axis: int) -> Vector3:
	if axis == 0:
		return Vector3(1.0, 0.0, 0.0)
	if axis == 1:
		return Vector3(0.0, 1.0, 0.0)
	return Vector3(0.0, 0.0, 1.0)


## Parse a typed numeric entry. Returns {"ok": bool, "value": float}.
##
## Accepts an integer or decimal with an optional sign and surrounding space
## ("0.303", " -96 ", "+.5"); refuses empty, blank, or anything with a stray
## character ("12deg", "1,5", "abc"). On refusal the caller keeps the old value —
## a malformed entry never moves the weapon.
static func parse_number(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "" or not t.is_valid_float():
		return {"ok": false, "value": 0.0}
	return {"ok": true, "value": t.to_float()}


## How far apart two bases read, as the summed drift of their three axis columns.
## Zero is the same orientation; the lab and the harness both use it to judge
## "same visible pose" and "distinct rows".
static func basis_drift(a: Basis, b: Basis) -> float:
	return (a.x - b.x).length() + (a.y - b.y).length() + (a.z - b.z).length()
