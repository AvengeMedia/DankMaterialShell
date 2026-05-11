// ===== wp_parallax.frag =====
// Parallax wallpaper shader - optimized version with CPU-side spring calculation
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;

    // Pre-computed scroll position from CPU (replaces per-pixel spring calculation)
    float scrollX;
    float scrollY;

    float imageWidth1;
    float imageHeight1;
    float imageWidth2;
    float imageHeight2;
    float screenWidth;
    float screenHeight;
    vec4 fillColor;
} ubuf;

vec2 calculateParallaxUV(vec2 uv, float imgWidth, float imgHeight) {
    float imageAspect = imgWidth / imgHeight;
    float screenAspect = ubuf.screenWidth / ubuf.screenHeight;

    bool scrollHorizontal = imageAspect > screenAspect + 0.01;
    bool scrollVertical = imageAspect < screenAspect - 0.01;

    float scale = max(ubuf.screenWidth / imgWidth, ubuf.screenHeight / imgHeight);
    vec2 scaledSize = vec2(imgWidth, imgHeight) * scale;

    vec2 uvScale = vec2(ubuf.screenWidth, ubuf.screenHeight) / scaledSize;
    vec2 uvScrollRange = vec2(1.0) - uvScale;

    vec2 scrollOffset = vec2(
        scrollHorizontal ? (ubuf.scrollX / 100.0) * uvScrollRange.x : uvScrollRange.x * 0.5,
        scrollVertical ? (ubuf.scrollY / 100.0) * uvScrollRange.y : uvScrollRange.y * 0.5
    );

    return uv * uvScale + scrollOffset;
}

vec4 sampleParallax(sampler2D tex, vec2 uv, float imgWidth, float imgHeight) {
    if (imgWidth <= 0.0 || imgHeight <= 0.0) {
        return ubuf.fillColor;
    }

    vec2 transformedUV = calculateParallaxUV(uv, imgWidth, imgHeight);

    if (transformedUV.x < 0.0 || transformedUV.x > 1.0 ||
        transformedUV.y < 0.0 || transformedUV.y > 1.0) {
        return ubuf.fillColor;
    }

    return texture(tex, transformedUV);
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec4 color1 = sampleParallax(source1, uv, ubuf.imageWidth1, ubuf.imageHeight1);
    vec4 color2 = sampleParallax(source2, uv, ubuf.imageWidth2, ubuf.imageHeight2);

    fragColor = mix(color1, color2, ubuf.progress) * ubuf.qt_Opacity;
}
