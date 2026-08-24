pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Services

FocusScope {
    id: root

    required property var controller
    property var effectiveScreen: null
    property real alignedX: 0
    property real alignedY: 0
    property real alignedWidth: 0
    property real alignedHeight: 0
    property real bottomInset: Theme.spacingM
    property bool _heightReportPending: false

    clip: true

    function resetState() {
        hostContract.editMode = false;
        hostContract.expandedSection = "";
        hostContract.expandedWidgetIndex = -1;
        hostContract.expandedWidgetData = null;
    }

    function beginSession() {
        hostContract.editMode = false;
        hostContract.expandedSection = root.controller.controlCenterPendingSection || "";
        hostContract.expandedWidgetIndex = -1;
        hostContract.expandedWidgetData = null;
        root.queueHeightReport();
    }

    function queueHeightReport() {
        if (root._heightReportPending)
            return;
        root._heightReportPending = true;
        Qt.callLater(() => {
            root._heightReportPending = false;
            root.controller.setDestinationContentHeight("controlcenter", content.targetImplicitHeight + Theme.spacingXS + root.bottomInset);
        });
    }

    QtObject {
        id: hostContract

        property bool editMode: false
        property string expandedSection: ""
        property int expandedWidgetIndex: -1
        property var expandedWidgetData: null

        readonly property bool shouldBeVisible: root.controller.activeActivity === "controlcenter" && root.controller.expanded
        readonly property bool headerTogglesClose: true
        readonly property bool powerMenuOpen: PopoutService.powerMenuModalLoader?.item?.shouldBeVisible ?? false
        readonly property var screen: root.effectiveScreen
        readonly property var triggerScreen: root.effectiveScreen
        readonly property var colorPickerModal: PopoutService.colorPickerModal
        readonly property var powerMenuModalLoader: PopoutService.powerMenuModalLoader
        readonly property real alignedX: root.alignedX
        readonly property real alignedY: root.alignedY
        readonly property real alignedWidth: root.alignedWidth
        readonly property real alignedHeight: root.alignedHeight
        readonly property real popupWidth: root.alignedWidth
        readonly property real popupHeight: root.alignedHeight

        signal lockRequested

        function close() {
            root.controller.requestCollapse();
        }

        function collapseAll() {
            hostContract.expandedSection = "";
            hostContract.expandedWidgetIndex = -1;
            hostContract.expandedWidgetData = null;
        }

        function toggleSection(section) {
            if (hostContract.expandedSection === section) {
                hostContract.expandedSection = "";
                hostContract.expandedWidgetIndex = -1;
                return;
            }
            hostContract.expandedSection = section;
        }
    }

    function releaseScanState() {
        if (NetworkService.activeService)
            NetworkService.activeService.autoRefreshEnabled = false;
        if (BluetoothService.adapter && BluetoothService.adapter.discovering)
            BluetoothService.adapter.discovering = false;
    }

    function applyPresentationLifecycle() {
        if (!hostContract.shouldBeVisible) {
            root.releaseScanState();
            return;
        }
        if (NetworkService.activeService)
            NetworkService.activeService.autoRefreshEnabled = NetworkService.wifiEnabled;
    }

    Component.onDestruction: {
        if (hostContract.shouldBeVisible)
            root.releaseScanState();
    }

    Connections {
        target: hostContract

        function onLockRequested() {
            IdleService.lockRequested();
        }

        function onShouldBeVisibleChanged() {
            Qt.callLater(root.applyPresentationLifecycle);
        }
    }

    Connections {
        target: NetworkService

        function onCredentialsRequestedChanged() {
            if (NetworkService.credentialsRequested && hostContract.shouldBeVisible)
                root.controller.requestCollapse();
        }
    }

    ControlCenterContent {
        id: content

        anchors {
            fill: parent
            leftMargin: Theme.spacingXS
            rightMargin: Theme.spacingXS
            topMargin: Theme.spacingXS
            bottomMargin: root.bottomInset
        }
        host: hostContract

        onTargetImplicitHeightChanged: root.queueHeightReport()
    }

    Connections {
        target: root.controller

        function onSessionStarted(activityId) {
            if (activityId === "controlcenter")
                Qt.callLater(root.beginSession);
        }

        function onExpandedChanged() {
            if (!root.controller.expanded)
                root.resetState();
        }

        function onActiveActivityChanged() {
            if (root.controller.activeActivity !== "controlcenter")
                root.resetState();
        }
    }

    Component.onCompleted: root.controller.markVisualsReady("controlcenter")
}
