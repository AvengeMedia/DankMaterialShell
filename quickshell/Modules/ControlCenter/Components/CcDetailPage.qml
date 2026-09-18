pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Details
import qs.Widgets
import "../utils/sections.js" as Sections

Item {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string section: ""
    property var model: null
    property string screenName: ""
    property string screenModel: ""

    signal backRequested
    signal collapseRequested
    signal codecSelectorRequested(var device)
    signal portSelectorRequested(var node)

    property string shownSection: ""
    readonly property var pageItem: pageLoader.item
    readonly property real preferredHeight: CcMetrics.pageHeaderHeight + CcMetrics.preferredDetailHeight(shownSection, pageItem?.preferredHeight ?? 0)
    readonly property string title: {
        const own = pageItem?.title ?? "";
        if (own)
            return own;
        const parsed = Sections.parse(shownSection);
        return model?.getWidgetForId(parsed.base)?.text ?? "";
    }
    readonly property real offscreenX: I18n.isRtl ? -width : width

    visible: shownSection !== ""

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
        if (section === "") {
            slideOut.start();
            return;
        }
        slideOut.stop();
        shownSection = section;
        pageLoader.sourceComponent = _componentFor(section);
        if (!CcMetrics.animationsEnabled) {
            panel.x = 0;
            return;
        }
        panel.x = offscreenX;
        slideIn.start();
    }

    NumberAnimation {
        id: slideIn
        target: panel
        property: "x"
        to: 0
        duration: CcMetrics.transitionDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.standard
    }

    NumberAnimation {
        id: slideOut
        target: panel
        property: "x"
        to: root.offscreenX
        duration: CcMetrics.animationsEnabled ? CcMetrics.transitionDuration : 0
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.expressiveCurves.standard
        onFinished: {
            if (root.section !== "")
                return;
            pageLoader.sourceComponent = null;
            root.shownSection = "";
        }
    }

    Item {
        id: panel
        width: root.width
        height: root.height
        x: root.offscreenX

        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: CcMetrics.pageHeaderHeight

            DankActionButton {
                id: backButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: Theme.iconButtonSize
                iconSize: Theme.iconSize
                iconName: I18n.isRtl ? "arrow_forward" : "arrow_back"
                iconColor: Theme.surfaceText
                Accessible.name: I18n.tr("Back")
                onClicked: root.backRequested()
            }

            StyledText {
                anchors.left: backButton.right
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
            anchors.bottom: parent.bottom
            active: root.shownSection !== ""
            onLoaded: {
                const actions = item.headerActions ?? null;
                if (actions)
                    actions.parent = headerSlot;
                item.forceActiveFocus();
            }
        }
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
        NetworkDetail {}
    }

    Component {
        id: bluetoothComponent
        BluetoothDetail {}
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
