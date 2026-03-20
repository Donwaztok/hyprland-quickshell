import caelestia.config
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    width: 0
    height: 0
    visible: false

    property int bars: Config.services.visualiserBars
    property list<real> values: []

    readonly property string configPath: Quickshell.shellPath("scripts/cava/raw_output_config.txt")

    function _regen(): void {
        const v = [];
        for (let i = 0; i < Math.max(0, bars); ++i)
            v.push(0);
        values = v;
    }

    function _normalize(v: real): real {
        if (v <= 1.5)
            return Math.max(0, Math.min(1, v));
        return Math.max(0, Math.min(1, v / 1000));
    }

    function _applyPoints(points: var): void {
        const want = Math.max(1, root.bars);
        const n = points.length;
        if (n === 0) {
            root._regen();
            return;
        }
        const out = [];
        for (let i = 0; i < want; ++i) {
            const t = (i + 0.5) / want;
            const idx = Math.min(n - 1, Math.max(0, Math.floor(t * n)));
            out.push(_normalize(points[idx]));
        }
        root.values = out;
    }

    onBarsChanged: _regen()

    Component.onCompleted: _regen()

    Process {
        id: cavaProc

        running: Config.background.visualiser.enabled
        command: ["cava", "-p", root.configPath]

        stdout: SplitParser {
            onRead: data => {
                const points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root._applyPoints(points);
            }
        }

        onRunningChanged: {
            if (!running)
                root._regen();
        }
    }
}

