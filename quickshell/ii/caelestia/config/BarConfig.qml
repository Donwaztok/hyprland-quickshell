import Quickshell.Io

JsonObject {
    // Position of the taskbar: "left", "right", "top", "bottom"
    property string position: "left"
    // Bar size scale (1.0 = 100%), same for horizontal and vertical bar
    property real size: 1.0
    property bool persistent: true
    property bool showOnHover: true
    property int dragThreshold: 20
    property ScrollActions scrollActions: ScrollActions {}
    property Popouts popouts: Popouts {}
    property Tray tray: Tray {}
    property Status status: Status {}
    property Clock clock: Clock {}
    property Sizes sizes: Sizes {}
    property list<string> excludedScreens: []

    property list<var> entries: [
        {
            id: "logo",
            enabled: true
        },
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

    component ScrollActions: JsonObject {
        property bool volume: true
        property bool brightness: true
    }

    component Popouts: JsonObject {
        property bool tray: true
        property bool statusIcons: true
    }

    component Tray: JsonObject {
        property bool background: false
        property bool recolour: false
        property bool compact: false
        property list<var> iconSubs: []
        property list<string> hiddenIcons: []
    }

    component Status: JsonObject {
        property bool showAudio: false
        property bool showMicrophone: false
        property bool showKbLayout: false
        property bool showNetwork: true
        property bool showWifi: true
        property bool showBluetooth: true
        property bool showBattery: true
        property bool showLockStatus: true
    }

    component Clock: JsonObject {
        property bool showIcon: true
    }

    component Sizes: JsonObject {
        property int innerWidth: 40
        property int windowPreviewSize: 400
        property int trayMenuWidth: 300
        property int batteryWidth: 250
        property int networkWidth: 320
        property int kbLayoutWidth: 320
    }
}
