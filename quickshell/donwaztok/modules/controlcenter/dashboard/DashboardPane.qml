pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    // General Settings (not named `enabled` — that shadows `Item.enabled` and triggers Qt warnings)
    property bool dashboardEnabled: Config.dashboard.enabled ?? true
    property bool showOnHover: Config.dashboard.showOnHover ?? true
    property int mediaUpdateInterval: Config.dashboard.mediaUpdateInterval ?? 1000
    property int resourceUpdateInterval: Config.dashboard.resourceUpdateInterval ?? 1000
    property int dragThreshold: Config.dashboard.dragThreshold ?? 50

    // Dashboard Tabs
    property bool showDashboard: Config.dashboard.showDashboard ?? true
    property bool showMedia: Config.dashboard.showMedia ?? true
    property bool showPerformance: Config.dashboard.showPerformance ?? true
    property bool showWeather: Config.dashboard.showWeather ?? true
    property string weatherLocation: Config.services.weatherLocation ?? ""

    // Performance Resources
    property bool showBattery: Config.dashboard.performance.showBattery ?? false
    property bool showGpu: Config.dashboard.performance.showGpu ?? true
    property bool showCpu: Config.dashboard.performance.showCpu ?? true
    property bool showMemory: Config.dashboard.performance.showMemory ?? true
    property bool showStorage: Config.dashboard.performance.showStorage ?? true
    property bool showNetwork: Config.dashboard.performance.showNetwork ?? true

    anchors.fill: parent

    function saveConfig() {
        Config.dashboard.enabled = root.dashboardEnabled;
        Config.dashboard.showOnHover = root.showOnHover;
        Config.dashboard.mediaUpdateInterval = root.mediaUpdateInterval;
        Config.dashboard.resourceUpdateInterval = root.resourceUpdateInterval;
        Config.dashboard.dragThreshold = root.dragThreshold;
        Config.dashboard.showDashboard = root.showDashboard;
        Config.dashboard.showMedia = root.showMedia;
        Config.dashboard.showPerformance = root.showPerformance;
        Config.dashboard.showWeather = root.showWeather;
        Config.services.weatherLocation = root.weatherLocation.trim();
        Config.dashboard.performance.showBattery = root.showBattery;
        Config.dashboard.performance.showGpu = root.showGpu;
        Config.dashboard.performance.showCpu = root.showCpu;
        Config.dashboard.performance.showMemory = root.showMemory;
        Config.dashboard.performance.showStorage = root.showStorage;
        Config.dashboard.performance.showNetwork = root.showNetwork;
        // Note: sizes properties are readonly and cannot be modified
        Config.save();
    }

    StyledFlickable {
        id: contentFlickable
        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: contentLayout.implicitHeight

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: contentFlickable
        }

        ColumnLayout {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Appearance.spacing.normal

            Item {
                Layout.fillWidth: true
                implicitHeight: constrainedColumn.implicitHeight

                readonly property real maxContentWidth: 860

                ColumnLayout {
                    id: constrainedColumn
                    width: Math.min(parent.width, parent.maxContentWidth)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.normal

                    SettingsHeader {
                        title: qsTr("Dashboard")
                        subtitle: qsTr("Which tabs appear, weather location, and performance meters.")
                        layoutBottomMargin: Appearance.spacing.smaller
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Appearance.spacing.smaller
                        implicitHeight: 1
                        color: ControlCenterChrome.paneSectionRule
                    }

                    GeneralSection {
                        Layout.fillWidth: true
                        rootItem: root
                    }

                    PerformanceSection {
                        Layout.fillWidth: true
                        rootItem: root
                    }
                }
            }
        }
    }
}
