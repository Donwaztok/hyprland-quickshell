pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property AppearanceConfig appearance: DonwaztokConfigStore.topLevel.appearance
    readonly property GeneralConfig general: DonwaztokConfigStore.topLevel.general
    readonly property BackgroundConfig background: DonwaztokConfigStore.topLevel.background
    readonly property BarConfig bar: DonwaztokConfigStore.topLevel.bar
    readonly property BorderConfig border: DonwaztokConfigStore.topLevel.border
    readonly property DashboardConfig dashboard: DonwaztokConfigStore.topLevel.dashboard
    readonly property ControlCenterConfig controlCenter: DonwaztokConfigStore.topLevel.controlCenter
    readonly property LauncherConfig launcher: DonwaztokConfigStore.topLevel.launcher
    readonly property NotifsConfig notifs: DonwaztokConfigStore.topLevel.notifs
    readonly property SessionConfig session: DonwaztokConfigStore.topLevel.session
    readonly property WInfoConfig winfo: DonwaztokConfigStore.topLevel.winfo
    readonly property LockConfig lock: DonwaztokConfigStore.topLevel.lock
    readonly property UtilitiesConfig utilities: DonwaztokConfigStore.topLevel.utilities
    readonly property SidebarConfig sidebar: DonwaztokConfigStore.topLevel.sidebar
    readonly property ServiceConfig services: DonwaztokConfigStore.topLevel.services
    readonly property UserPaths paths: DonwaztokConfigStore.topLevel.paths

    /// M3 / `options` block in donwaztok/config.json (lock blur, AI, search, etc.)
    readonly property var shellOptions: DonwaztokConfigStore.shellOptions

    // Bar UI scale vs 36px design baseline (avoids a separate singleton that would circular-import Config via qs.utils).
    readonly property real barThicknessScale: (bar.sizes.thickness > 0) ? (bar.sizes.thickness / 36) : 1

    readonly property bool loaded: DonwaztokConfigStore.ready

    // Public save function - call this to persist config changes
    function save(): void {
        DonwaztokConfigStore.markTopLevelWritten();
        saveTimer.restart();
    }

    // Helper function to serialize the config object
    function serializeConfig(): var {
        return {
            appearance: serializeAppearance(),
            general: serializeGeneral(),
            background: serializeBackground(),
            bar: serializeBar(),
            border: serializeBorder(),
            dashboard: serializeDashboard(),
            controlCenter: serializeControlCenter(),
            launcher: serializeLauncher(),
            notifs: serializeNotifs(),
            session: serializeSession(),
            winfo: serializeWinfo(),
            lock: serializeLock(),
            utilities: serializeUtilities(),
            sidebar: serializeSidebar(),
            services: serializeServices(),
            paths: serializePaths()
        };
    }

    function cloneRealList(lst) {
        const o = [];
        if (!lst)
            return o;
        for (let i = 0; i < lst.length; ++i)
            o.push(lst[i]);
        return o;
    }

    function serializeAppearance(): var {
        return {
            themeMode: appearance.themeMode || "dark",
            rounding: {
                scale: appearance.rounding.scale
            },
            spacing: {
                scale: appearance.spacing.scale
            },
            padding: {
                scale: appearance.padding.scale
            },
            font: {
                family: {
                    sans: appearance.font.family.sans,
                    mono: appearance.font.family.mono,
                    material: appearance.font.family.material,
                    clock: appearance.font.family.clock
                },
                size: {
                    scale: appearance.font.size.scale
                }
            },
            anim: {
                mediaGifSpeedAdjustment: appearance.anim.mediaGifSpeedAdjustment ?? 300,
                durations: {
                    scale: appearance.anim.durations.scale
                },
                curves: {
                    emphasized: cloneRealList(appearance.anim.curves.emphasized),
                    emphasizedAccel: cloneRealList(appearance.anim.curves.emphasizedAccel),
                    emphasizedDecel: cloneRealList(appearance.anim.curves.emphasizedDecel),
                    standard: cloneRealList(appearance.anim.curves.standard),
                    standardAccel: cloneRealList(appearance.anim.curves.standardAccel),
                    standardDecel: cloneRealList(appearance.anim.curves.standardDecel),
                    expressiveFastSpatial: cloneRealList(appearance.anim.curves.expressiveFastSpatial),
                    expressiveDefaultSpatial: cloneRealList(appearance.anim.curves.expressiveDefaultSpatial),
                    expressiveEffects: cloneRealList(appearance.anim.curves.expressiveEffects)
                }
            }
        };
    }

    function serializeGeneral(): var {
        return {
            excludedScreens: general.excludedScreens,
            apps: {
                terminal: general.apps.terminal,
                audio: general.apps.audio,
                playback: general.apps.playback,
                explorer: general.apps.explorer
            },
            idle: {
                lockBeforeSleep: general.idle.lockBeforeSleep,
                inhibitWhenAudio: general.idle.inhibitWhenAudio,
                timeouts: general.idle.timeouts
            },
            battery: {
                warnLevels: general.battery.warnLevels,
                criticalLevel: general.battery.criticalLevel
            }
        };
    }

    function serializeBackground(): var {
        return {
            enabled: background.enabled,
            wallpaperEnabled: background.wallpaperEnabled,
            desktopClock: {
                enabled: background.desktopClock.enabled,
                scale: background.desktopClock.scale,
                position: background.desktopClock.position,
                invertColors: background.desktopClock.invertColors,
                background: {
                    enabled: background.desktopClock.background.enabled,
                    opacity: background.desktopClock.background.opacity,
                    blur: background.desktopClock.background.blur
                },
                shadow: {
                    enabled: background.desktopClock.shadow.enabled,
                    opacity: background.desktopClock.shadow.opacity,
                    blur: background.desktopClock.shadow.blur
                }
            }
        };
    }

    function serializeBar(): var {
        return {
            position: bar.position,
            persistent: bar.persistent,
            showOnHover: bar.showOnHover,
            borderless: bar.borderless,
            dragThreshold: bar.dragThreshold,
            popouts: {
                tray: bar.popouts.tray,
                statusIcons: bar.popouts.statusIcons
            },
            tray: {
                background: bar.tray.background,
                recolour: bar.tray.recolour,
                compact: bar.tray.compact,
                iconSubs: bar.tray.iconSubs,
                hiddenIcons: bar.tray.hiddenIcons
            },
            status: {
                showAudio: bar.status.showAudio,
                showMicrophone: bar.status.showMicrophone,
                showKbLayout: bar.status.showKbLayout,
                showNetwork: bar.status.showNetwork,
                showBluetooth: bar.status.showBluetooth,
                showBattery: bar.status.showBattery,
                showLockStatus: bar.status.showLockStatus
            },
            clock: {
                showIcon: bar.clock.showIcon
            },
            sizes: {
                thickness: bar.sizes.thickness,
                innerWidth: bar.sizes.innerWidth,
                windowPreviewSize: bar.sizes.windowPreviewSize,
                trayMenuWidth: bar.sizes.trayMenuWidth,
                batteryWidth: bar.sizes.batteryWidth,
                networkWidth: bar.sizes.networkWidth,
                kbLayoutWidth: bar.sizes.kbLayoutWidth
            },
            workspaces: {
                style: bar.workspaces.style,
                shown: bar.workspaces.shown,
                showAppIcons: bar.workspaces.showAppIcons,
                alwaysShowNumbers: bar.workspaces.alwaysShowNumbers,
                showNumberDelay: bar.workspaces.showNumberDelay,
                numberMap: bar.workspaces.numberMap,
                useNerdFont: bar.workspaces.useNerdFont,
                classicSlotWidth: bar.workspaces.classicSlotWidth,
                workspaceButtonWidth: bar.workspaces.workspaceButtonWidth,
                activeSlotWidth: bar.workspaces.activeSlotWidth,
                dashWidthFactor: bar.workspaces.dashWidthFactor,
                dashMargin: bar.workspaces.dashMargin,
                indicatorSize: bar.workspaces.indicatorSize,
                dotSize: bar.workspaces.dotSize,
                pillHeight: bar.workspaces.pillHeight,
                superKey: {
                    showNumbers: bar.workspaces.superKey.showNumbers,
                    delayMs: bar.workspaces.superKey.delayMs
                }
            },
            entries: bar.entries,
            excludedScreens: bar.excludedScreens
        };
    }

    function serializeBorder(): var {
        return {
            thickness: border.thickness,
            rounding: border.rounding
        };
    }

    function serializeDashboard(): var {
        return {
            enabled: dashboard.enabled,
            showOnHover: dashboard.showOnHover,
            mediaUpdateInterval: dashboard.mediaUpdateInterval,
            resourceUpdateInterval: dashboard.resourceUpdateInterval,
            dragThreshold: dashboard.dragThreshold,
            performance: {
                showBattery: dashboard.performance.showBattery,
                showGpu: dashboard.performance.showGpu,
                showCpu: dashboard.performance.showCpu,
                showMemory: dashboard.performance.showMemory,
                showStorage: dashboard.performance.showStorage,
                showNetwork: dashboard.performance.showNetwork
            }
        };
    }

    function serializeControlCenter(): var {
        return {};
    }

    function serializeLauncher(): var {
        return {
            enabled: launcher.enabled,
            maxShown: launcher.maxShown,
            maxWallpapers: launcher.maxWallpapers,
            clipboardMaxShown: launcher.clipboardMaxShown,
            clipboardMaxHeightRatio: launcher.clipboardMaxHeightRatio,
            actionPrefix: launcher.actionPrefix,
            clipboardPrefix: launcher.clipboardPrefix,
            pendingOpenPrefix: launcher.pendingOpenPrefix,
            enableDangerousActions: launcher.enableDangerousActions,
            dragThreshold: launcher.dragThreshold,
            vimKeybinds: launcher.vimKeybinds,
            cardOpacity: launcher.cardOpacity,
            verticalAnchor: launcher.verticalAnchor,
            favouriteApps: launcher.favouriteApps,
            hiddenApps: launcher.hiddenApps,
            sizes: {
                itemWidth: launcher.sizes.itemWidth,
                itemHeight: launcher.sizes.itemHeight,
                searchBarHeight: launcher.sizes.searchBarHeight,
                cardRadius: launcher.sizes.cardRadius,
                wallpaperWidth: launcher.sizes.wallpaperWidth,
                wallpaperHeight: launcher.sizes.wallpaperHeight,
                clipboardImagePreviewHeight: launcher.sizes.clipboardImagePreviewHeight
            },
            actions: launcher.actions
        };
    }

    function serializeNotifs(): var {
        return {
            expire: notifs.expire,
            defaultExpireTimeout: notifs.defaultExpireTimeout,
            clearThreshold: notifs.clearThreshold,
            expandThreshold: notifs.expandThreshold,
            actionOnClick: notifs.actionOnClick,
            groupPreviewNum: notifs.groupPreviewNum
        };
    }

    function serializeSession(): var {
        return {
            enabled: session.enabled,
            dragThreshold: session.dragThreshold,
            vimKeybinds: session.vimKeybinds,
            icons: {
                logout: session.icons.logout,
                shutdown: session.icons.shutdown,
                hibernate: session.icons.hibernate,
                reboot: session.icons.reboot
            },
            commands: {
                logout: session.commands.logout,
                shutdown: session.commands.shutdown,
                hibernate: session.commands.hibernate,
                reboot: session.commands.reboot
            }
        };
    }

    function serializeWinfo(): var {
        return {};
    }

    function serializeLock(): var {
        return {
            recolourLogo: lock.recolourLogo,
            enableFprint: lock.enableFprint,
            maxFprintTries: lock.maxFprintTries,
            hideNotifs: lock.hideNotifs
        };
    }

    function serializeUtilities(): var {
        return {
            enabled: utilities.enabled,
            maxToasts: utilities.maxToasts,
            toasts: {
                configLoaded: utilities.toasts.configLoaded,
                chargingChanged: utilities.toasts.chargingChanged,
                dndChanged: utilities.toasts.dndChanged,
                audioOutputChanged: utilities.toasts.audioOutputChanged,
                audioInputChanged: utilities.toasts.audioInputChanged,
                capsLockChanged: utilities.toasts.capsLockChanged,
                numLockChanged: utilities.toasts.numLockChanged,
                kbLayoutChanged: utilities.toasts.kbLayoutChanged,
                vpnChanged: utilities.toasts.vpnChanged,
                nowPlaying: utilities.toasts.nowPlaying
            },
            vpn: {
                enabled: utilities.vpn.enabled,
                provider: utilities.vpn.provider
            },
            quickToggles: utilities.quickToggles
        };
    }

    function serializeSidebar(): var {
        return {
            enabled: sidebar.enabled,
            dragThreshold: sidebar.dragThreshold
        };
    }

    function serializeServices(): var {
        return {
            weatherLocation: services.weatherLocation,
            useFahrenheit: services.useFahrenheit,
            useFahrenheitPerformance: services.useFahrenheitPerformance,
            useTwelveHourClock: services.useTwelveHourClock,
            gpuType: services.gpuType,
            audioIncrement: services.audioIncrement,
            brightnessIncrement: services.brightnessIncrement,
            maxVolume: services.maxVolume,
            wallpaperSetCommand: services.wallpaperSetCommand,
            defaultPlayer: services.defaultPlayer,
            playerAliases: services.playerAliases
        };
    }

    function serializePaths(): var {
        return {
            wallpaperDir: paths.wallpaperDir,
            mediaGif: paths.mediaGif
        };
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: {
            try {
                DonwaztokConfigStore.writeFullConfig();
            } catch (e) {
                Toaster.toast(qsTr("Failed to serialize config"), e.message, "settings_alert", Toast.Error);
            }
        }
    }

    Connections {
        target: DonwaztokConfigStore.configFileView

        function onLoaded() {
            try {
                JSON.parse(target.text());
                const elapsed = DonwaztokConfigStore.configLoadElapsed.elapsedMs();
                const ad = DonwaztokConfigStore.topLevel;
                if (ad.utilities.toasts.configLoaded && !DonwaztokConfigStore.topLevelWriteCooldown && elapsed > 0) {
                    Toaster.toast(qsTr("Config loaded"), qsTr("Config loaded in %1ms").arg(elapsed), "rule_settings");
                } else if (ad.utilities.toasts.configLoaded && DonwaztokConfigStore.topLevelWriteCooldown && elapsed > 0) {
                    Toaster.toast(qsTr("Config saved"), qsTr("Config reloaded in %1ms").arg(elapsed), "rule_settings");
                }
            } catch (e) {
                Toaster.toast(qsTr("Failed to load config"), e.message, "settings_alert", Toast.Error);
            }
        }

        function onLoadFailed(err) {
            if (err !== FileViewError.FileNotFound)
                Toaster.toast(qsTr("Failed to read config file"), FileViewError.toString(err), "settings_alert", Toast.Warning);
        }

        function onSaveFailed(err) {
            Toaster.toast(qsTr("Failed to save config"), FileViewError.toString(err), "settings_alert", Toast.Error);
        }
    }
}
