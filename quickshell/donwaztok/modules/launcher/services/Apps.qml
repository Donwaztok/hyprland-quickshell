pragma Singleton

import QtQuick
import qs.config
import qs.services.shell
import qs.utils
import Quickshell

Searcher {
    id: root

    function launch(entry: DesktopEntry): void {
        if (!entry)
            return;
        appDb.incrementFrequency(entry.id);

        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: ["app2unit", "--", ...Config.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    function search(search: string): list<var> {
        return query(search);
    }

    list: appDb.apps

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
