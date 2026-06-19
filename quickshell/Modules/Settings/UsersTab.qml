pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    property string statusText: ""
    property bool statusIsError: false
    property bool operationPending: false
    property string pendingUsername: ""
    property string pendingPassword: ""
    property string pendingConfirm: ""
    property bool pendingAdmin: false
    property bool pendingGreeter: false

    function _resetForm() {
        pendingUsername = "";
        pendingPassword = "";
        pendingConfirm = "";
        pendingAdmin = false;
        pendingGreeter = false;
        usernameField.text = "";
        passwordField.text = "";
        confirmField.text = "";
    }

    function _passwordsMatch() {
        return pendingPassword.length > 0 && pendingPassword === pendingConfirm;
    }

    function _createCanProceed() {
        return !operationPending && UsersService.isValidUsername(pendingUsername) && !UsersService.userExists(pendingUsername) && _passwordsMatch();
    }

    Connections {
        target: UsersService
        function onOperationCompleted(op, username, success, message) {
            root.operationPending = false;
            root.statusIsError = !success;
            if (success) {
                root.statusText = message + (username ? (" — " + username) : "");
                if (op === "create")
                    root._resetForm();
            } else {
                root.statusText = (username ? (username + ": ") : "") + message;
            }
        }
    }

    ConfirmModal {
        id: deleteUserConfirm
    }

    ConfirmModal {
        id: adminToggleConfirm
    }

    ConfirmModal {
        id: greeterToggleConfirm
    }

    DankFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn
            topPadding: 4
            width: Math.min(600, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            StyledText {
                width: parent.width
                visible: !PolkitService.polkitAvailable
                text: I18n.tr("Polkit integration is disabled. User management requires Polkit to elevate privileges.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.error
                wrapMode: Text.WordWrap
            }

            SettingsCard {
                width: parent.width
                iconName: "group"
                title: I18n.tr("Existing Users")
                settingKey: "usersList"
                visible: PolkitService.polkitAvailable

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Administrator group:")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: UsersService.adminGroup
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: Theme.spacingM
                        height: 1
                    }

                    StyledText {
                        text: I18n.tr("Greeter group:")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: UsersService.greeterGroup
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: Theme.spacingM
                        height: 1
                    }

                    StyledText {
                        text: UsersService.refreshing ? I18n.tr("Refreshing...") : ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Greeter group members can sync their login-screen theme with dms greeter sync --profile after logging out and back in.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: UsersService.users

                    Rectangle {
                        id: userRow
                        required property var modelData
                        width: parent.width
                        height: Math.max(48, rowContent.implicitHeight + Theme.spacingS * 2)
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        readonly property bool isLastAdmin: modelData.isAdmin && UsersService.adminMembers.length <= 1

                        Row {
                            id: rowContent
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "account_circle"
                                size: Theme.iconSize
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSize - actionButtons.width - Theme.spacingM * 3
                                spacing: 2
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: userRow.modelData.username
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        visible: userRow.modelData.isAdmin
                                        width: adminChipText.implicitWidth + Theme.spacingS * 2
                                        height: adminChipText.implicitHeight + Theme.spacingXS * 2
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.primary, 0.15)
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            id: adminChipText
                                            anchors.centerIn: parent
                                            text: I18n.tr("admin")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.primary
                                            font.weight: Font.Medium
                                        }
                                    }

                                    Rectangle {
                                        visible: userRow.modelData.isGreeter
                                        width: greeterChipText.implicitWidth + Theme.spacingS * 2
                                        height: greeterChipText.implicitHeight + Theme.spacingXS * 2
                                        radius: Theme.cornerRadius
                                        color: Theme.withAlpha(Theme.secondary, 0.15)
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            id: greeterChipText
                                            anchors.centerIn: parent
                                            text: I18n.tr("Greeter")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.secondary
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                StyledText {
                                    text: userRow.modelData.gecos && userRow.modelData.gecos.length > 0 ? userRow.modelData.gecos + " · UID " + userRow.modelData.uid : "UID " + userRow.modelData.uid
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            Row {
                                id: actionButtons
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                DankActionButton {
                                    id: greeterToggleBtn
                                    readonly property bool actionBlocked: root.operationPending
                                    buttonSize: 36
                                    iconSize: 20
                                    iconName: userRow.modelData.isGreeter ? "login" : "how_to_reg"
                                    iconColor: userRow.modelData.isGreeter ? Theme.secondary : Theme.surfaceVariantText
                                    opacity: actionBlocked ? 0.4 : 1.0
                                    tooltipText: userRow.modelData.isGreeter ? I18n.tr("Remove greeter login access") : I18n.tr("Allow greeter login access")
                                    tooltipSide: "left"
                                    onClicked: {
                                        if (actionBlocked)
                                            return;
                                        const enableGreeter = !userRow.modelData.isGreeter;
                                        greeterToggleConfirm.showWithOptions({
                                            title: enableGreeter ? I18n.tr("Allow greeter access?") : I18n.tr("Remove greeter access?"),
                                            message: enableGreeter ? I18n.tr("Add \"%1\" to the %2 group? They must log out and back in, then run dms greeter sync --profile to publish their login-screen theme.").arg(userRow.modelData.username).arg(UsersService.greeterGroup) : I18n.tr("Remove \"%1\" from the %2 group?").arg(userRow.modelData.username).arg(UsersService.greeterGroup),
                                            confirmText: enableGreeter ? I18n.tr("Allow") : I18n.tr("Remove"),
                                            confirmColor: Theme.primary,
                                            onConfirm: () => {
                                                root.operationPending = true;
                                                root.statusText = "";
                                                UsersService.setGreeterAccess(userRow.modelData.username, enableGreeter, null);
                                            }
                                        });
                                    }
                                }

                                DankActionButton {
                                    id: adminToggleBtn
                                    readonly property bool actionBlocked: root.operationPending || (userRow.isLastAdmin && userRow.modelData.isAdmin)
                                    buttonSize: 36
                                    iconSize: 20
                                    iconName: userRow.modelData.isAdmin ? "shield_person" : "shield"
                                    iconColor: userRow.modelData.isAdmin ? Theme.primary : Theme.surfaceVariantText
                                    opacity: actionBlocked ? 0.4 : 1.0
                                    tooltipText: (userRow.isLastAdmin && userRow.modelData.isAdmin) ? I18n.tr("Cannot remove the only administrator") : (userRow.modelData.isAdmin ? I18n.tr("Remove admin") : I18n.tr("Make admin"))
                                    tooltipSide: "left"
                                    onClicked: {
                                        if (actionBlocked)
                                            return;
                                        const makeAdmin = !userRow.modelData.isAdmin;
                                        adminToggleConfirm.showWithOptions({
                                            title: makeAdmin ? I18n.tr("Grant admin?") : I18n.tr("Remove admin?"),
                                            message: makeAdmin ? I18n.tr("Add \"%1\" to the %2 group?").arg(userRow.modelData.username).arg(UsersService.adminGroup) : I18n.tr("Remove \"%1\" from the %2 group?").arg(userRow.modelData.username).arg(UsersService.adminGroup),
                                            confirmText: makeAdmin ? I18n.tr("Grant") : I18n.tr("Remove"),
                                            confirmColor: Theme.primary,
                                            onConfirm: () => {
                                                root.operationPending = true;
                                                root.statusText = "";
                                                UsersService.setAdmin(userRow.modelData.username, makeAdmin, null);
                                            }
                                        });
                                    }
                                }

                                DankActionButton {
                                    id: deleteBtn
                                    readonly property bool actionBlocked: root.operationPending || !UsersService.canDelete(userRow.modelData.username)
                                    buttonSize: 36
                                    iconSize: 20
                                    iconName: "delete"
                                    iconColor: Theme.error
                                    opacity: actionBlocked ? 0.4 : 1.0
                                    tooltipText: userRow.isLastAdmin ? I18n.tr("Cannot delete the only administrator") : I18n.tr("Delete user")
                                    tooltipSide: "left"
                                    onClicked: {
                                        if (actionBlocked)
                                            return;
                                        deleteUserConfirm.showWithOptions({
                                            title: I18n.tr("Delete user?"),
                                            message: I18n.tr("Delete \"%1\" and remove the home directory? This cannot be undone.").arg(userRow.modelData.username),
                                            confirmText: I18n.tr("Delete"),
                                            confirmColor: Theme.primary,
                                            onConfirm: () => {
                                                root.operationPending = true;
                                                root.statusText = "";
                                                UsersService.deleteUser(userRow.modelData.username, null);
                                            }
                                        });
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: UsersService.users.length === 0 && !UsersService.refreshing
                    text: I18n.tr("No human user accounts found.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "person_add"
                title: I18n.tr("Create User")
                settingKey: "createUser"
                visible: PolkitService.polkitAvailable

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Username")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: usernameField
                        width: parent.width
                        placeholderText: I18n.tr("e.g. alice")
                        backgroundColor: Theme.surfaceContainerHighest
                        normalBorderColor: usernameInvalid ? Theme.error : Theme.outlineMedium
                        focusedBorderColor: usernameInvalid ? Theme.error : Theme.primary

                        readonly property bool usernameInvalid: text.length > 0 && (!UsersService.isValidUsername(text) || UsersService.userExists(text))

                        onTextEdited: {
                            root.pendingUsername = text.trim();
                        }
                    }

                    StyledText {
                        width: parent.width
                        visible: usernameField.text.length > 0 && !UsersService.isValidUsername(usernameField.text)
                        text: I18n.tr("Username must start with a lowercase letter or underscore and contain only lowercase letters, digits, hyphens, or underscores.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        visible: usernameField.text.length > 0 && UsersService.isValidUsername(usernameField.text) && UsersService.userExists(usernameField.text)
                        text: I18n.tr("A user with that name already exists.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Password")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: passwordField
                        width: parent.width
                        placeholderText: I18n.tr("Set initial password")
                        echoMode: TextInput.Password
                        showPasswordToggle: true
                        backgroundColor: Theme.surfaceContainerHighest
                        normalBorderColor: Theme.outlineMedium
                        focusedBorderColor: Theme.primary
                        onTextEdited: root.pendingPassword = text
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: I18n.tr("Confirm password")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: confirmField
                        width: parent.width
                        placeholderText: I18n.tr("Re-enter password")
                        echoMode: TextInput.Password
                        showPasswordToggle: true
                        backgroundColor: Theme.surfaceContainerHighest
                        normalBorderColor: confirmMismatch ? Theme.error : Theme.outlineMedium
                        focusedBorderColor: confirmMismatch ? Theme.error : Theme.primary

                        readonly property bool confirmMismatch: text.length > 0 && text !== passwordField.text

                        onTextEdited: root.pendingConfirm = text
                    }

                    StyledText {
                        width: parent.width
                        visible: confirmField.text.length > 0 && confirmField.text !== passwordField.text
                        text: I18n.tr("Passwords do not match.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                    }
                }

                SettingsToggleRow {
                    settingKey: "createUserAdmin"
                    tags: ["user", "admin", "sudo", "wheel"]
                    text: I18n.tr("Grant administrator privileges")
                    description: I18n.tr("Add the new user to the %1 group so they can use sudo.").arg(UsersService.adminGroup)
                    checked: root.pendingAdmin
                    onToggled: checked => root.pendingAdmin = checked
                }

                SettingsToggleRow {
                    settingKey: "createUserGreeter"
                    tags: ["user", "greeter", "login", "sync"]
                    text: I18n.tr("Allow greeter login access")
                    description: I18n.tr("Add the new user to the %1 group so they can run dms greeter sync --profile.").arg(UsersService.greeterGroup)
                    checked: root.pendingGreeter
                    onToggled: checked => root.pendingGreeter = checked
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingM

                    DankButton {
                        text: root.operationPending ? I18n.tr("Working...") : I18n.tr("Create User")
                        iconName: "person_add"
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        enabled: root._createCanProceed()
                        onClicked: {
                            if (!root._createCanProceed())
                                return;
                            root.operationPending = true;
                            root.statusText = "";
                            UsersService.createUser(root.pendingUsername, root.pendingPassword, root.pendingAdmin, root.pendingGreeter, null);
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.statusText
                        color: root.statusIsError ? Theme.error : Theme.primary
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        width: parent.width - parent.children[0].width - Theme.spacingM
                    }
                }
            }
        }
    }
}
