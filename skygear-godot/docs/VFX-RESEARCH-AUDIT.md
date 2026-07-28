# SkyGear Godot rendering and VFX research audit

Written 2026-07-28 against Godot 4.7 and the current isolated Godot port.

This is a research and implementation brief. It does not authorize changes to
the original browser SkyGear files.

## Executive verdict

Forward+ is the right primary renderer for a Windows-first SkyGear build. Its
clustered lights, decals, SSAO, HDR pipeline, volumetric fog, and GPU particles
suit the small but effects-heavy 3D deck.

The current direction is strong, particularly:

- The locked perspective camera and hybrid 2D simulation/3D presentation.
- Projected `Decal` effects instead of coplanar quads.
- Separate visual RNG.
- Ground shadows beneath airborne projectiles.
- A strict distinction between gameplay-readable effects and decoration.
- Soft-light glow, a cool key light, warm practical lights, and cheap distance
  fog.

Before adding more spectacle, correct the architectural and factual issues
below.

## Highest-priority audit findings

### 1. Forward+ does not necessarily mean Vulkan

The renderer and rendering driver are separate. Forward+ can run through Vulkan
or Direct3D 12 on Windows. The project does not explicitly select a driver, so
the design document's "Forward+ (Vulkan)" assumption should not be trusted.

Implementation guidance:

- Query `RenderingServer.get_current_rendering_method()` and
  `RenderingServer.get_current_rendering_driver_name()` at runtime.
- Test both D3D12 and Vulkan release builds.
- Select the default based on first-run stutter, frame pacing, visual
  correctness, and driver coverage.
- Never silently assume a Compatibility fallback will look correct:
  Compatibility does not support decals, so core telegraphs could disappear.
- Either provide a floor-quad fallback for Compatibility or show a clear
  unsupported-renderer message.

References:

- [Internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html)
- [ProjectSettings](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html)

### 2. The existing "pools" are not actually pools

In `scripts/view3d.gd`, unused billboards and decals are `queue_free()`d every
frame and recreated when needed. That is node/resource churn, not pooling.

Build fixed-capacity pools for:

- Gameplay decals.
- Decorative decals.
- Impact emitters.
- Light flashes.
- Projectile heads and ribbons.
- Floating numbers.
- Ground-shadow instances.

Nodes should be created during loading, then claimed, reset, hidden, and
returned. Gameplay-critical effects get reserved capacity and are never
displaced by decorative effects.

Initial budgets to profile:

| Pool | Starting capacity |
|---|---:|
| Hostile telegraphs | 48 |
| Player shapes/fields | 16 |
| Decorative/scorch decals | 16 |
| Impact particles | 512 live particles total |
| Impact light flashes | 8 |
| Projectile ribbons | 24 |
| Persistent aura bodies | 4 |
| Full-screen post effects | 1 |

### 3. Revise the proposed particle architecture

The existing plan recommends four `GPUParticles3D` systems, one per element,
and varying `amount_ratio` by damage. That is not the best model.

Godot notes that reducing `amount_ratio` does not reduce processing cost because
capacity remains allocated. Restarting a shared one-shot emitter also disrupts
overlapping impacts. `GPUParticles3D.emit_particle()` can instead inject
particles with individual transforms, velocity, color, and custom data.

Use one shared emitter per behavior family, not per element:

- Sparks and hot fragments.
- Smoke and steam.
- Frost shards.
- Heavy debris.
- Small motes/energy wisps.

Pass element color, magnitude, direction, and variation per emitted particle.
Use:

- `local_coords = false`.
- Fixed capacity determined by the stress test.
- `fixed_fps = 30` with interpolation.
- `preprocess = 0`.
- Accurate visibility AABBs.
- Alpha and scale curves.
- Shared immutable draw materials.
- No particle collision unless a measured playtest proves it materially
  improves readability.

Reference:

