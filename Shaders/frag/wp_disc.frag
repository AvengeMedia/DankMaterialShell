// ===== wp_disc.frag =====
#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source1;  // Current wallpaper
layout(binding = 2) uniform sampler2D source2;  // Next wallpaper

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;      // Transition progress (0.0 to 1.0)
    float centerX;       // X coordinate of disc center (0.0 to 1.0)
    float centerY;       // Y coordinate of disc center (0.0 to 1.0)
    float smoothness;    // Edge smoothness (0.0 to 1.0, 0=sharp, 1=very smooth)
    float aspectRatio;   // Width / Height of the screen
    
    float fillMode;      // 0=stretch, 1=fit, 2=crop, 3=tile, 4=tileV, 5=tileH, 6=pad
    float imageWidth1;
    float imageHeight1;
    float imageWidth2;
    float imageHeight2;
    float screenWidth;
    float screenHeight;
    vec4 fillColor;
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
    else {
        vec2 screenPixel = uv * vec2(ubuf.screenWidth, ubuf.screenHeight);
        vec2 imageOffset = (vec2(ubuf.screenWidth, ubuf.screenHeight) - vec2(imgWidth, imgHeight)) * 0.5;
        vec2 imagePixel = screenPixel - imageOffset;
        transformedUV = imagePixel / vec2(imgWidth, imgHeight);
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

void main() {
    vec2 uv = qt_TexCoord0;

    // Sample textures with fill mode
    vec4 color1 = sampleWithFillMode(source1, uv, ubuf.imageWidth1, ubuf.imageHeight1);
    vec4 color2 = sampleWithFillMode(source2, uv, ubuf.imageWidth2, ubuf.imageHeight2);

    // Map smoothness from 0.0-1.0 to 0.001-0.5 range
    // Using a non-linear mapping for better control
    float mappedSmoothness = mix(0.001, 0.5, ubuf.smoothness * ubuf.smoothness);

    // Adjust UV coordinates to compensate for aspect ratio
    // This makes distances circular instead of elliptical
    vec2 adjustedUV = vec2(uv.x * ubuf.aspectRatio, uv.y);
    vec2 adjustedCenter = vec2(ubuf.centerX * ubuf.aspectRatio, ubuf.centerY);
    
    // Calculate distance in aspect-corrected space
    float dist = distance(adjustedUV, adjustedCenter);
    
    // Calculate the maximum possible distance (corner to corner)
    // This ensures the disc can cover the entire screen
    float maxDistX = max(ubuf.centerX * ubuf.aspectRatio, 
                         (1.0 - ubuf.centerX) * ubuf.aspectRatio);
    float maxDistY = max(ubuf.centerY, 1.0 - ubuf.centerY);
    float maxDist = length(vec2(maxDistX, maxDistY));
    
    // Scale progress to cover the maximum distance
    // Add extra range for smoothness to ensure complete coverage
    // Adjust smoothness for aspect ratio to maintain consistent visual appearance
    float adjustedSmoothness = mappedSmoothness * max(1.0, ubuf.aspectRatio);
    float radius = ubuf.progress * (maxDist + adjustedSmoothness);
    
    // Use smoothstep for a smooth edge transition
    float factor = smoothstep(radius - adjustedSmoothness, radius + adjustedSmoothness, dist);
    
    // Mix the textures (factor = 0 inside disc, 1 outside)
    fragColor = mix(color2, color1, factor);
    
    if (ubuf.progress <= 0.0) fragColor = color1;

    fragColor *= ubuf.qt_Opacity;
}