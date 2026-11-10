pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services.shell
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Quickshell.Widgets

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

    // Room on the chosen side, set before opening; the list shrinks to fit it.
    property bool openAbove: false
    property real room: maxListHeight
    readonly property bool searchShown: showSearch && rows.length >= searchThreshold
    readonly property real chromeHeight: topPadding + bottomPadding
        + (searchShown ? searchField.implicitHeight + Appearance.spacing.smaller : 0)

    parent: anchor
    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    x: 0
    y: openAbove ? -height - 4 : anchor.height + 4
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

    onAboutToShow: {
        const top = anchor.mapToItem(null, 0, 0).y;
        const below = anchor.Window.height - top - anchor.height - 8;
        const above = top - 8;
        openAbove = below < maxListHeight + chromeHeight && above > below;
        room = openAbove ? above : below;
    }

    function navKey(event) {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            const step = event.key === Qt.Key_Down ? 1 : -1;
            listView.currentIndex = Math.max(0, Math.min(listView.count - 1, listView.currentIndex + step));
            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
            event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && listView.currentItem) {
            popup.valueChosen(listView.currentItem.modelData.value);
            popup.close();
            event.accepted = true;
        }
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
        focus: true

        Keys.onPressed: event => popup.navKey(event)

        StyledTextField {
            id: searchField

            visible: popup.searchShown
            Layout.fillWidth: true
            placeholderText: qsTr("Search…")

            // Typing stays in the field; Up/Down/Enter drive the list.
            Keys.onPressed: event => popup.navKey(event)

            onTextChanged: {
                listView.model = popup.filteredRows();
            }
        }

        // Fixed list height so Popup implicit size matches painted background (no overflow bleed).
        Item {
            id: listClip

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(80, Math.min(popup.maxListHeight, popup.room - popup.chromeHeight))

            ListView {
                id: listView

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0

                model: []
                onModelChanged: currentIndex = 0

                delegate: StyledRect {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
                    radius: Appearance.rounding.small
                    color: ListView.isCurrentItem ? Qt.alpha(Colours.palette.m3onSurface, 0.06) : "transparent"

                    RowLayout {
                        id: row

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        IconImage {
                            readonly property string iconSource: modelData && modelData.icon ? String(modelData.icon) : ""

                            visible: iconSource.length > 0
                            source: iconSource
                            implicitSize: 20
                            Layout.preferredWidth: visible ? 20 : 0
                            Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignVCenter
                        }

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
                        // Not containsMouse: keyboard scrolling under a resting pointer must not move the row
                        onPositionChanged: listView.currentIndex = index
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
