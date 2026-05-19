pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Session session

    spacing: Appearance.spacing.normal

    SettingsHeader {
        icon: "apps"
        title: qsTr("Launcher Settings")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("Enabled")
            checked: Config.launcher.enabled
            toggle.onToggled: {
                Config.launcher.enabled = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Vim keybinds")
            checked: Config.launcher.vimKeybinds
            toggle.onToggled: {
                Config.launcher.vimKeybinds = checked;
                Config.save();
            }
        }

        ToggleRow {
            label: qsTr("Enable dangerous actions")
            checked: Config.launcher.enableDangerousActions
            toggle.onToggled: {
                Config.launcher.enableDangerousActions = checked;
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Appearance")
        description: qsTr("Card opacity, vertical position, and shape")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Card opacity")
            value: Config.launcher.cardOpacity * 100
            from: 35
            to: 100
            stepSize: 1
            suffix: "%"
            validator: IntValidator {
                bottom: 35
                top: 100
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.cardOpacity = newValue / 100;
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Vertical position")
            value: Config.launcher.verticalAnchor * 100
            from: 22
            to: 50
            stepSize: 1
            suffix: "%"
            validator: IntValidator {
                bottom: 22
                top: 50
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.verticalAnchor = newValue / 100;
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Corner radius")
            value: Config.launcher.sizes.cardRadius
            from: 0
            to: 24
            stepSize: 1
            suffix: "px"
            validator: IntValidator {
                bottom: 0
                top: 24
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.cardRadius = Math.round(newValue);
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Results")
        description: qsTr("How many items appear in the list")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Max app results")
            value: Config.launcher.maxShown
            from: 3
            to: 15
            stepSize: 1
            suffix: ""
            validator: IntValidator {
                bottom: 3
                top: 15
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.maxShown = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Max wallpapers")
            value: Config.launcher.maxWallpapers
            from: 3
            to: 15
            stepSize: 1
            suffix: ""
            validator: IntValidator {
                bottom: 3
                top: 15
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.maxWallpapers = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Max clipboard history")
            value: Config.launcher.clipboardMaxShown
            from: 5
            to: 20
            stepSize: 1
            suffix: ""
            validator: IntValidator {
                bottom: 5
                top: 20
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.clipboardMaxShown = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Max clipboard image height")
            value: Config.launcher.sizes.clipboardImagePreviewHeight
            from: 80
            to: 480
            stepSize: 8
            suffix: "px"
            validator: IntValidator {
                bottom: 80
                top: 480
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.clipboardImagePreviewHeight = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Clipboard panel height")
            value: Config.launcher.clipboardMaxHeightRatio * 100
            from: 45
            to: 85
            stepSize: 5
            suffix: "%"
            validator: IntValidator {
                bottom: 45
                top: 85
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.clipboardMaxHeightRatio = Math.round(newValue) / 100;
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Layout")
        description: qsTr("Search bar and result row dimensions")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Window width")
            value: Config.launcher.sizes.itemWidth
            from: 480
            to: 900
            stepSize: 10
            suffix: "px"
            validator: IntValidator {
                bottom: 480
                top: 900
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.itemWidth = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Search bar height")
            value: Config.launcher.sizes.searchBarHeight
            from: 40
            to: 64
            stepSize: 2
            suffix: "px"
            validator: IntValidator {
                bottom: 40
                top: 64
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.searchBarHeight = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Result row height")
            value: Config.launcher.sizes.itemHeight
            from: 32
            to: 56
            stepSize: 2
            suffix: "px"
            validator: IntValidator {
                bottom: 32
                top: 56
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.itemHeight = Math.round(newValue);
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Prefixes")
        description: qsTr("Type these in the search bar to switch modes")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small / 2

        PropertyRow {
            label: qsTr("Actions")
            value: Config.launcher.actionPrefix || qsTr("None")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Clipboard history")
            value: Config.launcher.clipboardPrefix || qsTr("None")
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Wallpaper picker")
        description: qsTr("Sizes when using %1wallpaper").arg(Config.launcher.actionPrefix)
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Thumbnail width")
            value: Config.launcher.sizes.wallpaperWidth
            from: 160
            to: 400
            stepSize: 10
            suffix: "px"
            validator: IntValidator {
                bottom: 160
                top: 400
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.wallpaperWidth = Math.round(newValue);
                Config.save();
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Picker height")
            value: Config.launcher.sizes.wallpaperHeight
            from: 120
            to: 320
            stepSize: 10
            suffix: "px"
            validator: IntValidator {
                bottom: 120
                top: 320
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                Config.launcher.sizes.wallpaperHeight = Math.round(newValue);
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Applications")
        description: qsTr("Favourites and hidden apps are managed in the Applications tab")
    }

    SectionContainer {
        PropertyRow {
            label: qsTr("Hidden from launcher")
            value: qsTr("%1").arg(Config.launcher.hiddenApps ? Config.launcher.hiddenApps.length : 0)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Favourites")
            value: qsTr("%1").arg(Config.launcher.favouriteApps ? Config.launcher.favouriteApps.length : 0)
        }
    }
}
