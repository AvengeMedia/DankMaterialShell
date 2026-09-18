pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Modules.DankDash

QtObject {
    id: root

    required property var player
    property var backend: DMSService
    property bool enabled: false

    readonly property var presentation: root.player.presentation
    readonly property var activePlayer: root.player.activePlayer
    readonly property string fileUrl: {
        const url = activePlayer?.metadata?.["xesam:url"] ?? "";
        return url.startsWith("file://") ? url : "";
    }
    readonly property string embeddedText: activePlayer?.metadata?.["xesam:asText"] ?? ""
    readonly property string trackKey: presentation ? JSON.stringify([presentation.key, presentation.title, presentation.artist, presentation.album, fileUrl, MediaOptions.enabledLyricsProviders]) : ""
    readonly property int duration: Math.round(presentation?.length ?? 0)
    readonly property real position: activePlayer?.position ?? 0
    readonly property int playbackState: activePlayer?.playbackState ?? MprisPlaybackState.Stopped
    readonly property bool playing: playbackState === MprisPlaybackState.Playing
    readonly property real rate: activePlayer?.rate ?? 1

    property var lines: []
    property var plainLines: []
    property bool synced: false
    property string attributionName: ""
    property string attributionUrl: ""
    property string attributionText: ""
    property int activeIndex: -1
    property real wordTime: -1
    property real wordEnd: -1
    property int wordRevision: 0
    property real sampleTime: 0
    property var cueTimes: []
    property var focusedGroups: []
    property string state: "idle"
    property bool showLoading: false
    property string requestedKey: ""
    property int requestedDuration: 0
    property var requestId: null
    readonly property bool staleDuration: duration !== requestedDuration && state !== "ready" && state !== "instrumental"
    property int serial: 0
    property real anchorPosition: 0
    property real anchorWall: 0
    property bool anchorPlaying: false
    property real anchorRate: 1
    property real positionWall: 0

    onTrackKeyChanged: {
        cancel();
        clear();
        requestedKey = "";
        if (enabled)
            requestDelay.restart();
    }
    onEnabledChanged: {
        if (!enabled) {
            cancel();
            if (state === "loading") {
                requestedKey = "";
                state = "idle";
            }
            return;
        }
        if (requestedKey !== trackKey || staleDuration || state === "idle" || state === "error") {
            requestDelay.restart();
            return;
        }
        reanchor();
    }
    onStaleDurationChanged: {
        if (!enabled || !staleDuration)
            return;
        requestDelay.restart();
    }
    onEmbeddedTextChanged: {
        if (enabled && (state === "none" || state === "error"))
            useEmbeddedText(state);
    }
    onPositionChanged: scheduleAnchor()
    onRateChanged: updatePlaybackClock()
    onPlayingChanged: updatePlaybackClock()
    onPlaybackStateChanged: {
        if (playbackState === MprisPlaybackState.Stopped && !anchorPlaying)
            updatePlaybackClock();
    }
    Component.onDestruction: cancel()

    function cancel() {
        serial++;
        if (requestId !== null)
            backend.cancelRequest(requestId);
        requestId = null;
        tick.stop();
        anchorUpdate.stop();
        loadingDelay.stop();
        requestDelay.stop();
        showLoading = false;
    }

    function clear() {
        lines = [];
        plainLines = [];
        synced = false;
        attributionName = "";
        attributionUrl = "";
        attributionText = "";
        activeIndex = -1;
        wordTime = -1;
        wordEnd = -1;
        cueTimes = [];
        focusedGroups = [];
        wordRevision++;
        state = "idle";
    }

    function request() {
        cancel();
        if (!enabled)
            return;
        if (root.player.presentationSettling) {
            state = "loading";
            loadingDelay.restart();
            requestDelay.restart();
            return;
        }
        clear();
        requestedKey = trackKey;
        requestedDuration = duration;
        const snapshot = presentation;
        if (!snapshot || ((!snapshot.title || !snapshot.artist) && !fileUrl)) {
            useEmbeddedText("none");
            return;
        }
        const token = serial;
        state = "loading";
        loadingDelay.restart();
        requestId = backend.sendRequest("lyrics.get", {
            "title": snapshot.title || "",
            "artist": snapshot.artist || "",
            "album": snapshot.album || "",
            "duration": requestedDuration,
            "fileUrl": fileUrl,
            "allowNetwork": MediaOptions.enabledLyricsProviders.length > 0,
            "providers": MediaOptions.enabledLyricsProviders
        }, response => root.receive(token, response), DashMetrics.mediaLyricsRequestTimeout) ?? null;
    }

    function receive(token, response) {
        if (token !== serial || !enabled)
            return;
        requestId = null;
        loadingDelay.stop();
        showLoading = false;
        if (response.error) {
            useEmbeddedText("error");
            return;
        }
        const result = response.result;
        if (!result?.found) {
            useEmbeddedText("none");
            return;
        }
        if (result.instrumental) {
            state = "instrumental";
            return;
        }
        lines = prepareLines(result.synced ?? [], result.voices ?? {});
        synced = lines.length > 0;
        plainLines = (result.plain ?? "").trim().split("\n");
        if (!synced && !plainLines.some(line => line.trim() !== "")) {
            useEmbeddedText("none");
            return;
        }
        attributionName = result.attribution?.name ?? "";
        attributionUrl = result.attribution?.url ?? "";
        attributionText = result.attribution?.text ?? "";
        state = "ready";
        reanchor();
    }

    function prepareLines(source, voices) {
        const parts = source.filter(line => Number.isFinite(line.t) && line.t >= 0 && typeof line.x === "string").map(line => ({
                    t: line.t,
                    e: Number.isFinite(line.e) && line.e > line.t ? line.e : 0,
                    x: line.x,
                    w: wordsFor(line),
                    voice: typeof line.voice === "string" ? line.voice : "",
                    background: line.background === true,
                    group: Number.isInteger(line.group) && line.group > 0 ? line.group : 0
                })).sort((a, b) => a.t - b.t);
        const singers = [...new Set(parts.filter(part => part.voice && !part.background && voices[part.voice]?.type !== "group").map(part => part.voice))];
        const nextStarts = new Map();
        const events = new Set();
        for (let i = parts.length - 1; i >= 0; i--) {
            const part = parts[i];
            const lane = part.voice + "\u0000" + part.background;
            const following = nextStarts.get(lane);
            const next = following?.t === part.t ? following.next : following?.t ?? Infinity;
            const cues = part.w.slice().sort((a, b) => a.t - b.t);
            const last = cues[cues.length - 1];
            if (part.e <= part.t) {
                const trackEnd = presentation?.length > part.t ? presentation.length : Infinity;
                part.e = last?.e > last?.t ? Math.max(...cues.map(word => word.e)) : next > part.t ? Math.min(next, trackEnd) : trackEnd;
            }
            if (last && part.e <= last.t)
                part.e = next > last.t ? next : Infinity;
            if (next > part.t)
                part.e = Math.min(part.e, next);
            nextStarts.set(lane, {
                t: part.t,
                next
            });
            part.cues = cues;
            const voice = voices[part.voice];
            const singerIndex = singers.indexOf(part.voice);
            part.voiceIndex = Math.max(0, singerIndex);
            part.chorus = singers.length > 1 && singerIndex < 0 && voice?.type === "group";
            part.side = singers.length > 1 && singerIndex >= 0 ? (singerIndex % 2 === 0 ? -1 : 1) : 0;
            part.voiceName = typeof voice?.name === "string" ? voice.name : "";
            events.add(part.t);
            if (Number.isFinite(part.e))
                events.add(part.e);
            for (const word of cues)
                events.add(word.t);
        }
        const groups = new Map();
        for (const part of parts) {
            const key = part.group ? "group:" + part.group : "time:" + part.t;
            let group = groups.get(key);
            if (!group) {
                group = {
                    t: part.t,
                    e: part.e,
                    parts: [],
                    x: ""
                };
                groups.set(key, group);
            }
            group.t = Math.min(group.t, part.t);
            group.e = Math.max(group.e, part.e);
            group.parts.push(part);
        }
        const prepared = [...groups.values()].sort((a, b) => a.t - b.t);
        for (const group of prepared) {
            group.parts.sort((a, b) => Number(a.background) - Number(b.background) || a.t - b.t);
            group.x = group.parts.map(part => part.x).join("\n");
        }
        cueTimes = [...events].sort((a, b) => a - b).map(t => ({
                    t
                }));
        return prepared;
    }

    function wordsFor(line) {
        if (!Array.isArray(line.w) || !line.w.every(word => Number.isFinite(word.t) && word.t >= line.t && typeof word.x === "string"))
            return [];
        if (line.w.map(word => word.x).join("") !== line.x)
            return [];
        return line.w.map(word => ({
                    t: word.t,
                    e: Number.isFinite(word.e) && word.e > word.t ? word.e : word.t,
                    x: word.x
                }));
    }

    function useEmbeddedText(fallback) {
        if (!embeddedText.trim()) {
            state = fallback;
            return;
        }
        plainLines = embeddedText.trim().split("\n");
        synced = false;
        state = "ready";
    }

    function currentTime() {
        if (!anchorPlaying)
            return anchorPosition;
        return anchorPosition + (Date.now() - anchorWall) * anchorRate / 1000;
    }

    function updatePlaybackClock() {
        const predicted = currentTime();
        const sampled = position + (anchorPlaying ? (Date.now() - positionWall) * anchorRate / 1000 : 0);
        const pendingSeek = anchorUpdate.running && Math.abs(sampled - predicted) >= DashMetrics.mediaLyricsPositionTolerance;
        anchorUpdate.stop();
        anchorPosition = playbackState === MprisPlaybackState.Stopped ? 0 : pendingSeek ? sampled : predicted;
        anchorWall = Date.now();
        anchorPlaying = playing;
        anchorRate = rate;
        resync();
    }

    function scheduleAnchor() {
        positionWall = Date.now();
        if (enabled && synced && !anchorUpdate.running)
            anchorUpdate.start();
    }

    function reanchor(force = true) {
        anchorUpdate.stop();
        const observed = activePlayer?.position ?? 0;
        if (!force && anchorPlaying && Math.abs(observed - currentTime()) < DashMetrics.mediaLyricsPositionTolerance)
            return false;
        anchorPosition = observed;
        anchorWall = Date.now();
        anchorPlaying = playing;
        anchorRate = rate;
        resync();
        return true;
    }

    function resync() {
        tick.stop();
        if (!enabled || !synced)
            return;
        const at = currentTime();
        sampleTime = at;
        const nextIndex = indexFor(at, lines);
        const focused = [];
        for (let i = 0; i <= nextIndex; i++) {
            if (i === nextIndex || lines[i].parts.some(part => part.t <= at && at < part.e))
                focused.push(i);
        }
        if (focused.join() !== focusedGroups.join())
            focusedGroups = focused;
        activeIndex = nextIndex;
        const parts = lines[activeIndex]?.parts ?? [];
        const lead = parts.find(part => !part.background && part.t <= at);
        const timing = wordTiming(lead ?? lines[activeIndex]?.parts[0], at);
        wordTime = timing.t;
        wordEnd = timing.e;
        const next = cueTimes[indexFor(at, cueTimes) + 1]?.t ?? Infinity;
        wordRevision++;
        if (!playing || rate <= 0 || !Number.isFinite(next))
            return;
        tick.interval = Math.max(1, Math.min(2147483647, (next - at) * 1000 / rate));
        tick.start();
    }

    function wordTiming(part, at) {
        const cues = part?.cues ?? [];
        const index = indexFor(at, cues);
        const word = cues[index];
        if (!word)
            return {
                t: -1,
                e: -1
            };
        return {
            t: word.t,
            e: Math.min(part.e, cues[index + 1]?.t ?? Infinity, word.e)
        };
    }

    function indexFor(at, timeline) {
        let low = 0;
        let high = timeline.length - 1;
        let found = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            if (timeline[mid].t <= at) {
                found = mid;
                low = mid + 1;
                continue;
            }
            high = mid - 1;
        }
        return found;
    }

    property Timer tick: Timer {
        onTriggered: {
            if (root.anchorUpdate.running && root.reanchor(false))
                return;
            root.resync();
        }
    }

    property Timer anchorUpdate: Timer {
        interval: 0
        onTriggered: root.reanchor(false)
    }

    property Timer requestDelay: Timer {
        interval: DashMetrics.mediaLyricsLoadingDelay
        onTriggered: root.request()
    }

    property Timer loadingDelay: Timer {
        interval: DashMetrics.mediaLyricsLoadingDelay
        onTriggered: root.showLoading = true
    }
}
