import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    LayoutMirroring.enabled: false
    LayoutMirroring.childrenInherit: true

    required property var controller
    property alias font: measure.font
    property color color: Theme.surfaceText
    property bool live: true

    readonly property int revision: controller.wordRevision
    readonly property string fontKey: measure.font.family + "/" + measure.font.pixelSize + "/" + measure.font.weight
    property string pagedKey: ""
    property string pageKey: ""
    property var pages: []
    property bool snapping: false
    property real shift: 0

    clip: true

    onRevisionChanged: place()
    onVisibleChanged: place()
    onWidthChanged: place()
    onFontKeyChanged: place()
    Component.onCompleted: place()

    function flat(value) {
        return value.replace(/\s*\n\s*/g, " ");
    }

    function widthOf(value) {
        measure.text = value.replace(/\s+$/, "");
        return measure.implicitWidth;
    }

    function place() {
        const parts = visible ? (controller.lines[controller.activeIndex]?.parts ?? []) : [];
        const at = controller.currentTime();
        const next = parts.find(candidate => !candidate.background && at >= candidate.t && at < candidate.e) ?? parts.find(candidate => !candidate.background) ?? parts[0] ?? null;
        if (!next) {
            clearLine();
            return;
        }
        const key = controller.activeIndex + "/" + next.t + "/" + next.voice;
        const paged = key + "/" + width + "/" + fontKey;
        if (paged !== pagedKey) {
            pagedKey = paged;
            pages = paginate(next.w.length > 0 ? next.w.map(word => word.x) : (flat(next.x).match(/\S+\s*/g) ?? [flat(next.x)]));
        }
        if (next.w.length > 0) {
            placeWords(key, next, at);
            return;
        }
        placeLine(key, next, at);
    }

    function placeWords(key, line, at) {
        nextPage.stop();
        const index = lastStarted(line.w, at);
        const page = pages.find(candidate => index <= candidate.last) ?? pages[pages.length - 1];
        const sung = index < page.first ? 0 : widthOf(flat(line.w.slice(page.first, index + 1).map(word => word.x).join("")));
        turnTo(key + "/" + page.first, page.text, sung);
    }

    function placeLine(key, line, at) {
        nextPage.stop();
        const span = line.e - line.t;
        const timed = pages.length > 1 && Number.isFinite(span) && span > 0;
        const pageIndex = timed ? Math.max(0, Math.min(pages.length - 1, Math.floor((at - line.t) / span * pages.length))) : 0;
        const page = pages[pageIndex];
        turnTo(key + "/" + page.first, page.text, widthOf(page.text));
        if (!timed || !live || !controller.playing || controller.rate <= 0 || pageIndex >= pages.length - 1)
            return;
        const boundary = line.t + span * (pageIndex + 1) / pages.length;
        nextPage.interval = Math.max(1, Math.min(2147483647, (boundary - at) * 1000 / controller.rate));
        nextPage.start();
    }

    // Time-sorted cues reorder kugou's space cues, which share the next word's start; w keeps text order.
    function lastStarted(words, at) {
        let index = -1;
        for (let i = 0; i < words.length; i++) {
            if (words[i].t <= at)
                index = i;
        }
        return index;
    }

    function paginate(chunks) {
        const words = [];
        for (let i = 0; i < chunks.length; i++) {
            const text = flat(chunks[i]);
            const open = words.length > 0 && !words[words.length - 1].closed;
            if (open) {
                words[words.length - 1].last = i;
                words[words.length - 1].text += text;
            } else {
                words.push({
                    first: i,
                    last: i,
                    text
                });
            }
            words[words.length - 1].closed = /\s$/.test(text);
        }
        const result = [];
        let page = null;
        for (const word of words) {
            if (page && widthOf(page.text + word.text) > width) {
                result.push(page);
                page = null;
            }
            if (!page) {
                page = {
                    first: word.first,
                    last: word.last,
                    text: word.text
                };
                continue;
            }
            page.last = word.last;
            page.text += word.text;
        }
        if (page)
            result.push(page);
        return result;
    }

    function turnTo(key, text, sung) {
        if (key === pageKey) {
            current.fill = sung;
            return;
        }
        pageKey = key;
        slide.stop();
        const animate = live && !SettingsData.reduceMotion && current.text !== "";
        outgoing.text = animate ? current.text : "";
        outgoing.fill = current.fill;
        snap(text, sung);
        shift = animate ? 1 : 0;
        if (animate)
            slide.start();
    }

    function clearLine() {
        nextPage.stop();
        slide.stop();
        pagedKey = "";
        pageKey = "";
        pages = [];
        outgoing.text = "";
        snap("", 0);
        shift = 0;
    }

    function snap(text, sung) {
        snapping = true;
        current.text = text;
        current.fill = sung;
        snapping = false;
    }

    Timer {
        id: nextPage
        onTriggered: root.place()
    }

    NumberAnimation {
        id: slide
        target: root
        property: "shift"
        to: 0
        duration: Theme.mediumDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
        onFinished: outgoing.text = ""
    }

    StyledText {
        id: measure
        visible: false
        wrapMode: Text.NoWrap
        elide: Text.ElideNone
    }

    component Face: Item {
        id: face
        property string text: ""
        property real fill: 0

        width: root.width
        height: root.height

        Behavior on fill {
            enabled: root.live && !root.snapping && !SettingsData.reduceMotion
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
            }
        }

        StyledText {
            id: dim
            anchors.verticalCenter: parent.verticalCenter
            text: face.text
            font: measure.font
            color: Theme.withAlpha(root.color, Theme.pendingOpacity)
            wrapMode: Text.NoWrap
            elide: Text.ElideNone
            Accessible.name: face.text
        }

        Item {
            width: face.fill
            height: parent.height
            clip: true

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: face.text
                font: measure.font
                color: root.color
                wrapMode: Text.NoWrap
                elide: Text.ElideNone
                Accessible.ignored: true
            }
        }
    }

    Face {
        id: outgoing
        y: (root.shift - 1) * root.height
        opacity: root.shift
        visible: text !== ""
    }

    Face {
        id: current
        y: root.shift * root.height
        opacity: 1 - root.shift
    }
}
