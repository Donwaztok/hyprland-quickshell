pragma ComponentBehavior: Bound

import qs.components
import qs.config
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    readonly property int spacing: Appearance.spacing.small
    property bool flag

    implicitWidth: {
        let w = 0;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i) as ToastWrapper;
            if (item && !item.modelData.closed && !item.previewHidden)
                w = Math.max(w, item.implicitWidth);
        }
        return w;
    }

    implicitHeight: {
        let h = 0;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i) as ToastWrapper;
            if (item && !item.modelData.closed && !item.previewHidden)
                h += item.implicitHeight + root.spacing;
        }
        return h > 0 ? h - root.spacing : 0;
    }

    Repeater {
        id: repeater

        model: ScriptModel {
            values: {
                const toasts = [];
                let count = 0;
                for (const toast of Toaster.toasts) {
                    toasts.push(toast);
                    if (!toast.closed) {
                        count++;
                        if (count > Config.utilities.maxToasts)
                            break;
                    }
                }
                return toasts;
            }
            onValuesChanged: root.flagChanged()
        }

        ToastWrapper {}
    }

    component ToastWrapper: MouseArea {
        id: toast

        required property int index
        required property Toast modelData

        readonly property bool previewHidden: {
            let extraHidden = 0;
            for (let i = 0; i < index; i++)
                if (Toaster.toasts[i].closed)
                    extraHidden++;
            return index >= Config.utilities.maxToasts + extraHidden;
        }

        onPreviewHiddenChanged: {
            if (initAnim.running && previewHidden)
                initAnim.stop();
        }

        opacity: modelData.closed || previewHidden ? 0 : 1
        scale: modelData.closed || previewHidden ? 0.7 : 1

        anchors.topMargin: {
            root.flag; // Force update
            let y = 0;
            for (let i = 0; i < index; i++) {
                const item = repeater.itemAt(i) as ToastWrapper;
                if (item && !item.modelData.closed && !item.previewHidden)
                    y += item.implicitHeight + root.spacing;
            }
            return y;
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        implicitWidth: toastInner.implicitWidth
        implicitHeight: toastInner.implicitHeight

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: modelData.close()

        Component.onCompleted: modelData.lock(this)

        Anim {
            id: initAnim

            Component.onCompleted: running = !toast.previewHidden

            target: toast
            properties: "opacity,scale"
            from: 0
            to: 1
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }

        ParallelAnimation {
            running: toast.modelData.closed
            onStarted: toast.anchors.topMargin = toast.anchors.topMargin
            onFinished: toast.modelData.unlock(toast)

            Anim {
                target: toast
                property: "opacity"
                to: 0
            }
            Anim {
                target: toast
                property: "scale"
                to: 0.7
            }
        }

        ToastItem {
            id: toastInner

            modelData: toast.modelData
        }

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on anchors.topMargin {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }
}
