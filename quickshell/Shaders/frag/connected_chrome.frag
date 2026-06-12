#version 450

// Popout-local connected chrome body + bar-edge connector as one SDF.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float widthPx;
    float heightPx;
    vec4 surfaceColor;  // straight (non-premultiplied) rgba
    vec4 shadowColor;   // straight rgba; a = 0 disables both shadow terms
    vec4 shadowParam;   // key: x = blur px, y = spread px, z,w = offset px
    vec4 ambientParam;  // ambient: x = blur px, y = spread px, z = alpha
    vec4 bodyRect;      // body rounded rect in item px: x, y, w, h
    vec4 cornerRadius;  // topLeft, topRight, bottomRight, bottomLeft
    vec4 edgeParam;     // x = bar side (0 top, 1 bottom, 2 left, 3 right), y = fillet k
} ubuf;

float sdRoundBox4(vec2 p, vec2 c, vec2 hs, vec4 r) {
    p -= c;
    float rr = (p.x >= 0.0) ? (p.y >= 0.0 ? r.z : r.y) : (p.y >= 0.0 ? r.w : r.x);
    rr = min(rr, min(hs.x, hs.y));
    vec2 q = abs(p) - hs + rr;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rr;
}

float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

float sceneDist(vec2 px) {
    float side = ubuf.edgeParam.x;
    float dEdge = side < 0.5 ? px.y
                : side < 1.5 ? (ubuf.heightPx - px.y)
                : side < 2.5 ? px.x
                : (ubuf.widthPx - px.x);
    vec2 hs = ubuf.bodyRect.zw * 0.5;
    float dBody = sdRoundBox4(px, ubuf.bodyRect.xy + hs, hs, ubuf.cornerRadius);
    return smin(dEdge, dBody, ubuf.edgeParam.y);
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.widthPx, ubuf.heightPx);
    float d = sceneDist(px);
    float fw = max(fwidth(d), 1e-4);
    float cov = 1.0 - smoothstep(-fw, fw, d);
    vec4 col = vec4(ubuf.surfaceColor.rgb, 1.0) * cov;
    if (ubuf.shadowColor.a > 0.0) {
        float dk = sceneDist(px - ubuf.shadowParam.zw) - ubuf.shadowParam.y;
        float bk = max(ubuf.shadowParam.x, fw);
        float covK = 1.0 - smoothstep(-bk, bk, dk);
        float ba = max(ubuf.ambientParam.x, fw);
        float covA = 1.0 - smoothstep(-ba, ba, d - ubuf.ambientParam.y);
        float sh = 1.0 - (1.0 - covK * ubuf.shadowColor.a) * (1.0 - covA * ubuf.ambientParam.z);
        col += vec4(ubuf.shadowColor.rgb, 1.0) * (sh * (1.0 - col.a));
    }
    fragColor = col * (ubuf.surfaceColor.a * ubuf.qt_Opacity);
}
