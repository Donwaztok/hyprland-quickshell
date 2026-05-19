import qs.components
import qs.components.controls
import qs.components.containers
import qs.services.shell
import qs.config
import Quickshell
import QtQuick

Item {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities
    property int bottomRadius: Config.launcher.sizes.cardRadius

    property alias calcRow: resultRow
    property alias suggestionList: suggestions

    width: parent?.width ?? implicitWidth
    implicitHeight: (resultRow.visible ? resultRow.implicitHeight : 0) + suggestions.implicitHeight

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    CalcItem {
        id: resultRow

        anchors.top: parent.top
        visible: Qalculator.canEvaluate(root.search.text)
        width: parent.width
        search: root.search
        visibilities: root.visibilities
        bottomRadius: suggestions.count === 0 ? root.bottomRadius : 0
    }

    StyledListView {
        id: suggestions

        anchors.top: resultRow.visible ? resultRow.bottom : parent.top
        width: parent.width
        spacing: 0
        orientation: Qt.Vertical
        interactive: count > Config.launcher.maxShown

        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: ListView.ApplyRange
        highlightFollowsCurrentItem: false

        highlight: Item {
            y: suggestions.currentItem?.y ?? 0
            width: suggestions.width
            implicitHeight: suggestions.currentItem?.implicitHeight ?? 0

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
        }

        model: ScriptModel {
            values: Qalculator.suggestions(root.search.text)

            onValuesChanged: suggestions.currentIndex = 0
        }

        implicitHeight: count === 0 ? 0
                        : (Config.launcher.sizes.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

        delegate: CalcSuggestionItem {
            width: suggestions.width
            search: root.search
            bottomRadius: root.bottomRadius
        }
    }
}
