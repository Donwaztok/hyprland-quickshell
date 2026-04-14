pragma Singleton

import ".."
import qs.config
import qs.services.shell
import qs.utils
import Quickshell
import QtQuick

Searcher {
    id: root

    readonly property string currentScheme: Colours.scheme + " " + Colours.flavour + " " + (Colours.currentLight ? "light" : "dark")
    readonly property string currentVariant: Colours.flavour

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        const mode = item.mode || (item.colours?.background && parseInt(String(item.colours.background).substring(0, 2), 16) < 0x80 ? "dark" : "light");
        return `${item.name} ${item.flavour} ${mode}`;
    }

    function reload(): void {
        // Builtin schemes only; Colours updates drive UI.
    }

    readonly property var builtinSchemeList: [Colours.builtinSchemes.defaultDark, Colours.builtinSchemes.defaultLight]

    list: schemes.instances
    useFuzzy: Config.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        model: builtinSchemeList
        Scheme {}
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            list.visibilities.launcher = false;
            Colours.writeScheme(modelData);
        }
    }
}
