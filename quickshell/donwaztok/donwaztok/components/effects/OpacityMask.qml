import Quickshell
import QtQuick

ShaderEffect {
    required property Item source
    required property Item maskSource

    fragmentShader: Qt.resolvedUrl(`${Quickshell.shellDir}/donwaztok/assets/shaders/opacitymask.frag.qsb`)
}
