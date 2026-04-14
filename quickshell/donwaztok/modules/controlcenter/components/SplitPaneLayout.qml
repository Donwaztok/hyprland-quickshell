pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.services.shell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    spacing: 0

    property Component leftContent: null
    property Component rightContent: null

    property real leftWidthRatio: 0.36
    property int leftMinimumWidth: 400
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})

    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    Item {
        id: leftPane

        Layout.preferredWidth: Math.floor(parent.width * root.leftWidthRatio)
        Layout.minimumWidth: root.leftMinimumWidth
        Layout.fillHeight: true

        ClippingRectangle {
            id: leftClippingRect

            anchors.fill: parent
            anchors.topMargin: ControlCenterChrome.splitPaneLeftOuterMargin
            anchors.bottomMargin: ControlCenterChrome.splitPaneLeftOuterMargin
            anchors.leftMargin: Appearance.padding.smaller
            anchors.rightMargin: Appearance.padding.smaller

            radius: Appearance.rounding.small
            color: ControlCenterChrome.splitPaneListSurface
            border.width: 0

            Loader {
                id: leftLoader

                anchors.fill: parent
                anchors.margins: ControlCenterChrome.splitPaneLeftContentPadding

                sourceComponent: root.leftContent

                Component.onCompleted: {
                    for (const key in root.leftLoaderProperties) {
                        leftLoader[key] = root.leftLoaderProperties[key];
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        color: ControlCenterChrome.splitPaneDivider
    }

    Item {
        id: rightPane

        Layout.fillWidth: true
        Layout.fillHeight: true

        ClippingRectangle {
            id: rightClippingRect

            anchors.fill: parent
            anchors.topMargin: ControlCenterChrome.splitPaneOuterMargin
            anchors.bottomMargin: ControlCenterChrome.splitPaneOuterMargin
            anchors.leftMargin: Appearance.padding.smaller
            anchors.rightMargin: ControlCenterChrome.splitPaneOuterMargin

            radius: Appearance.rounding.small
            color: ControlCenterChrome.splitPaneDetailSurface
            border.width: 0

            Loader {
                id: rightLoader

                anchors.fill: parent
                anchors.margins: ControlCenterChrome.splitPaneContentPadding

                sourceComponent: root.rightContent

                Component.onCompleted: {
                    for (const key in root.rightLoaderProperties) {
                        rightLoader[key] = root.rightLoaderProperties[key];
                    }
                }
            }
        }
    }
}
