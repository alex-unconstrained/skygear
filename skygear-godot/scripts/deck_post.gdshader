shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

/*  THE INK PASS — a screen-space edge over the whole deck, plus a vignette.

    WHY THIS GAME WANTS AN OUTLINE AND MOST 3D GAMES DO NOT. SkyGear's authored
    art is ink-rimmed: `_plate()` in `hud.gd` describes the house look as "dark
    fill, hard ink edge, brass inlay", every sprite in `assets/art/` carries a
    drawn rim, and the opening cinematic's whole brief is hand-painted
    brushwork. The 3D deck had no such line, so the meshes read as a different
    game from the art wrapped around them. This is the seam it closes.

    AND IT IS A READABILITY FIX BEFORE IT IS A STYLE ONE. Wave 11 opens with
    twenty-one gremlins in one frame, brass on brass, over ember-lit orange
    planking. The project has been fighting that legibility problem asset by
    asset for weeks — SG-141's x-ray silhouette, SG-113's fades, SG-94's contact
    shadows. An edge is the general answer: it separates every figure from every
    other figure and from the deck, for one pass over the pixels.

    DEPTH **AND** NORMAL, NOT DEPTH ALONE. A depth-only edge misses the join
    where two boarders overlap at the same distance from the camera — which on
    a deck where boarders walk in lanes abreast is the case that matters most.
    A normal-only edge draws a line down every crease in a rigged model and
    turns a figure into a wireframe. Together: depth catches the silhouette,
    normal catches the shoulder against the chest behind it, and the depth
    term's distance falloff keeps the far end of the deck from turning to lace.

    NOT A CompositorEffect. That is the modern door and it needs a
    RenderingDevice-level pass; this is a quad in front of the camera, which is
    the same technique the project's own `sky.gdshader` argues for in reverse —
    there a quad was WRONG because the background must be invariant under zoom,
    here it is right because the effect is defined in screen space by
    construction. `POSITION` is written directly, so the quad's own transform,
    size and distance from the camera are all irrelevant.

    FORWARD+ ONLY. `hint_normal_roughness_texture` does not exist in Mobile or
    Compatibility. The project is Forward+ (`view3d.gd` reasons about reverse-Z
    when it sets `camera.far`), and `view3d.gd::_arm_deck_post` refuses to
    install this pass on any other renderer rather than shipping a black screen.  */

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;

/*  Every one of these is a dial the FX lab can reach (`tools/fx_lab.gd` reads
    the same names out of `fx.json`), because "how strong is the outline" is a
    taste question and the answer belongs to whoever is looking at it.  */
uniform float outline_strength : hint_range(0.0, 1.0) = 0.55;
uniform float depth_threshold : hint_range(0.0, 4.0) = 0.55;
uniform float normal_threshold : hint_range(0.0, 2.0) = 0.62;
/*  Past this many metres the edge is gone. The far cloud layer sits at 640 and
    the deck's far end at roughly 30; drawing ink on cloud would put a hard line
    around a painted sky.  */
uniform float outline_far : hint_range(1.0, 200.0) = 46.0;
uniform vec3 ink_color : source_color = vec3(0.035, 0.027, 0.055);

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.28;
uniform float vignette_softness : hint_range(0.05, 1.5) = 0.62;

varying flat mat4 inv_proj;

void vertex() {
    /*  A 2x2 quad's own vertices ARE clip space. Writing POSITION skips the
        model/view/projection chain entirely, so this fills the screen at the
        far plane whatever the node's transform happens to be.  */
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
    inv_proj = INV_PROJECTION_MATRIX;
}

/*  Raw reverse-Z depth to metres in front of the camera. The project's camera
    is Forward+ and therefore reverse-Z, which is why this cannot be the usual
    `near*far / (far - d*(far-near))` — it has to go back through the real
    projection matrix.  */
float view_depth(vec2 uv) {
    float raw = texture(depth_tex, uv).r;
    vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, raw, 1.0);
    return -(view.z / view.w);
}

vec3 view_normal(vec2 uv) {
    return normalize(texture(normal_tex, uv).rgb * 2.0 - 1.0);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 base = texture(screen_tex, uv).rgb;
    vec2 texel = 1.0 / VIEWPORT_SIZE;

    float d0 = view_depth(uv);
    vec3 n0 = view_normal(uv);

    /*  Four taps on the cross, not eight on the ring. The diagonals cost twice
        as much and buy a line one pixel thicker on 45-degree edges, which at
        this camera pitch is almost every edge on the deck — so it reads as a
        uniformly fatter line rather than a better one.  */
    float depth_edge = 0.0;
    float normal_edge = 0.0;
    vec2 taps[4] = {vec2(texel.x, 0.0), vec2(-texel.x, 0.0),
                    vec2(0.0, texel.y), vec2(0.0, -texel.y)};
    for (int i = 0; i < 4; i++) {
        vec2 at = uv + taps[i];
        depth_edge = max(depth_edge, abs(view_depth(at) - d0));
        normal_edge = max(normal_edge, 1.0 - dot(view_normal(at), n0));
    }

    /*  The depth threshold grows with distance. A 0.55 m step is a silhouette
        two metres away and it is the thickness of a plank thirty metres away;
        holding one absolute threshold draws the far deck as a grid.  */
    float scale = 1.0 + d0 * 0.11;
    float edge = max(step(depth_threshold * scale, depth_edge),
                     step(normal_threshold, normal_edge));
    /*  ...and it fades out entirely before the sky. `d0` on an uncovered pixel
        comes back enormous, so this is also what keeps the ink off the sky
        shader's painting without a separate test for it.  */
    edge *= 1.0 - smoothstep(outline_far * 0.6, outline_far, d0);

    vec3 col = mix(base, ink_color, edge * outline_strength);

    /*  The vignette. Aspect-corrected, so a 2560-wide window does not get an
        oval — the project photographs every screen at four widths and an
        effect that changes shape between them is one more thing to explain.  */
    vec2 centred = (uv - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
    float fall = smoothstep(vignette_softness, vignette_softness + 0.55,
                            length(centred));
    col *= 1.0 - fall * vignette_strength;

    ALBEDO = col;
}
