pragma ComponentBehavior: Bound

import qs.modules.launcher.services
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import qs.services
import Quickshell
import QtQuick

Item {
    id: root

    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight

    readonly property int padding: Appearance.padding.large
    readonly property int rounding: Appearance.rounding.large

    function applyWallpaperFromLauncher(): bool {
        if (!list.showWallpapers)
            return false;
        const pv = list.currentList;
        const wp = pv?.currentWallpaperEntry ?? pv?.currentItem?.modelData;
        const path = wp?.path;
        if (!path)
            return false;
        if (Colours.scheme === "dynamic" && path !== Wallpapers.actualCurrent)
            Wallpapers.previewColourLock = true;
        Wallpapers.setWallpaper(path);
        root.visibilities.launcher = false;
        return true;
    }

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: searchWrapper.height + listWrapper.height + padding * 2

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: searchWrapper.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - searchWrapper.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    StyledRect {
        id: searchWrapper

        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Appearance.rounding.full
        border.width: 1
        border.color: search.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, Colours.light ? 0.34 : 0.48)

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        Behavior on border.color {
            CAnim {}
        }

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            showChrome: false
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Appearance.spacing.small
            anchors.rightMargin: Appearance.spacing.small

            placeholderText: qsTr("Type \"%1\" for commands").arg(Config.launcher.actionPrefix)

            onAccepted: {
                if (list.showWallpapers) {
                    root.applyWallpaperFromLauncher();
                    return;
                }
                const currentItem = list.currentList?.currentItem;
                if (!currentItem)
                    return;
                if (text.startsWith(Config.launcher.clipboardPrefix)) {
                    if (typeof currentItem.modelData === "string")
                        Cliphist.copy(currentItem.modelData);
                    root.visibilities.launcher = false;
                } else if (text.startsWith(Config.launcher.actionPrefix)) {
                    if (text.startsWith(`${Config.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.visibilities.launcher = false;
                }
            }

            Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
            Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

            Keys.onEscapePressed: root.visibilities.launcher = false

            Keys.onPressed: event => {
                if (list.showWallpapers && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    if (root.applyWallpaperFromLauncher())
                        event.accepted = true;
                    return;
                }
                if (!Config.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                forceActiveFocus();
                if (Config.launcher.pendingOpenPrefix) {
                    search.text = Config.launcher.pendingOpenPrefix;
                    Config.launcher.pendingOpenPrefix = "";
                }
            }

            function applyPendingPrefix(): void {
                if (!Config.launcher.pendingOpenPrefix)
                    return;
                search.text = Config.launcher.pendingOpenPrefix;
                Config.launcher.pendingOpenPrefix = "";
                Qt.callLater(() => search.forceActiveFocus());
            }

            Connections {
                target: root.visibilities

                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher) {
                        search.text = "";
                        return;
                    }
                    applyPendingPrefix();
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session)
                        search.forceActiveFocus();
                }
            }

            Connections {
                target: Visibilities

                function onLauncherPrefixNonceChanged(): void {
                    if (!root.visibilities.launcher)
                        return;
                    search.applyPendingPrefix();
                }
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }
        }
    }
}
