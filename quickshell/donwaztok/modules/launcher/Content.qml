pragma ComponentBehavior: Bound

import qs.modules.launcher.services
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import qs.services
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight
    required property real availableHeight

    readonly property int padding: 12
    readonly property int rounding: Config.launcher.sizes.cardRadius
    readonly property int searchBarHeight: Config.launcher.sizes.searchBarHeight
    readonly property color cardColor: {
        const base = Colours.palette.m3surfaceContainer;
        return Qt.rgba(base.r, base.g, base.b, Config.launcher.cardOpacity);
    }

    readonly property real panelMaxHeight: {
        const ratioCap = search.text.startsWith(Config.launcher.clipboardPrefix)
            ? root.screen.height * Config.launcher.clipboardMaxHeightRatio
            : root.maxHeight;
        return Math.min(ratioCap, root.availableHeight);
    }

    readonly property real listMaxHeight: {
        const reserved = searchRow.height + listDivider.height + 8;
        return root.panelMaxHeight - reserved;
    }

    readonly property bool showResults: {
        const t = search.text;
        const actionP = Config.launcher.actionPrefix;
        const clipP = Config.launcher.clipboardPrefix;
        if (list.showWallpapers)
            return true;
        if (t.startsWith(clipP))
            return true;
        if (t.startsWith(actionP))
            return true;
        return t.trim().length > 0;
    }

    function focusSearchField(): void {
        search.forceActiveFocus();
        search.selectAll();
    }

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

    width: launcherCard.width
    height: launcherCard.height
    implicitWidth: launcherCard.implicitWidth
    implicitHeight: launcherCard.implicitHeight

    Item {
        id: launcherCard

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: Config.launcher.sizes.itemWidth
        implicitHeight: searchRow.height
                        + (root.showResults ? listDivider.height + list.implicitHeight : 0)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.55)
        }

        StyledRect {
            id: cardPlate

            anchors.fill: parent
            radius: root.rounding
            color: root.cardColor
        }

        Item {
            id: cardContent

            anchors.fill: parent
            z: 1

            Item {
                id: searchRow

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right

                height: root.searchBarHeight

                StyledTextField {
                    id: search

                    showChrome: false
                    anchors.fill: parent
                    anchors.leftMargin: root.padding
                    anchors.rightMargin: root.padding + searchIcon.implicitWidth + 8

                    color: Colours.palette.m3onSurface
                    placeholderTextColor: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.65)
                    font.pointSize: Appearance.font.size.normal
                    font.weight: Font.Normal
                    padding: 0

                    placeholderText: qsTr("Search")

                    onAccepted: {
                        if (list.showWallpapers) {
                            root.applyWallpaperFromLauncher();
                            return;
                        }
                        if (list.showQuickCalc && list.quickCalcRow) {
                            list.quickCalcRow.onClicked();
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
                            if (list.currentList?.state === "calc") {
                                const panel = list.currentList.currentItem;
                                const result = panel?.calcRow?.resultText ?? "";
                                if (result.length > 0 && result !== "…") {
                                    panel.calcRow.onClicked();
                                } else {
                                    const suggestion = panel?.suggestionList?.currentItem?.modelData;
                                    if (suggestion)
                                        Qalculator.applySuggestion(search, suggestion.snippet);
                                }
                            } else {
                                currentItem.modelData.onClicked(list.currentList);
                            }
                        } else {
                            Apps.launch(currentItem.modelData);
                            root.visibilities.launcher = false;
                        }
                    }

                    Keys.onUpPressed: {
                        if (list.currentList?.state === "calc") {
                            const panel = list.currentList.currentItem;
                            panel?.suggestionList?.decrementCurrentIndex();
                        } else {
                            list.currentList?.decrementCurrentIndex();
                        }
                    }
                    Keys.onDownPressed: {
                        if (list.currentList?.state === "calc") {
                            const panel = list.currentList.currentItem;
                            panel?.suggestionList?.incrementCurrentIndex();
                        } else {
                            list.currentList?.incrementCurrentIndex();
                        }
                    }
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
                        Qt.callLater(() => root.focusSearchField());
                    }

                    Connections {
                        target: root.visibilities

                        function onLauncherChanged(): void {
                            if (!root.visibilities.launcher) {
                                search.text = "";
                                return;
                            }
                            search.applyPendingPrefix();
                            Qt.callLater(() => root.focusSearchField());
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
                    id: searchIcon

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.padding

                    text: "search"
                    font.weight: 300
                    font.pointSize: Appearance.font.size.large
                    color: search.activeFocus
                        ? Colours.palette.m3primary
                        : Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.75)

                    Behavior on color { CAnim {} }
                }
            }

            Rectangle {
                id: listDivider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: searchRow.bottom

                height: root.showResults ? 1 : 0
                opacity: root.showResults ? 1 : 0
                color: Qt.alpha(Colours.palette.m3onSurface, 0.12)

                Behavior on opacity {
                    Anim {
                        duration: Appearance.anim.durations.expressiveEffects
                        easing.bezierCurve: Appearance.anim.curves.expressiveEffects
                    }
                }
            }

            ContentList {
                id: list

                showResults: root.showResults
                content: root
                visibilities: root.visibilities
                panels: root.panels
                maxHeight: root.listMaxHeight
                search: search
                padding: root.padding
                rounding: root.rounding

                anchors.top: listDivider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
            }
        }
    }
}
