pragma Singleton

import ".."
import caelestia.config
import caelestia.services
import caelestia.utils
import Quickshell
import Quickshell.Io
import QtQuick

Searcher {
    id: root

    property string _currentSchemeFromCli: ""
    property string _currentVariantFromCli: ""
    readonly property string currentScheme: CaelestiaCli.available ? _currentSchemeFromCli : (Colours.scheme + " " + Colours.flavour)
    readonly property string currentVariant: CaelestiaCli.available ? _currentVariantFromCli : Colours.flavour

    function transformSearch(search: string): string {
        return search.slice(`${Config.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        if (CaelestiaCli.available)
            getCurrent.running = true;
    }

    property var schemesFromCli: []
    readonly property var builtinSchemeList: [Colours.builtinSchemes.defaultDark, Colours.builtinSchemes.defaultLight]

    list: schemes.instances
    useFuzzy: Config.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        model: CaelestiaCli.available ? schemesFromCli : builtinSchemeList
        Scheme {}
    }

    Process {
        id: getSchemes

        running: CaelestiaCli.available
        command: ["caelestia", "scheme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const schemeData = JSON.parse(text);
                const list = Object.entries(schemeData).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
                                name,
                                flavour,
                                colours
                            })));

                const flat = [];
                for (const s of list)
                    for (const f of s)
                        flat.push(f);

                root.schemesFromCli = flat.sort((a, b) => (a.name + a.flavour).localeCompare((b.name + b.flavour)));
            }
        }
    }

    Process {
        id: getCurrent

        running: CaelestiaCli.available
        command: ["caelestia", "scheme", "get", "-nfv"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\n");
                root._currentSchemeFromCli = parts.length >= 2 ? `${parts[0]} ${parts[1]}` : "";
                root._currentVariantFromCli = parts.length >= 3 ? parts[2] : "";
            }
        }
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
