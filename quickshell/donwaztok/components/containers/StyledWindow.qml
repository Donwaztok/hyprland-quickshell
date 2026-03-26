import Quickshell
import Quickshell.Wayland

PanelWindow {
    required property string name

    WlrLayershell.namespace: `donwaztok-${name}`
    color: "transparent"
}
