pragma ComponentBehavior: Bound

import ".."
import caelestia.components
import caelestia.components.controls
import caelestia.components.containers
import caelestia.services
import caelestia.config
import QtQuick

CollapsibleSection {
    title: qsTr("Theme mode")
    description: qsTr("Light or dark theme")
    showBackground: true

    SwitchRow {
        label: qsTr("Dark mode")
        checked: !Colours.currentLight
        onToggled: checked => {
            Colours.setMode(checked ? "dark" : "light");
        }
    }
}
