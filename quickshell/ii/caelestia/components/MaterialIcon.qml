import caelestia.services
import caelestia.config

StyledText {
    property real fill
    property int grade: Colours.light ? 0 : -25
    // Multiply base icon point size (e.g. set to Config.barThicknessScale in the bar).
    property real pointSizeScale: 1

    font.family: Appearance.font.family.material
    font.pointSize: Appearance.font.size.larger * pointSizeScale
    font.variableAxes: ({
            FILL: fill.toFixed(1),
            GRAD: grade,
            opsz: fontInfo.pixelSize,
            wght: fontInfo.weight
        })
}
