#version 450

// Standalone elevation surface as a signed-distance field: one quad draws the
// rounded-rect fill, its border, and the M3 two-part shadow (directional key +
// non-directional ambient) analytically — no FBO, no blur passes. The shadow
// is masked to outside the silhouette, so translucent fills never get
// interior darkening.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float widthPx;
    float heightPx;
    float borderWidth;
    vec4 rectPx;        // rounded rect in item px: x, y, w, h
    vec4 cornerRadius;  // topLeft, topRight, bottomRight, bottomLeft
    vec4 fillColor;     // straight (non-premultiplied) rgba
    vec4 borderColor;   // straight rgba
    vec4 shadowColor;   // straight rgba; a = 0 disables both shadow terms
    vec4 shadowParam;   // key: x = blur px, y = spread px, z,w = offset px
    vec4 ambientParam;  // ambient: x = blur px, y = spread px, z = alpha
} ubuf;

// Per-corner rounded box. r = (topLeft, topRight, bottomRight, bottomLeft).
float sdRoundBox4(vec2 p, vec2 c, vec2 hs, vec4 r) {
    p -= c;
    float rr = (p.x >= 0.0) ? (p.y >= 0.0 ? r.z : r.y) : (p.y >= 0.0 ? r.w : r.x);
    rr = min(rr, min(hs.x, hs.y));
    vec2 q = abs(p) - hs + rr;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rr;
}

float rectDist(vec2 px) {
    vec2 hs = ubuf.rectPx.zw * 0.5;
    return sdRoundBox4(px, ubuf.rectPx.xy + hs, hs, ubuf.cornerRadius);
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.widthPx, ubuf.heightPx);
    float d = rectDist(px);
    float fw = max(fwidth(d), 1e-4);
    float cov = 1.0 - smoothstep(-fw, fw, d);
    // Qt Rectangle semantics: border band on the rim, fill inset inside it.
    float covInner = 1.0 - smoothstep(-fw, fw, d + ubuf.borderWidth);
    vec4 col = vec4(ubuf.fillColor.rgb, 1.0) * (ubuf.fillColor.a * covInner)
             + vec4(ubuf.borderColor.rgb, 1.0) * (ubuf.borderColor.a * max(0.0, cov - covInner));
    if (ubuf.shadowColor.a > 0.0) {
        float dk = rectDist(px - ubuf.shadowParam.zw) - ubuf.shadowParam.y;
        float bk = max(ubuf.shadowParam.x, fw);
        float covK = 1.0 - smoothstep(-bk, bk, dk);
        float ba = max(ubuf.ambientParam.x, fw);
        float covA = 1.0 - smoothstep(-ba, ba, d - ubuf.ambientParam.y);
        float sh = 1.0 - (1.0 - covK * ubuf.shadowColor.a) * (1.0 - covA * ubuf.ambientParam.z);
        col += vec4(ubuf.shadowColor.rgb, 1.0) * (sh * (1.0 - cov));
    }
    fragColor = col * ubuf.qt_Opacity;
}
