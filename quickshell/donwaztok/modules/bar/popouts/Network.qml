pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property Item wrapper

    property string connectingToSsid: ""
    property var passwordNetwork: null
    property bool showPasswordDialog: false

    readonly property bool summaryIsWifi: !Nmcli.activeEthernet && Nmcli.active
    readonly property var activeDetails: Nmcli.activeEthernet ? Nmcli.ethernetDeviceDetails : Nmcli.wirelessDeviceDetails
    readonly property bool showActiveSummary: Nmcli.activeEthernet || Nmcli.active

    spacing: Appearance.spacing.small
    width: Config.bar.sizes.networkWidth

    Connections {
        target: root.wrapper

        function onCurrentNameChanged(): void {
            if (root.wrapper.currentName === "network")
                Nmcli.refreshActiveDeviceDetails(null);
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.wrapper && root.wrapper.currentName === "network"
        onTriggered: Nmcli.refreshActiveDeviceDetails(null)
    }

    Component.onCompleted: {
        if (root.wrapper && root.wrapper.currentName === "network")
            Nmcli.refreshActiveDeviceDetails(null);
    }

    ColumnLayout {
        id: activeSummaryBlock

        visible: root.showActiveSummary
        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.small
        Layout.bottomMargin: visible ? Appearance.spacing.normal : 0
        spacing: 4

        StyledText {
            text: qsTr("Connected")
            font.weight: 600
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurface
        }

        StyledText {
            visible: {
                const d = root.activeDetails;
                return d && d.connectionName && d.connectionName.length > 0;
            }
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
                const d = root.activeDetails;
                return d && d.connectionName ? qsTr("Profile: %1").arg(d.connectionName) : "";
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        RowLayout {
            visible: {
                const d = root.activeDetails;
                return d && d.linkSpeed && d.linkSpeed.length > 0;
            }
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                text: qsTr("Velocidade")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            StyledText {
                text: {
                    const d = root.activeDetails;
                    return d && d.linkSpeed ? d.linkSpeed : "";
                }
                color: Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.small
                horizontalAlignment: Text.AlignRight
            }
        }

        StyledText {
            visible: root.summaryIsWifi && root.activeDetails && root.activeDetails.wifiChannel
            Layout.fillWidth: true
            text: {
                const d = root.activeDetails;
                return d && d.wifiChannel ? qsTr("Channel: %1").arg(d.wifiChannel) : "";
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            visible: root.summaryIsWifi && root.activeDetails && root.activeDetails.wifiApRate
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
                const d = root.activeDetails;
                return d && d.wifiApRate ? qsTr("Rate to access point: %1").arg(d.wifiApRate) : "";
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            visible: {
                const d = root.activeDetails;
                return d && d.ipAddress && d.ipAddress.length > 0;
            }
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
                const d = root.activeDetails;
                if (!d || !d.ipAddress)
                    return "";
                return d.subnet ? qsTr("IP: %1 (%2)").arg(d.ipAddress).arg(d.subnet) : qsTr("IP: %1").arg(d.ipAddress);
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            visible: {
                const d = root.activeDetails;
                return d && d.gateway && d.gateway.length > 0;
            }
            Layout.fillWidth: true
            text: {
                const d = root.activeDetails;
                return d && d.gateway ? qsTr("Gateway: %1").arg(d.gateway) : "";
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }

        StyledText {
            visible: {
                const d = root.activeDetails;
                return d && d.dns && d.dns.length > 0;
            }
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: {
                const d = root.activeDetails;
                return d && d.dns && d.dns.length > 0 ? qsTr("DNS: %1").arg(d.dns.slice(0, 4).join(", ")) : "";
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.small
        }
    }

    Rectangle {
        visible: root.showActiveSummary
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? 1 : 0
        Layout.bottomMargin: visible ? Appearance.spacing.small : 0
        color: Colours.palette.m3outlineVariant
    }

    // Wireless section
    StyledText {
        Layout.topMargin: Appearance.padding.normal
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("Wireless")
        font.weight: 500
    }

    Toggle {
        label: qsTr("Enabled")
        checked: Nmcli.wifiEnabled
        toggle.onToggled: Nmcli.enableWifi(checked)
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("%1 networks available").arg(Nmcli.networks.length)
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.small
    }

    Repeater {
        model: ScriptModel {
            values: [...Nmcli.networks].sort((a, b) => {
                if (a.active !== b.active)
                    return b.active - a.active;
                return b.strength - a.strength;
            }).slice(0, 8)
        }

        RowLayout {
            id: networkItem

            required property Nmcli.AccessPoint modelData
            readonly property bool isConnecting: root.connectingToSsid === modelData.ssid
            readonly property bool loading: networkItem.isConnecting

            Layout.fillWidth: true
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: Icons.getNetworkIcon(networkItem.modelData.strength)
                color: networkItem.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }

            MaterialIcon {
                visible: networkItem.modelData.isSecure
                text: "lock"
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.leftMargin: Appearance.spacing.small / 2
                Layout.rightMargin: Appearance.spacing.small / 2
                Layout.fillWidth: true
                text: networkItem.modelData.ssid
                elide: Text.ElideRight
                font.weight: networkItem.modelData.active ? 500 : 400
                color: networkItem.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
            }

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: wirelessConnectIcon.implicitHeight + Appearance.padding.small

                radius: Appearance.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, networkItem.modelData.active ? 1 : 0)

                CircularIndicator {
                    anchors.fill: parent
                    running: networkItem.loading
                }

                StateLayer {
                    color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    disabled: networkItem.loading || !Nmcli.wifiEnabled

                    function onClicked(): void {
                        if (networkItem.modelData.active) {
                            Nmcli.disconnectFromNetwork();
                        } else {
                            root.connectingToSsid = networkItem.modelData.ssid;
                            NetworkConnection.handleConnect(networkItem.modelData, null, network => {
                                // Password is required - show password dialog
                                root.passwordNetwork = network;
                                root.showPasswordDialog = true;
                                root.wrapper.currentName = "wirelesspassword";
                            });

                            // Clear connecting state if connection succeeds immediately (saved profile)
                            // This is handled by the onActiveChanged connection below
                        }
                    }
                }

                MaterialIcon {
                    id: wirelessConnectIcon

                    anchors.centerIn: parent
                    animate: true
                    text: networkItem.modelData.active ? "link_off" : "link"
                    color: networkItem.modelData.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                    opacity: networkItem.loading ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }
        }
    }

    StyledRect {
        Layout.topMargin: Appearance.spacing.small
        Layout.fillWidth: true
        implicitHeight: rescanBtn.implicitHeight + Appearance.padding.small * 2

        radius: Appearance.rounding.full
        color: Colours.palette.m3primary

        StateLayer {
            color: Colours.palette.m3onPrimary
            disabled: Nmcli.scanning || !Nmcli.wifiEnabled

            function onClicked(): void {
                Nmcli.rescanWifi();
            }
        }

        RowLayout {
            id: rescanBtn

            anchors.centerIn: parent
            spacing: Appearance.spacing.small
            opacity: Nmcli.scanning ? 0 : 1

            MaterialIcon {
                id: scanIcon

                Layout.topMargin: Math.round(fontInfo.pointSize * 0.0575)
                animate: true
                text: "wifi_find"
                color: Colours.palette.m3onPrimary
            }

            StyledText {
                Layout.topMargin: -Math.round(scanIcon.fontInfo.pointSize * 0.0575)
                text: qsTr("Rescan networks")
                color: Colours.palette.m3onPrimary
            }

            Behavior on opacity {
                Anim {}
            }
        }

        CircularIndicator {
            anchors.centerIn: parent
            strokeWidth: Appearance.padding.small / 2
            bgColour: "transparent"
            implicitSize: parent.implicitHeight - Appearance.padding.smaller * 2
            running: Nmcli.scanning
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: Appearance.spacing.normal
        color: Colours.palette.m3outlineVariant
    }

    // Ethernet section
    StyledText {
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("Ethernet")
        font.weight: 500
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.small
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("%1 devices available").arg(Nmcli.ethernetDevices.length)
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Appearance.font.size.small
    }

    Repeater {
        model: ScriptModel {
            values: [...Nmcli.ethernetDevices].sort((a, b) => {
                if (a.connected !== b.connected)
                    return b.connected - a.connected;
                return (a.interface || "").localeCompare(b.interface || "");
            }).slice(0, 8)
        }

        RowLayout {
            id: ethernetItem

            required property var modelData
            readonly property bool loading: false

            Layout.fillWidth: true
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: "computer"
                color: ethernetItem.modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.leftMargin: Appearance.spacing.small / 2
                Layout.rightMargin: Appearance.spacing.small / 2
                Layout.fillWidth: true
                text: ethernetItem.modelData.interface || qsTr("Unknown")
                elide: Text.ElideRight
                font.weight: ethernetItem.modelData.connected ? 500 : 400
                color: ethernetItem.modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurface
            }

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Appearance.padding.small

                radius: Appearance.rounding.full
                color: Qt.alpha(Colours.palette.m3primary, ethernetItem.modelData.connected ? 1 : 0)

                CircularIndicator {
                    anchors.fill: parent
                    running: ethernetItem.loading
                }

                StateLayer {
                    color: ethernetItem.modelData.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    disabled: ethernetItem.loading

                    function onClicked(): void {
                        if (ethernetItem.modelData.connected && ethernetItem.modelData.connection) {
                            Nmcli.disconnectEthernet(ethernetItem.modelData.connection, () => {});
                        } else {
                            Nmcli.connectEthernet(ethernetItem.modelData.connection || "", ethernetItem.modelData.interface || "", () => {});
                        }
                    }
                }

                MaterialIcon {
                    id: connectIcon

                    anchors.centerIn: parent
                    animate: true
                    text: ethernetItem.modelData.connected ? "link_off" : "link"
                    color: ethernetItem.modelData.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                    opacity: ethernetItem.loading ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }
        }
    }

    Connections {
        target: Nmcli

        function onActiveChanged(): void {
            if (Nmcli.active && root.connectingToSsid === Nmcli.active.ssid) {
                root.connectingToSsid = "";
                // Close password dialog if we successfully connected
                if (root.showPasswordDialog && root.passwordNetwork && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                    root.showPasswordDialog = false;
                    root.passwordNetwork = null;
                    if (root.wrapper.currentName === "wirelesspassword") {
                        root.wrapper.currentName = "network";
                    }
                }
            }
        }

        function onScanningChanged(): void {
            if (!Nmcli.scanning)
                scanIcon.rotation = 0;
        }
    }

    Connections {
        target: root.wrapper
        function onCurrentNameChanged(): void {
            // Clear password network when leaving password dialog
            if (root.wrapper.currentName !== "wirelesspassword" && root.showPasswordDialog) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.small
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle
        }
    }
}
