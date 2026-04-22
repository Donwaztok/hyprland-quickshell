pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

PreferencesGroup {
    id: root

    required property var rootPane

    Layout.fillWidth: true
    title: qsTr("Background")
    description: qsTr("Whether the compositor draws the background layer and shows your wallpaper.")

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        SwitchRow {
            flatStyle: true
            label: qsTr("Background enabled")
            checked: rootPane.backgroundEnabled
            onToggled: checked => {
                rootPane.backgroundEnabled = checked;
                rootPane.saveConfig();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.45 : 0.32)
        }

        SwitchRow {
            flatStyle: true
            label: qsTr("Wallpaper enabled")
            checked: rootPane.wallpaperEnabled
            onToggled: checked => {
                rootPane.wallpaperEnabled = checked;
                rootPane.saveConfig();
            }
        }
    }
}
