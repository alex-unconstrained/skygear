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

/*  AND THE STATUS, ON THE SAME RAIL (board SG-293).

    Burn, frost and stun had no channel on a boarder at all. `view3d.gd` carried
    a block that read `_billboards.get(key).modulate = tint` — and `_billboards`
    is the PAINTED-PLATE pool, null for every rigged figure in the game, so the
    line had been a no-op since the models were ingested. SG-141 found and fixed
    exactly that in `_xray` and left this one standing beside it.

    A SECOND INSTANCE UNIFORM RATHER THAN A SECOND PASS, for the same reason the
    first one is an instance uniform: twenty-one gremlins share one material and
    one compile, and each carries its own status.

    `rgb` is the ink and `a` is the strength, so one vec4 says both and there is
    no second parameter to keep in step with the first.

    ADDITIVE AND RIM-WEIGHTED, WHICH IS NOT WHAT THE DEAD LINE DID. That line
    MULTIPLIED a sprite — it made a frozen figure darker and bluer. On a deck
    whose entire readability argument is bright pops against #0D0B12, taking a
    figure DOWN to say something about it is the wrong direction: it costs
    contrast against the planking exactly when the player most needs to pick the
    boarder out. This adds a low, edge-biased glow instead, so the status reads
    on the silhouette and the figure underneath keeps its own material.

    HELD WELL UNDER THE FLASH. A hit is an event and must out-read a condition,
    so the status is capped far below `flash` and the two are summed rather than
    blended — a boarder struck WHILE burning gets the hit, plainly, and keeps its
    burn underneath it.  */
instance uniform vec4 status_ink = vec4(0.0, 0.0, 0.0, 0.0);

const vec3 FLASH_INK = vec3(1.0, 0.86, 0.62);

/*  The rim term. A flat additive pass lights the parts of the figure already
    facing the camera, which are the parts already lit; weighting toward the
    grazing angle puts the light on the EDGE, where a silhouette is read. Half
    flat, half rim — enough to see the whole figure react, biased to the part
    that carries the shape.  */
void fragment() {
    if (flash <= 0.001 && status_ink.a <= 0.001) {
        ALBEDO = vec3(0.0);
        ALPHA = 0.0;
    } else {
        float facing = clamp(dot(normalize(NORMAL), vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
        float rim = pow(1.0 - facing, 2.0);
        /*  The hit keeps its own weighting — half flat, half rim. The status is
            pushed harder onto the edge (a fifth flat, four fifths rim) because a
            condition has to be readable for seconds without ever becoming the
            thing the eye lands on, and an edge does that where a wash does not. */
        ALBEDO = FLASH_INK * flash * (0.45 + 0.55 * rim)
               + status_ink.rgb * status_ink.a * (0.20 + 0.80 * rim);
        ALPHA = 1.0;
    }
}
