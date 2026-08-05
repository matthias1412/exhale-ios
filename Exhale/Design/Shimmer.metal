#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// A slow caustic drift across the breathing orb.
///
/// The orb was a static radial gradient that only changed size. Breath moving
/// through something should look like it is moving *through* it, not like a
/// circle being scaled. Two offset sine fields at different rates give an
/// interference pattern that never repeats visibly and costs one pass.
///
/// Deliberately subtle — amplitude is capped low. This should read as the
/// surface being alive, not as a lava lamp.
[[ stitchable ]] half4 orbShimmer(float2 position, half4 colour,
                                  float2 size, float time, float strength) {
    if (colour.a < 0.01h) { return colour; }

    float2 uv = position / size;
    float2 centre = uv - 0.5;
    float radius = length(centre);

    // Two drifting fields, deliberately non-harmonic so they don't beat.
    float a = sin(uv.x * 7.3 + time * 0.55) * cos(uv.y * 6.1 - time * 0.41);
    float b = sin((uv.x + uv.y) * 4.7 - time * 0.33);
    float field = (a + b * 0.6) * 0.5;

    // Fade out toward the rim so the edge stays clean.
    float falloff = smoothstep(0.5, 0.08, radius);
    half lift = half(field * falloff * strength);

    return half4(colour.rgb + lift, colour.a);
}
