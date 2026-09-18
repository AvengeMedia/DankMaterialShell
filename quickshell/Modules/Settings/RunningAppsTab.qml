import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets

Item {
    id: root

    SettingsPage {
        id: mainColumn

        SettingsCard {
            width: parent.width
            iconName: "find_replace"
            title: I18n.tr("App ID substitutions")
            settingKey: "appIdSubstitutions"
            tags: ["app", "icon", "substitution", "replacement", "pattern", "window", "class", "regex"]

            headerActions: [
                DankActionButton {
                    iconName: "restart_alt"
                    tooltipText: I18n.tr("Reset to default")
                    visible: JSON.stringify(SettingsData.appIdSubstitutions) !== JSON.stringify(SettingsData.getDefaultAppIdSubstitutions())
                    iconColor: Theme.surfaceVariantText
                    onClicked: SettingsData.resetAppIdSubstitutions()
                },
                DankActionButton {
                    iconName: "add"
                    Accessible.name: I18n.tr("Add")
                    iconColor: Theme.primary
                    onClicked: SettingsData.addAppIdSubstitution("", "", "exact")
                }
            ]

            SettingsRow {
                subtitle: I18n.tr("Map window class names to icon names for proper icon display")
            }

            Repeater {
                model: SettingsData.appIdSubstitutions

                delegate: SettingsGroup {
                    id: substitutionGroup
                    required property var modelData
                    required property int index
                    readonly property bool isSettingsRow: true
                    readonly property bool transparentSlot: true

                    SettingsTextFieldRow {
                        id: patternField
                        leftIconName: "filter_list"
                        text: I18n.tr("Pattern", "noun, text field label for a match or filter pattern")
                        value: substitutionGroup.modelData.pattern
                        onEditingFinished: value => SettingsData.updateAppIdSubstitution(substitutionGroup.index, value, replacementField.value, substitutionGroup.modelData.type)

                        actions: DankActionButton {
                            iconName: "delete"
                            iconColor: Theme.error
                            Accessible.name: I18n.tr("Remove")
                            onClicked: SettingsData.removeAppIdSubstitution(substitutionGroup.index)
                        }
                    }

                    SettingsTextFieldRow {
                        id: replacementField
                        leftIconName: "swap_horiz"
                        text: I18n.tr("Replacement", "text field label, replacement for the matched app name pattern")
                        value: substitutionGroup.modelData.replacement
                        onEditingFinished: value => SettingsData.updateAppIdSubstitution(substitutionGroup.index, patternField.value, value, substitutionGroup.modelData.type)
                    }

                    SettingsDropdownRow {
                        text: I18n.tr("Type")
                        currentValue: substitutionGroup.modelData.type
                        options: ["exact", "contains", "regex"]
                        onValueChanged: value => SettingsData.updateAppIdSubstitution(substitutionGroup.index, substitutionGroup.modelData.pattern, substitutionGroup.modelData.replacement, value)
                    }
                }
            }
        }
    }
}
