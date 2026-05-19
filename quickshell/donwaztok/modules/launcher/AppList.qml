pragma ComponentBehavior: Bound

import "items"
import qs.modules.launcher.services
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services.shell
import qs.config
import qs.services
import qs.modules.common.functions
import Quickshell
import QtQuick

StyledListView {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities

    model: ScriptModel {
        id: model

        onValuesChanged: root.currentIndex = 0
    }

    spacing: 0
    orientation: Qt.Vertical

    readonly property real clipboardViewportHeight: {
        root.contentHeight;
        const limit = Math.min(Config.launcher.clipboardMaxShown, count);
        let total = 0;
        for (let i = 0; i < limit; ++i) {
            if (i > 0)
                total += spacing;
            const item = root.itemAtIndex(i);
            if (item)
                total += item.implicitHeight;
            else {
                const entry = model.values?.[i];
                if (entry && Cliphist.entryIsImage(entry)) {
                    const match = entry.match(/(\d+)x(\d+)/);
                    if (match) {
                        const srcW = parseInt(match[1]);
                        const srcH = parseInt(match[2]);
                        const listWidth = root.width > 0 ? root.width : Config.launcher.sizes.itemWidth;
                        const maxW = Math.max(0, listWidth - 24 - 24 - Appearance.spacing.normal);
                        const maxH = Config.launcher.sizes.clipboardImagePreviewHeight;
                        const scale = Math.min(maxW / srcW, maxH / srcH);
                        total += Appearance.padding.smaller * 2 + srcH * scale;
                    } else {
                        total += Config.launcher.sizes.clipboardImagePreviewHeight;
                    }
                } else {
                    total += Config.launcher.sizes.itemHeight;
                }
            }
        }
        return total;
    }

    implicitHeight: root.state === "calc" && root.currentItem
        ? root.currentItem.implicitHeight
        : root.state === "clipboard"
        ? root.clipboardViewportHeight
        : (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: Item {
        visible: root.state !== "calc"
        y: root.currentItem?.y ?? 0
        width: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3onSurface, 0.1)
        }

        Rectangle {
            width: 3
            height: parent.height
            color: Colours.palette.m3primary
        }

        Behavior on y {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }

        Behavior on implicitHeight {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }

    state: {
        const text = search.text;
        if (text.startsWith(Config.launcher.clipboardPrefix))
            return "clipboard";
        const prefix = Config.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            for (const action of ["calc", "scheme", "variant"])
                if (text.startsWith(`${prefix}${action} `))
                    return action;

            return "actions";
        }

        return "apps";
    }

    onStateChanged: {
        if (state === "scheme" || state === "variant")
            Schemes.reload();
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                model.values: Apps.search(search.text)
                root.delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                model.values: Actions.query(search.text)
                root.delegate: actionItem
            }
        },
        State {
            name: "calc"

            PropertyChanges {
                model.values: [0]
                root.delegate: calcPanelItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                model.values: Schemes.query(search.text)
                root.delegate: schemeItem
            }
        },
        State {
            name: "variant"

            PropertyChanges {
                model.values: M3Variants.query(search.text)
                root.delegate: variantItem
            }
        },
        State {
            name: "clipboard"

            PropertyChanges {
                model.values: Cliphist.fuzzyQuery(StringUtils.cleanOnePrefix(search.text, [Config.launcher.clipboardPrefix]).trim())
                root.delegate: clipboardItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardAccel
                }
            }
            PropertyAction {
                targets: [model, root]
                properties: "values,delegate"
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standardDecel
                }
            }
            PropertyAction {
                targets: [root.add, root.remove]
                property: "enabled"
                value: true
            }
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: !root.state

        Anim {
            properties: "opacity,scale"
            from: 0
            to: 1
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            properties: "opacity,scale"
            from: 1
            to: 0
            easing.bezierCurve: Appearance.anim.curves.standardAccel
        }
    }

    move: Transition {
        Anim { property: "y" }
        Anim { properties: "opacity,scale"; to: 1 }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
        Anim { properties: "opacity,scale"; to: 1 }
    }

    displaced: Transition {
        Anim { property: "y" }
        Anim { properties: "opacity,scale"; to: 1 }
    }

    Component {
        id: appItem

        AppItem {
            visibilities: root.visibilities
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: calcPanelItem

        CalcPanel {
            search: root.search
            visibilities: root.visibilities
            bottomRadius: Config.launcher.sizes.cardRadius
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Component {
        id: variantItem

        VariantItem {
            list: root
        }
    }

    Component {
        id: clipboardItem

        ClipboardItem {
            list: root
            visibilities: root.visibilities
        }
    }

}
