pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

// Label + dropdown for `{ text, value }[]` — compact popup; search appears when list is long.
RowLayout {
    id: root

    required property string label
    required property var options
    required property string currentValue

    property bool enabled: true

    signal optionChosen(string value)

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal
    opacity: root.enabled ? 1 : 0.45

    readonly property string currentLabel: {
        const o = root.options;
        if (!o || !o.length)
            return root.currentValue;
        for (let i = 0; i < o.length; i++) {
            if (o[i].value === root.currentValue)
                return o[i].text;
        }
        return root.currentValue;
    }

    StyledText {
        Layout.fillWidth: true
        text: root.label
        font.weight: Font.Medium
        color: Colours.palette.m3onSurface
        elide: Text.ElideRight
    }

    Item {
        id: triggerHost

        Layout.preferredWidth: Math.min(280, Math.floor(parent.width * 0.5))
        Layout.minimumWidth: 140
        Layout.maximumWidth: 320
        Layout.fillWidth: false
        implicitHeight: trigger.height

        StyledRect {
            id: trigger

            anchors.fill: parent
            implicitHeight: 40
            radius: Appearance.rounding.normal
            color: !root.enabled ? Colours.tPalette.m3surfaceContainerLow : triggerMa.containsMouse ? Colours.tPalette.m3surfaceContainer : Colours.tPalette.m3surfaceContainerHighest
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.55 : 0.42)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.normal
                anchors.rightMargin: Appearance.padding.normal
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.currentLabel
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                MaterialIcon {
                    text: "expand_more"
                    font.pointSize: Appearance.font.size.normal
                    color: Colours.palette.m3onSurfaceVariant
                    rotation: menuPopup.opened ? 180 : 0

                    Behavior on rotation {
                        Anim {
                            duration: Appearance.anim.durations.small
                            easing.bezierCurve: Appearance.anim.curves.standard
                        }
                    }
                }
            }

            MouseArea {
                id: triggerMa

                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menuPopup.open()
            }
        }

        SelectMenuPopup {
            id: menuPopup

            anchor: trigger
            rows: root.options
            showSearch: true
            searchThreshold: 8
            minimumPopupWidth: 200

            onValueChosen: value => {
                root.optionChosen(value);
            }
        }
    }
}
