function normalize(rows, start, end) {
    if (!Array.isArray(rows))
        return [];
    const samples = rows.filter(row => Array.isArray(row) && row.length >= 3 && row.every(value => typeof value === "number" && isFinite(value)) && row[0] >= start && row[0] <= end && row[1] >= 0 && row[1] <= 100);
    samples.sort((a, b) => a[0] - b[0]);
    return samples.filter((sample, index) => index === samples.length - 1 || sample[0] !== samples[index + 1][0]);
}

function windowSamples(rows, start, end, current) {
    const samples = normalize(rows, 0, end);
    const visible = samples.filter(sample => sample[0] >= start);
    const previous = samples.filter(sample => sample[0] < start).pop();
    if (previous && visible[0]?.[0] !== start)
        visible.unshift([start, previous[1], previous[2]]);
    const latest = normalize([current], end, end)[0];
    if (!latest)
        return visible;
    if (visible[visible.length - 1]?.[0] === end)
        visible.pop();
    visible.push(latest);
    return visible;
}

function segments(samples, lowThreshold) {
    const result = [];
    let segment = null;
    for (const sample of samples) {
        if (sample[2] === 0) {
            segment = null;
            continue;
        }
        const kind = sample[2] === 1 ? "charging" : sample[1] <= lowThreshold ? "low" : "normal";
        if (!segment || segment.kind !== kind) {
            if (segment)
                segment.samples.push(sample);
            segment = {
                kind,
                samples: []
            };
            result.push(segment);
        }
        segment.samples.push(sample);
    }
    return result;
}
