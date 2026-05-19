import Quickshell.Io

JsonObject {
    property bool enabled: true
    property int maxShown: 7
    property int maxWallpapers: 9 // Warning: even numbers look bad
    property int clipboardMaxShown: 12
    property real clipboardMaxHeightRatio: 0.75
    property string actionPrefix: ">"
    property string clipboardPrefix: ";"
    property string pendingOpenPrefix: ""
    property bool enableDangerousActions: false // Show launcher actions marked dangerous (add your own via donwaztok config)
    property int dragThreshold: 50
    property bool vimKeybinds: false
    property real cardOpacity: 0.88
    property real verticalAnchor: 0.38
    property list<string> favouriteApps: []
    property list<string> hiddenApps: []
    property Sizes sizes: Sizes {}

    component Sizes: JsonObject {
        property int itemWidth: 640
        property int itemHeight: 40
        property int searchBarHeight: 48
        property int cardRadius: 10
        property int wallpaperWidth: 280
        property int wallpaperHeight: 200
        property int clipboardImagePreviewHeight: 320
    }

    property list<var> actions: [
        {
            name: "Calculator",
            icon: "calculate",
            description: "Do simple math equations (powered by Qalc)",
            command: ["autocomplete", "calc"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Wallpaper",
            icon: "image",
            description: "Change the current wallpaper",
            command: ["autocomplete", "wallpaper"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Random",
            icon: "casino",
            description: "Switch to a random wallpaper",
            command: ["randomWallpaper"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Light",
            icon: "light_mode",
            description: "Change the scheme to light mode",
            command: ["setMode", "light"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Dark",
            icon: "dark_mode",
            description: "Change the scheme to dark mode",
            command: ["setMode", "dark"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Lock",
            icon: "lock",
            description: "Lock the current session",
            command: ["bash", "-c", "hyprctl dispatch global donwaztok:lock 2>/dev/null || loginctl lock-session"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Sleep",
            icon: "bedtime",
            description: "Suspend then hibernate",
            command: ["systemctl", "suspend-then-hibernate"],
            enabled: true,
            dangerous: false
        },
        {
            name: "Settings",
            icon: "settings",
            description: "Configure the shell",
            command: ["openControlCenter"],
            enabled: true,
            dangerous: false
        }
    ]
}
