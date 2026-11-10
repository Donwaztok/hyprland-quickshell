pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services.shell
import qs.config
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Session session

    spacing: Appearance.spacing.larger

    SettingsHeader {
        icon: "bluetooth"
        title: qsTr("Bluetooth Settings")
    }

    PreferencesGroup {
        title: qsTr("Adapter status")
        description: qsTr("General adapter settings")

        Toggle {
            label: qsTr("Powered")
            checked: Bluetooth.defaultAdapter?.enabled ?? false
            toggle.onToggled: {
                const adapter = Bluetooth.defaultAdapter;
                if (adapter)
                    adapter.enabled = checked;
            }
        }

        Toggle {
            label: qsTr("Discoverable")
            checked: Bluetooth.defaultAdapter?.discoverable ?? false
            toggle.onToggled: {
                const adapter = Bluetooth.defaultAdapter;
                if (adapter)
                    adapter.discoverable = checked;
            }
        }

        Toggle {
            label: qsTr("Pairable")
            checked: Bluetooth.defaultAdapter?.pairable ?? false
            toggle.onToggled: {
                const adapter = Bluetooth.defaultAdapter;
                if (adapter)
                    adapter.pairable = checked;
            }
        }
    }

    PreferencesGroup {
        title: qsTr("Adapter properties")
        description: qsTr("Per-adapter settings")

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Current adapter")
                font.weight: Font.Medium
            }

            Item {
                id: adapterPickerButton

                property bool expanded: false

                implicitWidth: adapterPicker.implicitWidth + Appearance.padding.normal * 2
                implicitHeight: adapterPicker.implicitHeight + Appearance.padding.smaller * 2

                StyledRect {
                    z: 0
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: Colours.tPalette.m3surfaceContainer
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, Colours.light ? 0.4 : 0.52)
                }

                StateLayer {
                    z: 2
                    radius: Appearance.rounding.small

                    function onClicked(): void {
                        adapterPickerButton.expanded = !adapterPickerButton.expanded;
                    }
                }

                RowLayout {
                    id: adapterPicker

                    z: 1
                    anchors.fill: parent
                    anchors.margins: Appearance.padding.normal
                    anchors.topMargin: Appearance.padding.smaller
                    anchors.bottomMargin: Appearance.padding.smaller
                    spacing: Appearance.spacing.normal

                    StyledText {
                        Layout.leftMargin: Appearance.padding.small
                        text: Bluetooth.defaultAdapter?.name ?? qsTr("None")
                    }

                    MaterialIcon {
                        text: "expand_more"
                    }
                }

                Elevation {
                    anchors.fill: adapterListBg
                    radius: adapterListBg.radius
                    opacity: adapterPickerButton.expanded ? 1 : 0
                    scale: adapterPickerButton.expanded ? 1 : 0.7
                    level: 2

                    Behavior on opacity {
                        Anim {}
                    }

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.expressiveFastSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
                        }
                    }
                }

                StyledClippingRect {
                    id: adapterListBg

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    implicitHeight: adapterPickerButton.expanded ? adapterList.implicitHeight : adapterPickerButton.implicitHeight

                    color: Colours.palette.m3secondaryContainer
                    radius: Appearance.rounding.small
                    opacity: adapterPickerButton.expanded ? 1 : 0
                    scale: adapterPickerButton.expanded ? 1 : 0.7

                    ColumnLayout {
                        id: adapterList

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        spacing: 0

                        Repeater {
                            model: Bluetooth.adapters

                            Item {
                                id: adapter

                                required property BluetoothAdapter modelData

                                Layout.fillWidth: true
                                implicitHeight: adapterInner.implicitHeight + Appearance.padding.normal * 2

                                StateLayer {
                                    disabled: !adapterPickerButton.expanded

                                    function onClicked(): void {
                                        adapterPickerButton.expanded = false;
                                        root.session.bt.currentAdapter = adapter.modelData;
                                    }
                                }

                                RowLayout {
                                    id: adapterInner

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Appearance.padding.normal
                                    spacing: Appearance.spacing.normal

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: Appearance.padding.small
                                        text: adapter.modelData.name
                                        color: Colours.palette.m3onSecondaryContainer
                                    }

                                    MaterialIcon {
                                        text: "check"
                                        color: Colours.palette.m3onSecondaryContainer
                                        visible: adapter.modelData === root.session.bt.currentAdapter
                                    }
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        Anim {}
                    }

                    Behavior on scale {
                        Anim {
                            duration: Appearance.anim.durations.expressiveFastSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {
                            duration: Appearance.anim.durations.expressiveDefaultSpatial
                            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Discoverable timeout")
                font.weight: Font.Medium
            }

            CustomSpinBox {
                min: 0
                value: root.session.bt.currentAdapter?.discoverableTimeout ?? 0
                onValueModified: value => {
                    if (root.session.bt.currentAdapter) {
                        root.session.bt.currentAdapter.discoverableTimeout = value;
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Adapter name")
                font.weight: Font.Medium
            }

            // Quickshell's BluetoothAdapter.name is read-only, so the adapter cannot be renamed here
            StyledText {
                text: root.session.bt.currentAdapter?.name ?? ""
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    PreferencesGroup {
        title: qsTr("Adapter information")
        description: qsTr("Information about the default adapter")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small / 2

            StyledText {
                text: qsTr("Adapter state")
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: Bluetooth.defaultAdapter ? BluetoothAdapterState.toString(Bluetooth.defaultAdapter.state) : qsTr("Unknown")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.normal
                text: qsTr("Dbus path")
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: Bluetooth.defaultAdapter?.dbusPath ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.normal
                text: qsTr("Adapter id")
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: Bluetooth.defaultAdapter?.adapterId ?? ""
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
            }
        }
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: parent.label
            color: Colours.palette.m3onSurface
            font.weight: Font.Medium
        }

        StyledSwitch {
            id: toggle

            cLayer: 2
        }
    }
}
