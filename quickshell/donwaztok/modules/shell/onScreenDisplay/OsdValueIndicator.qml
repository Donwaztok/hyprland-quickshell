import qs.components
import qs.components.effects
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property real value
    required property string icon
    required property string name
    property bool rotateIcon: false
    property bool scaleIcon: false

    readonly property real shadowMargin: 10

    implicitWidth: 260 + 2 * shadowMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * shadowMargin

    Elevation {
        anchors.fill: valueIndicator
        radius: valueIndicator.radius
        level: 2
        opacity: valueIndicator.opacity
        scale: valueIndicator.scale
    }

    StyledRect {
        id: valueIndicator

        anchors.fill: parent
        anchors.margins: root.shadowMargin
        radius: Appearance.rounding.full
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        implicitHeight: valueRow.implicitHeight + Appearance.padding.normal * 2

        opacity: 0
        scale: 0.9
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.small
            }
        }

        Behavior on scale {
            Anim {
                duration: Appearance.anim.durations.expressiveFastSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
            }
        }

        RowLayout {
            id: valueRow

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large * 1.5
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignHCenter
                text: root.icon
                fill: 1
                font.pointSize: Appearance.font.size.larger * (root.scaleIcon ? 0.75 + 0.35 * root.value : 1.1)
                rotation: 180 * (root.rotateIcon ? root.value : 0)

                Behavior on font.pointSize {
                    Anim {}
                }

                Behavior on rotation {
                    Anim {}
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.name
                    }

                    StyledText {
                        text: Math.round(root.value * 100)
                        font.family: Appearance.font.family.mono
                    }
                }

                StyledRect {
                    id: track

                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: Appearance.rounding.full
                    color: Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.25 : 0.3)

                    StyledRect {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, root.value))
                        radius: parent.radius
                        color: Colours.palette.m3primary

                        Behavior on width {
                            Anim {
                                duration: Appearance.anim.durations.small
                            }
                        }
                    }
                }
            }
        }
    }
}
