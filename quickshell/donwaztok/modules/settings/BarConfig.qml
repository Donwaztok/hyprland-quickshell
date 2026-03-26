import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.config as DwCfg

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "notifications"
        title: qsTr("Notifications")
        ConfigSwitch {
            buttonIcon: "counter_2"
            text: qsTr("Unread indicator: show count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
            }
        }
    }

    ContentSection {
        icon: "spoke"
        title: qsTr("Positioning")

        ConfigRow {
            ContentSubsection {
                title: qsTr("Bar position")
                Layout.fillWidth: true

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
        }

        ConfigRow {

            ContentSubsection {
                title: qsTr("Corner style")
                Layout.fillWidth: true

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

            ContentSubsection {
                title: qsTr("Group style")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.barGroupStyle
                    onSelected: newValue => {
                        Config.options.bar.groupStyle = newValue;
                        Config.options.bar.borderless = (newValue !== 0);
                        DwCfg.Config.bar.borderless = (newValue !== 0);
                        DwCfg.Config.save();
                    }
                    options: [
                        {
                            displayName: qsTr("Pills"),
                            icon: "location_chip",
                            value: 0
                        },
                        {
                            displayName: qsTr("Line-separated"),
                            icon: "split_scene",
                            value: 1
                        },
                        {
                            displayName: qsTr("Empty"),
                            icon: "space_dashboard",
                            value: 2
                        }
                    ]
                }
            }
        }

        ConfigSpinBox {
            icon: "height"
            text: qsTr("Bar size (%)")
            value: Math.round((Config.options.bar.size ?? 0.8) * 100)
            from: 50
            to: 120
            stepSize: 5
            onValueChanged: Config.options.bar.size = value / 100
        }
    }

    ContentSection {
        icon: "cloud"
        title: qsTr("Weather")
        ConfigSwitch {
            buttonIcon: "check"
            text: qsTr("Enable")
            checked: Config.options.bar.weather.enable
            onCheckedChanged: {
                Config.options.bar.weather.enable = checked;
            }
        }
    }

    ContentSection {
        icon: "workspaces"
        title: qsTr("Workspaces")

        ContentSubsection {
            title: qsTr("Indicator style")
            ConfigSelectionArray {
                currentValue: DwCfg.Config.bar.workspaces.style ?? "classic"
                onSelected: newValue => {
                    DwCfg.Config.bar.workspaces.style = newValue
                    DwCfg.Config.save()
                }
                options: [
                    { displayName: qsTr("Classic"), icon: "grid_view", value: "classic" },
                    { displayName: qsTr("GNOME"), icon: "radio_button_checked", value: "gnome" }
                ]
            }
        }

        ContentSubsection {
            title: qsTr("Classic style")
            visible: (DwCfg.Config.bar.workspaces.style ?? "classic") === "classic"
            ConfigSwitch {
                buttonIcon: "counter_1"
                text: qsTr('Always show numbers')
                checked: DwCfg.Config.bar.workspaces.alwaysShowNumbers ?? false
                onCheckedChanged: {
                    DwCfg.Config.bar.workspaces.alwaysShowNumbers = checked
                    DwCfg.Config.save()
                }
            }
            ConfigSwitch {
                buttonIcon: "award_star"
                text: qsTr('Show app icons')
                checked: DwCfg.Config.bar.workspaces.showAppIcons ?? true
                onCheckedChanged: {
                    DwCfg.Config.bar.workspaces.showAppIcons = checked
                    DwCfg.Config.save()
                }
            }
            ConfigSpinBox {
                icon: "touch_long"
                text: qsTr("Number show delay when pressing Super (ms)")
                value: DwCfg.Config.bar.workspaces.showNumberDelay ?? 300
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.showNumberDelay = value
                    DwCfg.Config.save()
                }
            }
            ConfigSelectionArray {
                currentValue: JSON.stringify(DwCfg.Config.bar.workspaces.numberMap ?? [])
                onSelected: newValue => {
                    DwCfg.Config.bar.workspaces.numberMap = JSON.parse(newValue)
                    DwCfg.Config.save()
                }
                options: [
                    { displayName: qsTr("Normal"), icon: "timer_10", value: '[]' },
                    { displayName: qsTr("Han chars"), icon: "square_dot", value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                    { displayName: qsTr("Roman"), icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
                ]
            }
            ConfigSpinBox {
                icon: "view_column"
                text: qsTr("Slot width (px)")
                value: DwCfg.Config.bar.workspaces.classicSlotWidth ?? 26
                from: 20
                to: 40
                stepSize: 1
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.classicSlotWidth = value
                    DwCfg.Config.save()
                }
            }
        }

        ContentSubsection {
            title: qsTr("GNOME style")
            visible: (DwCfg.Config.bar.workspaces.style ?? "classic") === "gnome"
            ConfigSpinBox {
                icon: "circle"
                text: qsTr("Dot / slot width (px)")
                value: DwCfg.Config.bar.workspaces.workspaceButtonWidth ?? 11
                from: 6
                to: 24
                stepSize: 1
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.workspaceButtonWidth = value
                    DwCfg.Config.save()
                }
            }
            ConfigSpinBox {
                icon: "horizontal_rule"
                text: qsTr("Active slot width (px)")
                value: DwCfg.Config.bar.workspaces.activeSlotWidth ?? 32
                from: 16
                to: 48
                stepSize: 1
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.activeSlotWidth = value
                    DwCfg.Config.save()
                }
            }
            ConfigSpinBox {
                icon: "aspect_ratio"
                text: qsTr("Dash width factor")
                value: (DwCfg.Config.bar.workspaces.dashWidthFactor ?? 2.0) * 10
                from: 10
                to: 35
                stepSize: 1
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.dashWidthFactor = value / 10
                    DwCfg.Config.save()
                }
            }
            ConfigSpinBox {
                icon: "padding"
                text: qsTr("Dash margin")
                value: (DwCfg.Config.bar.workspaces.dashMargin ?? 1) * 10
                from: 0
                to: 30
                stepSize: 1
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.dashMargin = value / 10
                    DwCfg.Config.save()
                }
            }
            ConfigSpinBox {
                icon: "circle"
                text: qsTr("Indicator size (px)")
                value: DwCfg.Config.bar.workspaces.indicatorSize ?? 8
                from: 4
                to: 12
                stepSize: 1
                onValueChanged: {
                    DwCfg.Config.bar.workspaces.indicatorSize = value
                    DwCfg.Config.save()
                }
            }
        }

        ConfigSpinBox {
            icon: "view_column"
            text: qsTr("Workspaces shown")
            value: DwCfg.Config.bar.workspaces.shown ?? 0
            from: 0
            to: 30
            stepSize: 1
            onValueChanged: {
                DwCfg.Config.bar.workspaces.shown = value
                DwCfg.Config.save()
            }
        }

        ConfigSwitch {
            buttonIcon: "keyboard_command_key"
            text: qsTr("Show workspace numbers when holding Super")
            checked: DwCfg.Config.bar.workspaces.superKey.showNumbers ?? true
            onCheckedChanged: {
                DwCfg.Config.bar.workspaces.superKey.showNumbers = checked
                DwCfg.Config.save()
            }
        }
        ConfigSpinBox {
            icon: "schedule"
            text: qsTr("Super-key number hint delay (ms)")
            value: DwCfg.Config.bar.workspaces.superKey.delayMs ?? 140
            from: 0
            to: 500
            stepSize: 10
            onValueChanged: {
                DwCfg.Config.bar.workspaces.superKey.delayMs = value
                DwCfg.Config.save()
            }
        }
    }
}
