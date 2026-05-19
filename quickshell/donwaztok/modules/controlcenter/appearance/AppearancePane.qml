pragma ComponentBehavior: Bound

import ".."
import "../components"
import "./sections"
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

    property real animDurationsScale: Config.appearance.anim.durations.scale ?? 1
    property string fontFamilyMaterial: Config.appearance.font.family.material ?? "Material Symbols Rounded"
    property string fontFamilyMono: Config.appearance.font.family.mono ?? "CaskaydiaCove NF"
    property string fontFamilySans: Config.appearance.font.family.sans ?? "Rubik"
    property real fontSizeScale: Config.appearance.font.size.scale ?? 1
    property real paddingScale: Config.appearance.padding.scale ?? 1
    property real roundingScale: Config.appearance.rounding.scale ?? 1
    property real spacingScale: Config.appearance.spacing.scale ?? 1
    property real borderRounding: Config.border.rounding ?? 1
    property real borderThickness: Config.border.thickness ?? 1

    property bool desktopClockEnabled: Config.background.desktopClock.enabled ?? false
    property real desktopClockScale: Config.background.desktopClock.scale ?? 1
    property string desktopClockPosition: Config.background.desktopClock.position ?? "bottom-right"
    property bool desktopClockShadowEnabled: Config.background.desktopClock.shadow.enabled ?? true
    property real desktopClockShadowOpacity: Config.background.desktopClock.shadow.opacity ?? 0.7
    property real desktopClockShadowBlur: Config.background.desktopClock.shadow.blur ?? 0.4
    property bool desktopClockBackgroundEnabled: Config.background.desktopClock.background.enabled ?? false
    property real desktopClockBackgroundOpacity: Config.background.desktopClock.background.opacity ?? 0.7
    property bool desktopClockBackgroundBlur: Config.background.desktopClock.background.blur ?? false
    property bool desktopClockInvertColors: Config.background.desktopClock.invertColors ?? false
    property bool backgroundEnabled: Config.background.enabled ?? true
    property bool wallpaperEnabled: Config.background.wallpaperEnabled ?? true

    anchors.fill: parent

    function saveConfig() {
        Config.appearance.anim.durations.scale = root.animDurationsScale;

        Config.appearance.font.family.material = root.fontFamilyMaterial;
        Config.appearance.font.family.mono = root.fontFamilyMono;
        Config.appearance.font.family.sans = root.fontFamilySans;
        Config.appearance.font.size.scale = root.fontSizeScale;

        Config.appearance.padding.scale = root.paddingScale;
        Config.appearance.rounding.scale = root.roundingScale;
        Config.appearance.spacing.scale = root.spacingScale;

        Config.background.desktopClock.enabled = root.desktopClockEnabled;
        Config.background.enabled = root.backgroundEnabled;
        Config.background.desktopClock.scale = root.desktopClockScale;
        Config.background.desktopClock.position = root.desktopClockPosition;
        Config.background.desktopClock.shadow.enabled = root.desktopClockShadowEnabled;
        Config.background.desktopClock.shadow.opacity = root.desktopClockShadowOpacity;
        Config.background.desktopClock.shadow.blur = root.desktopClockShadowBlur;
        Config.background.desktopClock.background.enabled = root.desktopClockBackgroundEnabled;
        Config.background.desktopClock.background.opacity = root.desktopClockBackgroundOpacity;
        Config.background.desktopClock.background.blur = root.desktopClockBackgroundBlur;
        Config.background.desktopClock.invertColors = root.desktopClockInvertColors;

        Config.background.wallpaperEnabled = root.wallpaperEnabled;

        Config.border.rounding = root.borderRounding;
        Config.border.thickness = root.borderThickness;

        Config.save();
    }

    StyledFlickable {
        id: contentFlickable
        readonly property var rootPane: root
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

            readonly property var rootPane: contentFlickable.rootPane

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
                        title: qsTr("Appearance")
                        subtitle: qsTr("Theme, type, wallpaper, and desktop clock.")
                        layoutBottomMargin: Appearance.spacing.smaller
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Appearance.spacing.smaller
                        implicitHeight: 1
                        color: ControlCenterChrome.paneSectionRule
                    }

                    ThemeModeSection {
                        id: themeModeSection
                        Layout.fillWidth: true
                    }

                    PreferencesGroup {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        title: qsTr("Wallpaper")
                        description: qsTr("Select an image; the compositor will be updated if supported.")

                        WallpaperGrid {
                            session: root.session
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(cellHeight, Math.min(contentHeight, 420))
                        }
                    }

                    BackgroundSection {
                        id: backgroundSection
                        Layout.fillWidth: true
                        rootPane: contentFlickable.rootPane
                    }

                    DesktopClockSection {
                        id: desktopClockSection
                        Layout.fillWidth: true
                        rootPane: contentFlickable.rootPane
                    }

                    AnimationsSection {
                        id: animationsSection
                        Layout.fillWidth: true
                        rootPane: contentFlickable.rootPane
                    }

                    FontsSection {
                        id: fontsSection
                        Layout.fillWidth: true
                        rootPane: contentFlickable.rootPane
                    }

                    ScalesSection {
                        id: scalesSection
                        Layout.fillWidth: true
                        rootPane: contentFlickable.rootPane
                    }

                    BorderSection {
                        id: borderSection
                        Layout.fillWidth: true
                        rootPane: contentFlickable.rootPane
                    }
                }
            }
        }
    }
}
