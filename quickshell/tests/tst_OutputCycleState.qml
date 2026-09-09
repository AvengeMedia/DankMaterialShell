import QtQuick
import QtTest
import "../Services/OutputCycleState.js" as OutputCycleState

TestCase {
    name: "OutputCycleState"

    function output(id, enabled) {
        return { id: id, enabled: enabled };
    }

    function test_disabledTargetStartsPendingCycle() {
        const result = OutputCycleState.requestCycle(OutputCycleState.emptyState(), [
            output("HDMI-A-1", false),
            output("eDP-1", true)
        ], "eDP-1");

        compare(result.status, "accepted");
        compare(result.state.pending, "HDMI-A-1");
        compare(result.intents.length, 1);
        compare(result.intents[0].id, "HDMI-A-1");
        verify(result.intents[0].enabled);
    }

    function test_confirmedTargetDisablesEveryOtherEnabledOutput() {
        const state = { ring: ["HDMI-A-1", "eDP-1", "DP-1"], selected: "eDP-1", pending: "HDMI-A-1" };
        const result = OutputCycleState.handleOutputsChanged(state, [
            output("DP-1", true),
            output("HDMI-A-1", true),
            output("eDP-1", true)
        ]);

        compare(result.state.pending, "");
        compare(result.state.selected, "HDMI-A-1");
        compare(result.intents.length, 2);
        compare(result.intents[0].id, "DP-1");
        verify(!result.intents[0].enabled);
        compare(result.intents[1].id, "eDP-1");
        verify(!result.intents[1].enabled);
    }

    function test_alreadyEnabledTargetDisablesPeersImmediately() {
        const result = OutputCycleState.requestCycle(OutputCycleState.emptyState(), [
            output("DP-1", true),
            output("eDP-1", true)
        ], "DP-1");

        compare(result.status, "accepted");
        compare(result.state.selected, "eDP-1");
        compare(result.intents.length, 1);
        compare(result.intents[0].id, "DP-1");
        verify(!result.intents[0].enabled);
    }

    function test_emptyMapRetainsState() {
        const state = { ring: ["HDMI-A-1", "eDP-1"], selected: "HDMI-A-1", pending: "" };
        const result = OutputCycleState.handleOutputsChanged(state, []);

        compare(result.state.ring, state.ring);
        compare(result.state.selected, state.selected);
        compare(result.state.pending, state.pending);
        compare(result.intents.length, 0);
    }

    function test_emptyMapRetainsPendingCycleUntilTargetConfirms() {
        const state = { ring: ["HDMI-A-1", "eDP-1"], selected: "eDP-1", pending: "HDMI-A-1" };
        const empty = OutputCycleState.handleOutputsChanged(state, []);

        compare(empty.state.ring, state.ring);
        compare(empty.state.selected, "eDP-1");
        compare(empty.state.pending, "HDMI-A-1");
        compare(empty.intents.length, 0);

        const confirmed = OutputCycleState.handleOutputsChanged(empty.state, [
            output("HDMI-A-1", true),
            output("eDP-1", true)
        ]);

        compare(confirmed.state.pending, "");
        compare(confirmed.state.selected, "HDMI-A-1");
        compare(confirmed.intents.length, 1);
        compare(confirmed.intents[0].id, "eDP-1");
        verify(!confirmed.intents[0].enabled);
    }

    function test_unplugPreservesAllEnabledOutputs() {
        const state = { ring: ["DP-1", "HDMI-A-1", "eDP-1"], selected: "HDMI-A-1", pending: "" };
        const result = OutputCycleState.handleOutputsChanged(state, [
            output("DP-1", true),
            output("eDP-1", true)
        ]);

        compare(result.state.pending, "");
        compare(result.intents, []);
    }

    function test_disabledFallbackOnlyEnablesPreviousOutput() {
        const state = { ring: ["DP-1", "HDMI-A-1", "eDP-1"], selected: "HDMI-A-1", pending: "" };
        const result = OutputCycleState.handleOutputsChanged(state, [
            output("DP-1", false),
            output("eDP-1", false)
        ]);

        compare(result.state.pending, "");
        compare(result.state.selected, "DP-1");
        compare(result.intents.length, 1);
        compare(result.intents[0].id, "DP-1");
        verify(result.intents[0].enabled);
    }

    function test_unplugWithoutCyclePreservesWorkingDisplay() {
        let state = OutputCycleState.handleOutputsChanged(OutputCycleState.emptyState(), [
            output("DP-1", true), output("DP-2", false), output("eDP-1", false)
        ]).state;
        state = OutputCycleState.handleOutputsChanged(state, [
            output("DP-1", true), output("DP-2", true), output("eDP-1", false)
        ]).state;
        const unplugged = OutputCycleState.handleOutputsChanged(state, [
            output("DP-2", true), output("eDP-1", false)
        ]);
        compare(unplugged.intents, []);
        compare(unplugged.state.pending, "");
        const repeated = OutputCycleState.handleOutputsChanged(unplugged.state, [
            output("DP-2", true), output("eDP-1", false)
        ]);
        compare(repeated.intents, []);
    }

    function test_fallbackConfirmationDoesNotDisableNewlyEnabledPeer() {
        const state = OutputCycleState.handleOutputsChanged(OutputCycleState.emptyState(), [
            output("DP-1", true), output("DP-2", false), output("eDP-1", false)
        ]).state;
        const unplugged = OutputCycleState.handleOutputsChanged(state, [
            output("DP-2", false), output("eDP-1", false)
        ]);
        compare(unplugged.intents, [{ id: "eDP-1", enabled: true }]);
        const confirmed = OutputCycleState.handleOutputsChanged(unplugged.state, [
            output("DP-2", true), output("eDP-1", true)
        ]);
        compare(confirmed.intents, []);
        compare(confirmed.state.pending, "");
    }

    function test_missingPendingTargetCancelsWithoutIntent() {
        const state = { ring: ["HDMI-A-1", "eDP-1"], selected: "eDP-1", pending: "HDMI-A-1" };
        const result = OutputCycleState.handleOutputsChanged(state, [output("eDP-1", true)]);

        compare(result.state.pending, "");
        compare(result.intents.length, 0);
    }

    function test_pendingCycleIsBusy() {
        const state = { ring: ["HDMI-A-1", "eDP-1"], selected: "eDP-1", pending: "HDMI-A-1" };
        const result = OutputCycleState.requestCycle(state, [output("HDMI-A-1", false), output("eDP-1", true)], "eDP-1");

        compare(result.status, "busy");
        compare(result.intents.length, 0);
    }

    function test_singleOutputIsNoop() {
        const state = OutputCycleState.emptyState();
        const result = OutputCycleState.requestCycle(state, [output("eDP-1", true)], "eDP-1");

        compare(result.status, "no-op");
        compare(result.intents.length, 0);
    }
}
