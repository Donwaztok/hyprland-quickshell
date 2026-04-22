pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services.shell
import qs.config
import QtQuick

Item {
    id: root

    property string text: ""
    property var validator: null
    property bool readOnly: false
    property int horizontalAlignment: TextInput.AlignHCenter
    /** When false, the field is read-only and dimmed (does not shadow `Item.enabled`). */
    property bool inputEnabled: true

    // Expose activeFocus through alias to avoid FINAL property override
    readonly property alias hasFocus: inputField.activeFocus

    signal textEdited(string text)
    signal editingFinished

    implicitWidth: 70
    implicitHeight: inputField.implicitHeight
    opacity: root.inputEnabled ? 1 : 0.5

    StyledTextField {
        id: inputField

        anchors.fill: parent
        horizontalAlignment: root.horizontalAlignment
        validator: root.validator
        readOnly: root.readOnly
        enabled: root.inputEnabled

        onActiveFocusChanged: {
            if (!inputField.activeFocus)
                inputField.text = root.text;
        }
        Component.onCompleted: inputField.text = root.text

        Connections {
            target: root
            function onTextChanged() {
                if (!inputField.activeFocus && inputField.text !== root.text)
                    inputField.text = root.text;
            }
        }

        onTextChanged: {
            root.text = text;
            root.textEdited(text);
        }

        onEditingFinished: {
            root.editingFinished();
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.NoButton
        enabled: root.inputEnabled
    }
}
