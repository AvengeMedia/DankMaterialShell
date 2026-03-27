// ===== wp_pixelate.frag =====
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source1;  // Current wallpaper (underlay)
layout(binding = 2) uniform sampler2D source2;  // Next wallpaper (pixelated overlay → sharp)

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;      // 0..1
    float centerX;       // (unused, API compat)
    float centerY;       // (unused)
    float smoothness;    // controls starting block size (0..1)
    float aspectRatio;   // (unused)

    float fillMode;      // 0=stretch, 1=fit, 2=crop, 3=tile, 4=tileV, 5=tileH, 6=pad, 7=scroll
    float imageWidth1;
    float imageHeight1;
    float imageWidth2;
    float imageHeight2;
    float screenWidth;
    float screenHeight;
    vec4  fillColor;

    // Scroll position (0-100 range, only used when fillMode >= 6.5)
    float scrollX;
    float scrollY;
} ubuf;

vec2 calculateUV(vec2 uv, float imgWidth, float imgHeight) {
    vec2 transformedUV = uv;

    if (ubuf.fillMode < 0.5) {
        transformedUV = uv;
    }
    else if (ubuf.fillMode < 1.5) {
        float scale = min(ubuf.screenWidth / imgWidth, ubuf.screenHeight / imgHeight);
        vec2 scaledImageSize = vec2(imgWidth, imgHeight) * scale;
        vec2 offset = (vec2(ubuf.screenWidth, ubuf.screenHeight) - scaledImageSize) * 0.5;
        vec2 screenPixel = uv * vec2(ubuf.screenWidth, ubuf.screenHeight);
        vec2 imagePixel = (screenPixel - offset) / scale;
        transformedUV = imagePixel / vec2(imgWidth, imgHeight);
    }
    else if (ubuf.fillMode < 2.5) {
        float scale = max(ubuf.screenWidth / imgWidth, ubuf.screenHeight / imgHeight);
        vec2 scaledImageSize = vec2(imgWidth, imgHeight) * scale;
        vec2 offset = (scaledImageSize - vec2(ubuf.screenWidth, ubuf.screenHeight)) / scaledImageSize;
        transformedUV = uv * (vec2(1.0) - offset) + offset * 0.5;
    }
    else if (ubuf.fillMode < 3.5) {
        transformedUV = fract(uv * vec2(ubuf.screenWidth, ubuf.screenHeight) / vec2(imgWidth, imgHeight));
    }
    else if (ubuf.fillMode < 4.5) {
        vec2 tileUV = uv * vec2(ubuf.screenWidth, ubuf.screenHeight) / vec2(imgWidth, imgHeight);
        transformedUV = vec2(uv.x, fract(tileUV.y));
    }
    else if (ubuf.fillMode < 5.5) {
        vec2 tileUV = uv * vec2(ubuf.screenWidth, ubuf.screenHeight) / vec2(imgWidth, imgHeight);
        transformedUV = vec2(fract(tileUV.x), uv.y);
    }
    else if (ubuf.fillMode < 6.5) {
        // fillMode 6 = Pad
        vec2 screenPixel = uv * vec2(ubuf.screenWidth, ubuf.screenHeight);
        vec2 imageOffset = (vec2(ubuf.screenWidth, ubuf.screenHeight) - vec2(imgWidth, imgHeight)) * 0.5;
        vec2 imagePixel = screenPixel - imageOffset;
        transformedUV = imagePixel / vec2(imgWidth, imgHeight);
    }
    else {
        // fillMode 7 = Scroll (Crop with variable offset)
        float imageAspect = imgWidth / imgHeight;
        float screenAspect = ubuf.screenWidth / ubuf.screenHeight;

        float scale = max(ubuf.screenWidth / imgWidth, ubuf.screenHeight / imgHeight);
        vec2 scaledImageSize = vec2(imgWidth, imgHeight) * scale;
        vec2 offset = (scaledImageSize - vec2(ubuf.screenWidth, ubuf.screenHeight)) / scaledImageSize;

        // Determine scroll axis based on aspect ratio
        bool scrollHorizontal = imageAspect > screenAspect + 0.01;
        bool scrollVertical = imageAspect < screenAspect - 0.01;

        vec2 scrollOffset = vec2(
            scrollHorizontal ? offset.x * (ubuf.scrollX / 100.0) : offset.x * 0.5,
            scrollVertical ? offset.y * (ubuf.scrollY / 100.0) : offset.y * 0.5
        );

        transformedUV = uv * (vec2(1.0) - offset) + scrollOffset;
    }

    return transformedUV;
}

vec4 sampleWithFillMode(sampler2D tex, vec2 uv, float imgWidth, float imgHeight) {
    vec2 transformedUV = calculateUV(uv, imgWidth, imgHeight);

    if (ubuf.fillMode >= 2.5 && ubuf.fillMode <= 5.5) {
        return texture(tex, transformedUV);
    }

    if (transformedUV.x < 0.0 || transformedUV.x > 1.0 ||
        transformedUV.y < 0.0 || transformedUV.y > 1.0) {
        return ubuf.fillColor;
    }

    return texture(tex, transformedUV);
}

vec2 quantizeUV(vec2 uv, float cellPx) {
    vec2 screenSize = vec2(max(1.0, ubuf.screenWidth), max(1.0, ubuf.screenHeight));
    float cell = max(1.0, ceil(cellPx));                  // integer pixel cells
    vec2 grid = floor(uv * screenSize / cell) * cell + 0.5 * cell;
    return grid / screenSize;
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec4 oldCol = sampleWithFillMode(source1, uv, ubuf.imageWidth1, ubuf.imageHeight1);

    float p = clamp(ubuf.progress, 0.0, 1.0);
    float pe = p * p * (3.0 - 2.0 * p); // smootherstep for opacity

    // Screen-relative starting cell size:
    // smoothness=0 → ~10% of min(screen), smoothness=1 → ~80% of min(screen)
    float s = clamp(ubuf.smoothness, 0.0, 1.0);
    float minSide = min(max(1.0, ubuf.screenWidth), max(1.0, ubuf.screenHeight));
    float startPx = mix(minSide * 0.10, minSide * 0.80, s);   // big and obvious even on small screens

    // Cell size shrinks continuously from startPx → 1 as p grows
    float cellPx = mix(startPx, 1.0, p);

    // Sample next as pixelated overlay
    vec2 uvq = quantizeUV(uv, cellPx);
    vec4 newPix = sampleWithFillMode(source2, uvq, ubuf.imageWidth2, ubuf.imageHeight2);

    // As we approach the end, sharpen the next from pixelated → full-res
    float sharpen = smoothstep(0.75, 1.0, p);              // only near the end
    vec4 newFull = sampleWithFillMode(source2, uv, ubuf.imageWidth2, ubuf.imageHeight2);
    vec4 newCol = mix(newPix, newFull, sharpen);

    vec4 outColor = mix(oldCol, newCol, pe);

    // Snaps
    if (p <= 0.0) outColor = oldCol;
    if (p >= 1.0) outColor = newFull;

    fragColor = outColor * ubuf.qt_Opacity;
}