- [GPUParticles3D](https://docs.godotengine.org/en/4.7/classes/class_gpuparticles3d.html)

### 4. Colored light is still a hue cue

The plan says element identity should move "through light, not hue," but colored
light remains hue-based. It cannot be the accessibility solution by itself.

Give each element a shape, timing, and motion signature:

- Ember: rising embers, radial lick, longer fading light.
- Frost: sharp outward shards, crystalline star silhouette, immediate decay.
- Arc: branching geometry and a localized double pulse.
- Steam: expanding soft ring, upward billow, slow dissolution.

Keep eight pooled `OmniLight3D` flashes as reinforcement. They should be
shadowless, distance-faded, short-ranged, and have
`volumetric_fog_energy = 0` to avoid temporal fog trails.

## Renderer and image-quality configuration

Recommended shipping presets:

| Feature | Low | Medium/default | High |
|---|---|---|---|
| Renderer | Forward+ | Forward+ | Forward+ |
| 3D scale | 0.80-0.90 | 1.0 | 1.0 |
| Upscaling | Bilinear or FSR1 | Native | Native |
| 3D MSAA | Off/2x | 2x | 4x |
| TAA/FSR2 | Off | Off | Optional, tested |
| Glow | Reduced | On | On, bicubic upscale |
| SSAO | Off | Low | On |
| Volumetric fog | Off | Off | Optional |
| Dynamic impact lights | 4 | 8 | 8 |
| Shadow quality | Low | Medium | High |

For this mixture of painted billboards, thin telegraphs, and a mostly fixed
camera, native rendering with 2x or 4x MSAA is a better default than TAA.
Temporal techniques can smear projectile heads, aura edges, animated
billboards, and camera shake. FSR2 should be an opt-in option for high
resolutions only, after ghosting tests.

Keep the HUD at native resolution while scaling only the 3D buffer.

Reference:

- [Resolution scaling](https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html)

## Tonemapping, glow, and grading

The current environment enables glow, SSAO, contrast, and saturation, but it
does not explicitly choose a tonemapper.

Implementation guidance:

- Set a tonemapper explicitly.
- A/B test Filmic against AgX.
- Prefer AgX on High if its improved preservation of bright hues materially
  helps the four elements.
- Keep exposure fixed during gameplay.
- Leave auto exposure off; explosions should not dim telegraphs or make the
  entire deck visibly pump.
- Replace ad hoc contrast/saturation adjustments with a deliberate
  color-correction LUT once the palette is locked.
- Enable debanding if fog or dusk gradients show banding.
- Keep glow selective: exact telegraph boundaries should remain sharp, with
  bloom added outside them as a secondary halo.
- Maintain separate albedo and premultiplied emission maps for decals.

Do not enable display HDR yet. Internal HDR rendering for bloom is useful; HDR
monitor output is a separate feature that needs its own calibration UI and
display testing.

Reference:

- [Environment and post-processing](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)

## Decals and ground readability

The current decal conversion is fundamentally correct, including the
premultiplied emission-map fix. However, one projection policy should not serve
every effect.

Create three receiver/use policies:

### Gameplay telegraphs

- Project onto the deck only.
- Use a dedicated floor receiver layer.
- Keep the projection box shallow.
- Preserve an exact non-blooming boundary.
- Never allow cargo sides to distort the apparent damage footprint.

### Impact and scorch decoration

- May project onto deck and props.
- Use normal fade and distance fade where appropriate.
- Cap persistent marks and evict the oldest decorative mark first.

### Contact and projectile shadows

- Do not use individual `Decal` nodes.
- The deck is planar, so use a shared `MultiMeshInstance3D` of blob quads.
- This avoids dozens of clustered decals and lets all identical shadows render
  as one managed batch.

Reference:

- [Decal](https://docs.godotengine.org/en/4.7/classes/class_decal.html)

## Transparency and billboards

Overlapping transparent surfaces are a major GPU cost, and automatically
instanced opaque objects do not extend to alpha-blended geometry.

Implementation guidance:

- Use alpha scissor, alpha hash, or opaque prepass for character billboards
  where visual quality permits.
- Reserve alpha blending for soft particles, aura haze, and additive light
  effects.
- Disable shadow casting on particles, airstream streaks, aura geometry, and
  most billboards if blob shadows already carry grounding.
- Atlas compatible VFX textures, with padded borders to prevent mip bleeding.
- Keep albedo textures in sRGB and normal/ORM data linear.
- Use mipmaps for world sprites and anisotropic filtering on the deck.
- Consider Forward+/Mobile high-quality VRAM compression for large color
  textures.

Reference:

- [GPU optimization](https://docs.godotengine.org/en/latest/tutorials/performance/gpu_optimization.html)

## Specific effect recommendations

### Impact feedback

Implement together:

- Particle burst.
- Damage-scaled camera trauma.
- Small shadowless light flash.
- Existing damage number.
- Optional localized ground flash.

Use approximately 20-35 ms of simulation hit-stop on strong normal hits and
40-70 ms on kills or boss impacts. Do not freeze the entire engine globally:
UI, particles, audio envelopes, and accessibility overlays should keep
updating.

Camera shake should be additive to ship sway, use visual RNG, decay through a
smooth envelope, and have a reduced-motion alternative.

### Projectile trails and chain effects

Do not create an `ImmediateMesh` per projectile every frame.

Prefer:

- One preallocated ribbon batch for all gameplay projectiles, updated once per
  frame; or
- Built-in particle `RibbonTrailMesh` where the projectile can sensibly be
  represented as a particle system.

Keep projectile ground shadows separate because they communicate collision
position better than the airborne trail.

Use at most 6-10 stored points per normal bolt, width tapering toward zero, and
a hard global ribbon budget.

Reference:

- [3D particle trails](https://docs.godotengine.org/en/4.7/tutorials/3d/particles/trails.html)

### Aura and fields

The exact ground ring is the gameplay effect. Everything above it is optional
reinforcement.

Default implementation:

- Exact floor ring.
- Sparse upward particles.
- One or two camera-facing mist cross-quads.
- Element-specific edge motif.

High-only implementation:

- Small `FogVolume`, after profiling.
- Global volumetric density at zero if only local volumes are needed.
- Limited fog range and low froxel resolution.
- Reduced or disabled temporal reprojection for a player-following volume.

Moving fog volumes and short-lived lights can ghost under temporal
reprojection. Billboarded fog quads are generally cheaper and better for
fast-moving effects.

The existing plan should not default volumetric fields on based only on
"Windows" or an integrated/dedicated GPU label. Use the quality preset and an
actual benchmark.

Reference:

- [Volumetric fog and fog volumes](https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html)

### Airstream and clouds

The current 48 individual transparent airstream meshes should become:

- A single `GPUParticles3D` stream, or
- One manually managed `MultiMeshInstance3D`.

Additive streak ordering is not important, making it a good candidate for
explicit instancing.

Merge cloud bands where practical or move far clouds into a lightweight sky
shader. Do not add volumetric clouds; painted layered clouds match SkyGear's art
direction and are much cheaper.

### Weapon trail

Use a `BoneAttachment3D` on the captain's hand and drive the trail from the
animation, not a gameplay timer. Activate it only during the authored swing
window.

Use a ribbon with:

- Hot narrow core.
- Wider low-opacity outer arc.
- Width and alpha taper.
- Element motif.
- No collision or shadow.
- Reduced-motion version that keeps only the exact attack arc.

### Screen effects

Prefer cheap overlays:

- Damage vignette.
- Brief desaturation on near-death.
- Warm Boiler-critical pulse.
- Boss-transition letterbox/grade.

Avoid continuous chromatic aberration, radial blur, and distortion. They reduce
combat readability and require screen reads or compositor work. If used,
restrict them to a prewarmed, sub-150 ms ultimate or boss transition and
disable them under reduced motion.

A custom `CompositorEffect` should be the last tool added, after built-in
Environment effects and simple `CanvasLayer` overlays.

Reference:

- [Shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/)

## Lighting and materials

Keep:

- One shadowed steel-blue directional key.
- One unshadowed warm directional fill.
- Small practical lantern lights.
- Painted pools beneath practical lights.

Improve:

- Tighten the directional shadow distance around the actual visible deck
  instead of the current 60-meter maximum.
- Tune shadow bias and normal bias against the deck/cargo geometry.
- Use only one shadowed directional light.
- Keep all impact and practical omni lights shadowless.
- Add distance fading to small lights.
- Prevent short-lived lights from interacting with volumetric fog.
- Reduce SSAO if it double-darkens the manually painted contact shadows.

Do not add SDFGI, VoxelGI, or SSR. They offer little benefit to this fixed,
stylized, compact deck. A single static reflection probe may be worth testing
for brass and the captain's PBR material, but only after the core VFX pass.

Before writing a custom deck shader, improve the existing
`StandardMaterial3D` with:

- Subtle normal detail along plank grain.
- Roughness variation.
- A restrained ORM map.
- Proper metallic values only on actual metal.
- Optional low-frequency cloud shadow modulation.

## Shader-stutter prevention

This must be treated as a release requirement.

Implementation guidance:

- Instantiate every particle system, material mode, decal family, ribbon, light
  type, and optional post effect during loading.
- Render the warm-up scene for at least one hidden/offscreen frame before
  gameplay.
- Avoid switching material features such as transparency, blend mode, shadow
  mode, or motion vectors for the first time during combat.
- Watch the pipeline-compilation monitors; there should be no `Surface` or
  `Draw` spikes after the first wave starts.
- Enable the export preset's shader baker.

Important: Godot's shader baker is not supported during a headless export
because it requires GPU access. The production export path must therefore
include a GPU-capable non-headless baking step.

Reference:

- [Reducing stutter from shader compilations](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html)

## Validation requirements

Acceptance gates:

- 60 FPS target with a 16.67 ms frame budget.
- Rendering GPU time below roughly 10 ms on the chosen minimum-spec machine.
- No first-use hitch when any element, projectile, aura, boss effect, or screen
  effect appears.
- No gameplay allocation/free spikes during a maximum-density fight.
- No missing telegraphs under the actual renderer/driver.
- No cosmetic RNG calls changing simulation RNG.
- All effect pools remain within their caps.
- Gameplay-critical effects are never dropped to preserve decoration.
- Exact telegraph boundaries remain readable with glow disabled.
- Element identity remains understandable in grayscale.
- Reduced-motion mode removes sway, shake, distortion, and full-screen flashes
  without removing mechanical information.

Required stress captures:

- First launch after clearing the shader/pipeline cache.
- Maximum boarder count.
- Keg chain reaction amid multiple telegraphs.
- Four simultaneous player fields/passives.
- Maximum hostile projectile count.
- Boiler-critical lighting plus boss effects.
- 1280x720, 1366x768, 1920x1080, 2560x1440, and ultrawide.
- Medium and High presets on both D3D12 and Vulkan.
- Visual Profiler capture with transparent effects at peak density.

Use Godot's Visual Profiler and pipeline-compilation monitors, and report
average, 95th-percentile, and worst-frame times, not only FPS.

Reference:

- [Visual Profiler](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/debugger_panel.html)

## Recommended implementation order

1. Replace per-frame node destruction with real pools.
2. Add runtime renderer/driver reporting and a non-Forward+ safety path.
3. Add explicit tonemapping, quality presets, MSAA, and reduced motion.
4. Build manual-emission impact particle families.
5. Add capped shadowless impact lights with non-hue identity.
6. Move contact/projectile shadows to one MultiMesh.
7. Batch projectile ribbons.
8. Replace the 48 airstream meshes with GPU particles or MultiMesh.
9. Refine aura particles/quads; profile `FogVolume` only on High.
10. Add an animation-driven weapon trail.
11. Add shader warm-up and GPU-enabled export baking.
12. Only then consider custom compositor effects, reflection probes, or more
    elaborate deck shading.

This sequence should improve both spectacle and frame consistency while
protecting the information hierarchy that already makes SkyGear playable.
