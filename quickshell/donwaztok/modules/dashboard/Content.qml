pragma ComponentBehavior: Bound

import qs.components
import qs.config
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state

    function clampCurrentTab(): void {
        const n = dashboardTabs.length;
        if (n <= 0)
            return;
        if (state.currentTab >= n)
            state.currentTab = n - 1;
        else if (state.currentTab < 0)
            state.currentTab = 0;
    }

    Component.onCompleted: Qt.callLater(() => root.clampCurrentTab())

    readonly property var dashboardTabs: {
        const allTabs = [
            {
                component: dashComponent,
                iconName: "dashboard",
                text: qsTr("Dashboard"),
                enabled: Config.dashboard.showDashboard
            },
            {
                component: mediaComponent,
                iconName: "queue_music",
                text: qsTr("Media"),
                enabled: Config.dashboard.showMedia
            },
            {
                component: performanceComponent,
                iconName: "speed",
                text: qsTr("Performance"),
                enabled: Config.dashboard.showPerformance && (Config.dashboard.performance.showCpu || Config.dashboard.performance.showGpu || Config.dashboard.performance.showMemory || Config.dashboard.performance.showStorage || Config.dashboard.performance.showNetwork || Config.dashboard.performance.showBattery)
            },
            {
                component: weatherComponent,
                iconName: "cloud",
                text: qsTr("Weather"),
                enabled: Config.dashboard.showWeather
            }
        ];
        return allTabs.filter(tab => tab.enabled);
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Appearance.padding.normal
        anchors.margins: Appearance.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        state: root.state
        tabs: root.dashboardTabs
    }

    ClippingRectangle {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Appearance.padding.large

        radius: Appearance.rounding.normal
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.state.currentTab
            readonly property int safeCurrentIndex: paneRepeater.count > 0 ? Math.min(Math.max(0, currentIndex), paneRepeater.count - 1) : 0
            readonly property Item currentItem: paneRepeater.count > 0 ? paneRepeater.itemAt(safeCurrentIndex) : null

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            implicitWidth: currentItem ? currentItem.implicitWidth : 0
            implicitHeight: currentItem ? currentItem.implicitHeight : 0

            contentX: currentItem ? currentItem.x : 0
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.state.currentTab = Math.min(root.state.currentTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.state.currentTab = Math.max(root.state.currentTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.state.currentTab = Math.min(root.state.currentTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.state.currentTab = Math.max(root.state.currentTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem ? currentItem.x : 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: paneRepeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        Layout.alignment: Qt.AlignTop

                        sourceComponent: modelData.component

                        Component.onCompleted: active = Qt.binding(() => {
                            const n = paneRepeater.count;
                            if (n <= 0)
                                return false;
                            const current = Math.min(Math.max(0, root.state.currentTab), n - 1);
                            if (index === current)
                                return true;
                            if (index === current - 1 || index === current + 1)
                                return true;
                            return false;
                        })
                    }
                }
            }

            Component {
                id: dashComponent
                Dash {
                    visibilities: root.visibilities
                    state: root.state
                }
            }

            Component {
                id: mediaComponent
                Media {
                    visibilities: root.visibilities
                }
            }

            Component {
                id: performanceComponent
                Performance {}
            }

            Component {
                id: weatherComponent
                Weather {}
            }

            Behavior on contentX {
                Anim {}
            }
        }
    }

    Connections {
        target: paneRepeater

        function onCountChanged(): void {
            root.clampCurrentTab();
        }
    }

    Behavior on implicitWidth {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }
}
