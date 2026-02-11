import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Compact iNiR shell update indicator for the bar.
 * Shows when a new version is available in the git repo.
 * Redesigned with better visual hierarchy and animated feedback.
 */
MouseArea {
    id: root

    visible: ShellUpdates.showUpdate
    implicitWidth: visible ? pill.width : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    readonly property color accentColor: Appearance.inirEverywhere ? (Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    readonly property color textColor: {
        if (Appearance.inirEverywhere) return Appearance.inir?.colText ?? Appearance.colors.colOnLayer1
        if (Appearance.auroraEverywhere) return Appearance.aurora?.colText ?? Appearance.colors.colOnLayer1
        return Appearance.colors.colOnLayer1
    }

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            ShellUpdates.dismiss()
        } else {
            ShellUpdates.performUpdate()
        }
    }

    // Background pill
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 16
        height: contentRow.implicitHeight + 8
        radius: height / 2
        scale: root.pressed ? 0.93 : (root.containsMouse ? 1.03 : 1.0)
        color: {
            if (root.pressed) {
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer2Active
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurfaceActive
                return Appearance.colors.colLayer1Active
            }
            if (root.containsMouse) {
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurface
                return Appearance.colors.colLayer1Hover
            }
            if (Appearance.inirEverywhere) return ColorUtils.transparentize(Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary, 0.85)
            return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.88)
        }

        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: pill
        spacing: 5

        MaterialSymbol {
            id: updateIcon
            text: "upgrade"
            iconSize: Appearance.font.pixelSize.normal
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter

            // Gentle pulse when hovered
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.containsMouse
                NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            text: ShellUpdates.commitsBehind > 0
                ? ShellUpdates.commitsBehind.toString()
                : "!"
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Hover popup
    StyledPopup {
        id: updatePopup
        hoverTarget: root

        ColumnLayout {
            spacing: 8

            // Header row with icon and title
            RowLayout {
                spacing: 8
                Layout.fillWidth: true

                Rectangle {
                    width: 36
                    height: 36
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.85)

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "upgrade"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.m3colors.m3primary
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    StyledText {
                        text: Translation.tr("iNiR Update")
                        font {
                            weight: Font.DemiBold
                            pixelSize: Appearance.font.pixelSize.normal
                        }
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: ShellUpdates.commitsBehind > 0
                            ? Translation.tr("%1 commit(s) behind").arg(ShellUpdates.commitsBehind)
                            : Translation.tr("Update available")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: ShellUpdates.commitsBehind > 10
                            ? Appearance.m3colors.m3error
                            : Appearance.colors.colSubtext
                    }
                }
            }

            // Version comparison card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: versionCol.implicitHeight + 16
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                ColumnLayout {
                    id: versionCol
                    anchors {
                        fill: parent
                        margins: 8
                    }
                    spacing: 6

                    // Current → Available
                    RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        Rectangle {
                            width: currentLabel.implicitWidth + 12
                            height: currentLabel.implicitHeight + 4
                            radius: height / 2
                            color: Appearance.colors.colSurfaceContainerLow

                            StyledText {
                                id: currentLabel
                                anchors.centerIn: parent
                                text: ShellUpdates.localCommit || "—"
                                font {
                                    pixelSize: Appearance.font.pixelSize.smallest
                                    family: Appearance.font.family.monospace
                                    weight: Font.Medium
                                }
                                color: Appearance.colors.colSubtext
                            }
                        }

                        MaterialSymbol {
                            text: "arrow_forward"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3primary
                            visible: ShellUpdates.remoteCommit.length > 0
                        }

                        Rectangle {
                            visible: ShellUpdates.remoteCommit.length > 0
                            width: remoteLabel.implicitWidth + 12
                            height: remoteLabel.implicitHeight + 4
                            radius: height / 2
                            color: ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.85)

                            StyledText {
                                id: remoteLabel
                                anchors.centerIn: parent
                                text: ShellUpdates.remoteCommit || "—"
                                font {
                                    pixelSize: Appearance.font.pixelSize.smallest
                                    family: Appearance.font.family.monospace
                                    weight: Font.DemiBold
                                }
                                color: Appearance.m3colors.m3primary
                            }
                        }
                    }

                    // Branch
                    RowLayout {
                        visible: ShellUpdates.currentBranch.length > 0
                        spacing: 4

                        MaterialSymbol {
                            text: "account_tree"
                            iconSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: ShellUpdates.currentBranch
                            font {
                                pixelSize: Appearance.font.pixelSize.smallest
                                family: Appearance.font.family.monospace
                            }
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // Latest commit message
                    RowLayout {
                        visible: ShellUpdates.latestMessage.length > 0
                        spacing: 4
                        Layout.fillWidth: true
                        Layout.maximumWidth: 280

                        MaterialSymbol {
                            text: "notes"
                            iconSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: ShellUpdates.latestMessage
                            font {
                                pixelSize: Appearance.font.pixelSize.smallest
                                family: Appearance.font.family.monospace
                            }
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                    }
                }
            }

            // Error display
            RowLayout {
                spacing: 4
                visible: ShellUpdates.lastError.length > 0
                Layout.fillWidth: true
                Layout.maximumWidth: 280

                MaterialSymbol {
                    text: "error"
                    color: Appearance.m3colors.m3error
                    iconSize: Appearance.font.pixelSize.smaller
                }
                StyledText {
                    Layout.fillWidth: true
                    text: ShellUpdates.lastError
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.m3colors.m3error
                    wrapMode: Text.WordWrap
                }
            }

            // Hint
            StyledText {
                text: Translation.tr("Click to update · Right-click to dismiss")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                opacity: 0.7
            }
        }
    }
}
