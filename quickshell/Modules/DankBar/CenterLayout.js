.pragma library

function indexCenter(sizes, indices, offsets, spacing) {
    const configuredMiddle = Math.floor(sizes.length / 2);
    const middle = indices.indexOf(configuredMiddle);
    if (sizes.length % 2 === 1 && middle >= 0)
        return offsets[middle] + sizes[configuredMiddle] / 2;
    if (sizes.length % 2 === 0 && middle >= 0 && indices.includes(configuredMiddle - 1))
        return offsets[middle] - spacing / 2;

    const visibleMiddle = Math.floor(indices.length / 2);
    if (indices.length % 2 === 1)
        return offsets[visibleMiddle] + sizes[indices[visibleMiddle]] / 2;
    return offsets[visibleMiddle] - spacing / 2;
}

function resolve(sizes, length, spacing, mode) {
    const indices = [];
    const offsets = [];
    const positions = sizes.map(() => null);
    let totalSize = 0;
    for (let index = 0; index < sizes.length; index++) {
        if (sizes[index] === null)
            continue;
        if (indices.length > 0)
            totalSize += spacing;
        indices.push(index);
        offsets.push(totalSize);
        totalSize += sizes[index];
    }

    if (indices.length === 0)
        return { positions, totalSize: 0 };

    const centerOffset = mode === "geometric" ? totalSize / 2 : indexCenter(sizes, indices, offsets, spacing);
    const start = length / 2 - centerOffset;
    for (let i = 0; i < indices.length; i++)
        positions[indices[i]] = start + offsets[i];
    return { positions, totalSize };
}
