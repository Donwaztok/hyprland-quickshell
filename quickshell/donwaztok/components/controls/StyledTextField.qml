pragma ComponentBehavior: Bound

import ".."
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Controls

TextField {
    id: root

    /** When false, background and border are omitted so a parent row can draw one outline around icons + field. */
    property bool showChrome: true

    color: Colours.palette.m3onSurface
    placeholderTextColor: Colours.palette.m3outline
    font.family: Appearance.font.family.sans
    font.pointSize: Appearance.font.size.smaller
    /** NativeRendering misplaces placeholder vs cursor/border on many setups (search in SelectMenuPopup). */
    renderType: TextField.QtRendering
    verticalAlignment: Text.AlignVCenter
    cursorVisible: !readOnly

    // Single `padding` keeps placeholder, text, and cursor aligned; mixing larger top/bottom
    // with defaults elsewhere misplaces placeholder vs border on several Qt builds.
    padding: Appearance.padding.smaller

    background: StyledRect {
        radius: root.showChrome ? Appearance.rounding.small : 0
        color: !root.showChrome ? "transparent" : (root.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2))
        border.width: root.showChrome ? 1 : 0
        border.color: root.showChrome ? (root.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, Colours.light ? 0.34 : 0.48)) : "transparent"

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }
    }

    cursorDelegate: StyledRect {
        id: cursor

        property bool disableBlink

        implicitWidth: 2
        color: Colours.palette.m3primary
        radius: Appearance.rounding.normal

        Connections {
            target: root

            function onCursorPositionChanged(): void {
                if (root.activeFocus && root.cursorVisible) {
                    cursor.opacity = 1;
                    cursor.disableBlink = true;
                    enableBlink.restart();
                }
            }
        }

        Timer {
            id: enableBlink

            interval: 100
            onTriggered: cursor.disableBlink = false
        }

        Timer {
            running: root.activeFocus && root.cursorVisible && !cursor.disableBlink
            repeat: true
            triggeredOnStart: true
            interval: 500
            onTriggered: parent.opacity = parent.opacity === 1 ? 0 : 1
        }

        Binding {
            when: !root.activeFocus || !root.cursorVisible
            cursor.opacity: 0
        }

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on placeholderTextColor {
        CAnim {}
    }
}
