pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string osName
    property string osPrettyName
    property string osId
    property list<string> osIdLike
    property string osLogo: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/icons/linux-symbolic.svg`)

    property string uptime
    readonly property string user: Quickshell.env("USER")
    readonly property string wm: Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP")
    readonly property string shell: Quickshell.env("SHELL").split("/").pop()

    FileView {
        id: osRelease

        path: "/etc/os-release"
        onLoaded: {
            const raw = text();
            const lines = raw.split("\n");

            const fd = key => lines.find(l => l.startsWith(`${key}=`))?.split("=")[1].replace(/"/g, "") ?? "";

            root.osName = fd("NAME");
            root.osPrettyName = fd("PRETTY_NAME");
            root.osId = fd("ID");
            root.osIdLike = fd("ID_LIKE").split(" ");

            function bundledIconFile(iconBaseName) {
                return Qt.resolvedUrl(`${Quickshell.shellDir}/assets/icons/${iconBaseName}.svg`);
            }

            function distroBundledIconName(distroId, rawOsRelease) {
                let name = "linux-symbolic";
                switch (distroId) {
                case "artix":
                case "arch":
                    name = "arch-symbolic";
                    break;
                case "endeavouros":
                    name = "endeavouros-symbolic";
                    break;
                case "cachyos":
                    name = "cachyos-symbolic";
                    break;
                case "nixos":
                    name = "nixos-symbolic";
                    break;
                case "fedora":
                    name = "fedora-symbolic";
                    break;
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos":
                    name = "ubuntu-symbolic";
                    break;
                case "debian":
                case "raspbian":
                case "kali":
                    name = "debian-symbolic";
                    break;
                case "funtoo":
                case "gentoo":
                    name = "gentoo-symbolic";
                    break;
                }
                if (rawOsRelease.toLowerCase().includes("nyarch"))
                    name = "nyarch-symbolic";
                return name;
            }

            const logoField = fd("LOGO").trim();
            let chosen = "";
            if (logoField.length > 0)
                chosen = Quickshell.iconPath(logoField, true) || "";
            if (!chosen) {
                const bundledName = distroBundledIconName(fd("ID"), raw);
                chosen = Quickshell.iconPath(bundledName, true) || "";
                if (!chosen)
                    chosen = bundledIconFile(bundledName);
            }
            if (!chosen) {
                chosen = Quickshell.iconPath("linux-symbolic", true) || "";
                if (!chosen)
                    chosen = bundledIconFile("linux-symbolic");
            }
            root.osLogo = chosen;
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: fileUptime.reload()
    }

    FileView {
        id: fileUptime

        path: "/proc/uptime"
        onLoaded: {
            const up = parseInt(text().split(" ")[0] ?? 0);

            const days = Math.floor(up / 86400);
            const hours = Math.floor((up % 86400) / 3600);
            const minutes = Math.floor((up % 3600) / 60);

            let str = "";
            if (days > 0)
                str += `${days} day${days === 1 ? "" : "s"}`;
            if (hours > 0)
                str += `${str ? ", " : ""}${hours} hour${hours === 1 ? "" : "s"}`;
            if (minutes > 0 || !str)
                str += `${str ? ", " : ""}${minutes} minute${minutes === 1 ? "" : "s"}`;
            root.uptime = str;
        }
    }
}
