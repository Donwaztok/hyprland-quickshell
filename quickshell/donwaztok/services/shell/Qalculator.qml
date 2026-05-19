pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var _cache: ({})
    property int _tick: 0
    property string _pending: ""

    readonly property var functions: [
        { name: "sqrt", snippet: "sqrt()", desc: qsTr("Square root") },
        { name: "cbrt", snippet: "cbrt()", desc: qsTr("Cube root") },
        { name: "sin", snippet: "sin()", desc: qsTr("Sine") },
        { name: "cos", snippet: "cos()", desc: qsTr("Cosine") },
        { name: "tan", snippet: "tan()", desc: qsTr("Tangent") },
        { name: "log", snippet: "log()", desc: qsTr("Logarithm") },
        { name: "ln", snippet: "ln()", desc: qsTr("Natural logarithm") },
        { name: "abs", snippet: "abs()", desc: qsTr("Absolute value") },
        { name: "round", snippet: "round()", desc: qsTr("Round") },
        { name: "ceil", snippet: "ceil()", desc: qsTr("Round up") },
        { name: "floor", snippet: "floor()", desc: qsTr("Round down") },
        { name: "fact", snippet: "fact()", desc: qsTr("Factorial") },
        { name: "exp", snippet: "exp()", desc: qsTr("Exponential") },
        { name: "min", snippet: "min(,)", desc: qsTr("Minimum") },
        { name: "max", snippet: "max(,)", desc: qsTr("Maximum") },
        { name: "avg", snippet: "avg()", desc: qsTr("Average") },
        { name: "sum", snippet: "sum()", desc: qsTr("Sum") }
    ]

    function expressionFromSearch(text) {
        const prefix = `${Config.launcher.actionPrefix}calc `;
        const t = String(text ?? "");
        if (t.startsWith(prefix))
            return t.slice(prefix.length).trim();
        return t.trim();
    }

    function isCalcMode(text) {
        return String(text ?? "").startsWith(`${Config.launcher.actionPrefix}calc `);
    }

    function canEvaluate(text) {
        const t = root.expressionFromSearch(text);
        return /\d/.test(t) && /[\+\-\*\/×÷\^%()]/.test(t);
    }

    function looksLikeMath(text) {
        const t = String(text ?? "").trim();
        if (!t || root.isCalcMode(t))
            return false;
        if (t.startsWith(Config.launcher.actionPrefix))
            return false;
        return root.canEvaluate(t);
    }

    function currentToken(text) {
        const t = String(text ?? "");
        const match = t.match(/(?:^|[\s+\-*/^%(,])([a-zA-Z][a-zA-Z0-9]*)$/);
        return match ? match[1].toLowerCase() : "";
    }

    function suggestions(text) {
        const expr = root.expressionFromSearch(text);
        const token = root.currentToken(expr);
        const limit = Config.launcher.maxShown;

        const list = !token
            ? root.functions.slice(0, limit)
            : root.functions.filter(entry => entry.name.startsWith(token)).slice(0, limit);

        const last = list.length - 1;
        return list.map((entry, i) => ({
            name: entry.name,
            snippet: entry.snippet,
            desc: entry.desc,
            isLast: i === last
        }));
    }

    function applySuggestion(search, snippet) {
        search.text = `${Config.launcher.actionPrefix}calc ${snippet}`;
        search.forceActiveFocus();
    }

    function request(expression) {
        const expr = String(expression ?? "").trim();
        if (!expr || root._cache[expr] !== undefined || root._pending === expr)
            return;

        root._pending = expr;
        evalTimer.restart();
    }

    function display(expression) {
        void root._tick;
        return root._cache[String(expression ?? "").trim()] ?? "";
    }

    Timer {
        id: evalTimer

        interval: 60
        repeat: false
        onTriggered: evalProc.exec(["qalc", "-t", root._pending])
    }

    Process {
        id: evalProc

        stdout: StdioCollector {
            onStreamFinished: {
                const expr = root._pending;
                if (!expr)
                    return;

                const cache = Object.assign({}, root._cache);
                cache[expr] = text.trim() || qsTr("No result");
                root._cache = cache;
                root._tick++;
            }
        }
    }
}
