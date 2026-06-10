#version 450

// Connected Frame Mode silhouette as a signed-distance field: the frame ring
// (an inverted rounded rectangle) smooth-unioned with each active chrome
// (popout/modal, dock, notification). The smooth-min radius IS the connector
// fillet. Antialiasing is analytic via fwidth -> crisp at any scale, no FBO.
// The elevation shadow samples the same field at the light offset, so both
// elevation states render in this one pass.

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
    vec4 shadowColor;   // straight rgba; a = 0 disables both shadow terms
    vec4 shadowParam;   // key: x = blur px, y = spread px, z,w = offset px
    vec4 ambientParam;  // ambient: x = blur px, y = spread px, z = alpha
    // Up to four chrome slots. rect = x,y,w,h (px). corner = per-corner radii,
    // k = per-corner junction fillet radii (both topLeft, topRight, bottomRight,
    // bottomLeft; a corner is sharp exactly where its k > 0). param = active, 0, 0, 0
    vec4 chromeRect0;
    vec4 chromeCorner0;
    vec4 chromeK0;
    vec4 chromeParam0;
    vec4 chromeRect1;
    vec4 chromeCorner1;
    vec4 chromeK1;
    vec4 chromeParam1;
    vec4 chromeRect2;
    vec4 chromeCorner2;
    vec4 chromeK2;
    vec4 chromeParam2;
    vec4 chromeRect3;
    vec4 chromeCorner3;
    vec4 chromeK3;
    vec4 chromeParam3;
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

// Per-corner rounded box. r = (topLeft, topRight, bottomRight, bottomLeft).
float sdRoundBox4(vec2 p, vec2 c, vec2 hs, vec4 r) {
    p -= c;
    float rr = (p.x >= 0.0) ? (p.y >= 0.0 ? r.z : r.y) : (p.y >= 0.0 ? r.w : r.x);
    rr = min(rr, min(hs.x, hs.y));
    vec2 q = abs(p) - hs + rr;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rr;
}

// Circular smooth-min: blends two SDFs with a fillet of radius k.
float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float chromeDist(vec2 px, vec4 rect, vec4 corner) {
    vec2 c = rect.xy + rect.zw * 0.5;
    return sdRoundBox4(px, c, rect.zw * 0.5, corner);
}

// Per-corner junction fillet radius, selected by chrome-rect quadrant.
float chromeK(vec2 px, vec4 rect, vec4 ks) {
    vec2 p = px - (rect.xy + rect.zw * 0.5);
    return (p.x >= 0.0) ? (p.y >= 0.0 ? ks.z : ks.y) : (p.y >= 0.0 ? ks.w : ks.x);
}

float sceneDist(vec2 px) {
    // Frame ring: inside the screen rect AND outside the rounded cutout (hole).
    vec2 sc = vec2(ubuf.widthPx, ubuf.heightPx) * 0.5;
    float dOuter = sdBox(px, sc, sc);
    vec2 cutC = vec2((ubuf.cutout.x + ubuf.cutout.z) * 0.5, (ubuf.cutout.y + ubuf.cutout.w) * 0.5);
    vec2 cutH = vec2((ubuf.cutout.z - ubuf.cutout.x) * 0.5, (ubuf.cutout.w - ubuf.cutout.y) * 0.5);
    float dCut = sdRoundBox(px, cutC, cutH, ubuf.cutoutRadius);
    float d = max(dOuter, -dCut);

    // Smooth-union the active chrome surfaces; smin radius = junction fillet.
    if (ubuf.chromeParam0.x > 0.5)
        d = smin(d, chromeDist(px, ubuf.chromeRect0, ubuf.chromeCorner0), chromeK(px, ubuf.chromeRect0, ubuf.chromeK0));
    if (ubuf.chromeParam1.x > 0.5)
        d = smin(d, chromeDist(px, ubuf.chromeRect1, ubuf.chromeCorner1), chromeK(px, ubuf.chromeRect1, ubuf.chromeK1));
    if (ubuf.chromeParam2.x > 0.5)
        d = smin(d, chromeDist(px, ubuf.chromeRect2, ubuf.chromeCorner2), chromeK(px, ubuf.chromeRect2, ubuf.chromeK2));
    if (ubuf.chromeParam3.x > 0.5)
        d = smin(d, chromeDist(px, ubuf.chromeRect3, ubuf.chromeCorner3), chromeK(px, ubuf.chromeRect3, ubuf.chromeK3));
    return d;
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.widthPx, ubuf.heightPx);
    float d = sceneDist(px);
    float fw = max(fwidth(d), 1e-4);
    float cov = 1.0 - smoothstep(-fw, fw, d);
    // Opaque silhouette over shadow, then the surface alpha applied to the
    // whole result — matches the old flattened-FBO + group-opacity look.
    vec4 col = vec4(ubuf.surfaceColor.rgb, 1.0) * cov;
    if (ubuf.shadowColor.a > 0.0) {
        float dk = sceneDist(px - ubuf.shadowParam.zw) - ubuf.shadowParam.y;
        float bk = max(ubuf.shadowParam.x, fw);
        float covK = 1.0 - smoothstep(-bk, bk, dk);
        // Ambient wrap reuses the field already computed for the silhouette.
        float ba = max(ubuf.ambientParam.x, fw);
        float covA = 1.0 - smoothstep(-ba, ba, d - ubuf.ambientParam.y);
        float sh = 1.0 - (1.0 - covK * ubuf.shadowColor.a) * (1.0 - covA * ubuf.ambientParam.z);
        col += vec4(ubuf.shadowColor.rgb, 1.0) * (sh * (1.0 - col.a));
    }
    fragColor = col * (ubuf.surfaceColor.a * ubuf.qt_Opacity);
}
