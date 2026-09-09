import QtQuick
import QtTest
import "../Services"

TestCase {
    id: testCase
    name: "NiriOutputCycle"

    property var wlr
    property var socket
    property var adapter

    Component {
        id: wlrFactory
        QtObject {
            property bool wlrOutputAvailable: true
            property var outputs: []
            signal stateChanged

            function getOutput(name) {
                return outputs.find(output => output.name === name) || null;
            }

            function publish(heads) {
                outputs = heads;
                stateChanged();
            }
        }
    }

    Component {
        id: socketFactory
        QtObject {
            property bool connected: true
            property bool linkUp: true
            property var requests: []
            property var afterSend: null
            signal connectionStateChanged

            function send(request) {
                requests = requests.concat([request]);
                if (afterSend)
                    afterSend(request);
            }

            function reconnect() {
                linkUp = true;
                connectionStateChanged();
            }
        }
    }

    Component {
        id: adapterFactory
        NiriOutputCycle {}
    }

    function head(name, enabled) {
        return { name: name, enabled: enabled };
    }

    function start(heads, currentOutput, linkUp = true) {
        wlr = createTemporaryObject(wlrFactory, testCase, { outputs: heads });
        socket = createTemporaryObject(socketFactory, testCase, { linkUp: linkUp });
        adapter = createTemporaryObject(adapterFactory, testCase, {
            wlrOutputService: wlr,
            socket: socket,
            isNiri: true,
            currentOutput: currentOutput
        });
        verify(adapter !== null);
    }

    function compareRequests(expected) {
        compare(socket.requests, expected.map(item => ({ Output: { output: item[0], action: item[1] } })));
    }

    function test_wlrSignalConfirmsDisabledTargetBeforePeersTurnOff() {
        start([head("eDP-1", true), head("", false), head("DP-1", false)], "eDP-1");

        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");
        compareRequests([["DP-1", "On"]]);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_BUSY");

        wlr.publish([head("eDP-1", true), head("DP-1", false)]);
        compareRequests([["DP-1", "On"]]);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_BUSY");

        wlr.publish([head("eDP-1", true), head("DP-1", true)]);
        compareRequests([["DP-1", "On"], ["eDP-1", "Off"]]);
    }

    function test_connectionDesiredWithoutActualLinkRejectsCycle() {
        start([head("DP-1", false), head("eDP-1", true)], "eDP-1", false);

        verify(socket.connected);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_UNSUPPORTED");
        compareRequests([]);

        socket.reconnect();
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");
        compareRequests([["DP-1", "On"]]);
    }

    function test_reconnectConsumesCurrentWlrStateWithoutAnotherOutputEvent() {
        start([head("DP-1", false), head("eDP-1", true)], "eDP-1");
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");

        socket.linkUp = false;
        wlr.publish([head("DP-1", true), head("eDP-1", true)]);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_UNSUPPORTED");
        compareRequests([["DP-1", "On"]]);

        socket.reconnect();
        compareRequests([["DP-1", "On"], ["eDP-1", "Off"]]);
    }

    function test_unavailableWlrPreservesPendingCycleUntilStateRecovery() {
        start([head("DP-1", false), head("eDP-1", true)], "eDP-1");
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");
        compareRequests([["DP-1", "On"]]);

        wlr.wlrOutputAvailable = false;
        wlr.publish([head("DP-1", true), head("eDP-1", true)]);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_UNSUPPORTED");
        compareRequests([["DP-1", "On"]]);

        wlr.wlrOutputAvailable = true;
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_BUSY");
        compareRequests([["DP-1", "On"]]);

        wlr.publish([head("DP-1", true), head("eDP-1", true)]);
        compareRequests([["DP-1", "On"], ["eDP-1", "Off"]]);
    }

    function test_initialSelectionLeavesDisabledHeadAloneAfterUnplug() {
        start([head("DP-1", true), head("eDP-1", false)], "DP-1");
        compareRequests([]);

        wlr.publish([head("eDP-1", false)]);
        compareRequests([]);

        wlr.publish([head("DP-1", true), head("eDP-1", false)]);
        compareRequests([]);
    }

    function test_unpluggedPendingTargetCancelsAndNewHeadJoinsCycle() {
        start([head("DP-1", false), head("eDP-1", true)], "eDP-1");
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");

        wlr.publish([head("eDP-1", true)]);
        compareRequests([["DP-1", "On"]]);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_NOOP");

        wlr.publish([head("HDMI-A-1", false), head("eDP-1", true)]);
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");
        compareRequests([["DP-1", "On"], ["HDMI-A-1", "On"]]);
    }

    function test_outputMembershipIsCheckedForEachSend() {
        start([head("DP-1", false), head("HDMI-A-1", true), head("eDP-1", true)], "eDP-1");
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");
        socket.afterSend = function(request) {
            if (request.Output.action === "Off")
                wlr.outputs = [head("DP-1", true)];
        };

        wlr.publish([head("DP-1", true), head("HDMI-A-1", true), head("eDP-1", true)]);
        compareRequests([["DP-1", "On"], ["HDMI-A-1", "Off"]]);
    }

    function test_actualLinkIsCheckedForEachSend() {
        start([head("DP-1", false), head("HDMI-A-1", true), head("eDP-1", true)], "eDP-1");
        compare(adapter.cycleSingleOutput(), "OUTPUT_CYCLE_ACCEPTED");
        socket.afterSend = function(request) {
            if (request.Output.action === "Off")
                socket.linkUp = false;
        };

        wlr.publish([head("DP-1", true), head("HDMI-A-1", true), head("eDP-1", true)]);
        compareRequests([["DP-1", "On"], ["HDMI-A-1", "Off"]]);
    }
}
