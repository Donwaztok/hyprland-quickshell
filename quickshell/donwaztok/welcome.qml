//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    visible: true
    onClosing: {
        Quickshell.execDetached(["notify-send", qsTr("Welcome app"), qsTr("Enjoy! You can reopen the welcome app any time with <tt>Super+Shift+Alt+/</tt>. To open the settings app, hit <tt>Super+I</tt>"), "-a", "Shell"]);
        Qt.quit();
    }
    title: qsTr("Donwaztok Welcome")

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0 // Welcome app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 600
    minimumHeight: 400
    width: 900
    height: 650
    color: Appearance.m3colors.m3background

    Process {
        id: konachanWallProc
        property string status: ""
        command: ["bash", "-c", Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]
        stdout: SplitParser {
            onRead: data => {
                console.log(`Konachan wall proc output: ${data}`);
                konachanWallProc.status = data.trim();
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Item {
            // Titlebar
            visible: Config.options?.windows.showTitlebar
            Layout.fillWidth: true
            implicitHeight: Math.max(welcomeText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: welcomeText
                anchors {
                    left: Config.options.windows.centerTitle ? undefined : parent.left
                    horizontalCenter: Config.options.windows.centerTitle ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: qsTr("Hi there! First things first...")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: qsTr("Show next time")
                }
                StyledSwitch {
                    id: showNextTimeSwitch
                    checked: root.showNextTime
                    scale: 0.6
                    Layout.alignment: Qt.AlignVCenter
                    onCheckedChanged: {
                        if (checked) {
                            Quickshell.execDetached(["rm", root.firstRunFilePath]);
                        } else {
                            Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
                        }
                    }
                }
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }

                    StyledToolTip {
                        text: qsTr("Tip: Close a window with Super+Q")
                    }
                }
            }
        }

        Rectangle {
            // Content container
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - root.contentPadding
            implicitHeight: contentColumn.implicitHeight
            implicitWidth: contentColumn.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true

            ContentPage {
                id: contentColumn
                anchors.fill: parent

                ContentSection {
                    icon: "screenshot_monitor"
                    title: qsTr("Bar")

                    ConfigRow {
                        ContentSubsection {
                            title: qsTr("Bar position")
                            ConfigSelectionArray {
                                currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                                onSelected: newValue => {
                                    Config.options.bar.bottom = (newValue & 1) !== 0;
                                    Config.options.bar.vertical = (newValue & 2) !== 0;
                                }
                                options: [
                                    {
                                        displayName: qsTr("Top"),
                                        icon: "arrow_upward",
                                        value: 0 // bottom: false, vertical: false
                                    },
                                    {
                                        displayName: qsTr("Left"),
                                        icon: "arrow_back",
                                        value: 2 // bottom: false, vertical: true
                                    },
                                    {
                                        displayName: qsTr("Bottom"),
                                        icon: "arrow_downward",
                                        value: 1 // bottom: true, vertical: false
                                    },
                                    {
                                        displayName: qsTr("Right"),
                                        icon: "arrow_forward",
                                        value: 3 // bottom: true, vertical: true
                                    }
                                ]
                            }
                        }
                        ContentSubsection {
                            title: qsTr("Bar style")

                            ConfigSelectionArray {
                                currentValue: Config.options.bar.cornerStyle
                                onSelected: newValue => {
                                    Config.options.bar.cornerStyle = newValue; // Update local copy
                                }
                                options: [
                                    {
                                        displayName: qsTr("Hug"),
                                        icon: "line_curve",
                                        value: 0
                                    },
                                    {
                                        displayName: qsTr("Float"),
                                        icon: "page_header",
                                        value: 1
                                    },
                                    {
                                        displayName: qsTr("Rect"),
                                        icon: "toolbar",
                                        value: 2
                                    }
                                ]
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "format_paint"
                    title: qsTr("Style & wallpaper")

                    ButtonGroup {
                        Layout.alignment: Qt.AlignHCenter
                        LightDarkPreferenceButton {
                            dark: false
                        }
                        LightDarkPreferenceButton {
                            dark: true
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        RippleButtonWithIcon {
                            id: rndWallBtn
                            visible: Config.options.policies.weeb === 1
                            Layout.alignment: Qt.AlignHCenter
                            buttonRadius: Appearance.rounding.small
                            materialIcon: "ifl"
                            mainText: konachanWallProc.running ? qsTr("Be patient...") : qsTr("Random: Konachan")
                            onClicked: {
                                console.log(konachanWallProc.command.join(" "));
                                konachanWallProc.running = true;
                            }
                            StyledToolTip {
                                text: qsTr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "wallpaper"
                            StyledToolTip {
                                text: qsTr("Pick wallpaper image on your system")
                            }
                            onClicked: {
                                Quickshell.execDetached([`${Directories.wallpaperSwitchScriptPath}`]);
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 10
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: qsTr("Choose file")
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    RowLayout {
                                        spacing: 3
                                        KeyboardKey {
                                            key: "Ctrl"
                                        }
                                        KeyboardKey {
                                            key: "󰖳"
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            key: "T"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    NoticeBox {
                        Layout.fillWidth: true
                        text: qsTr("Change any time later with /dark, /light, /wallpaper in the launcher\nIf the shell's colors aren't changing:\n    1. Open the Donwaztok control center (default: Super+I)\n    2. Reload from there, or restart Quickshell (e.g. Ctrl+Super+R)")
                    }
                }

                ContentSection {
                    icon: "rule"
                    title: qsTr("Policies")

                    ConfigRow {
                        Layout.fillWidth: true

                        ContentSubsection {
                            title: "Weeb"

                            ConfigSelectionArray {
                                currentValue: Config.options.policies.weeb
                                onSelected: newValue => {
                                    Config.options.policies.weeb = newValue;
                                }
                                options: [
                                    {
                                        displayName: qsTr("No"),
                                        icon: "close",
                                        value: 0
                                    },
                                    {
                                        displayName: qsTr("Yes"),
                                        icon: "check",
                                        value: 1
                                    },
                                    {
                                        displayName: qsTr("Closet"),
                                        icon: "ev_shadow",
                                        value: 2
                                    }
                                ]
                            }
                        }

                        ContentSubsection {
                            title: "AI"

                            ConfigSelectionArray {
                                currentValue: Config.options.policies.ai
                                onSelected: newValue => {
                                    Config.options.policies.ai = newValue;
                                }
                                options: [
                                    {
                                        displayName: qsTr("No"),
                                        icon: "close",
                                        value: 0
                                    },
                                    {
                                        displayName: qsTr("Yes"),
                                        icon: "check",
                                        value: 1
                                    },
                                    {
                                        displayName: qsTr("Local only"),
                                        icon: "sync_saved_locally",
                                        value: 2
                                    }
                                ]
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "info"
                    title: qsTr("Info")

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        RippleButtonWithIcon {
                            materialIcon: "keyboard_alt"
                            onClicked: {
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "cheatsheet", "toggle"]);
                            }
                            mainContentComponent: Component {
                                RowLayout {
                                    spacing: 10
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        text: qsTr("Keybinds")
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    RowLayout {
                                        spacing: 3
                                        KeyboardKey {
                                            key: "󰖳"
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "+"
                                        }
                                        KeyboardKey {
                                            key: "/"
                                        }
                                    }
                                }
                            }
                        }

                        RippleButtonWithIcon {
                            materialIcon: "help"
                            mainText: qsTr("Usage")
                            onClicked: {
                                Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "construction"
                            mainText: qsTr("Configuration")
                            onClicked: {
                                Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/03config/");
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "monitoring"
                    title: qsTr("Useless buttons")

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        RippleButtonWithIcon {
                            nerdIcon: "󰊤"
                            mainText: qsTr("GitHub")
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/end-4/dots-hyprland");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "favorite"
                            mainText: "Funny number"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/sponsors/end-4");
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
