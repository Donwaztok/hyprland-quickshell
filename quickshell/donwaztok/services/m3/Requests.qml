pragma Singleton

import QtQuick

QtObject {
    readonly property string userAgent: "DonwaztokShell/1.0 (Quickshell; weather)"

    /// GET request. On HTTP 200, invokes callback(responseText). On failure, invokes errorCallback if provided.
    function get(url, callback, errorCallback): void {
        if (typeof callback !== "function")
            return;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    Qt.callLater(callback, xhr.responseText);
                } catch (e) {
                    console.warn("[Requests] callback error:", url, e);
                    if (typeof errorCallback === "function")
                        Qt.callLater(errorCallback);
                }
            } else {
                console.warn("[Requests] GET failed:", url, "HTTP", xhr.status);
                if (typeof errorCallback === "function")
                    Qt.callLater(errorCallback);
                else
                    Qt.callLater(callback, "{}");
            }
        };
        try {
            xhr.setRequestHeader("User-Agent", userAgent);
        } catch (e) {
            // Some Qt builds disallow overriding User-Agent
        }
        try {
            xhr.send();
        } catch (e) {
            console.warn("[Requests] GET send error:", url, e);
            if (typeof errorCallback === "function")
                Qt.callLater(errorCallback);
            else
                Qt.callLater(callback, "{}");
        }
    }
}
