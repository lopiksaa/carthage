// The glass look's ground: four colour fields in a chosen motion (Backdrop.qml).
// variant: 0 Still · 1 Drift · 2 Aurora · 3 Silk · 4 Lava.
// Dark hardware: the colours add light to a near-black ground (they glow, like neon through
// frosted glass). Light hardware: soft pastel washes over a bright ground.
// Compile: /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o backdrop.frag.qsb backdrop.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds (slow: everything takes a minute or more to come round)
    float variant;
    float aspect;    // width / height
    float dark;      // 1 = night (glow), 0 = day (pastel)
    vec4 bg;         // rgb
    vec4 c0; vec4 c1; vec4 c2; vec4 c3;   // rgb + strength
    vec4 p0; vec4 p1; vec4 p2; vec4 p3;   // centre xy, radii zw (fractions of the window)
    vec4 pointer;    // xy (0..1), z how present (0..1)
    vec4 pulse;      // xy centre (0..1), z progress (0..1), w strength
    vec4 accent;     // rgb: the pointer's glow and the pulse
    float scroll;    // parallax: the library's scroll, in window heights
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float gnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = dot(hash2(i) * 2.0 - 1.0, f);
    float b = dot(hash2(i + vec2(1, 0)) * 2.0 - 1.0, f - vec2(1, 0));
    float c = dot(hash2(i + vec2(0, 1)) * 2.0 - 1.0, f - vec2(0, 1));
    float d = dot(hash2(i + vec2(1, 1)) * 2.0 - 1.0, f - vec2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { s += a * gnoise(p); p = p * 2.02 + 17.1; a *= 0.5; }
    return s;
}

// How much field i shows at uv (0..1), with a falloff like the design's radial gradients.
float field(vec2 uv, vec4 p) {
    float d = length((uv - p.xy) / max(p.zw, vec2(0.01)));
    return clamp(1.0 - d / 0.7, 0.0, 1.0);
}

void main() {
    vec2 px = qt_TexCoord0;                      // the screen position
    vec2 uv = px + vec2(0.0, scroll * 0.12);      // the colours sit deeper: they scroll slower
    float t = time;
    vec4 P[4] = vec4[4](p0, p1, p2, p3);
    vec4 C[4] = vec4[4](c0, c1, c2, c3);
    float w[4] = float[4](0.0, 0.0, 0.0, 0.0);
    int v = int(variant + 0.5);

    if (v == 1) {            // Drift: the pools wander and breathe
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            vec2 c = P[i].xy + 0.11 * vec2(sin(t * (0.050 + 0.013 * fi) + fi * 1.7), cos(t * (0.041 + 0.011 * fi) + fi * 2.3));
            vec4 q = vec4(c, P[i].zw * (1.0 + 0.10 * sin(t * 0.07 + fi)));
            w[i] = field(uv, q);
        }
    } else if (v == 2) {     // Aurora: ribbons of light flowing sideways, brightest up top
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float y0 = 0.18 + 0.2 * fi + 0.07 * sin(uv.x * (2.2 + 0.4 * fi) + t * (0.10 + 0.02 * fi) + fi);
            float width = 0.07 + 0.04 * sin(uv.x * 3.1 - t * 0.06 + fi * 2.0);
            float band = exp(-pow((uv.y - y0) / max(width, 0.03), 2.0));
            float shimmer = 0.55 + 0.45 * sin(uv.x * 7.0 + t * 0.12 + fi * 1.3);
            w[i] = band * shimmer * (1.1 - 0.5 * uv.y);
        }
    } else if (v == 3) {     // Silk: one smooth gradient folding over itself
        vec2 p = uv * vec2(aspect, 1.0) * 1.6;
        vec2 q = vec2(fbm(p + vec2(0.0, t * 0.020)), fbm(p + vec2(5.2, 1.3) - vec2(t * 0.017, 0.0)));
        float r = fbm(p + 3.0 * q + vec2(1.7, 9.2) + t * 0.012);
        float s = clamp(0.5 + r * 1.4, 0.0, 1.0);
        float s2 = clamp(0.5 + q.x * 1.6, 0.0, 1.0);
        w[0] = (1.0 - s) * (1.0 - s2);
        w[1] = s * (1.0 - s2);
        w[2] = s2 * (1.0 - s);
        w[3] = s * s2;
        for (int i = 0; i < 4; i++) w[i] = smoothstep(0.05, 0.9, w[i]) * 0.95;
    } else if (v == 4) {     // Lava: blobs that merge and split
        vec2 p = uv * vec2(aspect, 1.0);
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float acc = 0.0;
            for (int j = 0; j < 2; j++) {
                float fj = float(j);
                vec2 c = vec2((P[i].x + 0.25 * fj) * aspect, P[i].y)
                       + vec2(0.22 * aspect * sin(t * (0.045 + 0.01 * fi) + fi * 2.1 + fj * 3.0),
                              0.25 * sin(t * (0.037 + 0.012 * fj) + fi * 1.3));
                float r = 0.16 + 0.05 * sin(t * 0.05 + fi + fj);
                acc += r * r / max(dot(p - c, p - c), 1e-4);
            }
            w[i] = smoothstep(0.55, 1.35, acc);
        }
    } else {                 // Still: the design's four fields
        for (int i = 0; i < 4; i++) w[i] = field(uv, P[i]);
    }

    vec3 col = bg.rgb;
    if (dark > 0.5) {
        // Night: the colours add light (they glow) and stay deep where they overlap.
        vec3 glow = vec3(0.0);
        for (int i = 0; i < 4; i++) glow += C[i].rgb * C[i].a * w[i];
        col = col + glow * 1.5;
        col = col / (1.0 + max(col - 0.85, 0.0));           // soft roll-off instead of clipping
        col *= 1.0 - 0.18 * smoothstep(0.35, 1.0, length(uv - vec2(0.5, 0.45)));   // a darker rim
    } else {
        // Day: soft pastel washes over a bright ground, a little light from the top left.
        for (int i = 0; i < 4; i++) col = mix(col, C[i].rgb, clamp(C[i].a * w[i] * 1.6, 0.0, 0.85));
        col = mix(col, vec3(1.0), 0.10 * (1.0 - smoothstep(0.0, 0.9, length(uv - vec2(0.15, 0.0)))));
    }
    // What you do: a soft glow that follows the pointer, and a ring of light from a pulse.
    vec2 sp = vec2(aspect, 1.0);
    float glow = pointer.z * exp(-dot((px - pointer.xy) * sp, (px - pointer.xy) * sp) / 0.045);
    float dpx = length((px - pulse.xy) * sp);
    float ring = pulse.w * (1.0 - pulse.z) * exp(-pow((dpx - pulse.z * 0.9) / 0.06, 2.0));
    if (dark > 0.5) col += accent.rgb * (0.10 * glow + 0.28 * ring);
    else col = mix(col, mix(vec3(1.0), accent.rgb, 0.35), clamp(0.22 * glow + 0.22 * ring, 0.0, 1.0));

    // Grain against banding (±1.2 levels), fixed in place.
    col += (hash(gl_FragCoord.xy) - 0.5) * (2.4 / 255.0);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
