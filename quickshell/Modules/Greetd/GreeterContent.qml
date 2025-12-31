import QtCore
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Lock

Item {
    id: root

    readonly property string xdgDataDirs: Quickshell.env("XDG_DATA_DIRS")
    property string screenName: ""
    property string randomFact: ""
    property string hyprlandCurrentLayout: ""
    property string hyprlandKeyboard: ""
    property int hyprlandLayoutCount: 0
    property bool isPrimaryScreen: !Quickshell.screens?.length || screenName === Quickshell.screens[0]?.name

    signal launchRequested

    function pickRandomFact() {
        randomFact = Facts.getRandomFact();
    }

    property bool weatherInitialized: false

    function initWeatherService() {
        if (weatherInitialized)
            return;
        if (!GreetdSettings.settingsLoaded)
            return;
        if (!GreetdSettings.weatherEnabled)
            return;
        weatherInitialized = true;
        WeatherService.addRef();
        WeatherService.forceRefresh();
    }

    Connections {
        target: GreetdSettings
        function onSettingsLoadedChanged() {
            if (GreetdSettings.settingsLoaded)
                initWeatherService();
        }
    }

    Component.onCompleted: {
        pickRandomFact();
        initWeatherService();

        if (isPrimaryScreen)
            applyLastSuccessfulUser();

        if (CompositorService.isHyprland)
            updateHyprlandLayout();
    }

    function applyLastSuccessfulUser() {
        const lastUser = GreetdMemory.lastSuccessfulUser;
        if (lastUser && !GreeterState.showPasswordInput && !GreeterState.username) {
            GreeterState.username = lastUser;
            GreeterState.usernameInput = lastUser;
            GreeterState.showPasswordInput = true;
            PortalService.getGreeterUserProfileImage(lastUser);
        }
    }

    Component.onDestruction: {
        if (weatherInitialized)
            WeatherService.removeRef();
    }

    function updateHyprlandLayout() {
        if (CompositorService.isHyprland) {
            hyprlandLayoutProcess.running = true;
        }
    }

    Process {
        id: hyprlandLayoutProcess
        running: false
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const mainKeyboard = data.keyboards.find(kb => kb.main === true);
                    hyprlandKeyboard = mainKeyboard.name;
                    if (mainKeyboard && mainKeyboard.active_keymap) {
                        const parts = mainKeyboard.active_keymap.split(" ");
                        if (parts.length > 0) {
                            hyprlandCurrentLayout = parts[0].substring(0, 2).toUpperCase();
                        } else {
                            hyprlandCurrentLayout = mainKeyboard.active_keymap.substring(0, 2).toUpperCase();
                        }
                    } else {
                        hyprlandCurrentLayout = "";
                    }
                    if (mainKeyboard && mainKeyboard.layout_names) {
                        hyprlandLayoutCount = mainKeyboard.layout_names.length;
                    } else {
                        hyprlandLayoutCount = 0;
                    }
                } catch (e) {
                    hyprlandCurrentLayout = "";
                    hyprlandLayoutCount = 0;
                }
            }
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            if (event.name === "activelayout")
                updateHyprlandLayout();
        }
    }

    Connections {
        target: GreetdMemory
        enabled: isPrimaryScreen
        function onLastSuccessfulUserChanged() {
            applyLastSuccessfulUser();
        }
    }

    Connections {
        target: GreeterState
        function onUsernameChanged() {
            if (GreeterState.username) {
                PortalService.getGreeterUserProfileImage(GreeterState.username);
            }
        }
    }

    DankBackdrop {
        anchors.fill: parent
        screenName: root.screenName
        visible: {
            var _ = SessionData.perMonitorWallpaper;
            var __ = SessionData.monitorWallpapers;
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
            return !currentWallpaper || currentWallpaper === "" || (currentWallpaper && currentWallpaper.startsWith("#"));
        }
    }

    Image {
        id: wallpaperBackground

        anchors.fill: parent
        source: {
            var _ = SessionData.perMonitorWallpaper;
            var __ = SessionData.monitorWallpapers;
            var currentWallpaper = SessionData.getMonitorWallpaper(screenName);
            return (currentWallpaper && !currentWallpaper.startsWith("#")) ? currentWallpaper : "";
        }
        fillMode: Theme.getFillMode(GreetdSettings.wallpaperFillMode)
        smooth: true
        asynchronous: false
        cache: true
        visible: source !== ""
        layer.enabled: true

        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.8
            blurMax: 32
            blurMultiplier: 1
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Item {
            id: clockContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: 60
            width: parent.width
            height: clockText.implicitHeight

            Row {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                spacing: 0

                property string fullTimeStr: {
                    const format = GreetdSettings.use24HourClock ? (GreetdSettings.showSeconds ? "HH:mm:ss" : "HH:mm") : (GreetdSettings.showSeconds ? "h:mm:ss AP" : "h:mm AP");
                    return systemClock.date.toLocaleTimeString(Qt.locale(), format);
                }
                property var timeParts: fullTimeStr.split(':')
                property string hours: timeParts[0] || ""
                property string minutes: timeParts[1] || ""
                property string secondsWithAmPm: timeParts.length > 2 ? timeParts[2] : ""
                property string seconds: secondsWithAmPm.replace(/\s*(AM|PM|am|pm)$/i, '')
                property string ampm: {
                    const match = fullTimeStr.match(/\s*(AM|PM|am|pm)$/i);
                    return match ? match[0].trim() : "";
                }
                property bool hasSeconds: timeParts.length > 2

                StyledText {
                    width: 75
                    text: clockText.hours.length > 1 ? clockText.hours[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    width: 75
                    text: clockText.hours.length > 1 ? clockText.hours[1] : clockText.hours.length > 0 ? clockText.hours[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: ":"
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                }

                StyledText {
                    width: 75
                    text: clockText.minutes.length > 0 ? clockText.minutes[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    width: 75
                    text: clockText.minutes.length > 1 ? clockText.minutes[1] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: clockText.hasSeconds ? ":" : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    visible: clockText.hasSeconds
                }

                StyledText {
                    width: 75
                    text: clockText.hasSeconds && clockText.seconds.length > 0 ? clockText.seconds[0] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    visible: clockText.hasSeconds
                }

                StyledText {
                    width: 75
                    text: clockText.hasSeconds && clockText.seconds.length > 1 ? clockText.seconds[1] : ""
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    visible: clockText.hasSeconds
                }

                StyledText {
                    width: 20
                    text: " "
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    visible: clockText.ampm !== ""
                }

                StyledText {
                    text: clockText.ampm
                    font.pixelSize: 120
                    font.weight: Font.Light
                    color: "white"
                    visible: clockText.ampm !== ""
                }
            }
        }

        StyledText {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockContainer.bottom
            anchors.topMargin: 4
            text: {
                if (GreetdSettings.lockDateFormat && GreetdSettings.lockDateFormat.length > 0) {
                    return systemClock.date.toLocaleDateString(Qt.locale(), GreetdSettings.lockDateFormat);
                }
                return systemClock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat);
            }
            font.pixelSize: Theme.fontSizeXLarge
            color: "white"
            opacity: 0.9
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dateText.bottom
            anchors.topMargin: Theme.spacingL
            width: 380
            height: 140

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingM

                RowLayout {
                    spacing: Theme.spacingL
                    Layout.fillWidth: true

                    DankCircularImage {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        imageSource: {
                            if (PortalService.profileImage === "") {
                                return "";
                            }

                            if (PortalService.profileImage.startsWith("/")) {
                                return "file://" + PortalService.profileImage;
                            }

                            return PortalService.profileImage;
                        }
                        fallbackIcon: "person"
                    }

                    Rectangle {
                        property bool showPassword: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
                        border.color: inputField.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.3)
                        border.width: inputField.activeFocus ? 2 : 1

                        DankIcon {
                            id: lockIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            name: GreeterState.showPasswordInput ? "lock" : "person"
                            size: 20
                            color: inputField.activeFocus ? Theme.primary : Theme.surfaceVariantText
                        }

                        TextInput {
                            id: inputField

                            property bool syncingFromState: false

                            anchors.fill: parent
                            anchors.leftMargin: lockIcon.width + Theme.spacingM * 2
                            anchors.rightMargin: {
                                let margin = Theme.spacingM;
                                if (GreeterState.showPasswordInput && revealButton.visible) {
                                    margin += revealButton.width;
                                }
                                if (virtualKeyboardButton.visible) {
                                    margin += virtualKeyboardButton.width;
                                }
                                if (enterButton.visible) {
                                    margin += enterButton.width + 2;
                                }
                                return margin;
                            }
                            opacity: 0
                            focus: true
                            echoMode: GreeterState.showPasswordInput ? (parent.showPassword ? TextInput.Normal : TextInput.Password) : TextInput.Normal
                            onTextChanged: {
                                if (syncingFromState)
                                    return;
                                if (GreeterState.showPasswordInput) {
                                    GreeterState.passwordBuffer = text;
                                } else {
                                    GreeterState.usernameInput = text;
                                }
                            }
                            onAccepted: {
                                if (GreeterState.showPasswordInput) {
                                    if (Greetd.state === GreetdState.Inactive && GreeterState.username) {
                                        Greetd.createSession(GreeterState.username);
                                    }
                                } else {
                                    if (text.trim()) {
                                        GreeterState.username = text.trim();
                                        GreeterState.showPasswordInput = true;
                                        PortalService.getGreeterUserProfileImage(GreeterState.username);
                                        GreeterState.passwordBuffer = "";
                                        syncingFromState = true;
                                        text = "";
                                        syncingFromState = false;
                                    }
                                }
                            }

                            Component.onCompleted: {
                                syncingFromState = true;
                                text = GreeterState.showPasswordInput ? GreeterState.passwordBuffer : GreeterState.usernameInput;
                                syncingFromState = false;
                                if (isPrimaryScreen && !powerMenu.isVisible)
                                    forceActiveFocus();
                            }
                            onVisibleChanged: {
                                if (visible && isPrimaryScreen && !powerMenu.isVisible)
                                    forceActiveFocus();
                            }
                        }

                        KeyboardController {
                            id: keyboard_controller
                            target: inputField
                            rootObject: root
                        }

                        StyledText {
                            id: placeholder

                            anchors.left: lockIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: (GreeterState.showPasswordInput && revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)))
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (GreeterState.unlocking) {
                                    return "Logging in...";
                                }
                                if (Greetd.state !== GreetdState.Inactive) {
                                    return "Authenticating...";
                                }
                                if (GreeterState.showPasswordInput) {
                                    return "Password...";
                                }
                                return "Username...";
                            }
                            color: GreeterState.unlocking ? Theme.primary : (Greetd.state !== GreetdState.Inactive ? Theme.primary : Theme.outline)
                            font.pixelSize: Theme.fontSizeMedium
                            opacity: (GreeterState.showPasswordInput ? GreeterState.passwordBuffer.length === 0 : GreeterState.usernameInput.length === 0) ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        StyledText {
                            anchors.left: lockIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: (GreeterState.showPasswordInput && revealButton.visible ? revealButton.left : (virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)))
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (GreeterState.showPasswordInput) {
                                    if (parent.showPassword) {
                                        return GreeterState.passwordBuffer;
                                    }
                                    return "•".repeat(GreeterState.passwordBuffer.length);
                                }
                                return GreeterState.usernameInput;
                            }
                            color: Theme.surfaceText
                            font.pixelSize: (GreeterState.showPasswordInput && !parent.showPassword) ? Theme.fontSizeLarge : Theme.fontSizeMedium
                            opacity: (GreeterState.showPasswordInput ? GreeterState.passwordBuffer.length > 0 : GreeterState.usernameInput.length > 0) ? 1 : 0
                            clip: true
                            elide: Text.ElideNone
                            horizontalAlignment: implicitWidth > width ? Text.AlignRight : Text.AlignLeft

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.mediumDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        DankActionButton {
                            id: revealButton

                            anchors.right: virtualKeyboardButton.visible ? virtualKeyboardButton.left : (enterButton.visible ? enterButton.left : parent.right)
                            anchors.rightMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: parent.showPassword ? "visibility_off" : "visibility"
                            buttonSize: 32
                            visible: GreeterState.showPasswordInput && GreeterState.passwordBuffer.length > 0 && Greetd.state === GreetdState.Inactive && !GreeterState.unlocking
                            enabled: visible
                            onClicked: parent.showPassword = !parent.showPassword
                        }
                        DankActionButton {
                            id: virtualKeyboardButton

                            anchors.right: enterButton.visible ? enterButton.left : parent.right
                            anchors.rightMargin: enterButton.visible ? 0 : Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "keyboard"
                            buttonSize: 32
                            visible: Greetd.state === GreetdState.Inactive && !GreeterState.unlocking
                            enabled: visible
                            onClicked: {
                                if (keyboard_controller.isKeyboardActive) {
                                    keyboard_controller.hide();
                                } else {
                                    keyboard_controller.show();
                                }
                            }
                        }

                        DankActionButton {
                            id: enterButton

                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "keyboard_return"
                            buttonSize: 36
                            visible: Greetd.state === GreetdState.Inactive && !GreeterState.unlocking
                            enabled: true
                            onClicked: {
                                if (GreeterState.showPasswordInput) {
                                    if (GreeterState.username) {
                                        Greetd.createSession(GreeterState.username);
                                    }
                                } else {
                                    if (inputField.text.trim()) {
                                        GreeterState.username = inputField.text.trim();
                                        GreeterState.showPasswordInput = true;
                                        PortalService.getGreeterUserProfileImage(GreeterState.username);
                                        GreeterState.passwordBuffer = "";
                                        inputField.text = "";
                                    }
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Layout.topMargin: -Theme.spacingS
                    Layout.bottomMargin: -Theme.spacingS
                    text: {
                        if (GreeterState.pamState === "error")
                            return "Authentication error - try again";
                        if (GreeterState.pamState === "fail")
                            return "Incorrect password";
                        return "";
                    }
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    opacity: GreeterState.pamState !== "" ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 0
                    Layout.preferredWidth: switchUserRow.width + Theme.spacingL * 2
                    Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainer
                    opacity: GreeterState.showPasswordInput ? 1 : 0
                    enabled: GreeterState.showPasswordInput

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }

                    Row {
                        id: switchUserRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "people"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Switch User")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StateLayer {
                        stateColor: Theme.primary
                        cornerRadius: parent.radius
                        enabled: !GreeterState.unlocking && Greetd.state === GreetdState.Inactive && GreeterState.showPasswordInput
                        onClicked: {
                            GreeterState.reset();
                            inputField.text = "";
                            PortalService.profileImage = "";
                        }
                    }
                }
            }
        }

        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Item {
                width: keyboardLayoutRow.width
                height: keyboardLayoutRow.height
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    if (CompositorService.isNiri) {
                        return NiriService.keyboardLayoutNames.length > 1;
                    } else if (CompositorService.isHyprland) {
                        return hyprlandLayoutCount > 1;
                    }
                    return false;
                }

                Row {
                    id: keyboardLayoutRow
                    spacing: 4

                    Item {
                        width: Theme.iconSize
                        height: Theme.iconSize

                        DankIcon {
                            name: "keyboard"
                            size: Theme.iconSize
                            color: "white"
                            anchors.centerIn: parent
                        }
                    }

                    Item {
                        width: childrenRect.width
                        height: Theme.iconSize

                        StyledText {
                            text: {
                                if (CompositorService.isNiri) {
                                    const layout = NiriService.getCurrentKeyboardLayoutName();
                                    if (!layout)
                                        return "";
                                    const parts = layout.split(" ");
                                    if (parts.length > 0) {
                                        return parts[0].substring(0, 2).toUpperCase();
                                    }
                                    return layout.substring(0, 2).toUpperCase();
                                } else if (CompositorService.isHyprland) {
                                    return hyprlandCurrentLayout;
                                }
                                return "";
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Light
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                MouseArea {
                    id: keyboardLayoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (CompositorService.isNiri) {
                            NiriService.cycleKeyboardLayout();
                        } else if (CompositorService.isHyprland) {
                            Quickshell.execDetached(["hyprctl", "switchxkblayout", hyprlandKeyboard, "next"]);
                            updateHyprlandLayout();
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    const keyboardVisible = (CompositorService.isNiri && NiriService.keyboardLayoutNames.length > 1) || (CompositorService.isHyprland && hyprlandLayoutCount > 1);
                    return keyboardVisible && GreetdSettings.weatherEnabled && WeatherService.weather.available;
                }
            }

            Row {
                spacing: 6
                visible: GreetdSettings.weatherEnabled && WeatherService.weather.available
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                    size: Theme.iconSize
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: (GreetdSettings.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) + "°"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: GreetdSettings.weatherEnabled && WeatherService.weather.available && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio) || BatteryService.batteryAvailable)
            }

            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                visible: NetworkService.networkStatus !== "disconnected" || (BluetoothService.available && BluetoothService.enabled) || (AudioService.sink && AudioService.sink.audio)

                DankIcon {
                    name: NetworkService.networkStatus === "ethernet" ? "lan" : NetworkService.wifiSignalIcon
                    size: Theme.iconSize - 2
                    color: NetworkService.networkStatus !== "disconnected" ? "white" : Qt.rgba(255, 255, 255, 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: NetworkService.networkStatus !== "disconnected"
                }

                DankIcon {
                    name: "bluetooth"
                    size: Theme.iconSize - 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: BluetoothService.available && BluetoothService.enabled
                }

                DankIcon {
                    name: {
                        if (!AudioService.sink?.audio) {
                            return "volume_up";
                        }
                        if (AudioService.sink.audio.muted)
                            return "volume_off";
                        if (AudioService.sink.audio.volume === 0)
                            return "volume_mute";
                        if (AudioService.sink.audio.volume * 100 < 33) {
                            return "volume_down";
                        }
                        return "volume_up";
                    }
                    size: Theme.iconSize - 2
                    color: (AudioService.sink && AudioService.sink.audio && (AudioService.sink.audio.muted || AudioService.sink.audio.volume === 0)) ? Qt.rgba(255, 255, 255, 0.5) : "white"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AudioService.sink && AudioService.sink.audio
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Qt.rgba(255, 255, 255, 0.2)
                anchors.verticalCenter: parent.verticalCenter
                visible: BatteryService.batteryAvailable && (NetworkService.networkStatus !== "disconnected" || BluetoothService.enabled || (AudioService.sink && AudioService.sink.audio))
            }

            Row {
                spacing: 4
                visible: BatteryService.batteryAvailable
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: {
                        if (BatteryService.isCharging) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full";
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90";
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80";
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60";
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50";
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30";
                            }

                            return "battery_charging_20";
                        }
                        if (BatteryService.isPluggedIn) {
                            if (BatteryService.batteryLevel >= 90) {
                                return "battery_charging_full";
                            }

                            if (BatteryService.batteryLevel >= 80) {
                                return "battery_charging_90";
                            }

                            if (BatteryService.batteryLevel >= 60) {
                                return "battery_charging_80";
                            }

                            if (BatteryService.batteryLevel >= 50) {
                                return "battery_charging_60";
                            }

                            if (BatteryService.batteryLevel >= 30) {
                                return "battery_charging_50";
                            }

                            if (BatteryService.batteryLevel >= 20) {
                                return "battery_charging_30";
                            }

                            return "battery_charging_20";
                        }
                        if (BatteryService.batteryLevel >= 95) {
                            return "battery_full";
                        }

                        if (BatteryService.batteryLevel >= 85) {
                            return "battery_6_bar";
                        }

                        if (BatteryService.batteryLevel >= 70) {
                            return "battery_5_bar";
                        }

                        if (BatteryService.batteryLevel >= 55) {
                            return "battery_4_bar";
                        }

                        if (BatteryService.batteryLevel >= 40) {
                            return "battery_3_bar";
                        }

                        if (BatteryService.batteryLevel >= 25) {
                            return "battery_2_bar";
                        }

                        return "battery_1_bar";
                    }
                    size: Theme.iconSize
                    color: {
                        if (BatteryService.isLowBattery && !BatteryService.isCharging) {
                            return Theme.error;
                        }

                        if (BatteryService.isCharging || BatteryService.isPluggedIn) {
                            return Theme.primary;
                        }

                        return "white";
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: BatteryService.batteryLevel + "%"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Light
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledText {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.spacingL
            width: Math.min(parent.width - Theme.spacingXL * 2, implicitWidth)
            text: root.randomFact
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
            opacity: 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            visible: root.randomFact !== ""
        }

        DankActionButton {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Theme.spacingXL
            visible: GreetdSettings.lockScreenShowPowerActions
            iconName: "power_settings_new"
            iconColor: Theme.error
            buttonSize: 40
            onClicked: powerMenu.show()
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Theme.spacingXL
            width: Math.max(200, currentSessionMetrics.width + 80)
            height: 60

            StyledTextMetrics {
                id: currentSessionMetrics
                text: root.currentSessionName
            }

            property real longestSessionWidth: {
                let maxWidth = 0;
                for (var i = 0; i < sessionMetricsRepeater.count; i++) {
                    const item = sessionMetricsRepeater.itemAt(i);
                    if (item && item.width > maxWidth) {
                        maxWidth = item.width;
                    }
                }
                return maxWidth;
            }

            Repeater {
                id: sessionMetricsRepeater
                model: GreeterState.sessionList
                delegate: StyledTextMetrics {
                    text: modelData
                }
            }

            DankDropdown {
                id: sessionDropdown
                anchors.fill: parent
                text: ""
                description: ""
                currentValue: root.currentSessionName
                options: GreeterState.sessionList
                enableFuzzySearch: GreeterState.sessionList.length > 5
                popupWidthOffset: 0
                popupWidth: Math.max(250, parent.longestSessionWidth + 100)
                openUpwards: true
                alignPopupRight: true
                onValueChanged: value => {
                    const idx = GreeterState.sessionList.indexOf(value);
                    if (idx < 0)
                        return;
                    GreeterState.currentSessionIndex = idx;
                    GreeterState.selectedSession = GreeterState.sessionExecs[idx];
                    GreeterState.selectedSessionPath = GreeterState.sessionPaths[idx];
                }
            }
        }
    }

    property string currentSessionName: GreeterState.sessionList[GreeterState.currentSessionIndex] || ""

    function finalizeSessionSelection() {
        if (GreeterState.sessionList.length === 0)
            return;

        const savedSession = GreetdMemory.lastSessionId;
        if (savedSession) {
            for (var i = 0; i < GreeterState.sessionPaths.length; i++) {
                if (GreeterState.sessionPaths[i] === savedSession) {
                    GreeterState.currentSessionIndex = i;
                    GreeterState.selectedSession = GreeterState.sessionExecs[i] || "";
                    GreeterState.selectedSessionPath = GreeterState.sessionPaths[i];
                    return;
                }
            }
        }

        GreeterState.currentSessionIndex = 0;
        GreeterState.selectedSession = GreeterState.sessionExecs[0] || "";
        GreeterState.selectedSessionPath = GreeterState.sessionPaths[0] || "";
    }

    property var sessionDirs: {
        const homeDir = Quickshell.env("HOME") || "";
        const dirs = ["/usr/share/wayland-sessions", "/usr/share/xsessions", "/usr/local/share/wayland-sessions", "/usr/local/share/xsessions"];

        if (homeDir) {
            dirs.push(homeDir + "/.local/share/wayland-sessions");
            dirs.push(homeDir + "/.local/share/xsessions");
        }

        if (xdgDataDirs) {
            xdgDataDirs.split(":").forEach(dir => {
                if (dir) {
                    dirs.push(dir + "/wayland-sessions");
                    dirs.push(dir + "/xsessions");
                }
            });
        }
        return dirs;
    }

    property var _pendingFiles: ({})
    property int _pendingCount: 0

    function _addSession(path, name, exec) {
        if (!name || !exec || GreeterState.sessionList.includes(name))
            return;
        GreeterState.sessionList = GreeterState.sessionList.concat([name]);
        GreeterState.sessionExecs = GreeterState.sessionExecs.concat([exec]);
        GreeterState.sessionPaths = GreeterState.sessionPaths.concat([path]);
    }

    function _parseDesktopFile(content, path) {
        let name = "";
        let exec = "";
        const lines = content.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!name && line.startsWith("Name="))
                name = line.substring(5).trim();
            else if (!exec && line.startsWith("Exec="))
                exec = line.substring(5).trim();
            if (name && exec)
                break;
        }
        _addSession(path, name, exec);
    }

    function _loadDesktopFile(filePath) {
        if (_pendingFiles[filePath])
            return;
        _pendingFiles[filePath] = true;
        _pendingCount++;

        const loader = desktopFileLoader.createObject(root, {
            "filePath": filePath
        });
    }

    function _onFileLoaded(filePath) {
        _pendingCount--;
        if (_pendingCount === 0)
            Qt.callLater(finalizeSessionSelection);
    }

    Component {
        id: desktopFileLoader

        FileView {
            id: fv
            property string filePath: ""
            path: filePath

            onLoaded: {
                root._parseDesktopFile(text(), filePath);
                root._onFileLoaded(filePath);
                fv.destroy();
            }

            onLoadFailed: {
                root._onFileLoaded(filePath);
                fv.destroy();
            }
        }
    }

    Repeater {
        model: isPrimaryScreen ? sessionDirs : []

        Item {
            required property string modelData

            FolderListModel {
                folder: "file://" + modelData
                nameFilters: ["*.desktop"]
                showDirs: false
                showDotAndDotDot: false

                onStatusChanged: {
                    if (status !== FolderListModel.Ready)
                        return;
                    for (let i = 0; i < count; i++) {
                        let fp = get(i, "filePath");
                        if (fp.startsWith("file://"))
                            fp = fp.substring(7);
                        root._loadDesktopFile(fp);
                    }
                }
            }
        }
    }

    Connections {
        target: Greetd
        enabled: isPrimaryScreen

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(GreeterState.passwordBuffer);
                GreeterState.passwordBuffer = "";
                inputField.text = "";
                return;
            }
            if (!error)
                Greetd.respond("");
        }

        function onReadyToLaunch() {
            const sessionCmd = GreeterState.selectedSession || GreeterState.sessionExecs[GreeterState.currentSessionIndex];
            const sessionPath = GreeterState.selectedSessionPath || GreeterState.sessionPaths[GreeterState.currentSessionIndex];
            if (!sessionCmd) {
                GreeterState.pamState = "error";
                placeholderDelay.restart();
                return;
            }

            GreeterState.unlocking = true;
            launchTimeout.restart();
            GreetdMemory.setLastSessionId(sessionPath);
            GreetdMemory.setLastSuccessfulUser(GreeterState.username);
            Greetd.launch(sessionCmd.split(" "), ["XDG_SESSION_TYPE=wayland"]);
        }

        function onAuthFailure(message) {
            launchTimeout.stop();
            GreeterState.unlocking = false;
            GreeterState.pamState = "fail";
            GreeterState.passwordBuffer = "";
            inputField.text = "";
            placeholderDelay.restart();
        }

        function onError(error) {
            launchTimeout.stop();
            GreeterState.unlocking = false;
            GreeterState.pamState = "error";
            GreeterState.passwordBuffer = "";
            inputField.text = "";
            placeholderDelay.restart();
            Greetd.cancelSession();
        }
    }

    Timer {
        id: launchTimeout
        interval: 8000
        onTriggered: {
            if (!GreeterState.unlocking)
                return;
            GreeterState.unlocking = false;
            GreeterState.pamState = "error";
            placeholderDelay.restart();
            Greetd.cancelSession();
        }
    }

    Timer {
        id: placeholderDelay
        interval: 4000
        onTriggered: GreeterState.pamState = ""
    }

    LockPowerMenu {
        id: powerMenu
        showLogout: false
        onClosed: {
            if (isPrimaryScreen && inputField && inputField.forceActiveFocus) {
                Qt.callLater(() => inputField.forceActiveFocus());
            }
        }
    }
}
