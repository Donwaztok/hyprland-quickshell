import QtQuick

Item {
    id: root

    property var keyboards: [mainKeyboard]
    property var lastIpcObject: ({})

    function updateFromIpc(data) {
        lastIpcObject = data ?? ({});

        const list = data?.keyboards;
        if (!Array.isArray(list) || list.length === 0)
            return;

        const kb = list.find(k => k.main) || list[0];
        mainKeyboard.address = kb.address ?? "";
        mainKeyboard.name = kb.name ?? "";
        mainKeyboard.layout = kb.layout ?? "us";
        mainKeyboard.activeKeymap = kb.active_keymap || "Unknown";
        mainKeyboard.capsLock = !!kb.capsLock;
        mainKeyboard.numLock = !!kb.numLock;
        mainKeyboard.main = true;
        mainKeyboard.lastIpcObject = kb;
    }

    HyprKeyboard {
        id: mainKeyboard
        main: true
    }
}
