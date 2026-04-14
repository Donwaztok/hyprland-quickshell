pragma ComponentBehavior: Bound

import qs.components
import qs.components.containers
import qs.services.shell
import qs.config
import Quickshell
import Quickshell.Wayland
import QtQuick

Loader {
    active: Config.background.enabled

    sourceComponent: Variants {
        model: Screens.screens

        StyledWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            name: "background"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
            color: Config.background.wallpaperEnabled ? "black" : "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Item {
                id: behindClock

                anchors.fill: parent

                Loader {
                    id: wallpaper

                    anchors.fill: parent
                    active: Config.background.wallpaperEnabled

                    sourceComponent: Wallpaper {}
                }

            }

            Loader {
                id: clockLoader
                active: Config.background.desktopClock.enabled

                anchors.margins: Math.round(Appearance.padding.large * 2 * Config.barThicknessScale)
                anchors.leftMargin: Math.round(Appearance.padding.large * 2 * Config.barThicknessScale) + Config.bar.sizes.thickness + Math.max(Math.round(Appearance.padding.smaller * Config.barThicknessScale), Config.border.thickness)

                state: Config.background.desktopClock.position
                states: [
                    State {
                        name: "top-left"
                        AnchorChanges {
                            target: clockLoader
                            anchors.top: parent.top
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "top-center"
                        AnchorChanges {
                            target: clockLoader
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "top-right"
                        AnchorChanges {
                            target: clockLoader
                            anchors.top: parent.top
                            anchors.right: parent.right
                        }
                    },
                    State {
                        name: "middle-left"
                        AnchorChanges {
                            target: clockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "middle-center"
                        AnchorChanges {
                            target: clockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "middle-right"
                        AnchorChanges {
                            target: clockLoader
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                        }
                    },
                    State {
                        name: "bottom-left"
                        AnchorChanges {
                            target: clockLoader
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                        }
                    },
                    State {
                        name: "bottom-center"
                        AnchorChanges {
                            target: clockLoader
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    },
                    State {
                        name: "bottom-right"
                        AnchorChanges {
                            target: clockLoader
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                        }
                    }
                ]

                transitions: Transition {
                    AnchorAnimation {
                        duration: Appearance.anim.durations.expressiveDefaultSpatial
                        easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                    }
                }

                sourceComponent: DesktopClock {
                    wallpaper: behindClock
                    absX: clockLoader.x
                    absY: clockLoader.y
                }
            }
        }
    }
}
