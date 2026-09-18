import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Settings.Widgets
import qs.Modules.DankDash

SettingsRow {
    id: root

    required property string entryId
    required property var spec

    readonly property var value: DashRegistry.option(entryId, spec.key)
    readonly property var choices: spec.choices ?? []
    readonly property int choiceIndex: choices.findIndex(c => c.value === value)

    function commit(next) {
        DashRegistry.setOption(entryId, spec.key, next);
    }

    title: spec.text ?? spec.key
    subtitle: spec.description ?? ""
    clickable: spec.type === "toggle"
    onClicked: commit(value !== true)

    Loader {
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: {
            switch (root.spec.type) {
            case "toggle":
                return toggleControl;
            case "choice":
                return choiceControl;
            case "number":
                return numberControl;
            }
            return null;
        }
    }

    Component {
        id: toggleControl

        DankToggle {
            hideText: true
            checked: root.value === true
            onToggled: checked => root.commit(checked)
        }
    }

    Component {
        id: choiceControl

        DankDropdown {
            options: root.choices.map(c => c.text)
            currentValue: root.choices[root.choiceIndex]?.text ?? ""
            onValueChanged: value => {
                const choice = root.choices.find(c => c.text === value);
                if (!choice)
                    return;
                root.commit(choice.value);
            }
        }
    }

    Component {
        id: numberControl

        DankNumberStepper {
            readonly property real step: root.spec.step ?? 1
            readonly property real current: Number(root.value) || 0

            text: current + (root.spec.unit ?? "")
            incrementEnabled: root.spec.max === undefined || current + step <= root.spec.max
            decrementEnabled: root.spec.min === undefined || current - step >= root.spec.min
            onIncrement: () => root.commit(current + step)
            onDecrement: () => root.commit(current - step)
        }
    }
}
