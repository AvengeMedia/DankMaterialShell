pragma ComponentBehavior: Bound

import QtQuick
import qs.Services

Item {
    id: keyboard_controller
    readonly property var log: Log.scoped("KeyboardController")

    // reference on the TextInput
    property Item target
    //Booléan on the state of the keyboard
    property bool isKeyboardActive: false

    property var rootObject

    function show() {
        if (!isKeyboardActive && keyboard === null) {
            keyboard = keyboardComponent.createObject(keyboard_controller.rootObject);
            keyboard.target = keyboard_controller.target;
            keyboard.dismissed.connect(hide);
            isKeyboardActive = true;
        } else
            log.debug("The keyboard is already shown");
    }

    function hide() {
        if (isKeyboardActive && keyboard !== null) {
            keyboard.destroy();
            isKeyboardActive = false;
        } else
            log.debug("The keyboard is already hidden");
    }

    // private
    property Item keyboard: null
    Component {
        id: keyboardComponent
        Keyboard {}
    }
}
