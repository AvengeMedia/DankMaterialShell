.pragma library

function formatRate(bytesPerSec, gbDecimals) {
    if (bytesPerSec < 1024)
        return bytesPerSec.toFixed(0) + " B/s";
    if (bytesPerSec < 1024 * 1024)
        return (bytesPerSec / 1024).toFixed(1) + " KB/s";
    if (bytesPerSec < 1024 * 1024 * 1024)
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
    return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(gbDecimals ?? 2) + " GB/s";
}

function formatBytes(bytes) {
    if (bytes < 1024)
        return bytes.toFixed(0) + "B";
    if (bytes < 1024 * 1024)
        return (bytes / 1024).toFixed(0) + "K";
    if (bytes < 1024 * 1024 * 1024)
        return (bytes / (1024 * 1024)).toFixed(1) + "M";
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + "G";
}

function formatIsoTime(isoString) {
    if (!isoString)
        return "";
    try {
        const date = new Date(isoString);
        if (isNaN(date.getTime()))
            return "";
        return date.toLocaleTimeString(Qt.locale(), "HH:mm");
    } catch (e) {
        return "";
    }
}

function formatRemaining(ms, zeroText, minText, hText, hmText) {
    if (ms <= 0)
        return zeroText;
    const totalMinutes = Math.ceil(ms / 60000);
    if (totalMinutes < 60)
        return minText.arg(totalMinutes);
    const hours = Math.floor(totalMinutes / 60);
    const mins = totalMinutes - hours * 60;
    if (mins === 0)
        return hText.arg(hours);
    return hmText.arg(hours).arg(mins);
}

function pad2(n) {
    return n < 10 ? "0" + n : "" + n;
}

function formatDuration(seconds) {
    if (!isFinite(seconds) || seconds < 0)
        return "0:00";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return m + ":" + pad2(s);
}

function formatUntil(ts, use24h) {
    if (!ts)
        return "";
    const d = new Date(ts);
    const hours = d.getHours();
    const minutes = d.getMinutes();
    if (use24h)
        return pad2(hours) + ":" + pad2(minutes);
    const suffix = hours >= 12 ? "PM" : "AM";
    const h12 = ((hours + 11) % 12) + 1;
    return h12 + ":" + pad2(minutes) + " " + suffix;
}

function addToHistory(arr, val, max) {
    const newArr = arr.slice();
    newArr.push(val);
    if (newArr.length > max)
        newArr.shift();
    return newArr;
}
