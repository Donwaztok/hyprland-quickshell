import qs.components
import qs.services.shell
import qs.config
import QtQuick

Item {
    id: root
    property var action
    property var selectionMode
    property bool windowPickMode: false
    // Bottom-bar placement: larger pill, expand text on hover (no auto-hide timer).
    property bool barMode: false

    property string description: {
        if (root.windowPickMode)
            return qsTr("Click a window to capture (hold Ctrl)");
        switch (root.action) {
        case RegionSelection.SnipAction.Copy:
        case RegionSelection.SnipAction.Edit:
            return qsTr("Copy region (LMB) or annotate (RMB) · Ctrl: window");
        case RegionSelection.SnipAction.Search:
            return qsTr("Search with Google Lens · Ctrl: window");
        case RegionSelection.SnipAction.CharRecognition:
            return qsTr("Recognize text · Ctrl: window");
        default:
            return "";
        }
    }
    property string materialSymbol: {
        if (root.windowPickMode)
            return "desktop_windows";
        switch (root.action) {
        case RegionSelection.SnipAction.Copy:
        case RegionSelection.SnipAction.Edit:
            return "content_cut";
        case RegionSelection.SnipAction.Search:
            return "image_search";
        case RegionSelection.SnipAction.CharRecognition:
            return "document_scanner";
        default:
            return "";
        }
    }

    property bool showDescription: !root.barMode
    function hideDescription() {
        if (root.barMode)
            return;
        root.showDescription = false;
    }
    Timer {
        id: descTimeout
        interval: 1000
        running: !root.barMode
        onTriggered: root.hideDescription()
    }
    onActionChanged: {
        if (root.barMode)
            return;
        root.showDescription = true;
        descTimeout.restart();
    }
    onWindowPickModeChanged: {
        if (root.barMode)
            return;
        root.showDescription = true;
        descTimeout.restart();
    }

    readonly property bool expanded: root.barMode
        ? (hoverArea.containsMouse || root.windowPickMode)
        : root.showDescription

    property int margins: root.barMode ? 0 : 8
    property real pillHeight: root.barMode ? 48 : 38
    property real iconPixelSize: root.barMode ? 26 : 22
    property real pillPadding: root.barMode ? 12 : 8

    implicitWidth: content.implicitWidth + margins * 2
    implicitHeight: content.implicitHeight + margins * 2

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: root.barMode
        acceptedButtons: Qt.NoButton
    }

    StyledRect {
        id: content
        anchors.centerIn: parent

        implicitHeight: root.pillHeight
        implicitWidth: root.expanded ? contentRow.implicitWidth + root.pillPadding * 2 : implicitHeight
        clip: true

        topLeftRadius: root.barMode ? implicitHeight / 2 : 6
        bottomLeftRadius: implicitHeight - topLeftRadius
        bottomRightRadius: bottomLeftRadius
        topRightRadius: bottomLeftRadius

        color: Colours.palette.m3primary

        Behavior on topLeftRadius {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
        Behavior on implicitWidth {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }

        Row {
            id: contentRow
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: root.pillPadding
            }
            spacing: root.barMode ? 14 : 12

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                font.pointSize: root.iconPixelSize * 0.75 // px → pt at 96 dpi
                color: Colours.palette.m3onPrimary
                fill: 1
                animate: true
                text: root.materialSymbol
            }

            FadeLoader {
                id: descriptionLoader
                anchors.verticalCenter: parent.verticalCenter
                shown: root.expanded
                sourceComponent: StyledText {
                    color: Colours.palette.m3onPrimary
                    text: root.description
                    font.pointSize: root.barMode ? Appearance.font.size.normal : Appearance.font.size.smaller
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                }
            }
        }
    }
}
