import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "notifications"
        title: Translation.tr("Notifications")
        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Unread indicator: show count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
            }
        }
    }

    ContentSection {
        icon: "spoke"
        title: Translation.tr("Positioning")

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top"),
                            icon: "arrow_upward",
                            value: 0 // bottom: false, vertical: false
                        },
                        {
                            displayName: Translation.tr("Left"),
                            icon: "arrow_back",
                            value: 2 // bottom: false, vertical: true
                        },
                        {
                            displayName: Translation.tr("Bottom"),
                            icon: "arrow_downward",
                            value: 1 // bottom: true, vertical: false
                        },
                        {
                            displayName: Translation.tr("Right"),
                            icon: "arrow_forward",
                            value: 3 // bottom: true, vertical: true
                        }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Automatically hide")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.autoHide.enable
                    onSelected: newValue => {
                        Config.options.bar.autoHide.enable = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigRow {

            ContentSubsection {
                title: Translation.tr("Corner style")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => {
                        Config.options.bar.cornerStyle = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("Hug"),
                            icon: "line_curve",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Float"),
                            icon: "page_header",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "toolbar",
                            value: 2
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Group style")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.barGroupStyle
                    onSelected: newValue => {
                        Config.options.bar.groupStyle = newValue;
                        Config.options.bar.borderless = (newValue !== 0);
                    }
                    options: [
                        {
                            displayName: Translation.tr("Pills"),
                            icon: "location_chip",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Line-separated"),
                            icon: "split_scene",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Empty"),
                            icon: "space_dashboard",
                            value: 2
                        }
                    ]
                }
            }
        }

        ConfigSpinBox {
            icon: "height"
            text: Translation.tr("Bar size (%)")
            value: Math.round((Config.options.bar.size ?? 0.8) * 100)
            from: 50
            to: 120
            stepSize: 5
            onValueChanged: Config.options.bar.size = value / 100
        }
    }

    ContentSection {
        icon: "shelf_auto_hide"
        title: Translation.tr("Tray")

        ConfigSwitch {
            buttonIcon: "keep"
            text: Translation.tr('Make icons pinned by default')
            checked: Config.options.tray.invertPinnedItems
            onCheckedChanged: {
                Config.options.tray.invertPinnedItems = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint icons')
            checked: Config.options.tray.monochromeIcons
            onCheckedChanged: {
                Config.options.tray.monochromeIcons = checked;
            }
        }
    }

    ContentSection {
        icon: "widgets"
        title: Translation.tr("Utility buttons")

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "content_cut"
                text: Translation.tr("Screen snip")
                checked: Config.options.bar.utilButtons.showScreenSnip
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenSnip = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "colorize"
                text: Translation.tr("Color picker")
                checked: Config.options.bar.utilButtons.showColorPicker
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showColorPicker = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Keyboard toggle")
                checked: Config.options.bar.utilButtons.showKeyboardToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showKeyboardToggle = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Mic toggle")
                checked: Config.options.bar.utilButtons.showMicToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showMicToggle = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Dark/Light toggle")
                checked: Config.options.bar.utilButtons.showDarkModeToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showDarkModeToggle = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "speed"
                text: Translation.tr("Performance Profile toggle")
                checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showPerformanceProfileToggle = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "videocam"
                text: Translation.tr("Record")
                checked: Config.options.bar.utilButtons.showScreenRecord
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenRecord = checked;
                }
            }
        }
    }

    ContentSection {
        icon: "cloud"
        title: Translation.tr("Weather")
        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.bar.weather.enable
            onCheckedChanged: {
                Config.options.bar.weather.enable = checked;
            }
        }
    }

    ContentSection {
        icon: "workspaces"
        title: Translation.tr("Workspaces")

        ContentSubsection {
            title: Translation.tr("Indicator style")
            ConfigSelectionArray {
                currentValue: Config.options.bar.workspaces.style ?? "classic"
                onSelected: newValue => { Config.options.bar.workspaces.style = newValue }
                options: [
                    { displayName: Translation.tr("Classic"), icon: "grid_view", value: "classic" },
                    { displayName: Translation.tr("GNOME"), icon: "radio_button_checked", value: "gnome" }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Classic style")
            visible: (Config.options.bar.workspaces.style ?? "classic") === "classic"
            ConfigSwitch {
                buttonIcon: "counter_1"
                text: Translation.tr('Always show numbers')
                checked: Config.options.bar.workspaces.alwaysShowNumbers ?? false
                onCheckedChanged: Config.options.bar.workspaces.alwaysShowNumbers = checked
            }
            ConfigSwitch {
                buttonIcon: "award_star"
                text: Translation.tr('Show app icons')
                checked: Config.options.bar.workspaces.showAppIcons ?? true
                onCheckedChanged: Config.options.bar.workspaces.showAppIcons = checked
            }
            ConfigSwitch {
                buttonIcon: "colors"
                text: Translation.tr('Tint app icons')
                checked: Config.options.bar.workspaces.monochromeIcons ?? true
                onCheckedChanged: Config.options.bar.workspaces.monochromeIcons = checked
            }
            ConfigSpinBox {
                icon: "touch_long"
                text: Translation.tr("Number show delay when pressing Super (ms)")
                value: Config.options.bar.workspaces.showNumberDelay ?? 300
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: Config.options.bar.workspaces.showNumberDelay = value
            }
            ConfigSelectionArray {
                currentValue: JSON.stringify(Config.options.bar.workspaces.numberMap ?? ["1", "2"])
                onSelected: newValue => { Config.options.bar.workspaces.numberMap = JSON.parse(newValue) }
                options: [
                    { displayName: Translation.tr("Normal"), icon: "timer_10", value: '[]' },
                    { displayName: Translation.tr("Han chars"), icon: "square_dot", value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                    { displayName: Translation.tr("Roman"), icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
                ]
            }
            ConfigSpinBox {
                icon: "view_column"
                text: Translation.tr("Slot width (px)")
                value: Config.options.bar.workspaces.classicSlotWidth ?? 26  // commit inicial: only classic, slot added later
                from: 20
                to: 40
                stepSize: 1
                onValueChanged: Config.options.bar.workspaces.classicSlotWidth = value
            }
        }

        ContentSubsection {
            title: Translation.tr("GNOME style")
            visible: (Config.options.bar.workspaces.style ?? "classic") === "gnome"
            ConfigSpinBox {
                icon: "circle"
                text: Translation.tr("Dot / slot width (px)")
                value: Config.options.bar.workspaces.workspaceButtonWidth ?? 11
                from: 6
                to: 24
                stepSize: 1
                onValueChanged: Config.options.bar.workspaces.workspaceButtonWidth = value
            }
            ConfigSpinBox {
                icon: "horizontal_rule"
                text: Translation.tr("Active slot width (px)")
                value: Config.options.bar.workspaces.activeSlotWidth ?? 32
                from: 16
                to: 48
                stepSize: 1
                onValueChanged: Config.options.bar.workspaces.activeSlotWidth = value
            }
            ConfigSpinBox {
                icon: "aspect_ratio"
                text: Translation.tr("Dash width factor")
                value: (Config.options.bar.workspaces.dashWidthFactor ?? 2.0) * 10
                from: 10
                to: 35
                stepSize: 1
                onValueChanged: Config.options.bar.workspaces.dashWidthFactor = value / 10
            }
            ConfigSpinBox {
                icon: "padding"
                text: Translation.tr("Dash margin")
                value: (Config.options.bar.workspaces.dashMargin ?? 1) * 10
                from: 0
                to: 30
                stepSize: 1
                onValueChanged: Config.options.bar.workspaces.dashMargin = value / 10
            }
            ConfigSpinBox {
                icon: "circle"
                text: Translation.tr("Indicator size (px)")
                value: Config.options.bar.workspaces.indicatorSize ?? 8
                from: 4
                to: 12
                stepSize: 1
                onValueChanged: Config.options.bar.workspaces.indicatorSize = value
            }
        }

        ConfigSpinBox {
            icon: "view_column"
            text: Translation.tr("Workspaces shown")
            value: Config.options.bar.workspaces.shown ?? 10  // commit inicial: 10
            from: 0
            to: 30
            stepSize: 1
            onValueChanged: Config.options.bar.workspaces.shown = value
        }
    }

    ContentSection {
        icon: "tooltip"
        title: Translation.tr("Tooltips")
        ConfigSwitch {
            buttonIcon: "ads_click"
            text: Translation.tr("Click to show")
            checked: Config.options.bar.tooltips.clickToShow
            onCheckedChanged: {
                Config.options.bar.tooltips.clickToShow = checked;
            }
        }
    }

    ContentSection {
        icon: "bug_report"
        title: Translation.tr("Debug")
        ConfigSwitch {
            buttonIcon: "view_week"
            text: Translation.tr("Show layout borders")
            checked: Config.options.bar.debugLayout ?? false
            onCheckedChanged: Config.options.bar.debugLayout = checked
        }
    }
}
