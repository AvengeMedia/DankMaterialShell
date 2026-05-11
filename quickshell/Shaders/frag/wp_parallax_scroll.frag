// ===== wp_parallax_scroll.frag =====
// Minimal parallax scrolling shader - single texture, UV offset only
// For performance debugging - isolated from transition effects
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float scrollX;      // 0-100 scroll position
    float scrollY;      // 0-100 scroll position
    float uvScaleX;     // Pre-computed: screenWidth / scaledImageWidth
    float uvScaleY;     // Pre-computed: screenHeight / scaledImageHeight
    float scrollRangeX; // Pre-computed: 1.0 - uvScaleX (or 0 if not scrollable)
    float scrollRangeY; // Pre-computed: 1.0 - uvScaleY (or 0 if not scrollable)
} ubuf;

void main() {
    vec2 uv = qt_TexCoord0;

    // Apply UV scale and scroll offset
    vec2 scrollOffset = vec2(
        ubuf.scrollRangeX * (ubuf.scrollX / 100.0),
        ubuf.scrollRangeY * (ubuf.scrollY / 100.0)
    );

    vec2 finalUV = uv * vec2(ubuf.uvScaleX, ubuf.uvScaleY) + scrollOffset;

    fragColor = texture(source, finalUV) * ubuf.qt_Opacity;
}
