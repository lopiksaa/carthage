// The glass look's ground (Backdrop.qml), in the hardware's colours (c0..c3) over bg.
// variant: 0 Still · 1 Studio · 2 Light rays · 3 Mesh · 4 Iridescent · 5 Contours
// (Sam's picks from the Glass Lab). Every variant gets light from the top left, a vignette,
// the pointer's glow, the pulse ring and fine grain. dark: 1 night (light adds), 0 day (washes).
// Compile: /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o backdrop.frag.qsb backdrop.frag
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float variant;
    float aspect;
    float dark;
    vec4 bg;
    vec4 c0; vec4 c1; vec4 c2; vec4 c3;
    vec4 p0; vec4 p1; vec4 p2; vec4 p3;
    vec4 pointer;    // xy (0..1), z how present
    vec4 pulse;      // xy centre, z progress, w strength
    vec4 accent;
    float scroll;    // the library's scroll, in window heights
};

float h1(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 h2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float n2(vec2 p) {
    vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
    return mix(mix(dot(h2(i) * 2.0 - 1.0, f), dot(h2(i + vec2(1, 0)) * 2.0 - 1.0, f - vec2(1, 0)), u.x),
               mix(dot(h2(i + vec2(0, 1)) * 2.0 - 1.0, f - vec2(0, 1)), dot(h2(i + vec2(1, 1)) * 2.0 - 1.0, f - vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 6; i++) { s += a * n2(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
vec3 pickc(float k) {
    k = fract(k) * 4.0;
    return k < 1.0 ? mix(c0.rgb, c1.rgb, k) : k < 2.0 ? mix(c1.rgb, c2.rgb, k - 1.0) : k < 3.0 ? mix(c2.rgb, c3.rgb, k - 2.0) : mix(c3.rgb, c0.rgb, k - 3.0);
}
float field(vec2 uv, vec4 p) { return clamp(1.0 - length((uv - p.xy) / max(p.zw, vec2(0.01))) / 0.7, 0.0, 1.0); }

void main() {
    vec2 px = qt_TexCoord0;                       // screen position
    vec2 uv = px + vec2(0.0, scroll * 0.12);      // the ground sits deeper: it scrolls slower
    float as = aspect;
    vec2 q = uv * vec2(as, 1.0);
    float t = time;
    bool night = dark > 0.5;
    // Day: not paper-white — the ground takes a little of the colours (Sam: "too white").
    vec3 B = night ? bg.rgb : mix(bg.rgb, (c0.rgb + c1.rgb + c2.rgb + c3.rgb) * 0.25, 0.16) * 0.97;
    vec3 col = B;
    float wash = night ? 1.0 : 1.35;              // day: stronger colour
    int v = int(variant + 0.5);

    if (v == 1) {            // Studio: one soft light from the top left, breathing
        float l = 1.0 - smoothstep(0.0, 1.25, length((uv - vec2(0.12, -0.05)) * vec2(1.0, 1.3)));
        vec3 lc = mix(c0.rgb, c1.rgb, 0.5 + 0.5 * sin(t * 0.05));
        col = mix(B, mix(B, lc, min(0.9, 0.55 * wash)), l * (0.75 + 0.15 * sin(t * 0.11)));
        if (night) col += 0.06 * lc * fbm(q * 1.2 + t * 0.02);
    } else if (v == 2) {     // Light rays from the top left through a soft haze
        vec2 d = uv - vec2(-0.15, -0.25);
        float ang = atan(d.y, d.x), r = length(d);
        float beams = pow(0.5 + 0.5 * n2(vec2(ang * 9.0 + t * 0.05, t * 0.03)), 3.0)
                    + 0.6 * pow(0.5 + 0.5 * n2(vec2(ang * 23.0 - t * 0.04, 1.0)), 4.0);
        float haze = fbm(q * 2.0 + t * 0.02) * 0.5 + 0.5;
        vec3 lc = mix(c0.rgb, c3.rgb, 0.5 + 0.5 * sin(t * 0.04));
        float amt = beams * exp(-r * 1.1) * (0.6 + 0.4 * haze);
        col = night ? B + lc * amt * 0.55 : mix(B, mix(vec3(1.0), lc, 0.5), min(1.0, amt * 0.5 * wash));
    } else if (v == 3) {     // Mesh: four colours flowing into each other
        vec2 w = q + 0.35 * vec2(fbm(q * 0.9 + t * 0.03), fbm(q * 0.9 - t * 0.025 + 4.0));
        vec2 a0 = vec2(0.2 * as + 0.15 * sin(t * 0.07), 0.25 + 0.1 * cos(t * 0.05));
        vec2 a1 = vec2(0.8 * as + 0.12 * cos(t * 0.06), 0.2 + 0.12 * sin(t * 0.08));
        vec2 a2 = vec2(0.65 * as + 0.15 * sin(t * 0.05 + 2.0), 0.85 + 0.08 * cos(t * 0.07));
        vec2 a3 = vec2(0.25 * as + 0.12 * cos(t * 0.04 + 1.0), 0.8 + 0.1 * sin(t * 0.06));
        float k0 = 1.0 / pow(length(w - a0) + 0.15, 2.5), k1 = 1.0 / pow(length(w - a1) + 0.15, 2.5);
        float k2 = 1.0 / pow(length(w - a2) + 0.15, 2.5), k3 = 1.0 / pow(length(w - a3) + 0.15, 2.5);
        vec3 m = (c0.rgb * k0 + c1.rgb * k1 + c2.rgb * k2 + c3.rgb * k3) / (k0 + k1 + k2 + k3);
        col = mix(B, m, night ? 0.42 : 0.62);
    } else if (v == 4) {     // Iridescent: a thin-film sheen sliding across
        float f = fbm(q * 1.4 + vec2(t * 0.03, -t * 0.02)) + 0.5 * fbm(q * 3.0 + t * 0.05);
        vec3 film = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + f * 1.6 + t * 0.02));
        film = mix(film, pickc(f + t * 0.01), 0.45);
        float sheen = smoothstep(0.0, 0.9, 0.5 + 0.6 * fbm(q * 0.8 - t * 0.02));
        col = mix(B, film, (night ? 0.32 : 0.48) * sheen);
    } else if (v == 5) {     // Contours of a slowly shifting landscape
        float e = fbm(q * 1.6 + vec2(t * 0.015, t * 0.01));
        float ln = 1.0 - smoothstep(0.0, 0.06, abs(fract(e * 14.0) - 0.5));
        vec3 g = mix(pickc(uv.x * 0.4 + 0.1), pickc(uv.y * 0.4 + 0.6), 0.5);
        col = mix(B, g, night ? 0.22 : 0.36) + (night ? 1.0 : -1.0) * ln * 0.07 * mix(vec3(1.0), g, 0.5);
    } else {                 // Still: the design's four fields
        vec4 P[4] = vec4[4](p0, p1, p2, p3);
        vec4 C[4] = vec4[4](c0, c1, c2, c3);
        if (night) { for (int i = 0; i < 4; i++) col += C[i].rgb * C[i].a * field(uv, P[i]) * 1.5; col = col / (1.0 + max(col - 0.85, 0.0)); }
        else for (int i = 0; i < 4; i++) col = mix(col, C[i].rgb, clamp(C[i].a * field(uv, P[i]) * 2.0, 0.0, 0.9));
    }

    // Light from the top left, a vignette, the pointer's glow, the pulse, grain.
    col += (night ? 0.025 : 0.03) * (1.0 - smoothstep(0.0, 1.2, length(px - vec2(0.05, 0.0))));
    col *= 1.0 - (night ? 0.28 : 0.10) * smoothstep(0.45, 1.15, length((px - 0.5) * vec2(1.1, 1.3)));
    vec2 sp = vec2(as, 1.0);
    float glow = pointer.z * exp(-dot((px - pointer.xy) * sp, (px - pointer.xy) * sp) / 0.03);
    float dpx = length((px - pulse.xy) * sp);
    float ring = pulse.w * (1.0 - pulse.z) * exp(-pow((dpx - pulse.z * 0.9) / 0.06, 2.0));
    if (night) col += mix(c0.rgb, c1.rgb, 0.5) * 0.10 * glow + accent.rgb * 0.28 * ring;
    else col = mix(col, mix(vec3(1.0), accent.rgb, 0.35), clamp(0.25 * glow + 0.22 * ring, 0.0, 1.0));
    col += (h1(gl_FragCoord.xy + fract(time) * 61.0) - 0.5) * (night ? 0.035 : 0.025);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
