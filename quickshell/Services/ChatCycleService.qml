pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common

// Cycles the conversations you are actually taking part in, across every chat
// provider.
//
// Intended for a Super+Tab style binding. A chat qualifies when either:
//   - it has unread messages, or
//   - you have written in it recently (replyWindowMs)
//
// The second rule is what keeps receive-only groups and announcement channels
// -- which are most of a busy messaging account -- out of the rotation, while
// the first keeps a new message from anyone one press away.
//
// Unread sorts ahead of the rest, so whatever just arrived is always the first
// press. Archived conversations never appear: archiving is how the user says
// "keep this out of my way".
//
// This lives apart from ChatService because the rotation spans providers --
// unread conversations from different services interleave by recency, so no
// single provider can own the ordering.
Singleton {
    id: root

    // A pause longer than this starts a fresh rotation from the newest chat, so
    // pressing after a break is predictable rather than resuming mid-list.
    readonly property int restartAfterMs: 3000

    // How far back a message of yours still counts as taking part. A group you
    // answered once a year ago is not a conversation any more.
    //
    // real, not int: 30 days in milliseconds is 2.59e9, which overflows QML's
    // 32-bit int and silently goes negative, letting nothing through.
    readonly property real replyWindowMs: 30 * 24 * 60 * 60 * 1000

    // The chat the rotation is sitting on, so the next press knows where to
    // continue from. Tracked here rather than read back from the window, which
    // may have been closed or moved on by other means.
    property string _cursor: ""

    // Snapshot of the rotation taken when it starts.
    //
    // Opening a chat marks it read, which drops it out of the live unread list
    // immediately -- so a rotation recomputed on every press would collapse to
    // one entry and never advance. The snapshot keeps every chat that qualified
    // when the rotation began, so a burst of messages can actually be walked.
    property var _rotation: []

    // Highest unread timestamp seen on the last build. A newer one means a
    // message arrived, which restarts the rotation at the top.
    property real _seenTs: 0
    property real _lastPressAt: 0

    // cycleChats merges every provider's eligible conversations: unread first,
    // then those you have written in recently, each newest-first.
    function cycleChats() {
        const out = [];
        const cutoff = Date.now() - root.replyWindowMs;
        const chats = ChatService.chats || [];

        for (let i = 0; i < chats.length; i++) {
            const chat = chats[i];

            // Archived conversations stay out of the rotation entirely.
            if (chat.archived)
                continue;
            // Address-book entries with no conversation yet.
            if (!((chat.lastTs || 0) > 0))
                continue;

            const unread = (chat.unread || 0) > 0;
            const repliedRecently = (chat.myLastTs || 0) > cutoff;
            if (!unread && !repliedRecently)
                continue;

            out.push({
                provider: chat.provider,
                chatId: chat.id,
                key: chat.provider + " " + chat.id,
                lastTs: chat.lastTs || 0,
                unread: unread
            });
        }

        // Unread first so a new message is always one press away; within each
        // group, most recent activity wins.
        out.sort((a, b) => {
            if (a.unread !== b.unread)
                return a.unread ? -1 : 1;
            return b.lastTs - a.lastTs;
        });
        return out;
    }

    // next advances the rotation.
    function next() {
        return step(1);
    }

    // previous walks the rotation backwards.
    //
    // Shares the snapshot with next() rather than keeping its own, so reversing
    // direction retraces the same conversations instead of starting a second,
    // differently ordered walk.
    function previous() {
        return step(-1);
    }

    // step returns the chat to open, or null when nothing qualifies. The result
    // carries its provider, since the caller has to know which service it is.
    function step(direction) {
        const live = root.cycleChats();
        const now = Date.now();

        // Only an incoming message restarts the rotation. Tracking the whole
        // list's newest timestamp would also fire on our own sends, yanking the
        // rotation back to the top every time the user replied.
        let newestTs = 0;
        for (let i = 0; i < live.length; i++) {
            if (live[i].unread && live[i].lastTs > newestTs)
                newestTs = live[i].lastTs;
        }

        const restart = newestTs > root._seenTs || (now - root._lastPressAt) > root.restartAfterMs || root._rotation.length === 0;

        root._lastPressAt = now;

        if (restart) {
            if (live.length === 0) {
                root._rotation = [];
                root._cursor = "";
                return null;
            }
            root._seenTs = newestTs;
            root._rotation = live;

            // Going backwards from a standing start means the oldest eligible
            // conversation, not the newest -- otherwise the first press
            // backwards and the first press forwards land on the same chat.
            const entry = direction < 0 ? live[live.length - 1] : live[0];
            root._cursor = entry.key;
            return entry;
        }

        // Continue through the snapshot. Chats already visited stay in it even
        // though opening them marked them read, which is what lets a rotation
        // walk past its first entry.
        let index = -1;
        for (let i = 0; i < root._rotation.length; i++) {
            if (root._rotation[i].key === root._cursor) {
                index = i;
                break;
            }
        }

        // Modulo in JS keeps the sign of the dividend, so a plain (index - 1)
        // goes negative at the start of the list and indexes nothing.
        const count = root._rotation.length;
        const next = ((index + direction) % count + count) % count;

        const chosen = root._rotation[next];
        root._cursor = chosen.key;
        return chosen;
    }

    // reset drops the rotation state, so the next press starts from the newest
    // unread chat. Called when the chat window closes.
    function reset() {
        root._cursor = "";
        root._rotation = [];
        root._lastPressAt = 0;
    }

    // The rotation has to know what is unread before the first press, so the
    // chat cache is kept warm rather than fetched on demand -- but only once a
    // provider is actually enabled, so users without chat plugins hold no
    // subscription at all.
    //
    // Deferred behind Qt.callLater: a singleton is built eagerly, and taking a
    // reference during construction forces ChatService to initialise before its
    // own dependencies are ready.
    property bool _started: false

    Loader {
        active: root._started && ChatService.hasEnabledProvider
        sourceComponent: Item {
            Ref {
                service: ChatService
            }
        }
    }

    Component.onCompleted: Qt.callLater(() => root._started = true)
}
