import Quickshell.Io

JsonObject {
    // Position of the taskbar: "left", "right", "top", "bottom"
    property string position: "left"
    property bool persistent: true
    property bool showOnHover: true
    property bool borderless: false
    property int dragThreshold: 20
    property Popouts popouts: Popouts {}
    property Tray tray: Tray {}
    property IconPlacement icons: IconPlacement {}
    property Clock clock: Clock {}
    property Sizes sizes: Sizes {}
    property Workspaces workspaces: Workspaces {}
    property list<string> excludedScreens: []

    property list<var> entries: [
        {
            id: "workspaces",
            enabled: true
        },
        {
            id: "spacer",
            enabled: true
        },
        {
            id: "tray",
            enabled: true
        },
        {
            id: "clock",
            enabled: true
        },
        {
            id: "statusIcons",
            enabled: true
        }
    ]

    component Popouts: JsonObject {
        property bool tray: true
        property bool statusIcons: true
    }

    component Tray: JsonObject {
        property bool background: false
        property bool recolour: false
        property bool compact: true
        property list<var> iconSubs: []
    }

    // Where each bar icon shows, in order. Shell icons use the ids in utils/BarIcons.qml; tray apps use
    // "app:<status notifier id>". All three empty means "not migrated yet".
    component IconPlacement: JsonObject {
        property list<string> status: []
        property list<string> tray: []
        property list<string> hidden: []
    }

    component Clock: JsonObject {
        property bool showIcon: false
    }

    component Sizes: JsonObject {
        // Bar depth in pixels: width when bar is vertical, height when horizontal.
        property int thickness: 36
        property int innerWidth: 40
        property int windowPreviewSize: 400
        property int trayMenuWidth: 300
        property int batteryWidth: 250
        property int networkWidth: 320
        property int kbLayoutWidth: 320
    }

    component WorkspaceSuperKey: JsonObject {
        property bool showNumbers: true
        property int delayMs: 140
    }

    component Workspaces: JsonObject {
        property string style: "gnome" // "classic" | "gnome"
        property int shown: 0 // 0 = dynamic (GNOME)
        property bool showAppIcons: true
        property bool alwaysShowNumbers: true
        property int showNumberDelay: 300
        property list<string> numberMap: []
        property bool useNerdFont: false
        property int classicSlotWidth: 26
        property int workspaceButtonWidth: 11
        property int activeSlotWidth: 32
        property real dashWidthFactor: 2.0
        property real dashMargin: 1
        property real indicatorSize: 8
        property real dotSize: 8
        property real pillHeight: 8
        property WorkspaceSuperKey superKey: WorkspaceSuperKey {}
    }
}
