import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities
    property int bottomRadius: Config.launcher.sizes.cardRadius

    readonly property string math: Qalculator.expressionFromSearch(search.text)
    readonly property string resultText: {
        void Qalculator._tick;
        if (!root.math.length)
            return "";
        const value = Qalculator.display(root.math);
        return value.length > 0 ? value : "…";
    }

    onMathChanged: {
        if (Qalculator.canEvaluate(root.math))
            Qalculator.request(root.math);
    }
    Component.onCompleted: {
        if (Qalculator.canEvaluate(root.math))
            Qalculator.request(root.math);
    }

    function onClicked(): void {
        const value = Qalculator.display(root.math);
        if (!value || value === "…")
            return;
        Quickshell.execDetached(["wl-copy", value]);
        root.visibilities.launcher = false;
    }

    implicitHeight: Config.launcher.sizes.itemHeight
    width: parent?.width ?? implicitWidth

    StateLayer {
        radius: 0
        rect.bottomLeftRadius: root.bottomRadius
        rect.bottomRightRadius: root.bottomRadius

        function onClicked(): void {
            root.onClicked();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        MaterialIcon {
            text: "calculate"
            font.pointSize: Appearance.font.size.extraLarge
            color: root.resultText.length > 0 && root.resultText !== "…"
                ? Colours.palette.m3primary
                : Colours.palette.m3onSurfaceVariant
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { CAnim {} }
        }

        StyledText {
            text: root.resultText
            font.pointSize: Appearance.font.size.normal
            font.family: Appearance.font.family.mono
            color: Colours.palette.m3onSurface
            elide: Text.ElideLeft
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            animate: true
            animateProp: "opacity"
            animateFrom: 0.35
            animateTo: 1
            animateDuration: Appearance.anim.durations.expressiveEffects
        }
    }
}
