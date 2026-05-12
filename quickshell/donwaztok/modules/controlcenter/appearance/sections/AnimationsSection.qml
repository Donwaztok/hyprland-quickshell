pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

PreferencesGroup {
    id: root

    required property var rootPane

    Layout.fillWidth: true
    title: qsTr("Animations")
    description: qsTr("Duration scaling and Bezier easing curves for shell transitions (same format as Qt Quick BezierSpline).")

    readonly property var curveKeyList: ["standard", "standardAccel", "standardDecel", "emphasized", "emphasizedAccel", "emphasizedDecel", "expressiveFastSpatial", "expressiveDefaultSpatial", "expressiveEffects"]

    /** Built-in defaults (must match `AppearanceConfig.qml` AnimCurves). */
    readonly property var defaultCurves: ({
        "standard": [0.2, 0, 0, 1, 1, 1],
        "standardAccel": [0.3, 0, 1, 1, 1, 1],
        "standardDecel": [0, 0, 0, 1, 1, 1],
        "emphasized": [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1],
        "emphasizedAccel": [0.3, 0, 0.8, 0.15, 1, 1],
        "emphasizedDecel": [0.05, 0.7, 0.1, 1, 1, 1],
        "expressiveFastSpatial": [0.42, 1.67, 0.21, 0.9, 1, 1],
        "expressiveDefaultSpatial": [0.38, 1.21, 0.22, 1, 1, 1],
        "expressiveEffects": [0.34, 0.8, 0.34, 1, 1, 1]
    })

    property string selectedCurveKey: "expressiveDefaultSpatial"

    /** Local copy for the graph editor (avoids rebinding from Config every frame). */
    property var _editorCurve: [0.38, 1.21, 0.22, 1, 1, 1]

    onSelectedCurveKeyChanged: {
        root._editorCurve = root.readCurveArray(root.selectedCurveKey);
    }

    Component.onCompleted: {
        root._editorCurve = root.readCurveArray(root.selectedCurveKey);
    }

    function curveOptions() {
        return root.curveKeyList.map(k => ({
            text: k,
            value: k
        }));
    }

    function readCurveArray(key) {
        const c = Config.appearance.anim.curves;
        let v;
        switch (key) {
        case "standard":
            v = c.standard;
            break;
        case "standardAccel":
            v = c.standardAccel;
            break;
        case "standardDecel":
            v = c.standardDecel;
            break;
        case "emphasized":
            v = c.emphasized;
            break;
        case "emphasizedAccel":
            v = c.emphasizedAccel;
            break;
        case "emphasizedDecel":
            v = c.emphasizedDecel;
            break;
        case "expressiveFastSpatial":
            v = c.expressiveFastSpatial;
            break;
        case "expressiveDefaultSpatial":
            v = c.expressiveDefaultSpatial;
            break;
        case "expressiveEffects":
            v = c.expressiveEffects;
            break;
        default:
            v = [];
        }
        return v && v.length ? v.slice() : root.defaultCurves[key].slice();
    }

    function writeCurveArray(key, arr) {
        const c = Config.appearance.anim.curves;
        const v = arr.slice();
        switch (key) {
        case "standard":
            c.standard = v;
            break;
        case "standardAccel":
            c.standardAccel = v;
            break;
        case "standardDecel":
            c.standardDecel = v;
            break;
        case "emphasized":
            c.emphasized = v;
            break;
        case "emphasizedAccel":
            c.emphasizedAccel = v;
            break;
        case "emphasizedDecel":
            c.emphasizedDecel = v;
            break;
        case "expressiveFastSpatial":
            c.expressiveFastSpatial = v;
            break;
        case "expressiveDefaultSpatial":
            c.expressiveDefaultSpatial = v;
            break;
        case "expressiveEffects":
            c.expressiveEffects = v;
            break;
        }
        Config.save();
    }

    SliderInput {
        Layout.fillWidth: true
        label: qsTr("Animation duration scale")
        value: rootPane.animDurationsScale
        from: 0.1
        to: 5.0
        decimals: 1
        suffix: "×"
        validator: DoubleValidator {
            bottom: 0.1
            top: 5.0
        }

        onValueModified: newValue => {
            rootPane.animDurationsScale = newValue;
            rootPane.saveConfig();
        }
    }

    OptionSelectRow {
        Layout.fillWidth: true
        label: qsTr("Curve to edit")
        options: root.curveOptions()
        currentValue: root.selectedCurveKey

        onOptionChosen: value => {
            root.selectedCurveKey = value;
        }
    }

    AnimBezierSplineEditor {
        id: curveEditor

        Layout.fillWidth: true
        Layout.minimumWidth: 280

        curveFlat: root._editorCurve
        defaultCurveFlat: root.defaultCurves[root.selectedCurveKey].slice()

        onCurveEdited: newFlat => {
            root._editorCurve = newFlat.slice();
            root.writeCurveArray(root.selectedCurveKey, newFlat);
        }
    }
}
