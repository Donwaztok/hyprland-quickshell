import qs.components
import qs.services.shell
import qs.config
import qs.utils
import QtQuick
import QtQuick.Controls

// Unified network indicator (Material, same glyphs as the popout list).
Item {
    id: root

    property color colour
    property bool inTray
    readonly property string linkSpeed: {
        Nmcli.activeEthernet;
        Nmcli.active;
        const d = Nmcli.activeEthernet ? Nmcli.ethernetDeviceDetails : Nmcli.wirelessDeviceDetails;
        return d && d.linkSpeed ? d.linkSpeed : "";
    }

    implicitWidth: Math.max(16, Math.round(Appearance.font.size.small * 2 * Config.barThicknessScale))
    implicitHeight: implicitWidth

    MaterialIcon {
        anchors.centerIn: parent
        pointSizeScale: Config.barThicknessScale
        animate: true
        text: {
            if (VPN.connected)
                return "vpn_key";
            if (VPN.connecting)
                return "vpn_key_off";
            if (Nmcli.activeEthernet)
                return "computer";
            if (!Nmcli.wifiEnabled)
                return "signal_wifi_off";
            if (Nmcli.active)
                return Icons.getNetworkIcon(Nmcli.active.strength ?? 0, Nmcli.active.isSecure);
            return "wifi_off";
        }
        fill: VPN.connected ? 1 : 0
        color: root.colour
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered && (Nmcli.activeEthernet || Nmcli.active))
                Nmcli.refreshActiveDeviceDetails(null);
        }
    }

    ToolTip.visible: hover.hovered && root.linkSpeed.length > 0
    ToolTip.delay: 400
    ToolTip.text: qsTr("Velocidade") + "\n" + root.linkSpeed
}
