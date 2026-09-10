pragma Singleton

import QtQuick
import qs.modules.utilities.toasts

QtObject {
    id: root

    property list<var> toasts: []

    function toast(title, message, icon, type, timeout) {
        const t = type === undefined || type === null ? Toast.Info : type;
        let ms = timeout === undefined || timeout === null ? 0 : timeout;
        if (!ms || ms <= 0) {
            if (t === Toast.Warning)
                ms = 7000;
            else if (t === Toast.Error)
                ms = 10000;
            else
                ms = 5000;
        }

        let ic = icon || "";
        if (!ic) {
            if (t === Toast.Success)
                ic = "check_circle_unread";
            else if (t === Toast.Warning)
                ic = "warning";
            else if (t === Toast.Error)
                ic = "error";
            else
                ic = "info";
        }

        const obj = toastComponent.createObject(root, {
            title: title || "",
            message: message || "",
            icon: ic,
            type: t,
            timeout: ms
        });
        if (!obj) {
            console.warn("Toaster: failed to create toast");
            return;
        }

        obj.finishedClose.connect(() => {
            const next = [];
            for (let i = 0; i < root.toasts.length; i++) {
                if (root.toasts[i] !== obj)
                    next.push(root.toasts[i]);
            }
            root.toasts = next;
            obj.destroy();
        });

        const prev = [];
        for (let i = 0; i < root.toasts.length; i++)
            prev.push(root.toasts[i]);
        root.toasts = [obj].concat(prev);
    }

    property Component toastComponent: Component {
        Toast {}
    }
}
