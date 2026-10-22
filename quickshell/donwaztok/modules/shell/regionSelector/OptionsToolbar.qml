import qs.components
import qs.components.controls
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick

// Rect / circle selection mode switch shown at the bottom of the region selector.
Item {
    id: root

    property var action
    property var selectionMode
    signal dismiss

    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight

    Elevation {
        anchors.fill: background
        radius: background.radius
        level: 2
    }

    StyledRect {
        id: background

        implicitWidth: modes.implicitWidth + Appearance.padding.small * 2
        implicitHeight: 48 // matches the CursorGuide pill in bar mode
        radius: Appearance.rounding.full
        color: Colours.tPalette.m3surfaceContainer

        Row {
            id: modes

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            Repeater {
                model: [
                    {
                        icon: "activity_zone",
                        name: qsTr("Rect"),
                        mode: RegionSelection.SelectionMode.RectCorners
                    },
                    {
                        icon: "gesture",
                        name: qsTr("Circle"),
                        mode: RegionSelection.SelectionMode.Circle
                    }
                ]

                IconTextButton {
                    required property var modelData

                    type: IconTextButton.Tonal
                    icon: modelData.icon
                    text: modelData.name
                    checked: root.selectionMode === modelData.mode
                    internalChecked: checked // onCheckedChanged alone misses the initial value
                    verticalPadding: Appearance.padding.normal
                    horizontalPadding: Appearance.padding.large
                    activeColour: Colours.palette.m3secondaryContainer
                    activeOnColour: Colours.palette.m3onSecondaryContainer
                    inactiveColour: "transparent"
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant

                    onClicked: root.selectionMode = modelData.mode
                }
            }
        }
    }
}
