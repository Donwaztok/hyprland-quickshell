pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import "items"
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    required property var content
    required property PersistentProperties visibilities
    required property var panels
    required property real maxHeight
    required property bool showResults
    required property StyledTextField search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: {
        const p = `${Config.launcher.actionPrefix}wallpaper`;
        const t = search.text;
        return t === p || t.startsWith(p + " ");
    }
    readonly property bool showQuickCalc: Qalculator.looksLikeMath(search.text)
    readonly property var quickCalcRow: quickCalcLoader.item
    readonly property Item currentList: showWallpapers ? wallpaperList.item : appList.item

    readonly property real appsContentHeight: {
        if (root.showQuickCalc)
            return quickCalcLoader.item?.implicitHeight ?? Config.launcher.sizes.itemHeight;
        const list = appList.item;
        if (!list || list.count === 0)
            return empty.implicitHeight;
        return list.implicitHeight;
    }

    implicitHeight: {
        if (!root.showResults)
            return 0;
        if (root.showWallpapers)
            return Config.launcher.sizes.wallpaperHeight;
        return Math.min(root.maxHeight, root.appsContentHeight);
    }

    visible: root.showResults
    opacity: root.showResults ? 1 : 0

    clip: true
    state: showWallpapers ? "wallpapers" : "apps"

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.expressiveEffects
            easing.bezierCurve: Appearance.anim.curves.expressiveEffects
        }
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                appList.active: root.showResults && !root.showQuickCalc
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                wallpaperList.active: root.showResults
            }
        }
    ]

    Behavior on state {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.expressiveEffects
                easing.bezierCurve: Appearance.anim.curves.standardAccel
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.expressiveEffects
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
        }
    }

    StyledClippingRect {
        anchors.fill: parent
        bottomLeftRadius: root.rounding
        bottomRightRadius: root.rounding
        color: "transparent"

        Loader {
            id: quickCalcLoader

            active: root.showResults && root.showQuickCalc
            width: parent.width

            sourceComponent: CalcItem {
                search: root.search
                visibilities: root.visibilities
                bottomRadius: root.rounding
            }
        }

        Loader {
            id: appList

            active: false

            anchors.fill: parent

            sourceComponent: AppList {
                search: root.search
                visibilities: root.visibilities
            }
        }

        Loader {
            id: wallpaperList

            active: false

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            sourceComponent: WallpaperList {
                search: root.search
                visibilities: root.visibilities
                panels: root.panels
                content: root.content
            }
        }

        Row {
            id: empty

            opacity: root.showQuickCalc ? 0 : (root.currentList?.count === 0 ? 1 : 0)
            scale: root.showQuickCalc ? 0.5 : (root.currentList?.count === 0 ? 1 : 0.5)

            spacing: Appearance.spacing.normal
            padding: Appearance.padding.large

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            MaterialIcon {
                text: root.state === "wallpapers" ? "wallpaper_slideshow" : "manage_search"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.extraLarge

                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: root.state === "wallpapers" ? qsTr("No wallpapers found") : qsTr("No results")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.larger
                    font.weight: 500
                }

                StyledText {
                    text: {
                        if (root.state !== "wallpapers")
                            return qsTr("Try searching for something else");
                        if (Wallpapers.list.length === 0)
                            return qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir));
                        if ((root.currentList?.count ?? 0) === 0)
                            return qsTr("No file matches that search — delete the text after %1wallpaper to list every image.").arg(Config.launcher.actionPrefix);
                        return "";
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.normal
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            Behavior on scale {
                Anim {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }
        }
    }
}
