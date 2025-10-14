pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: keyboard_controller

    // reference on the TextInput
    property Item target
    //Booléan on the state of the keyboard
    property bool isKeyboardActive: false

    property var rootObject

    function show() {
        if (!isKeyboardActive && keyboard === null) {
            keyboard = keyboardComponent.createObject(keyboard_controller.rootObject);
            keyboard.target = keyboard_controller.target;
            isKeyboardActive = true;
        } else
            console.info("The keyboard is already shown");
    }

    function hide() {
        if (isKeyboardActive && keyboard !== null) {
            keyboard.destroy();
            isKeyboardActive = false;
        } else
            console.info("The keyboard is already hidden");
    }

    // private
    property Item keyboard: null
    Component {
        id: keyboardComponent
        Keyboard {}
    }
}
