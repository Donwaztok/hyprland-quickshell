pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

/**
 * Dropdown list anchored under `anchor`: optional search field, scrollable list, max height.
 * `rows` is `[{ text: string, value: string }, ...]`.
 */
QQC2.Popup {
    id: popup

    required property Item anchor
    /** Full list of options (filtered by search when visible). */
    property var rows: []
    /** Show search when true and list is long enough to need it. */
    property bool showSearch: true
    /** Minimum rows before search field appears (when showSearch is true). */
    property int searchThreshold: 8
    readonly property int maxListHeight: 280
    property int minimumPopupWidth: 200

    signal valueChosen(string value)

    parent: anchor
    modal: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    x: 0
    y: anchor.height + 4
    width: Math.max(anchor.width, minimumPopupWidth)
    padding: Appearance.padding.smaller

    background: StyledRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: ControlCenterChrome.settingsGroupCard
        border.width: 1
        border.color: ControlCenterChrome.settingsGroupCardBorder
    }

    function filteredRows() {
        const q = searchField.text.trim().toLowerCase();
        const src = popup.rows;
        if (!q.length)
            return src;
        const out = [];
        for (let i = 0; i < src.length; i++) {
            const r = src[i];
            const t = r.text;
            if (t.toLowerCase().indexOf(q) >= 0)
                out.push(r);
        }
        return out;
    }

    onOpened: {
        searchField.text = "";
        listView.model = filteredRows();

        if (searchField.visible) {
            Qt.callLater(() => {
                searchField.forceActiveFocus();
                searchField.selectAll();
            });
        }
    }

    contentItem: ColumnLayout {
        id: col
        spacing: Appearance.spacing.smaller
        width: popup.availableWidth

        StyledTextField {
            id: searchField

            visible: popup.showSearch && popup.rows.length >= popup.searchThreshold
            Layout.fillWidth: true
            placeholderText: qsTr("Search…")

            onTextChanged: {
                listView.model = popup.filteredRows();
            }
        }

        // Fixed list height so Popup implicit size matches painted background (no overflow bleed).
        Item {
            id: listClip

            Layout.fillWidth: true
            Layout.preferredHeight: popup.maxListHeight

            ListView {
                id: listView

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0

                model: []

                delegate: StyledRect {
                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.small
                    color: ma.containsMouse ? Qt.alpha(Colours.palette.m3onSurface, 0.06) : "transparent"

                    RowLayout {
                        id: row

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.text
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: ma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popup.valueChosen(modelData.value);
                            popup.close();
                        }
                    }
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: listView
                }
            }
        }
    }
}
