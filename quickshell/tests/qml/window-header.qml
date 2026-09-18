import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.DankCommon.Common as DC
import qs.DankCommon.Widgets as DW
import qs.DankCommon.Modals.FileBrowser as FB

ShellRoot {
    id: root

    property bool failed: false
    property QtObject stubControls: QtObject {
        readonly property bool canMinimize: false
        readonly property bool canMaximize: false
        readonly property var targetWindow: null

        function tryStartMove() {
        }

        function tryToggleMaximize() {
        }

        function tryMinimize() {
        }
    }

    function typeName(item) {
        return String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "").replace(/_QML_\d+/, "");
    }

    function check(condition, label) {
        if (condition)
            return;
        failed = true;
        console.log("FIXTURE_FAIL " + label);
    }

    function findFirst(item, name, depth) {
        if (!item || depth > 10)
            return null;
        if (typeName(item) === name)
            return item;
        for (const child of item.children || []) {
            const found = findFirst(child, name, depth + 1);
            if (found)
                return found;
        }
        return null;
    }

    function headerParts(header) {
        const column = header.children.find(child => typeName(child) === "QQuickColumn");
        const buttons = header.children.find(child => typeName(child) === "QQuickRow");
        return {
            title: column.children[0],
            column: column,
            buttons: buttons,
            icon: findFirst(column, "DankIcon", 0)
        };
    }

    function verifyCentered(name, header) {
        const parts = headerParts(header);
        const titleCenter = parts.column.x + parts.column.width / 2;
        check(Math.abs(titleCenter - header.width / 2) <= 1, name + " title column centered, got " + titleCenter + " of " + header.width);
        check(parts.icon === null, name + " draws no icon");
        check(parts.column.x + parts.column.width <= parts.buttons.x - DC.Style.spacingM + 1, name + " title clears the buttons: " + (parts.column.x + parts.column.width) + " vs " + parts.buttons.x);
        check(parts.title.horizontalAlignment === Text.AlignHCenter, name + " title text centered");
        check(parts.column.width > 0, name + " title has width");
        const rightGap = header.width - (parts.buttons.x + parts.buttons.width);
        const topGap = parts.buttons.y;
        const bottomGap = header.height - (parts.buttons.y + parts.buttons.height);
        check(Math.abs(rightGap - topGap) <= 0.5 && Math.abs(bottomGap - topGap) <= 0.5, name + " controls inset equally: right " + rightGap + " top " + topGap + " bottom " + bottomGap);
    }

    function verifyLeft(name, header, inset) {
        const parts = headerParts(header);
        check(Math.abs(parts.column.x - inset) <= 1, name + " title starts at inset " + inset + ", got " + parts.column.x);
        check(parts.title.horizontalAlignment === Text.AlignLeft, name + " title text left aligned");
        check(parts.icon === null, name + " draws no icon");
    }

    PanelWindow {
        color: "transparent"
        implicitWidth: 760
        implicitHeight: 700
        anchors {
            top: true
            left: true
        }

        Column {
            id: stage
            anchors.fill: parent
            spacing: Theme.spacingM

            Rectangle {
                width: parent.width
                height: plain.height
                color: Theme.floatingWindowSurface

                DankWindowHeader {
                    id: plain
                    width: parent.width
                    controls: root.stubControls
                    title: "Settings"
                }
            }

            Rectangle {
                width: parent.width
                height: actions.height
                color: Theme.floatingWindowSurface

                DankWindowHeader {
                    id: actions
                    width: parent.width
                    controls: root.stubControls
                    title: "Select Wallpaper"

                    Repeater {
                        model: ["visibility", "grid_view", "photo_size_select_large", "info"]
                        DankActionButton {
                            required property string modelData
                            circular: false
                            buttonSize: Theme.buttonHeightXXS
                            iconName: modelData
                            iconSize: Theme.iconSize - 4
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: longTitle.height
                color: Theme.floatingWindowSurface

                DankWindowHeader {
                    id: longTitle
                    width: parent.width
                    controls: root.stubControls
                    title: "A very long window title that keeps going well past the space the header leaves between its symmetric button reserves"

                    DankActionButton {
                        iconName: "close_fullscreen"
                        buttonSize: Theme.buttonHeightXXS
                        iconSize: Theme.iconSizeSmall
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: dialogHeader.height + Theme.spacingL * 2
                color: Theme.surfaceContainerHigh

                DankWindowHeader {
                    id: dialogHeader
                    x: Theme.spacingL
                    y: Theme.spacingL
                    width: parent.width - Theme.spacingL * 2
                    controls: null
                    title: "New Window Rule with a headline that is long enough to wrap onto a second line inside the dialog padding"
                    titleAlignment: Text.AlignLeft
                    titleFontSize: Theme.fontSizeXLarge
                    wrapTitle: true
                    horizontalPadding: 0
                    showDivider: false
                }
            }

            Rectangle {
                width: parent.width
                height: 320
                color: Theme.floatingWindowSurface

                FB.FileBrowserContent {
                    id: browser
                    anchors.fill: parent
                    browserTitle: "Select Profile Image"
                    windowControls: root.stubControls
                    Component.onCompleted: initialize()
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        property int step: 0
        onTriggered: {
            if (step++ === 0) {
                Quickshell.watchFiles = false;
                DC.Style.theme = Theme;
                DC.Style.settings = SettingsData;
                DC.I18n.backend = I18n;
                return;
            }
            stop();
            root.verifyCentered("plain", plain);
            root.check(actions.height === plain.height && longTitle.height === plain.height, "toolbar actions keep the slim height: " + actions.height + " " + longTitle.height);
            root.verifyCentered("actions", actions);
            root.verifyCentered("long", longTitle);
            const longParts = root.headerParts(longTitle);
            root.check(longParts.title.truncated, "long title elides");
            root.verifyLeft("dialog", dialogHeader, 0);
            root.check(root.headerParts(dialogHeader).title.lineCount > 1, "dialog title wraps");
            root.check(Math.abs(dialogHeader.height - (root.headerParts(dialogHeader).column.implicitHeight + Theme.spacingXS * 2)) <= 1, "embedded header stays content sized, got " + dialogHeader.height);
            const browserHeader = root.findFirst(browser, "DankWindowHeader", 0);
            root.check(browserHeader !== null, "file browser has a header");
            if (browserHeader) {
                root.verifyCentered("browser", browserHeader);
                root.check(browserHeader.height === plain.height, "file browser header keeps the slim height, got " + browserHeader.height);
            }
            const image = Quickshell.env("DMS_FIXTURE_IMAGE");
            if (!image) {
                root.finish();
                return;
            }
            stage.grabToImage(result => {
                result.saveToFile(image);
                root.finish();
            });
        }
    }

    function finish() {
        console.log(root.failed ? "FIXTURE_FAIL see above" : "FIXTURE_PASS");
        Qt.quit();
    }
}
