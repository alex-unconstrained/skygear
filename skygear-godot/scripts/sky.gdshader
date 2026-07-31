shader_type sky;

/*  THE SKYBOX — the browser's, put back, as a real sky.

    WHAT THE BROWSER ACTUALLY DID. `_render_world.js: drawEnvironment()` draws
    `assets/env/sky_backdrop.png` stretched over the WHOLE viewport, behind
    everything, then paints the deck on top. That painting is what the player
    remembers: a moon breaking through cloud at the upper left, banked purple
    cumulus across the middle, a warm ember low on the right. It is not at the
    horizon and it does not move — the horizon is 762 pixels above the top of a
    900-pixel window at this pitch, and the two scrolling cloud bands the
    browser also draws are pinned to that horizon, which means they have been
    rendered off the top of the screen for the whole life of the build. Measured,
    not assumed: `CAM.horizonY()` returns -761.58 at 1600x900.

    WHY A SKY SHADER RATHER THAN A QUAD. The player can pull the camera back with
    the wheel now, and zoom moves the camera along its own axis rather than
    widening the lens — so the angular field never changes and a background at
    INFINITY is invariant under it by construction. A quad pinned behind the deck
    is not: it sits at a finite distance, so pulling back slides it through the
    frame and shears it against the perspective. A sky shader also costs one
    pass over the pixels no geometry covered, which over the side of a deck that
    fills most of the frame is a few percent of it.

    THE MAPPING IS THE BROWSER'S OWN PROJECTION, RUN BACKWARDS. For a view
    direction, work out where that direction would have landed on the browser's
    screen at the shipped framing, and sample the painting there. At 1600x900 the
    two agree to the pixel: the browser's `_f` is 1320 * min(w/1400, h/860) =
    1381.40 with the principal point at (800, 450), so its half-height in tangent
    units is 450/1381.40 = 0.32576 — and Godot's camera is built from the same
    two numbers, tan(fov/2) = (860*0.5)/1320 = 0.32576. Same lens.

    THE REFERENCE ASPECT IS NOT AN ASSUMPTION. `project.godot` stretches
    `canvas_items` from a 1920x1080 base and leaves `stretch/aspect` at its
    default of `keep`, so the render target is 16:9 whatever the window is —
    asked for 1920x800 and got 1422x800 back. There is therefore no window this
    game can open in which the mapping is anything but exact. The clamp below is
    for the radiance capture and for a build that changes that setting, and it
    clamps rather than restretching on purpose: content should stay at a fixed
    ANGLE and a wider frame should simply show more sky.  */

uniform sampler2D backdrop : source_color, filter_linear_mipmap, repeat_disable;

/*  The camera's own constants, passed in from `view3d.gd` rather than written
    twice. Two functions disagreeing about one number is this project's most
    frequent visual bug and the sky is downstream of all four of them.  */
uniform float pitch = 0.72;
uniform float ref_tan = 0.32575758;
uniform float ref_aspect = 1.7777778;

/*  The painting arrives finished and then goes through Filmic tonemapping, a
    1.10 contrast lift and 15% of the depth fog on its way to the screen, all of
    which take it down. This puts it back.  */
uniform float energy = 1.0;

/*  And this pushes only the moon disc and the brightest cloud rims above 1.0 so
    the bloom already in the environment finds them. Anything under `moon_floor`
    is untouched, so the dark two-thirds of the painting do not glow.  */
uniform float moon_floor = 0.66;
uniform float moon_gain = 3.2;

/*  Every direction outside the reference frustum — which on screen means only
    the far corners of an ultrawide window, but during radiance capture means
    five sixths of the sphere. Flat, and the colour the painting averages to, so
    the ambient probe is not lit by whichever edge texel it happened to clamp
    against.  */
uniform vec3 away : source_color = vec3(0.12, 0.10, 0.18);

/*  One early exit and no `return`: a sky processor function is not allowed one,
    and the branch is uniform across every pixel of the radiance capture anyway.  */
void sky() {
	float sp = sin(pitch);
	float cp = cos(pitch);
	vec3 fwd = vec3(0.0, -sp, -cp);
	vec3 rgt = vec3(1.0, 0.0, 0.0);
	vec3 upv = vec3(0.0, cp, -sp);

	vec3 d = normalize(EYEDIR);
	float z = dot(d, fwd);
	vec3 col = away * energy;
	if (!AT_CUBEMAP_PASS && z > 0.05) {
		/*  Perspective divide, exactly as the browser's `CAM.project` does it,
		    then into texture space. The 0.5 is because `ref_tan` is a HALF
		    field.  */
		float sx = dot(d, rgt) / z;
		float sy = dot(d, upv) / z;
		vec2 uv = vec2(
			0.5 + sx * 0.5 / (ref_tan * ref_aspect),
			0.5 - sy * 0.5 / ref_tan);
		col = texture(backdrop, clamp(uv, vec2(0.0), vec2(1.0))).rgb * energy;
		col += pow(max(col - vec3(moon_floor), vec3(0.0)), vec3(2.0)) * moon_gain;
	}
	COLOR = col;
}
