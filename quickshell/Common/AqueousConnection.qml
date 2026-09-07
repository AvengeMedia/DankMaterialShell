pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Common
import "AqueousIpc.js" as Ipc

Item {
    id: root
    property string path: ""
    property bool connected: false
    property bool events: false
    property var handshake: null
    property var pending: null
    property string lastId: "0"
    property bool subscribed: false
    property bool installed: false
    property bool resetting: false
    property string lastDelivery: ""
    property var frameParser: null
    readonly property bool ready: socket.linkUp && handshake !== null

    signal helloReceived
    signal batchReceived(var batch)
    signal reply(var result, string error)
    signal failed(string error)

    function clear() {
        const previousParser = frameParser;
        frameParser = null;
        if (previousParser)
            previousParser.destroy();
        deadline.stop();
        initialDeadline.stop();
        pending = null;
        handshake = null;
        subscribed = false;
        installed = false;
        lastId = "0";
        lastDelivery = "";
    }

    function reconnect() {
        resetting = true;
        clear();
        socket.reconnect();
        resetting = false;
    }

    function fail(error) {
        if (!resetting && connected)
            failed(error);
    }

    function request(op, params) {
        if (!socket.linkUp || pending || (op !== "hello" && !handshake))
            throw new Error("unavailable: IPC connection");
        const id = Ipc.nextId(lastId);
        const message = {
            ipc: 1,
            id: id,
            op: op,
            params: params
        };
        if (op !== "hello")
            message.session = handshake.session;
        const text = JSON.stringify(message);
        if (Ipc.byteLength(text) > (handshake?.max_request_bytes || 65536))
            throw new Error("invalid: IPC request exceeds size bound");
        lastId = id;
        pending = {
            id: id,
            op: op,
            params: params
        };
        deadline.restart();
        socket.send(text);
    }

    function receive(line) {
        try {
            const value = Ipc.envelope(line, handshake?.max_frame_bytes || 4259840);
            if (value.event !== undefined) {
                if (!events || !subscribed || pending || value.event !== "state" || !Ipc.decimal(value.delivery) || value.delivery === lastDelivery || value.id !== undefined || value.ok !== undefined || !Ipc.object(value.batch))
                    throw new Error("unexpected IPC state event");
                if (!installed && value.batch.type !== "snapshot")
                    throw new Error("missing initial snapshot");
                if (value.batch.session !== handshake.session || Ipc.byteLength(JSON.stringify(value.batch)) > handshake.max_batch_bytes)
                    throw new Error("invalid IPC batch identity or size");
                batchReceived(value.batch);
                if (!ready || resetting)
                    return;
                installed = true;
                initialDeadline.stop();
                lastDelivery = value.delivery;
                request("ack", {
                    delivery: value.delivery
                });
                return;
            }
            if (!pending)
                throw new Error("unsolicited IPC response");
            const error = Ipc.response(value, pending.id);
            const operation = pending;
            pending = null;
            deadline.stop();
            if (operation.op === "command") {
                reply(value.result || null, error);
                return;
            }
            if (error)
                throw new Error(error);
            switch (operation.op) {
            case "hello":
                handshake = Ipc.hello(value.result);
                helloReceived();
                break;
            case "subscribe":
                if (value.result.subscribed !== true)
                    throw new Error("invalid subscription response");
                subscribed = true;
                break;
            case "ack":
                if (value.result.acked !== operation.params.delivery)
                    throw new Error("invalid ack response");
                break;
            default:
                throw new Error("unexpected IPC operation");
            }
        } catch (e) {
            fail(String(e));
        }
    }

    function subscribe() {
        initialDeadline.restart();
        request("subscribe", {});
    }

    onConnectedChanged: {
        if (!connected)
            clear();
    }

    DankSocket {
        id: socket
        path: root.path
        connected: root.connected
        onConnectionStateChanged: {
            if (root.resetting)
                return;
            if (!linkUp) {
                root.fail("IPC stream disconnected");
                return;
            }
            root.clear();
            root.frameParser = parserComponent.createObject(root);
            try {
                root.request("hello", {});
            } catch (e) {
                root.fail(String(e));
            }
        }
        parser: root.frameParser
    }

    Component {
        id: parserComponent
        SplitParser {
            id: lineParser
            onRead: line => {
                if (root.frameParser === lineParser)
                    root.receive(line);
            }
        }
    }

    Timer {
        id: deadline
        interval: 5000
        onTriggered: root.fail("IPC request timed out")
    }
    Timer {
        id: initialDeadline
        interval: 8000
        onTriggered: root.fail("IPC initial snapshot timed out")
    }
}
