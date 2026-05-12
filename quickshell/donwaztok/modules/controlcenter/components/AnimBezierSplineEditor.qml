pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts

import "./BezierSplineMath.js" as BS

ColumnLayout {
    id: root

    /** Flat Qt BezierSpline list (6 values per cubic segment, first starts at 0,0). */
    property var curveFlat: []

    /** Same length as curveFlat; used by Reset. */
    property var defaultCurveFlat: []

    signal curveEdited(var newFlat)

    spacing: Appearance.spacing.normal

    readonly property real margin: 36
    readonly property real plotSize: Math.min(420, Math.max(220, width - margin * 2))
    readonly property real hitRNorm: 0.045

    function graphToNorm(mx, my) {
        const px = mx - margin;
        const py = my - margin;
        const gx = Math.max(0, Math.min(1, px / plotSize));
        const gy = Math.max(0, Math.min(1, 1 - py / plotSize));
        return { x: gx, y: gy };
    }

    function normToGraph(gx, gy) {
        return {
            x: margin + gx * plotSize,
            y: margin + (1 - gy) * plotSize
        };
    }

    property var _dragPick: null
    property var _working: []

    onCurveFlatChanged: {
        _working = curveFlat && curveFlat.length ? curveFlat.slice() : [];
        canvas.requestPaint();
    }

    Component.onCompleted: {
        _working = curveFlat && curveFlat.length ? curveFlat.slice() : [];
        canvas.requestPaint();
    }

    Item {
        Layout.fillWidth: true
        implicitWidth: root.plotSize + margin * 2
        implicitHeight: root.plotSize + margin * 2

        Canvas {
            id: canvas

            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                const W = width;
                const H = height;
                const m = root.margin;
                const ps = root.plotSize;
                ctx.reset();
                ctx.fillStyle = Colours.tPalette.m3surfaceContainerLowest;
                ctx.fillRect(0, 0, W, H);
                ctx.strokeStyle = Qt.rgba(0.5, 0.5, 0.5, 0.25);
                ctx.lineWidth = 1;
                for (let g = 0; g <= 4; g++) {
                    const t = g / 4;
                    const x = m + t * ps;
                    ctx.beginPath();
                    ctx.moveTo(x, m);
                    ctx.lineTo(x, m + ps);
                    ctx.stroke();
                    const y = m + t * ps;
                    ctx.beginPath();
                    ctx.moveTo(m, y);
                    ctx.lineTo(m + ps, y);
                    ctx.stroke();
                }
                ctx.setLineDash([4, 4]);
                ctx.strokeStyle = Qt.rgba(0.7, 0.7, 0.7, 0.45);
                ctx.beginPath();
                ctx.moveTo(m, m + ps);
                ctx.lineTo(m + ps, m);
                ctx.stroke();
                ctx.setLineDash([]);

                const flat = root._working;
                if (!flat || flat.length < 6) {
                    ctx.fillStyle = Colours.palette.m3onSurfaceVariant;
                    ctx.font = "13px sans-serif";
                    ctx.fillText(qsTr("Invalid curve data"), m + 8, m + 20);
                    return;
                }

                ctx.strokeStyle = Colours.palette.m3primary;
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                const steps = 140;
                for (let i = 0; i <= steps; i++) {
                    const p = i / steps;
                    const yv = BS.evalY(p, flat);
                    const gx = m + p * ps;
                    const gy = m + (1 - yv) * ps;
                    if (i === 0)
                        ctx.moveTo(gx, gy);
                    else
                        ctx.lineTo(gx, gy);
                }
                ctx.stroke();

                const segs = BS.parseSegments(flat);
                ctx.strokeStyle = Qt.rgba(0.85, 0.85, 0.85, 0.35);
                ctx.lineWidth = 1;
                for (let si = 0; si < segs.length; si++) {
                    const s = segs[si];
                    const a = root.normToGraph(s.p0.x, s.p0.y);
                    const b = root.normToGraph(s.p1.x, s.p1.y);
                    const c = root.normToGraph(s.p2.x, s.p2.y);
                    const d = root.normToGraph(s.p3.x, s.p3.y);
                    ctx.beginPath();
                    ctx.moveTo(a.x, a.y);
                    ctx.lineTo(b.x, b.y);
                    ctx.moveTo(c.x, c.y);
                    ctx.lineTo(d.x, d.y);
                    ctx.stroke();
                }

                ctx.fillStyle = Colours.palette.m3secondary;
                for (let si = 0; si < segs.length; si++) {
                    const s = segs[si];
                    for (const pt of [s.p1, s.p2]) {
                        const g = root.normToGraph(pt.x, pt.y);
                        ctx.beginPath();
                        ctx.arc(g.x, g.y, 6, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
                ctx.fillStyle = Colours.palette.m3tertiary;
                for (let si = 0; si < segs.length; si++) {
                    const s = segs[si];
                    const g = root.normToGraph(s.p3.x, s.p3.y);
                    ctx.beginPath();
                    ctx.arc(g.x, g.y, 5, 0, 2 * Math.PI);
                    ctx.fill();
                }
                ctx.fillStyle = Colours.palette.m3onSurface;
                const g0 = root.normToGraph(0, 0);
                ctx.beginPath();
                ctx.arc(g0.x, g0.y, 5, 0, 2 * Math.PI);
                ctx.fill();
            }
        }

        StyledText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 4
            anchors.topMargin: 4
            text: qsTr("Output ↑")
            font.pixelSize: 11
            color: Colours.palette.m3onSurfaceVariant
        }
        StyledText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 4
            anchors.bottomMargin: 4
            text: qsTr("Time / progress →")
            font.pixelSize: 11
            color: Colours.palette.m3onSurfaceVariant
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            onPressed: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    const n = root.graphToNorm(mouse.x, mouse.y);
                    const hit = BS.pickHandle(n.x, n.y, root._working, root.hitRNorm);
                    if (hit && hit.kind === "p3" && BS.parseSegments(root._working).length > 1) {
                        const segs = BS.parseSegments(root._working);
                        if (hit.seg === segs.length - 1) {
                            root._working = BS.removeLastSegment(root._working);
                            root._working = BS.snapEndToOne(root._working);
                            canvas.requestPaint();
                            root.curveEdited(root._working.slice());
                        }
                    }
                    return;
                }
                const n = root.graphToNorm(mouse.x, mouse.y);
                root._dragPick = BS.pickHandle(n.x, n.y, root._working, root.hitRNorm);
            }

            onPositionChanged: function (mouse) {
                if (!root._dragPick)
                    return;
                const n = root.graphToNorm(mouse.x, mouse.y);
                root._working = BS.moveHandle(root._working, root._dragPick, n.x, n.y);
                canvas.requestPaint();
            }

            onReleased: function (mouse) {
                if (!root._dragPick)
                    return;
                root._dragPick = null;
                root._working = BS.snapEndToOne(root._working);
                canvas.requestPaint();
                if (mouse.button === Qt.LeftButton)
                    root.curveEdited(root._working.slice());
            }

            onDoubleClicked: function (mouse) {
                const n = root.graphToNorm(mouse.x, mouse.y);
                const best = BS.closestSegmentAndU(n.x, n.y, root._working);
                const thr = 0.04 * 0.04;
                if (best.dist2 < thr && best.u > 0.08 && best.u < 0.92) {
                    root._working = BS.subdivideSegment(root._working, best.seg, best.u);
                    root._working = BS.snapEndToOne(root._working);
                    canvas.requestPaint();
                    root.curveEdited(root._working.slice());
                }
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        TextButton {
            text: qsTr("Snap end to (1,1)")
            type: TextButton.Tonal
            onClicked: {
                root._working = BS.snapEndToOne(root._working.slice());
                canvas.requestPaint();
                root.curveEdited(root._working.slice());
            }
        }
        TextButton {
            text: qsTr("Add segment")
            type: TextButton.Tonal
            onClicked: {
                root._working = BS.appendSegmentTowardOne(root._working.slice());
                root._working = BS.snapEndToOne(root._working);
                canvas.requestPaint();
                root.curveEdited(root._working.slice());
            }
        }
        TextButton {
            text: qsTr("Remove last segment")
            type: TextButton.Tonal
            onClicked: {
                root._working = BS.removeLastSegment(root._working.slice());
                if (root._working.length < 6)
                    root._working = root.defaultCurveFlat.slice();
                root._working = BS.snapEndToOne(root._working);
                canvas.requestPaint();
                root.curveEdited(root._working.slice());
            }
        }
        TextButton {
            text: qsTr("Reset curve")
            type: TextButton.Text
            onClicked: {
                root._working = root.defaultCurveFlat.slice();
                canvas.requestPaint();
                root.curveEdited(root._working.slice());
            }
        }
    }


    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: 12
        color: Colours.palette.m3onSurfaceVariant
        text: qsTr("Drag orange handles (tangents) and purple knots. Double-click the curve to add a control point. Right-click the last knot to remove the last segment. Diagonal = linear easing.")
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: Appearance.rounding.normal
        color: Colours.tPalette.m3surfaceContainerHighest
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

        Item {
            id: previewHost
            anchors.fill: parent
            anchors.margins: 6

            Rectangle {
                id: previewBar
                height: parent.height
                width: 0
                radius: 4
                color: Colours.palette.m3primary
            }

            SequentialAnimation {
                id: previewAnim

                NumberAnimation {
                    target: previewBar
                    property: "width"
                    from: 0
                    to: previewHost.width
                    duration: 900
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root._working && root._working.length >= 6 ? root._working : root.defaultCurveFlat
                }
                PauseAnimation {
                    duration: 220
                }
                NumberAnimation {
                    target: previewBar
                    property: "width"
                    to: 0
                    duration: 120
                    easing.type: Easing.InOutQuad
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: previewAnim.restart()
        }
    }

    StyledText {
        Layout.fillWidth: true
        font.pixelSize: 11
        color: Colours.palette.m3onSurfaceVariant
        text: qsTr("Tap the preview strip to play with the current curve (uses the same BezierSpline as the shell).")
    }
}
