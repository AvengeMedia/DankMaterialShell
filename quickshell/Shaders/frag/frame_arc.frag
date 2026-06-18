#version 450

// Frame perimeter ring with rounded cutout as one SDF.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float widthPx;
    float heightPx;
    float cutoutRadius;
    vec4 cutout;        // inner cutout edges in px: x=left y=top z=right w=bottom
    vec4 surfaceColor;  // straight (non-premultiplied) rgba
} ubuf;

float sdBox(vec2 p, vec2 c, vec2 hs) {
    vec2 q = abs(p - c) - hs;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0)));
}

float sdRoundBox(vec2 p, vec2 c, vec2 hs, float r) {
    r = min(r, min(hs.x, hs.y));
    vec2 q = abs(p - c) - hs + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.widthPx, ubuf.heightPx);
    vec2 sc = vec2(ubuf.widthPx, ubuf.heightPx) * 0.5;
    float dOuter = sdBox(px, sc, sc);
    vec2 cutC = vec2((ubuf.cutout.x + ubuf.cutout.z) * 0.5, (ubuf.cutout.y + ubuf.cutout.w) * 0.5);
    vec2 cutH = vec2((ubuf.cutout.z - ubuf.cutout.x) * 0.5, (ubuf.cutout.w - ubuf.cutout.y) * 0.5);
    float dCut = sdRoundBox(px, cutC, cutH, ubuf.cutoutRadius);
    float d = max(dOuter, -dCut);

    float fw = max(fwidth(d), 1e-4);
    float cov = 1.0 - smoothstep(-fw, fw, d);
    float a = ubuf.surfaceColor.a * cov * ubuf.qt_Opacity;
    fragColor = vec4(ubuf.surfaceColor.rgb * a, a);
}
