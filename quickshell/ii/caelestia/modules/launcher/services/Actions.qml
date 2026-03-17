pragma Singleton

import ".."
import caelestia.services
import caelestia.config
import caelestia.utils
import caelestia.modules.controlcenter
import Quickshell
import QtQuick

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(Config.launcher.actionPrefix.length);
    }

    list: variants.instances
    useFuzzy: Config.launcher.useFuzzy.actions

    Variants {
        id: variants

        model: Config.launcher.actions.filter(a => (a.enabled ?? true) && (Config.launcher.enableDangerousActions || !(a.dangerous ?? false)))

        Action {}
    }

    component Action: QtObject {
        required property var modelData
        readonly property string name: modelData.name ?? qsTr("Unnamed")
        readonly property string desc: modelData.description ?? qsTr("No description")
        readonly property string icon: modelData.icon ?? "help_outline"
        readonly property list<string> command: modelData.command ?? []
        readonly property bool enabled: modelData.enabled ?? true
        readonly property bool dangerous: modelData.dangerous ?? false

        function onClicked(list: AppList): void {
            if (command.length === 0)
                return;

            if (command[0] === "autocomplete" && command.length > 1) {
                list.search.text = `${Config.launcher.actionPrefix}${command[1]} `;
            } else if (command[0] === "setMode" && command.length > 1) {
                list.visibilities.launcher = false;
                Colours.setMode(command[1]);
            } else if (command[0] === "caelestia" && command.length >= 4 && command[1] === "shell" && command[2] === "controlCenter" && command[3] === "open") {
                list.visibilities.launcher = false;
                WindowFactory.create();
            } else if (command[0] === "caelestia" && command.length > 1) {
                list.visibilities.launcher = false;
                CaelestiaCli.exec(command.slice(1));
            } else {
                list.visibilities.launcher = false;
                Quickshell.execDetached(command);
            }
        }
    }
}
