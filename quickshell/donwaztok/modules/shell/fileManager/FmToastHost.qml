pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services.shell
import qs.config as Theme
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var session

    readonly property int pad: Theme.Appearance.padding.large
    readonly property bool compact: width < 820

    readonly property bool jobVisible: {
        if (session.demoJobActive)
            return true;
        if (!FileManagerService.jobActive)
            return false;
        return !FileManagerService.jobOwner || FileManagerService.jobOwner === session;
    }
    readonly property real jobProgress: session.demoJobActive ? session.demoJobProgress : (FileManagerService.jobProgress || 0)
    readonly property string jobLabel: {
        if (session.demoJobActive)
            return session.demoJobLabel || qsTr("Working…");
        return FileManagerService.jobLabel.length ? FileManagerService.jobLabel : qsTr("Working…");
    }
    readonly property string jobKind: session.demoJobActive ? session.demoJobKind : FileManagerService.jobKind
    readonly property string jobIcon: {
        const kind = root.jobKind;
        if (kind === "extract")
            return "folder_zip";
        if (kind === "move")
            return "drive_file_move";
        if (kind === "trash" || kind === "delete" || kind === "empty-trash")
            return "delete";
        if (kind === "restore")
            return "undo";
        return "progress_activity";
    }

    readonly property var timedToasts: {
        const src = session.toasts || [];
        const out = [];
        for (let i = 0; i < src.length; ++i) {
            if ((src[i].lane || "timed") === "timed")
                out.push(src[i]);
        }
        return out;
    }

    readonly property var infoToast: {
        const src = session.toasts || [];
        for (let i = src.length - 1; i >= 0; --i) {
            if (src[i].lane === "info")
                return src[i];
        }
        return null;
    }

    z: 92

    // Left — progress
    ProgressLane {
        id: progressLane
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        anchors.leftMargin: root.jobVisible ? root.pad : root.pad - 24
        width: root.compact ? 240 : 300
        visible: root.jobVisible || opacity > 0.01
        enabled: root.jobVisible
        opacity: root.jobVisible ? 1 : 0
        scale: root.jobVisible ? 1 : 0.86
        transformOrigin: Item.BottomLeft

        Behavior on opacity {
            Anim {
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
        Behavior on scale {
            Anim {
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
        Behavior on anchors.leftMargin {
            Anim {
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }

    // Center — timed actions
    Column {
        id: timedStack
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        spacing: Theme.Appearance.spacing.small
        width: root.compact ? Math.min(320, parent.width * 0.56) : 360

        Repeater {
            model: ScriptModel {
                values: root.timedToasts
            }

            delegate: TimedCard {
                required property var modelData
                required property int index
                width: timedStack.width
                toast: modelData
            }
        }
    }

    // Right — selection / folder info
    InfoLane {
        id: infoLane
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.infoToast ? root.pad : root.pad - 24
        anchors.bottomMargin: root.pad
        visible: !!root.infoToast || opacity > 0.01
        enabled: !!root.infoToast
        opacity: root.infoToast ? 1 : 0
        transformOrigin: Item.BottomRight

        Behavior on opacity {
            Anim {
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
        Behavior on anchors.rightMargin {
            Anim {
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }

    component ProgressLane: StyledRect {
        id: prog

        // Same radius as other toasts; pad clears the curve so the track isn't clipped
        readonly property int edgePad: Math.max(Theme.Appearance.padding.larger, Math.ceil(radius * 0.55))

        implicitHeight: headerRow.implicitHeight + 6 + 4 + prog.edgePad * 2
        radius: Theme.Appearance.rounding.large
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.94)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
        clip: true

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 4
            opacity: parent.opacity
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: prog.edgePad
            anchors.rightMargin: prog.edgePad
            anchors.topMargin: prog.edgePad
            spacing: Theme.Appearance.spacing.normal

            StyledRect {
                implicitWidth: 28
                implicitHeight: 28
                radius: Theme.Appearance.rounding.small
                color: Qt.alpha(Colours.palette.m3primary, 0.18)

                MaterialIcon {
                    id: progIcon
                    anchors.centerIn: parent
                    text: root.jobIcon
                    color: Colours.palette.m3primary
                    font.pointSize: Theme.Appearance.font.size.normal
                    fill: 1

                    SequentialAnimation on scale {
                        running: root.jobVisible
                        loops: Animation.Infinite
                        Anim {
                            to: 1.08
                            duration: 700
                            easing.bezierCurve: Theme.Appearance.anim.curves.expressiveEffects
                        }
                        Anim {
                            to: 1
                            duration: 700
                            easing.bezierCurve: Theme.Appearance.anim.curves.expressiveEffects
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.jobLabel
                color: Colours.palette.m3onSurface
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }

            StyledText {
                text: qsTr("%1%").arg(Math.round(root.jobProgress * 100))
                color: Colours.palette.m3primary
                font.pointSize: Theme.Appearance.font.size.small
                font.weight: Font.Bold
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: prog.edgePad
            anchors.rightMargin: prog.edgePad
            anchors.bottomMargin: prog.edgePad
            height: 4

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Colours.palette.m3onSurface, 0.14)
            }

            Rectangle {
                id: progFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(root.jobProgress > 0.001 ? height : 0, parent.width * Math.min(1, Math.max(0, root.jobProgress)))
                radius: height / 2
                color: Colours.palette.m3primary
                visible: width > 0

                Behavior on width {
                    Anim {
                        duration: Theme.Appearance.anim.durations.normal
                        easing.bezierCurve: Theme.Appearance.anim.curves.emphasizedDecel
                    }
                }
            }
        }
    }

    component TimedCard: Item {
        id: wrap

        property var toast: ({})
        readonly property int kind: Number(wrap.toast && wrap.toast.type) || 0
        readonly property bool showUndo: !!(wrap.toast && wrap.toast.showUndo)
        readonly property int timeoutMs: Number(wrap.toast && wrap.toast.timeout) || 0

        implicitHeight: timedBody.implicitHeight
        opacity: 0
        scale: 0.82
        transformOrigin: Item.Bottom

        Component.onCompleted: enterAnim.start()

        ParallelAnimation {
            id: enterAnim
            Anim {
                target: wrap
                property: "opacity"
                to: 1
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
            Anim {
                target: wrap
                property: "scale"
                to: 1
                duration: Theme.Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }

        Timer {
            interval: wrap.timeoutMs
            running: wrap.timeoutMs > 0
            repeat: false
            onTriggered: {
                if (wrap.showUndo)
                    root.session.dismissByKey("undo");
                else if (wrap.toast && wrap.toast.id)
                    root.session.dismissToast(wrap.toast.id);
            }
        }

        StyledRect {
            id: timedBody
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: timedCol.implicitHeight + Theme.Appearance.padding.normal * 2
            radius: Theme.Appearance.rounding.large
            clip: true
            color: {
                if (wrap.kind === 1)
                    return Colours.palette.m3successContainer;
                if (wrap.kind === 2)
                    return Colours.palette.m3secondary;
                if (wrap.kind === 3)
                    return Colours.palette.m3errorContainer;
                return Colours.palette.m3inverseSurface;
            }
            border.width: 1
            border.color: {
                if (wrap.kind === 1)
                    return Qt.alpha(Colours.palette.m3success, 0.4);
                if (wrap.kind === 2)
                    return Qt.alpha(Colours.palette.m3onSecondary, 0.25);
                if (wrap.kind === 3)
                    return Qt.alpha(Colours.palette.m3error, 0.45);
                return Qt.alpha(Colours.palette.m3outlineVariant, 0.35);
            }

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                z: -1
                level: 4
                opacity: wrap.opacity
            }

            ColumnLayout {
                id: timedCol
                x: Theme.Appearance.padding.normal
                y: Theme.Appearance.padding.normal
                width: parent.width - Theme.Appearance.padding.normal * 2
                spacing: Theme.Appearance.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Appearance.spacing.normal

                    StyledRect {
                        radius: Theme.Appearance.rounding.normal
                        implicitWidth: implicitHeight
                        implicitHeight: timedIcon.implicitHeight + Theme.Appearance.padding.smaller * 2
                        color: {
                            if (wrap.kind === 1)
                                return Colours.palette.m3success;
                            if (wrap.kind === 2)
                                return Colours.palette.m3secondaryContainer;
                            if (wrap.kind === 3)
                                return Colours.palette.m3error;
                            return Qt.alpha(Colours.palette.m3inverseOnSurface, 0.14);
                        }

                        MaterialIcon {
                            id: timedIcon
                            anchors.centerIn: parent
                            text: (wrap.toast && wrap.toast.icon) || "info"
                            color: {
                                if (wrap.kind === 1)
                                    return Colours.palette.m3onSuccess;
                                if (wrap.kind === 2)
                                    return Colours.palette.m3onSecondaryContainer;
                                if (wrap.kind === 3)
                                    return Colours.palette.m3onError;
                                return Colours.palette.m3inverseOnSurface;
                            }
                            font.pointSize: Math.round(Theme.Appearance.font.size.large * 1.15)

                            SequentialAnimation on scale {
                                running: wrap.showUndo
                                loops: Animation.Infinite
                                Anim {
                                    to: 1.12
                                    duration: 650
                                }
                                Anim {
                                    to: 1
                                    duration: 650
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: (wrap.toast && wrap.toast.title) || ""
                            color: {
                                if (wrap.kind === 1)
                                    return Colours.palette.m3onSuccessContainer;
                                if (wrap.kind === 2)
                                    return Colours.palette.m3onSecondary;
                                if (wrap.kind === 3)
                                    return Colours.palette.m3onErrorContainer;
                                return Colours.palette.m3inverseOnSurface;
                            }
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !!(wrap.toast && wrap.toast.message)
                            text: (wrap.toast && wrap.toast.message) || ""
                            color: {
                                if (wrap.kind === 1)
                                    return Colours.palette.m3onSuccessContainer;
                                if (wrap.kind === 2)
                                    return Colours.palette.m3onSecondary;
                                if (wrap.kind === 3)
                                    return Colours.palette.m3onErrorContainer;
                                return Colours.palette.m3inverseOnSurface;
                            }
                            opacity: 0.8
                            font.pointSize: Theme.Appearance.font.size.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledRect {
                        visible: wrap.showUndo
                        implicitWidth: undoLab.implicitWidth + Theme.Appearance.padding.normal * 2
                        implicitHeight: 34
                        radius: Theme.Appearance.rounding.full
                        color: wrap.kind === 2 ? Colours.palette.m3onSecondary : Colours.palette.m3inversePrimary

                        StateLayer {
                            color: wrap.kind === 2 ? Colours.palette.m3secondary : Colours.palette.m3inverseOnSurface
                            function onClicked(): void {
                                root.session.undoLast();
                            }
                        }

                        StyledText {
                            id: undoLab
                            anchors.centerIn: parent
                            text: qsTr("Undo")
                            color: wrap.kind === 2 ? Colours.palette.m3secondary : Colours.palette.m3inverseOnSurface
                            font.weight: Font.DemiBold
                        }
                    }

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            color: {
                                if (wrap.kind === 1)
                                    return Colours.palette.m3onSuccessContainer;
                                if (wrap.kind === 2)
                                    return Colours.palette.m3onSecondary;
                                if (wrap.kind === 3)
                                    return Colours.palette.m3onErrorContainer;
                                return Colours.palette.m3inverseOnSurface;
                            }
                            font.pointSize: Theme.Appearance.font.size.normal
                        }

                        StateLayer {
                            radius: Theme.Appearance.rounding.full
                            function onClicked(): void {
                                if (wrap.showUndo)
                                    root.session.dismissUndoToast();
                                else if (wrap.toast && wrap.toast.id)
                                    root.session.dismissToast(wrap.toast.id);
                            }
                        }
                    }
                }
            }
        }
    }

    component InfoLane: StyledRect {
        id: info

        readonly property var toast: root.infoToast
        implicitWidth: infoRow.implicitWidth + Theme.Appearance.padding.normal * 2
        implicitHeight: 40
        radius: Theme.Appearance.rounding.full
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.94)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
            opacity: parent.opacity
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Timer {
            interval: Number(info.toast && info.toast.timeout) || 0
            running: interval > 0 && !!(info.toast && info.toast.id)
            repeat: false
            onTriggered: {
                if (info.toast && info.toast.id)
                    root.session.dismissToast(info.toast.id);
            }
        }

        RowLayout {
            id: infoRow
            x: Theme.Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.Appearance.spacing.small

            MaterialIcon {
                text: (info.toast && info.toast.icon) || "info"
                color: Colours.palette.m3primary
                font.pointSize: Theme.Appearance.font.size.normal
                fill: 1
            }

            StyledText {
                text: (info.toast && info.toast.title) || ""
                color: Colours.palette.m3onSurface
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.maximumWidth: 220
            }
        }

        // Pulse when the title changes
        SequentialAnimation {
            id: infoPulse
            Anim {
                target: info
                property: "scale"
                to: 1.045
                duration: 160
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveFastSpatial
            }
            Anim {
                target: info
                property: "scale"
                to: 1
                duration: 280
                easing.bezierCurve: Theme.Appearance.anim.curves.expressiveDefaultSpatial
            }
        }

        Connections {
            target: root
            function onInfoToastChanged(): void {
                if (root.infoToast)
                    infoPulse.restart();
            }
        }
    }
}
