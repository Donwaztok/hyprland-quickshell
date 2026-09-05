import qs.modules.common
import qs.modules.common.widgets
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

    Rectangle {
        id: content
        anchors.centerIn: parent

        implicitHeight: root.pillHeight
        implicitWidth: root.expanded ? contentRow.implicitWidth + root.pillPadding * 2 : implicitHeight
        clip: true

        topLeftRadius: root.barMode ? implicitHeight / 2 : 6
        bottomLeftRadius: implicitHeight - topLeftRadius
        bottomRightRadius: bottomLeftRadius
        topRightRadius: bottomLeftRadius

        color: Appearance.colors.colPrimary

        Behavior on topLeftRadius {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        Behavior on implicitWidth {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        Row {
            id: contentRow
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: root.pillPadding
            }
            spacing: root.barMode ? 14 : 12

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                iconSize: root.iconPixelSize
                color: Appearance.colors.colOnPrimary
                animateChange: true
                text: root.materialSymbol
            }

            FadeLoader {
                id: descriptionLoader
                anchors.verticalCenter: parent.verticalCenter
                shown: root.expanded
                sourceComponent: StyledText {
                    color: Appearance.colors.colOnPrimary
                    text: root.description
                    font.pixelSize: root.barMode
                        ? (Appearance.font.pixelSize.small ?? 13)
                        : (Appearance.font.pixelSize.smaller ?? 12)
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                }
            }
        }
    }
}
