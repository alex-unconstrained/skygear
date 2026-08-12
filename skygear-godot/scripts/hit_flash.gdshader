shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

/*  THE HIT FLASH, MADE REAL (board SG-217).

    `SkyGearRig3D.react_hit()` has always set a `_flash` and pushed it out with
    `set_instance_shader_parameter("flash", ...)`, and `view3d.gd` wrote the
    verdict on that in the project's own words: it *"is a no-op against a
    StandardMaterial3D — it needs a shader that declares the uniform, which an
    imported glTF material does not"*. So the reaction has been running, decaying
    and costing a per-frame tree walk for the whole life of the port, against
    nothing. The squash half of `react_hit` was real; the white half was not.

    THIS IS THE MISSING DECLARATION, AND NOTHING ELSE. It is hung on each rig
    material's `next_pass`, so the imported glTF material keeps every one of its
    own properties — albedo, metallic, the normal map, the emission the furnace
    chests use — and this draws a second, additive pass over the same geometry.
    Replacing the material instead would have meant re-authoring seventeen
    imported looks to add one uniform.

    `instance uniform`, NOT `uniform`. That is the whole reason the call site
    works unchanged: an instance uniform is per-MeshInstance3D, so twenty-one
    gremlins share ONE ShaderMaterial and each still flashes on its own hit. A
    plain uniform would have made the whole wave flash together.

    WHY ADDITIVE AND NOT A WHITE ALBEDO. A hit reads as light coming OFF the
    figure, and additive keeps the silhouette — an albedo swap flattens a brass
    automaton into a white cut-out, which is exactly the "strobe" failure the
    board warns about. At `flash = 1.0` this lifts the figure toward white
    without erasing the shape underneath it.

    THE TINT IS EMBER, NOT WHITE. Every warm light on this deck comes from fire
    — braziers, the Boiler, firebox chests — and a pure-white pop reads as a
    rendering fault against that. `FLASH_INK` is the same brass-lit warmth the
    HUD uses for a landed blow.  */

instance uniform float flash : hint_range(0.0, 1.0) = 0.0;

const vec3 FLASH_INK = vec3(1.0, 0.86, 0.62);

/*  The rim term. A flat additive pass lights the parts of the figure already
    facing the camera, which are the parts already lit; weighting toward the
    grazing angle puts the light on the EDGE, where a silhouette is read. Half
    flat, half rim — enough to see the whole figure react, biased to the part
    that carries the shape.  */
void fragment() {
    if (flash <= 0.001) {
        ALBEDO = vec3(0.0);
        ALPHA = 0.0;
    } else {
        float facing = clamp(dot(normalize(NORMAL), vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
        float rim = pow(1.0 - facing, 2.0);
        ALBEDO = FLASH_INK * flash * (0.45 + 0.55 * rim);
        ALPHA = 1.0;
    }
}
