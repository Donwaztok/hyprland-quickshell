pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

// Label + searchable font dropdown (bounded height, type-to-filter in search field).
RowLayout {
    id: root

    required property string label
    required property string currentFamily

    signal familyChosen(string familyName)

    Layout.fillWidth: true
    spacing: Appearance.spacing.normal

    property var _fontRows: []

    Component.onCompleted: {
        const fam = Qt.fontFamilies();
        const rows = [];
        for (let i = 0; i < fam.length; i++) {
            const n = fam[i];
            rows.push({
                text: n,
                value: n
            });
        }
        root._fontRows = rows;
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

        // Same pattern as OptionSelectRow: no `parent.width` in layout hints (avoids recursive rearrange).
        Layout.fillWidth: true
        Layout.minimumWidth: 180
        Layout.maximumWidth: 400
        implicitHeight: trigger.height

        StyledRect {
            id: trigger

            anchors.fill: parent
            implicitHeight: 40
            radius: Appearance.rounding.normal
            color: triggerMa.containsMouse ? Colours.tPalette.m3surfaceContainer : Colours.tPalette.m3surfaceContainerHighest
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.55 : 0.42)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Appearance.padding.normal
                anchors.rightMargin: Appearance.padding.normal
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.currentFamily
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menuPopup.open()
            }
        }

        SelectMenuPopup {
            id: menuPopup

            anchor: trigger
            rows: root._fontRows
            showSearch: true
            searchThreshold: 6
            minimumPopupWidth: 320

            onValueChosen: value => {
                root.familyChosen(value);
            }
        }
    }
}
