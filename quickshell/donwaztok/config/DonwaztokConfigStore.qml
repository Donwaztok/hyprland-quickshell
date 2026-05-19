pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: storeRoot

    readonly property string filePath: {
        const h = Quickshell.env("HOME") || "";
        const xdg = Quickshell.env("XDG_CONFIG_HOME") || (h ? `${h}/.config` : "");
        return `${xdg}/donwaztok/config.json`;
    }

    property bool ready: false
    property bool blockWrites: false
    property int readWriteDelay: 50
    property bool topLevelWriteCooldown: false

    readonly property alias configFileView: unifiedCfgFileView

    function writeFullConfig(): void {
        unifiedCfgFileView.writeAdapter();
    }

    function markTopLevelWritten(): void {
        topLevelWriteCooldown = true;
        recentSaveCooldown.restart();
    }

    ElapsedTimer {
        id: loadElapsedTimer
    }

    readonly property alias configLoadElapsed: loadElapsedTimer

    Timer {
        id: fileReloadDebounce
        interval: storeRoot.readWriteDelay
        repeat: false
        onTriggered: {
            loadElapsedTimer.restart();
            unifiedCfgFileView.reload();
        }
    }

    Timer {
        id: fileWriteIiTimer
        interval: storeRoot.readWriteDelay
        repeat: false
        onTriggered: unifiedCfgFileView.writeAdapter()
    }

    Timer {
        id: recentSaveCooldown
        interval: 2000
        onTriggered: storeRoot.topLevelWriteCooldown = false
    }

    FileView {
        id: unifiedCfgFileView
        path: storeRoot.filePath
        watchChanges: true
        blockWrites: storeRoot.blockWrites

        onFileChanged: {
            if (!storeRoot.topLevelWriteCooldown)
                loadElapsedTimer.restart();
            fileReloadDebounce.restart();
        }

        onAdapterUpdated: fileWriteIiTimer.restart()

        onLoaded: {
            storeRoot.ready = true;
        }

        onLoadFailed: err => {
            storeRoot.ready = true;
            if (err == FileViewError.FileNotFound)
                unifiedCfgFileView.writeAdapter();
        }

        JsonAdapter {
            id: unifiedRootAdapter

            property JsonObject shell: JsonObject {

            property JsonObject policies: JsonObject {
                property int weeb: 1 // 0: No | 1: Open | 2: Closet
            }

            property JsonObject appearance: JsonObject {
                property bool extraBackgroundTint: true
                property JsonObject fonts: JsonObject {
                    property string main: "Google Sans Flex"
                    property string numbers: "Google Sans Flex"
                    property string title: "Google Sans Flex"
                    property string iconNerd: "JetBrains Mono NF"
                    property string monospace: "JetBrains Mono NF"
                    property string reading: "Readex Pro"
                    property string expressive: "Space Grotesk"
                }
            }

            property JsonObject audio: JsonObject {
                // Values in %
                property JsonObject protection: JsonObject {
                    // Prevent sudden bangs
                    property bool enable: false
                    property real maxAllowedIncrease: 10
                    property real maxAllowed: 99
                }
            }

            property JsonObject apps: JsonObject {
                property string bluetooth: "gnome-control-center bluetooth"
                property string changePassword: "kitty -1 --hold=yes zsh -ic 'passwd'"
                property string network: "gnome-control-center wifi"
                property string manageUser: "gnome-control-center user-accounts"
                property string networkEthernet: "gnome-control-center network"
                property string taskManager: "gnome-system-monitor"
                property string terminal: "kitty -1" // This is only for shell actions
                property string update: "kitty -1 --hold=yes zsh -ic 'pkexec pacman -Syu'"
                property string volumeMixer: `~/.config/hypr/hyprland/scripts/launch_first_available.sh "pavucontrol-qt" "pavucontrol"`
            }

            property JsonObject bar: JsonObject {
                property real size: 0.8 // Bar scale (height when horizontal, width when vertical)
                property bool bottom: false // Instead of top
                property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle
                property bool borderless: false // legacy: no grouping (kept for compat)
                property int groupStyle: 0 // 0: Pills | 1: Line-separated | 2: Empty (no divider)
                property bool verbose: true
                property bool vertical: false
                property JsonObject weather: JsonObject {
                    property bool enable: false
                    property bool enableGPS: true // gps based location
                    property string city: "" // When 'enableGPS' is false
                    property bool useUSCS: false // Instead of metric (SI) units
                    property int fetchInterval: 10 // minutes
                }
                property JsonObject indicators: JsonObject {
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: false
                    }
                }
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 5
                property int full: 101
                property bool automaticSuspend: true
                property int suspend: 3
            }

            property JsonObject cheatsheet: JsonObject {
                // Use a nerdfont to see the icons
                // 0: 󰖳  | 1: 󰌽 | 2: 󰘳 | 3:  | 4: 󰨡
                // 5:  | 6:  | 7: 󰣇 | 8:  | 9: 
                // 10:  | 11:  | 12:  | 13:  | 14: 󱄛
                property string superKey: ""
                property bool useMacSymbol: false
                property bool useMouseSymbol: false
                property bool useFnSymbol: false
                property JsonObject fontSize: JsonObject {
                    property int key: 12
                    property int comment: 12
                }
            }

            property JsonObject conflictKiller: JsonObject {
                property bool autoKillNotificationDaemons: false
                property bool autoKillTrays: false
            }

            property JsonObject interactions: JsonObject {
                property JsonObject scrolling: JsonObject {
                    property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
                    property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
                    property int mouseScrollFactor: 120
                    property int touchpadScrollFactor: 450
                }
                property JsonObject deadPixelWorkaround: JsonObject { // Hyprland leaves out 1 pixel on the right for interactions
                    property bool enable: false
                }
            }

            property JsonObject light: JsonObject {
                property JsonObject antiFlashbang: JsonObject {
                    property bool enable: false
                }
            }

            // Lock screen styling (shell.* in JSON); lock UI is `DonwaztokLockPanel`.
            property JsonObject lock: JsonObject {
                property JsonObject blur: JsonObject {
                    property bool enable: true
                    property real extraZoom: 1.1
                }
                property bool centerClock: true
                property bool showLockedText: true
            }

            property JsonObject media: JsonObject {
                // Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)
                property bool filterDuplicatePlayers: true
            }

            property JsonObject networking: JsonObject {
                property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7000
            }

            property JsonObject osd: JsonObject {
                property int timeout: 1000
            }

            property JsonObject regionSelector: JsonObject {
                property JsonObject targetRegions: JsonObject {
                    property bool windows: true
                    property bool layers: false
                    property bool content: true
                    property bool showLabel: false
                    property real opacity: 0.3
                    property real contentRegionOpacity: 0.8
                    property int selectionPadding: 5
                }
                property JsonObject rect: JsonObject {
                    property bool showAimLines: true
                }
                property JsonObject circle: JsonObject {
                    property int strokeWidth: 6
                    property int padding: 10
                }
                property JsonObject annotation: JsonObject {
                    property bool useSatty: false
                }
            }

            property JsonObject resources: JsonObject {
                property int updateInterval: 3000
                property int historyLength: 60
            }

            property JsonObject search: JsonObject {
                property int nonAppResultDelay: 30 // This prevents lagging when typing
                property string engineBaseUrl: "https://www.google.com/search?q="
                property list<string> excludedSites: ["quora.com", "facebook.com"]
                property bool sloppy: false // Uses levenshtein distance based scoring instead of fuzzy sort. Very weird.
                property JsonObject prefix: JsonObject {
                    property bool showDefaultActionsWithoutPrefix: true
                    property string action: "/"
                    property string app: ">"
                    property string clipboard: ";"
                    property string math: "="
                    property string shellCommand: "$"
                    property string webSearch: "?"
                }
                property JsonObject imageSearch: JsonObject {
                    property string imageSearchEngineBaseUrl: "https://lens.google.com/uploadbyurl?url="
                    property bool useCircleSelection: false
                }
            }

            property JsonObject screenSnip: JsonObject {
                property string savePath: "" // only copy to clipboard when empty
            }

            property JsonObject sounds: JsonObject {
                property bool battery: false
                property bool pomodoro: false
                property string theme: "freedesktop"
            }

            property JsonObject time: JsonObject {
                // https://doc.qt.io/qt-6/qtime.html#toString
                property string format: "hh:mm"
                property string shortDateFormat: "dd/MM"
                property string dateWithYearFormat: "dd/MM/yyyy"
                property string dateFormat: "ddd, dd/MM"
                property JsonObject pomodoro: JsonObject {
                    property int breakTime: 300
                    property int cyclesBeforeLongBreak: 4
                    property int focus: 1500
                    property int longBreak: 900
                }
                property bool secondPrecision: false
            }

            property JsonObject updates: JsonObject {
                property bool enableCheck: true
                property int checkInterval: 120 // minutes
                property int adviseUpdateThreshold: 75 // packages
                property int stronglyAdviseUpdateThreshold: 200 // packages
            }

            property JsonObject windows: JsonObject {
                property bool showTitlebar: true // Client-side decoration for shell apps
                property bool centerTitle: true
            }

            property JsonObject hacks: JsonObject {
                property int arbitraryRaceConditionDelay: 20 // milliseconds
            }

            property JsonObject workSafety: JsonObject {
                property JsonObject enable: JsonObject {
                    property bool wallpaper: false
                    property bool clipboard: false
                }
                property JsonObject triggerCondition: JsonObject {
                    property list<string> networkNameKeywords: ["airport", "cafe", "college", "company", "eduroam", "free", "guest", "public", "school", "university"]
                    property list<string> linkKeywords: ["hentai", "porn", "sukebei", "hitomi.la", "rule34", "gelbooru", "fanbox", "dlsite"]
                }
            }
            }

            property AppearanceConfig appearance: AppearanceConfig {}
            property GeneralConfig general: GeneralConfig {}
            property BackgroundConfig background: BackgroundConfig {}
            property BarConfig bar: BarConfig {}
            property BorderConfig border: BorderConfig {}
            property DashboardConfig dashboard: DashboardConfig {}
            property ControlCenterConfig controlCenter: ControlCenterConfig {}
            property LauncherConfig launcher: LauncherConfig {}
            property NotifsConfig notifs: NotifsConfig {}
            property SessionConfig session: SessionConfig {}
            property WInfoConfig winfo: WInfoConfig {}
            property LockConfig lock: LockConfig {}
            property UtilitiesConfig utilities: UtilitiesConfig {}
            property SidebarConfig sidebar: SidebarConfig {}
            property ServiceConfig services: ServiceConfig {}
            property UserPaths paths: UserPaths {}
        }
    }

    readonly property var shellOptions: unifiedRootAdapter.shell
    readonly property var topLevel: unifiedRootAdapter
}
