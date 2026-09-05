import QtQuick
import QtQuick.Layouts
import Quickshell

import './theme'

RowLayout {
    id: clockItem

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Text {
        id: clockText
        property bool showDate: false
        text: Qt.formatDateTime(clock.date, showDate ? "dddd - hh:mm - dd.MM.yyyy" : "hh:mm")
        color: Theme.foreground
        font { family: Theme.fontFamily; pixelSize: 14 }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    calendarPopup.visible = !calendarPopup.visible;
                } else {
                    clockText.showDate = !clockText.showDate;
                }
            }
        }
    }

    // Month calendar — right-click the clock. Custom-built: Qt has no calendar
    // widget in Qt6 (Qt Labs Calendar was dropped), so this is a plain Grid
    // with Date math. Weeks start Monday, today is highlighted with the accent,
    // adjacent-month days are shown dimmed.
    PopupBase {
        id: calendarPopup
        anchorItem: clockItem
        minWidth: 280

        property date viewMonth: firstOfMonth(new Date())

        function firstOfMonth(d) {
            return new Date(d.getFullYear(), d.getMonth(), 1);
        }

        // Some locales have no standalone month names → fallback to format
        function monthName(d) {
            const name = Qt.locale().standaloneMonthName(d.getMonth() + 1);
            return name && name.length > 0 ? name : Qt.formatDate(d, "MMMM");
        }

        onVisibleChanged: if (visible) viewMonth = firstOfMonth(new Date())

        ColumnLayout {
            spacing: 8

            // ── Header: < Month Year > ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    id: prevButton
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: prevHover.hovered ? Theme.hoverOverlay : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "<"
                        color: prevHover.hovered ? Theme.foreground : Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                    }

                    HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: calendarPopup.viewMonth =
                            new Date(calendarPopup.viewMonth.getFullYear(),
                                     calendarPopup.viewMonth.getMonth() - 1, 1)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: calendarPopup.monthName(calendarPopup.viewMonth)
                          + " " + calendarPopup.viewMonth.getFullYear()
                    color: Theme.mainAccent
                    font { family: Theme.fontFamily; pixelSize: 14; bold: true }
                }

                Rectangle {
                    id: nextButton
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 6
                    color: nextHover.hovered ? Theme.hoverOverlay : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ">"
                        color: nextHover.hovered ? Theme.foreground : Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                    }

                    HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: calendarPopup.viewMonth =
                            new Date(calendarPopup.viewMonth.getFullYear(),
                                     calendarPopup.viewMonth.getMonth() + 1, 1)
                    }
                }
            }

            // ── Weekday header (Monday-first, locale-aware) ──
            Grid {
                columns: 7
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: 7
                    Text {
                        required property int index
                        text: Qt.locale().dayName(index + 1, Locale.ShortFormat).slice(0, 2)
                        color: Theme.dimForeground
                        font { family: Theme.fontFamily; pixelSize: 11 }
                        horizontalAlignment: Text.AlignHCenter
                        width: 36
                    }
                }
            }

            // ── Day grid: 6 weeks, adjacent-month days dimmed ──
            Grid {
                columns: 7
                Layout.alignment: Qt.AlignHCenter

                readonly property int daysInMonth:
                    new Date(calendarPopup.viewMonth.getFullYear(),
                             calendarPopup.viewMonth.getMonth() + 1, 0).getDate()

                readonly property int firstWeekday:
                    (calendarPopup.viewMonth.getDay() + 6) % 7  // Monday = 0

                Repeater {
                    model: 42

                    Item {
                        id: dayCell

                        required property int index

                        readonly property int dayNumber: index - (parent as Grid).firstWeekday + 1
                        readonly property bool inMonth:
                            dayNumber >= 1 && dayNumber <= (parent as Grid).daysInMonth
                        readonly property date cellDate:
                            new Date(calendarPopup.viewMonth.getFullYear(),
                                     calendarPopup.viewMonth.getMonth(), dayNumber)
                        readonly property bool isToday: {
                            const now = new Date();
                            return cellDate.getFullYear() === now.getFullYear()
                                && cellDate.getMonth() === now.getMonth()
                                && cellDate.getDate() === now.getDate();
                        }

                        width: 36
                        height: 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 22
                            radius: 5
                            visible: dayCell.isToday
                            color: Theme.mainAccentSubtle
                            border.width: 1
                            border.color: Theme.mainAccent
                        }

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.cellDate.getDate()
                            color: !dayCell.inMonth ? Theme.overlay
                                : dayCell.isToday ? Theme.mainAccent : Theme.foreground
                            font {
                                family: Theme.fontFamily
                                pixelSize: 12
                                bold: dayCell.isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
