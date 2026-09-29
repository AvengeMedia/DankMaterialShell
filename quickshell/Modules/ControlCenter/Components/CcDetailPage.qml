pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Details
import qs.Widgets
import "../utils/sections.js" as Sections

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string section: ""
    property var model: null
    property string screenName: ""
    property string screenModel: ""
    property real topInset: 0
    property real minimumContentHeight: 0
    property vector4d cornerRadii: Qt.vector4d(Theme.windowRadius, Theme.windowRadius, Theme.windowRadius, Theme.windowRadius)
    property real coverage: 0

    signal dismissed
    signal backRequested
    signal collapseRequested
    signal codecSelectorRequested(var device)
    signal portSelectorRequested(var node)

    property string shownSection: ""
    property bool enterPending: false
    readonly property bool animationsEnabled: CcMetrics.animationsEnabled && !SettingsData.reduceMotion
    readonly property bool transitioning: enterPending || enterAnimation.running
    readonly property var pageItem: pageLoader.item
    readonly property real pageHeight: CcMetrics.preferredDetailHeight(shownSection, pageItem?.preferredHeight ?? 0)
    readonly property real contentHeight: Math.max(minimumContentHeight, pageHeight)
    readonly property real chromeHeight: header.height + footer.height + CcMetrics.detailDialogPadding * 2
    readonly property real maximumHeight: height - topInset - CcMetrics.detailDialogInset
    // plugin detail content may not scroll itself, so the panel grows to fit it
    readonly property bool pageScrollsItself: !shownSection.startsWith("plugin_")
    readonly property real minimumHeight: chromeHeight + (pageScrollsItself ? Math.min(contentHeight, CcMetrics.detailMinContentHeight) : pageHeight)
    readonly property string title: {
        const own = pageItem?.title ?? "";
        if (own)
            return own;
        const parsed = Sections.parse(shownSection);
        return model?.getWidgetForId(parsed.base)?.text ?? "";
    }
    visible: shownSection !== ""
    opacity: 0
    layer.enabled: enterPending || enterAnimation.running || exitAnimation.running
    layer.smooth: true
    Accessible.role: Accessible.Dialog
    Accessible.name: title

    function finishClose() {
        if (section !== "")
            return;
        pageLoader.sourceComponent = null;
        shownSection = "";
        dismissed();
    }

    function containsItem(item) {
        for (let ancestor = item; ancestor; ancestor = ancestor.parent) {
            if (ancestor === root)
                return true;
        }
        return false;
    }

    function moveFocus(backwards) {
        const current = root.Window.window?.activeFocusItem ?? root;
        const next = current.nextItemInFocusChain(!backwards);
        const target = root.containsItem(next) ? next : backwards ? closeButton : root.nextItemInFocusChain(true);
        (root.containsItem(target) ? target : closeButton).forceActiveFocus(backwards ? Qt.BacktabFocusReason : Qt.TabFocusReason);
    }

    Shortcut {
        sequence: "Tab"
        enabled: root.section !== "" && root.activeFocus
        onActivated: root.moveFocus(false)
    }

    Shortcut {
        sequences: ["Backtab", "Shift+Tab"]
        enabled: root.section !== "" && root.activeFocus
        onActivated: root.moveFocus(true)
    }

    function dismissTransient() {
        const item = pageItem;
        if (!item || typeof item.dismissTransient !== "function")
            return false;
        return item.dismissTransient() === true;
    }

    function _componentFor(sectionId) {
        const parsed = Sections.parse(sectionId);
        switch (parsed.base) {
        case "network":
        case "wifi":
            return networkComponent;
        case "bluetooth":
            return bluetoothComponent;
        case "audioOutput":
            return audioOutputComponent;
        case "audioInput":
            return audioInputComponent;
        case "battery":
            return batteryComponent;
        case "doNotDisturb":
            return dndComponent;
        case "idleInhibitor":
            return idleInhibitComponent;
        case "diskUsage":
            return diskUsageComponent;
        case "brightnessSlider":
            return brightnessComponent;
        }
        if (sectionId.startsWith("builtin_") || sectionId.startsWith("plugin_"))
            return pluginComponent;
        return null;
    }

    onSectionChanged: {
        enterPending = false;
        enterAnimation.stop();
        exitAnimation.stop();
        if (section === "") {
            if (!animationsEnabled) {
                root.opacity = 0;
                finishClose();
                return;
            }
            exitBlocker.forceActiveFocus();
            exitAnimation.start();
            return;
        }
        const opening = shownSection === "";
        enterPending = opening && animationsEnabled;
        root.opacity = enterPending ? 0 : 1;
        dialogSurface.entryScale = enterPending ? CcMetrics.popupEnterScale : 1;
        shownSection = section;
        pageLoader.sourceComponent = _componentFor(section);
        (pageItem ?? root).forceActiveFocus();
    }

    Connections {
        target: root.Window.window
        enabled: root.enterPending

        function onFrameSwapped() {
            root.enterPending = false;
            enterAnimation.start();
        }
    }

    ParallelAnimation {
        id: enterAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: CcMetrics.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
        NumberAnimation {
            target: dialogSurface
            property: "entryScale"
            to: 1
            duration: Theme.expressiveDurations.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
        }
    }

    NumberAnimation {
        id: exitAnimation
        target: root
        property: "opacity"
        to: 0
        duration: CcMetrics.fadeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        onFinished: root.finishClose()
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.cornerRadii.x
        topRightRadius: root.cornerRadii.y
        bottomRightRadius: root.cornerRadii.z
        bottomLeftRadius: root.cornerRadii.w
        color: Theme.scrimColor
        opacity: Theme.scrimAlpha
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onClicked: {
            if (root.section !== "")
                root.backRequested();
        }
        onWheel: wheel => wheel.accepted = true
    }

    Rectangle {
        id: dialogSurface

        x: CcMetrics.detailDialogInset
        y: root.topInset
        width: Math.max(0, root.width - CcMetrics.detailDialogInset * 2)
        height: Math.max(0, Math.min(root.chromeHeight + root.contentHeight, root.maximumHeight))
        radius: Theme.cornerRadiusXL
        color: CcMetrics.dialogColor
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        property real entryScale: 1
        scale: Math.min(1, entryScale)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: panel

            anchors.fill: parent
            anchors.margins: CcMetrics.detailDialogPadding
            opacity: CcMetrics.hideCoveredContent ? 1 - root.coverage : 1

            Item {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: CcMetrics.pageHeaderHeight

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: headerSlot.left
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    font.pixelSize: CcMetrics.pageTitleSize
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                }

                Item {
                    id: headerSlot
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: childrenRect.width
                    height: parent.height
                }
            }

            Loader {
                id: pageLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: footer.top
                active: root.shownSection !== ""
                onLoaded: {
                    const actions = item.headerActions ?? null;
                    if (actions)
                        actions.parent = headerSlot;
                }
            }

            Item {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: closeButton.height + Theme.spacingS

                DankButton {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: I18n.tr("Close")
                    onClicked: root.backRequested()
                }
            }
        }

        Item {
            id: menuOverlay
            anchors.fill: panel
        }
    }

    MouseArea {
        id: exitBlocker

        anchors.fill: parent
        visible: root.section === ""
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
        Keys.onPressed: event => event.accepted = true
        Keys.onReleased: event => event.accepted = true
    }

    Connections {
        target: root.pageItem
        ignoreUnknownSignals: true

        function onMountPathChanged(newMountPath) {
            Sections.updateWidgetForSection(root.shownSection, {
                "mountPath": newMountPath
            });
            root.collapseRequested();
        }

        function onDeviceNameChanged(newDeviceName) {
            Sections.updateWidgetForSection(root.shownSection, {
                "deviceName": newDeviceName
            });
        }

        function onShowCodecSelector(device) {
            root.codecSelectorRequested(device);
        }

        function onShowPortSelector(node) {
            root.portSelectorRequested(node);
        }

        function onDismissRequested() {
            root.backRequested();
        }
    }

    Component {
        id: networkComponent
        NetworkDetail {
            menuParent: menuOverlay
            transitioning: root.transitioning
        }
    }

    Component {
        id: bluetoothComponent
        BluetoothDetail {
            menuParent: menuOverlay
        }
    }

    Component {
        id: audioOutputComponent
        AudioOutputDetail {}
    }

    Component {
        id: audioInputComponent
        AudioInputDetail {}
    }

    Component {
        id: batteryComponent
        BatteryDetail {}
    }

    Component {
        id: dndComponent
        DoNotDisturbDetail {}
    }

    Component {
        id: idleInhibitComponent
        IdleInhibitorDetail {}
    }

    Component {
        id: diskUsageComponent
        DiskUsageDetail {
            readonly property var widgetEntry: Sections.widgetForSection(root.shownSection)
            currentMountPath: widgetEntry?.mountPath || "/"
        }
    }

    Component {
        id: brightnessComponent
        BrightnessDetail {
            readonly property var widgetEntry: Sections.widgetForSection(root.shownSection)
            initialDeviceName: widgetEntry?.deviceName || ""
            instanceId: widgetEntry?.instanceId || ""
            screenName: root.screenName
            screenModel: root.screenModel
        }
    }

    Component {
        id: pluginComponent
        PluginDetailShell {
            pluginId: root.shownSection.startsWith("plugin_") ? root.shownSection.replace("plugin_", "") : ""
            builtinInstance: root.shownSection.startsWith("builtin_") ? (root.model?.builtinInstances[root.shownSection] ?? null) : null
        }
    }
}
