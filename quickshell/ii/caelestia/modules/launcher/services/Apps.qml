pragma Singleton

import QtQuick
import caelestia.config
import caelestia.services
import caelestia.utils
import Quickshell

Searcher {
    id: root

    function launch(entry: DesktopEntry): void {
        if (!entry)
            return;
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "--", ...Config.general.apps.terminal, `${Quickshell.shellDir}/caelestia/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    function search(search: string): list<var> {
        const prefix = Config.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}c `)) {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}d `)) {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}e `)) {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}w `)) {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}g `)) {
            keys = ["genericName", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}k `)) {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name"];
            weights = [1];

            if (!search.startsWith(`${prefix}t `))
                return query(search);
        }

        const results = query(search.slice(prefix.length + 2));
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: Config.launcher.useFuzzy.apps

    property int _applicationsVersion: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _applicationsVersion += 1;
        }
    }

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: Config.launcher.favouriteApps
        entries: (root._applicationsVersion, ((DesktopEntries.applications && DesktopEntries.applications.values) || []).filter(a => a && !Strings.testRegexList(Config.launcher.hiddenApps || [], a.id)))
    }
}
