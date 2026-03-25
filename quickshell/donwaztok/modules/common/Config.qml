pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import donwaztok.config

Singleton {
    id: root

    property string filePath: DonwaztokConfigStore.filePath
    readonly property var options: DonwaztokConfigStore.shellOptions

    property int barGroupStyle: (function() {
        var b = root.options.bar;
        if (typeof b.groupStyle === "number")
            return b.groupStyle;
        return b.borderless ? 1 : 0;
    })()

    property bool ready: DonwaztokConfigStore.ready
    property int readWriteDelay: 50
    property bool blockWrites: false

    Binding {
        target: DonwaztokConfigStore
        property: "readWriteDelay"
        value: root.readWriteDelay
    }

    Binding {
        target: DonwaztokConfigStore
        property: "blockWrites"
        value: root.blockWrites
    }

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }
}
