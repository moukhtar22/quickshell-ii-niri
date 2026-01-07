pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services

/**
 * YT Music panel - Full-featured YouTube music player.
 * Features: Search, Playlists, Queue, Google Account sync, MPRIS integration.
 */
Item {
    id: root

    readonly property bool isAvailable: YtMusic.available
    readonly property bool hasResults: YtMusic.searchResults.length > 0
    readonly property bool hasQueue: YtMusic.queue.length > 0
    readonly property bool isPlaying: YtMusic.isPlaying
    readonly property bool hasTrack: YtMusic.currentVideoId !== ""

    // Current view: "search" | "playlists" | "queue" | "account"
    property string currentView: "search"

    function openCreatePlaylist() { createPlaylistDialog.open() }
    function openAddToPlaylist(item) { 
        globalAddToPlaylistPopup.targetItem = item
        globalAddToPlaylistPopup.open() 
    }

    // Adaptive colors from thumbnail
    ColorQuantizer {
        id: colorQuantizer
        source: YtMusic.currentThumbnail
        depth: 0
        rescaleSize: 1
    }

    property color artColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artColor }

    // Quad-Style theming
    readonly property color colText: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colSurface: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                      : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer1
    readonly property color colSurfaceHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                                           : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                           : Appearance.colors.colLayer1Hover
    readonly property color colLayer2: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                     : Appearance.colors.colLayer2
    readonly property color colLayer2Hover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                                          : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                          : Appearance.colors.colLayer2Hover
    readonly property color colBorder: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    readonly property int borderWidth: Appearance.inirEverywhere ? 1 : 0
    readonly property real radiusSmall: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    readonly property real radiusNormal: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Audio visualizer
    property list<real> visualizerPoints: []
    
    Process {
        id: cavaProc
        running: root.visible && root.isPlaying && GlobalStates.sidebarLeftOpen
        onRunningChanged: { if (!running) root.visualizerPoints = [] }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.visualizerPoints = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // === UNAVAILABLE STATE ===
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: !root.isAvailable
            visible: active
            sourceComponent: ColumnLayout {
                spacing: 16
                Item { Layout.fillHeight: true }
                MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "music_off"; iconSize: 56; color: root.colTextSecondary }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Translation.tr("yt-dlp not found"); font.pixelSize: Appearance.font.pixelSize.larger; font.weight: Font.Medium; color: root.colText }
                StyledText { Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true; Layout.margins: 20; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: Translation.tr("Install yt-dlp and mpv to use YT Music"); font.pixelSize: Appearance.font.pixelSize.small; color: root.colTextSecondary }
                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 160; implicitHeight: 42
                    buttonRadius: root.radiusNormal
                    colBackground: root.colPrimary
                    onClicked: Qt.openUrlExternally("https://github.com/yt-dlp/yt-dlp#installation")
                    contentItem: StyledText { anchors.centerIn: parent; text: Translation.tr("Install Guide"); color: Appearance.colors.colOnPrimary; font.weight: Font.Medium }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // === MAIN CONTENT ===
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.isAvailable
            visible: active
            
            sourceComponent: ColumnLayout {
                spacing: 8

                // Tab bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "search", icon: "search", label: Translation.tr("Search") },
                            { id: "playlists", icon: "library_music", label: Translation.tr("Playlists") },
                            { id: "queue", icon: "queue_music", label: Translation.tr("Queue") + (root.hasQueue ? ` (${YtMusic.queue.length})` : "") },
                            { id: "account", icon: YtMusic.googleConnected ? "account_circle" : "person_off", label: Translation.tr("Account") }
                        ]

                        RippleButton {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 36
                            buttonRadius: root.radiusSmall
                            colBackground: root.currentView === modelData.id ? root.colPrimary : "transparent"
                            colBackgroundHover: root.currentView === modelData.id ? root.colPrimary : root.colLayer2Hover
                            onClicked: root.currentView = modelData.id

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 18
                                    color: root.currentView === modelData.id 
                                         ? Appearance.colors.colOnPrimary 
                                         : root.colTextSecondary
                                }
                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: root.currentView === modelData.id ? Font.Medium : Font.Normal
                                    color: root.currentView === modelData.id 
                                         ? Appearance.colors.colOnPrimary 
                                         : root.colText
                                    visible: parent.width > 60
                                }
                            }
                        }
                    }
                }

                // === NOW PLAYING CARD ===
                Loader {
                    Layout.fillWidth: true
                    active: root.hasTrack
                    visible: active
                    
                    sourceComponent: Item {
                        implicitHeight: playerCard.implicitHeight + 8

                        StyledRectangularShadow { target: playerCard; visible: !Appearance.auroraEverywhere && !Appearance.inirEverywhere }

                        Rectangle {
                            id: playerCard
                            anchors.centerIn: parent
                            width: parent.width - 4
                            implicitHeight: 120
                            radius: root.radiusNormal
                            color: Appearance.inirEverywhere ? Appearance.inir.colLayer1 
                                 : Appearance.auroraEverywhere ? ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
                                 : (root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
                            border.width: root.borderWidth
                            border.color: root.colBorder
                            clip: true

                            layer.enabled: true
                            layer.effect: GE.OpacityMask { maskSource: Rectangle { width: playerCard.width; height: playerCard.height; radius: playerCard.radius } }

                            // Blurred background
                            Image {
                                anchors.fill: parent
                                source: YtMusic.currentThumbnail
                                fillMode: Image.PreserveAspectCrop
                                opacity: Appearance.inirEverywhere ? 0 : Appearance.auroraEverywhere ? 0.25 : 0.4
                                visible: opacity > 0
                                layer.enabled: Appearance.effectsEnabled
                                layer.effect: MultiEffect { blurEnabled: true; blur: 0.2; blurMax: 24; saturation: 0.3 }
                            }

                            // Visualizer
                            WaveVisualizer {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: 25
                                live: YtMusic.isPlaying
                                points: root.visualizerPoints
                                maxVisualizerValue: 1000
                                smoothing: 2
                                color: ColorUtils.transparentize(root.colPrimary, 0.5)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                // Cover art
                                Rectangle {
                                    Layout.preferredWidth: 100
                                    Layout.preferredHeight: 100
                                    radius: root.radiusSmall
                                    color: "transparent"
                                    clip: true
                                    layer.enabled: true
                                    layer.effect: GE.OpacityMask { maskSource: Rectangle { width: 100; height: 100; radius: root.radiusSmall } }

                                    Image {
                                        anchors.fill: parent
                                        source: YtMusic.currentThumbnail
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#40000000"
                                        visible: YtMusic.isPlaying
                                        MaterialSymbol { anchors.centerIn: parent; text: "graphic_eq"; iconSize: 32; fill: 1; color: "white" }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1
                                        visible: !YtMusic.currentThumbnail
                                        MaterialSymbol { 
                                            anchors.centerIn: parent
                                            text: YtMusic.loading ? "hourglass_empty" : "music_note"
                                            iconSize: 32
                                            color: root.colTextSecondary
                                            RotationAnimation on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: YtMusic.loading }
                                        }
                                    }
                                }

                                // Info & controls
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: YtMusic.currentTitle || Translation.tr("Loading...")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.Medium
                                        color: root.colText
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: YtMusic.currentArtist
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.colTextSecondary
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }

                                    Item { Layout.fillHeight: true }

                                    // Progress bar (clickable for seek)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        StyledText {
                                            text: StringUtils.friendlyTimeForSeconds(YtMusic.currentPosition)
                                            font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                                            font.family: Appearance.font.family.numbers
                                            color: root.colTextSecondary
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 16
                                            
                                            StyledSlider {
                                                id: seekSlider
                                                anchors.fill: parent
                                                configuration: StyledSlider.Configuration.XS
                                                from: 0
                                                to: YtMusic.currentDuration > 0 ? YtMusic.currentDuration : 1
                                                value: YtMusic.currentPosition
                                                highlightColor: root.colPrimary
                                                trackColor: ColorUtils.transparentize(root.colTextSecondary, 0.7)
                                                handleColor: root.colPrimary
                                                scrollable: false
                                                
                                                property bool userSeeking: false
                                                
                                                onPressedChanged: {
                                                    if (pressed) userSeeking = true
                                                    else {
                                                        YtMusic.seek(value)
                                                        userSeeking = false
                                                    }
                                                }
                                                
                                                Binding {
                                                    target: seekSlider
                                                    property: "value"
                                                    value: YtMusic.currentPosition
                                                    when: !seekSlider.userSeeking
                                                }
                                            }
                                        }

                                        StyledText {
                                            text: StringUtils.friendlyTimeForSeconds(YtMusic.currentDuration)
                                            font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                                            font.family: Appearance.font.family.numbers
                                            color: root.colTextSecondary
                                        }
                                    }

                                    // Controls
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Item { Layout.fillWidth: true }

                                        // Previous / Skip back (disabled for YT)
                                        RippleButton {
                                            implicitWidth: 36; implicitHeight: 36
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: root.colSurfaceHover
                                            enabled: false
                                            opacity: 0.3
                                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; iconSize: 24; fill: 1; color: root.colText }
                                        }

                                        // Play/Pause
                                        RippleButton {
                                            implicitWidth: 44; implicitHeight: 44
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: root.colPrimary
                                            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimaryHover
                                            onClicked: YtMusic.togglePlaying()

                                            contentItem: MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: YtMusic.isPlaying ? "pause" : "play_arrow"
                                                iconSize: 28
                                                fill: 1
                                                color: Appearance.colors.colOnPrimary
                                            }
                                        }

                                        // Next in queue
                                        RippleButton {
                                            implicitWidth: 36; implicitHeight: 36
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: root.colSurfaceHover
                                            enabled: root.hasQueue
                                            opacity: enabled ? 1 : 0.3
                                            onClicked: YtMusic.playNext()
                                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: 24; fill: 1; color: root.colText }
                                            StyledToolTip { text: Translation.tr("Next in queue") }
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Stop
                                        RippleButton {
                                            implicitWidth: 32; implicitHeight: 32
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: root.colSurfaceHover
                                            onClicked: YtMusic.stop()
                                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "stop"; iconSize: 20; fill: 1; color: root.colTextSecondary }
                                            StyledToolTip { text: Translation.tr("Stop") }
                                        }
                                        
                                        // Volume
                                        RippleButton {
                                            id: volumeBtn
                                            implicitWidth: 32; implicitHeight: 32
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: root.colSurfaceHover
                                            onClicked: volumePopup.open()
                                            contentItem: MaterialSymbol { 
                                                anchors.centerIn: parent
                                                text: YtMusic.volume < 0.01 ? "volume_off" 
                                                    : YtMusic.volume < 0.5 ? "volume_down" 
                                                    : "volume_up"
                                                iconSize: 20
                                                fill: 1
                                                color: root.colTextSecondary 
                                            }
                                            
                                            Popup {
                                                id: volumePopup
                                                y: -height - 8
                                                x: (parent.width - width) / 2
                                                width: 40
                                                height: 120
                                                padding: 8
                                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                                
                                                background: Rectangle {
                                                    color: root.colLayer2
                                                    radius: root.radiusSmall
                                                    border.width: root.borderWidth
                                                    border.color: root.colBorder
                                                }
                                                
                                                contentItem: ColumnLayout {
                                                    spacing: 4
                                                    
                                                    StyledText {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: Math.round(YtMusic.volume * 100)
                                                        font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                                                        font.family: Appearance.font.family.numbers
                                                        color: root.colText
                                                    }
                                                    
                                                    StyledSlider {
                                                        Layout.fillHeight: true
                                                        Layout.preferredWidth: 24
                                                        Layout.alignment: Qt.AlignHCenter
                                                        orientation: Qt.Vertical
                                                        configuration: StyledSlider.Configuration.S
                                                        from: 0
                                                        to: 1
                                                        value: YtMusic.volume
                                                        highlightColor: root.colPrimary
                                                        trackColor: ColorUtils.transparentize(root.colTextSecondary, 0.7)
                                                        handleColor: root.colPrimary
                                                        onMoved: YtMusic.setVolume(value)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Add to playlist
                                        RippleButton {
                                            implicitWidth: 32; implicitHeight: 32
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: root.colSurfaceHover
                                            enabled: true
                                            onClicked: {
                                                globalAddToPlaylistPopup.targetItem = {
                                                    videoId: YtMusic.currentVideoId,
                                                    title: YtMusic.currentTitle,
                                                    artist: YtMusic.currentArtist,
                                                    duration: YtMusic.currentDuration
                                                }
                                                globalAddToPlaylistPopup.open()
                                            }
                                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "playlist_add"; iconSize: 20; fill: 1; color: root.colTextSecondary }
                                            StyledToolTip { text: Translation.tr("Add to playlist") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Error message
                Loader {
                    Layout.fillWidth: true
                    active: YtMusic.error !== ""
                    visible: active
                    sourceComponent: Rectangle {
                        implicitHeight: 36
                        radius: root.radiusSmall
                        color: Appearance.colors.colErrorContainer
                        RowLayout {
                            anchors.centerIn: parent; width: parent.width - 16; spacing: 8
                            MaterialSymbol { text: "error"; iconSize: 18; color: Appearance.colors.colOnErrorContainer }
                            StyledText { Layout.fillWidth: true; text: YtMusic.error; color: Appearance.colors.colOnErrorContainer; font.pixelSize: Appearance.font.pixelSize.small; elide: Text.ElideRight }
                            RippleButton { implicitWidth: 24; implicitHeight: 24; buttonRadius: 12; colBackground: "transparent"; onClicked: YtMusic.error = ""; contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 16; color: Appearance.colors.colOnErrorContainer } }
                        }
                    }
                }

                // === VIEW CONTENT ===
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: ["search", "playlists", "queue", "account"].indexOf(root.currentView)

                    // SEARCH VIEW
                    SearchView {}

                    // PLAYLISTS VIEW
                    PlaylistsView {}

                    // QUEUE VIEW
                    QueueView {}

                    // ACCOUNT VIEW
                    AccountView {}
                }
            }
        }
    }

    // === GLOBAL DIALOGS ===

    Popup {
        id: createPlaylistDialog
        anchors.centerIn: parent
        width: 280
        height: 120
        modal: true
        dim: true
        
        background: Rectangle { 
            color: root.colSurface
            radius: root.radiusNormal
            border.width: root.borderWidth
            border.color: root.colBorder 
        }
        
        contentItem: ColumnLayout {
            spacing: 12
            
            StyledText { 
                text: Translation.tr("New Playlist")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText 
            }
            
            TextField { 
                id: newPlaylistName
                Layout.fillWidth: true
                placeholderText: Translation.tr("Playlist name")
                color: root.colText
                placeholderTextColor: root.colTextSecondary
                background: Rectangle { 
                    color: root.colLayer2
                    radius: root.radiusSmall 
                } 
                onAccepted: createBtn.clicked()
            }
            
            RowLayout { 
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                
                RippleButton { 
                    id: createBtn
                    implicitWidth: 80
                    implicitHeight: 32
                    buttonRadius: root.radiusSmall
                    colBackground: root.colPrimary
                    onClicked: { 
                        if (newPlaylistName.text.trim()) { 
                            YtMusic.createPlaylist(newPlaylistName.text)
                            newPlaylistName.text = ""
                            createPlaylistDialog.close() 
                        } 
                    }
                    
                    contentItem: StyledText { 
                        anchors.centerIn: parent
                        text: Translation.tr("Create")
                        color: Appearance.colors.colOnPrimary 
                    } 
                } 
            }
        }
    }

    Popup {
        id: globalAddToPlaylistPopup
        anchors.centerIn: parent
        width: 220
        height: Math.min(300, Math.max(100, YtMusic.playlists.length * 40 + 50))
        padding: 12
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        property var targetItem: null

        background: Rectangle {
            color: root.colSurface
            radius: root.radiusNormal
            border.width: root.borderWidth
            border.color: root.colBorder
        }
        
        contentItem: ColumnLayout {
            spacing: 8
            
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Add to Playlist")
                font.weight: Font.Medium
                color: root.colText
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: YtMusic.playlists
                spacing: 2
                delegate: RippleButton {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 36
                    buttonRadius: root.radiusSmall
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: {
                        if (globalAddToPlaylistPopup.targetItem) {
                            YtMusic.addToPlaylist(index, globalAddToPlaylistPopup.targetItem)
                            globalAddToPlaylistPopup.close()
                        }
                    }
                    contentItem: StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.name ?? ""
                        color: root.colText
                        elide: Text.ElideRight
                    }
                }
            }
            
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 32
                buttonRadius: root.radiusSmall
                colBackground: root.colLayer2
                colBackgroundHover: root.colLayer2Hover
                onClicked: {
                    globalAddToPlaylistPopup.close()
                    createPlaylistDialog.open()
                }
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { text: "add"; iconSize: 18; color: root.colPrimary }
                    StyledText { text: Translation.tr("New Playlist"); color: root.colPrimary }
                }
            }
        }
    }

    // === SUB-COMPONENTS ===

    component SearchView: ColumnLayout {
        spacing: 8

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Appearance.inirEverywhere ? root.radiusSmall : Appearance.rounding.full
            color: root.colLayer2
            border.width: root.borderWidth
            border.color: root.colBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10
                
                MaterialSymbol { 
                    text: YtMusic.searching ? "hourglass_empty" : "search"
                    iconSize: 20
                    color: root.colTextSecondary
                    RotationAnimation on rotation { 
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: YtMusic.searching 
                    } 
                }
                
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Search YouTube Music...")
                    color: root.colText
                    placeholderTextColor: root.colTextSecondary
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    background: Item {}
                    selectByMouse: true
                    onAccepted: { if (text.trim()) YtMusic.search(text) }
                    Keys.onEscapePressed: { text = ""; focus = false }
                }
                
                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    visible: searchField.text.length > 0
                    buttonRadius: 14
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: { searchField.text = ""; searchField.forceActiveFocus() }
                    
                    contentItem: MaterialSymbol { 
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 18
                        color: root.colTextSecondary 
                    }
                }
            }
        }

        // Results / Recent / Empty
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: 12
                visible: !root.hasResults && !YtMusic.searching && YtMusic.recentSearches.length === 0
                
                MaterialSymbol { 
                    Layout.alignment: Qt.AlignHCenter
                    text: "library_music"
                    iconSize: 56
                    color: root.colTextSecondary
                    opacity: 0.5 
                }
                
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Search for music")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: root.colTextSecondary 
                }
            }

            // Recent searches
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: !root.hasResults && !YtMusic.searching && YtMusic.recentSearches.length > 0
                
                RowLayout {
                    Layout.fillWidth: true
                    StyledText { 
                        text: Translation.tr("Recent")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.colTextSecondary 
                    }
                    Item { Layout.fillWidth: true }
                    
                    RippleButton { 
                        implicitWidth: 24
                        implicitHeight: 24
                        buttonRadius: 12
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: YtMusic.clearRecentSearches()
                        
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "delete_sweep"
                            iconSize: 16
                            color: root.colTextSecondary 
                        }
                        
                        StyledToolTip { text: Translation.tr("Clear") } 
                    }
                }
                
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: YtMusic.recentSearches
                    spacing: 2
                    delegate: RippleButton {
                        required property string modelData
                        width: ListView.view.width
                        implicitHeight: 36
                        buttonRadius: root.radiusSmall
                        colBackground: "transparent"
                        colBackgroundHover: root.colSurfaceHover
                        onClicked: { searchField.text = modelData; YtMusic.search(modelData) }
                        
                        contentItem: RowLayout { 
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            
                            MaterialSymbol { 
                                text: "history"
                                iconSize: 18
                                color: root.colTextSecondary 
                            }
                            
                            StyledText { 
                                Layout.fillWidth: true
                                text: modelData
                                color: root.colText
                                elide: Text.ElideRight 
                            } 
                        }
                    }
                }
            }

            // Results
            ListView {
                anchors.fill: parent
                visible: root.hasResults || YtMusic.searching
                clip: true
                model: YtMusic.searchResults
                spacing: 4
                
                header: Loader { 
                    width: parent.width
                    active: YtMusic.searching
                    height: active ? 40 : 0
                    
                    sourceComponent: RowLayout { 
                        spacing: 8
                        Item { Layout.fillWidth: true }
                        BusyIndicator { implicitWidth: 24; implicitHeight: 24; running: true }
                        StyledText { text: Translation.tr("Searching..."); color: root.colTextSecondary }
                        Item { Layout.fillWidth: true } 
                    } 
                }
                
                delegate: ResultItem {}
            }
        }
    }

    component ResultItem: Item {
        id: resultItem
        required property var modelData
        required property int index
        
        readonly property var itemData: modelData ?? {}
        
        width: ListView.view?.width ?? 200
        implicitHeight: modelData ? 64 : 0
        visible: modelData !== null && modelData !== undefined
        
        RippleButton {
            anchors.fill: parent
            visible: resultItem.visible
            buttonRadius: root.radiusSmall
            colBackground: "transparent"
            colBackgroundHover: root.colSurfaceHover
            onClicked: if (resultItem.modelData) YtMusic.playFromSearch(resultItem.index)

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 10
                
                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: root.radiusSmall
                    color: root.colLayer2
                    clip: true
                    
                    Image { 
                        anchors.fill: parent
                        source: resultItem.itemData?.thumbnail ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true 
                    }
                    
                    MaterialSymbol { 
                        anchors.centerIn: parent
                        visible: parent.children[0].status !== Image.Ready
                        text: "music_note"
                        iconSize: 22
                        color: root.colTextSecondary 
                    }
                    
                    Rectangle { 
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        width: durText.implicitWidth + 6
                        height: 14
                        radius: 3
                        color: "#CC000000"
                        visible: !!resultItem.itemData && ((resultItem.itemData?.duration ?? 0) > 0)
                        
                        StyledText { 
                            id: durText
                            anchors.centerIn: parent
                            text: {
                                const dur = resultItem.itemData?.duration
                                return StringUtils.friendlyTimeForSeconds(dur ?? 0)
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                            font.family: Appearance.font.family.numbers
                            color: "white" 
                        } 
                    }
                }
                
                ColumnLayout { 
                    Layout.fillWidth: true
                    spacing: 2
                    
                    StyledText { 
                        Layout.fillWidth: true
                        text: resultItem.itemData?.title ?? ""
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: root.colText
                        elide: Text.ElideRight 
                    }
                    
                    StyledText { 
                        Layout.fillWidth: true
                        text: resultItem.itemData?.artist ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.colTextSecondary
                        elide: Text.ElideRight
                        visible: text !== "" 
                    } 
                }
                
                RippleButton { 
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: if (resultItem.modelData) root.openAddToPlaylist(resultItem.modelData)
                    
                    contentItem: MaterialSymbol { 
                        anchors.centerIn: parent
                        text: "playlist_add"
                        iconSize: 20
                        color: root.colTextSecondary 
                    }
                    
                    StyledToolTip { text: Translation.tr("Add to playlist") } 
                }

                RippleButton { 
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    colBackgroundHover: root.colLayer2Hover
                    onClicked: if (resultItem.modelData) YtMusic.addToQueue(resultItem.modelData)
                    
                    contentItem: MaterialSymbol { 
                        anchors.centerIn: parent
                        text: "queue_music"
                        iconSize: 20
                        color: root.colTextSecondary 
                    }
                    
                    StyledToolTip { text: Translation.tr("Add to queue") } 
                }
            }
        }
    }

    component PlaylistsView: ColumnLayout {
        spacing: 8
        
        property int expandedPlaylist: -1  // Index of expanded playlist, -1 = none

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            // Back button when viewing playlist
            RippleButton {
                visible: expandedPlaylist >= 0
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: expandedPlaylist = -1
                
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 20
                    color: root.colText 
                }
            }
            
            StyledText { 
                text: expandedPlaylist >= 0 
                    ? (YtMusic.playlists[expandedPlaylist]?.name ?? Translation.tr("Playlist"))
                    : Translation.tr("Your Playlists")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText 
            }
            
            Item { Layout.fillWidth: true }
            
            // Play all (when viewing playlist)
            RippleButton {
                visible: expandedPlaylist >= 0 && (YtMusic.playlists[expandedPlaylist]?.items?.length ?? 0) > 0
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: root.colPrimary
                onClicked: YtMusic.playPlaylist(expandedPlaylist, false)
                
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "play_arrow"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimary 
                }
                
                StyledToolTip { text: Translation.tr("Play all") }
            }
            
            // Shuffle (when viewing playlist)
            RippleButton {
                visible: expandedPlaylist >= 0 && (YtMusic.playlists[expandedPlaylist]?.items?.length ?? 0) > 1
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: YtMusic.playPlaylist(expandedPlaylist, true)
                
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "shuffle"
                    iconSize: 20
                    color: root.colTextSecondary 
                }
                
                StyledToolTip { text: Translation.tr("Shuffle") }
            }
            
            // New playlist button (when viewing list)
            RippleButton {
                visible: expandedPlaylist < 0
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: 16
                colBackground: root.colPrimary
                onClicked: root.openCreatePlaylist()
                
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "add"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimary 
                }
                
                StyledToolTip { text: Translation.tr("New playlist") }
            }
        }

        // Playlists list (when not expanded)
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: expandedPlaylist < 0
            clip: true
            model: YtMusic.playlists
            spacing: 4
            
            delegate: RippleButton {
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: 56
                buttonRadius: root.radiusSmall
                colBackground: "transparent"
                colBackgroundHover: root.colSurfaceHover
                onClicked: expandedPlaylist = index

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10
                    
                    Rectangle { 
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: root.radiusSmall
                        color: root.colLayer2
                        
                        MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "queue_music"
                            iconSize: 22
                            color: root.colPrimary 
                        } 
                    }
                    
                    ColumnLayout { 
                        Layout.fillWidth: true
                        spacing: 2
                        
                        StyledText { 
                            Layout.fillWidth: true
                            text: modelData.name ?? ""
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: root.colText
                            elide: Text.ElideRight 
                        }
                        
                        StyledText { 
                            text: Translation.tr("%1 songs").arg(modelData.items?.length ?? 0)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary 
                        } 
                    }
                    
                    MaterialSymbol { 
                        text: "chevron_right"
                        iconSize: 20
                        color: root.colTextSecondary 
                    }
                }
            }

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: YtMusic.playlists.length === 0
                spacing: 12
                
                MaterialSymbol { 
                    Layout.alignment: Qt.AlignHCenter
                    text: "playlist_add"
                    iconSize: 48
                    color: root.colTextSecondary
                    opacity: 0.5 
                }
                
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No playlists yet")
                    color: root.colTextSecondary 
                }
            }
        }
        
        // Playlist content (when expanded)
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: expandedPlaylist >= 0
            clip: true
            model: expandedPlaylist >= 0 ? (YtMusic.playlists[expandedPlaylist]?.items ?? []) : []
            spacing: 4
            
            delegate: RippleButton {
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: 56
                buttonRadius: root.radiusSmall
                colBackground: "transparent"
                colBackgroundHover: root.colSurfaceHover
                onClicked: YtMusic.play(modelData)

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8
                    
                    StyledText { 
                        text: (index + 1).toString()
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.numbers
                        color: root.colTextSecondary
                        Layout.preferredWidth: 24 
                    }
                    
                    Rectangle { 
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: root.radiusSmall
                        color: root.colLayer2
                        clip: true
                        
                        Image { 
                            anchors.fill: parent
                            source: modelData.thumbnail ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true 
                        }
                        
                        MaterialSymbol { 
                            anchors.centerIn: parent
                            visible: parent.children[0].status !== Image.Ready
                            text: "music_note"
                            iconSize: 20
                            color: root.colTextSecondary 
                        }
                    }
                    
                    ColumnLayout { 
                        Layout.fillWidth: true
                        spacing: 2
                        
                        StyledText { 
                            Layout.fillWidth: true
                            text: modelData.title ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: root.colText
                            elide: Text.ElideRight 
                        }
                        
                        StyledText { 
                            Layout.fillWidth: true
                            text: modelData.artist ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary
                            elide: Text.ElideRight
                            visible: text !== "" 
                        } 
                    }
                    
                    // Duration
                    StyledText { 
                        text: StringUtils.friendlyTimeForSeconds(modelData.duration ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                        font.family: Appearance.font.family.numbers
                        color: root.colTextSecondary
                        visible: (modelData.duration ?? 0) > 0
                    }
                    
                    // Remove from playlist
                    RippleButton { 
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: YtMusic.removeFromPlaylist(expandedPlaylist, index)
                        
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 18
                            color: root.colTextSecondary 
                        }
                        
                        StyledToolTip { text: Translation.tr("Remove") }
                    }
                }
            }
            
            // Empty playlist
            ColumnLayout {
                anchors.centerIn: parent
                visible: expandedPlaylist >= 0 && (YtMusic.playlists[expandedPlaylist]?.items?.length ?? 0) === 0
                spacing: 12
                
                MaterialSymbol { 
                    Layout.alignment: Qt.AlignHCenter
                    text: "music_off"
                    iconSize: 48
                    color: root.colTextSecondary
                    opacity: 0.5 
                }
                
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Playlist is empty")
                    color: root.colTextSecondary 
                }
                
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Search for songs and add them here")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary 
                }
            }
        }
        
        // Delete playlist button (when viewing playlist)
        RippleButton {
            Layout.fillWidth: true
            visible: expandedPlaylist >= 0
            implicitHeight: 36
            buttonRadius: root.radiusSmall
            colBackground: "transparent"
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.85)
            onClicked: {
                YtMusic.deletePlaylist(expandedPlaylist)
                expandedPlaylist = -1
            }
            
            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 8
                MaterialSymbol { text: "delete"; iconSize: 18; color: Appearance.colors.colError }
                StyledText { text: Translation.tr("Delete playlist"); color: Appearance.colors.colError }
            }
        }
    }

    component QueueView: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText { 
                text: Translation.tr("Queue")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText 
            }
            
            StyledText { 
                text: "(" + YtMusic.queue.length + ")"
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colTextSecondary
                visible: root.hasQueue 
            }
            
            Item { Layout.fillWidth: true }
            
            // Shuffle queue
            RippleButton { 
                visible: root.hasQueue && YtMusic.queue.length > 1
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: YtMusic.shuffleQueue()
                
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "shuffle"
                    iconSize: 18
                    color: root.colTextSecondary 
                }
                
                StyledToolTip { text: Translation.tr("Shuffle") } 
            }
            
            RippleButton { 
                visible: root.hasQueue
                implicitWidth: 80
                implicitHeight: 28
                buttonRadius: root.radiusSmall
                colBackground: root.colPrimary
                onClicked: YtMusic.playQueue()
                
                contentItem: StyledText { 
                    anchors.centerIn: parent
                    text: Translation.tr("Play")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimary 
                } 
            }
            
            RippleButton { 
                visible: root.hasQueue
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: root.colLayer2Hover
                onClicked: YtMusic.clearQueue()
                
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    iconSize: 18
                    color: root.colTextSecondary 
                }
                
                StyledToolTip { text: Translation.tr("Clear") } 
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: YtMusic.queue
            spacing: 4
            
            delegate: RippleButton {
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: 56
                buttonRadius: root.radiusSmall
                colBackground: "transparent"
                colBackgroundHover: root.colSurfaceHover
                onClicked: { /* Play this item and remove previous */ }

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8
                    
                    StyledText { 
                        text: (index + 1).toString()
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.numbers
                        color: root.colTextSecondary
                        Layout.preferredWidth: 20 
                    }
                    
                    Rectangle { 
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: root.radiusSmall
                        color: root.colLayer2
                        clip: true
                        
                        Image { 
                            anchors.fill: parent
                            source: modelData.thumbnail ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true 
                        } 
                    }
                    
                    ColumnLayout { 
                        Layout.fillWidth: true
                        spacing: 2
                        
                        StyledText { 
                            Layout.fillWidth: true
                            text: modelData.title ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: root.colText
                            elide: Text.ElideRight 
                        }
                        
                        StyledText { 
                            Layout.fillWidth: true
                            text: modelData.artist ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary
                            elide: Text.ElideRight
                            visible: text !== "" 
                        } 
                    }
                    
                    RippleButton { 
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: YtMusic.removeFromQueue(index)
                        
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 18
                            color: root.colTextSecondary 
                        } 
                    }
                }
            }

            ColumnLayout { 
                anchors.centerIn: parent
                visible: !root.hasQueue
                spacing: 12
                
                MaterialSymbol { 
                    Layout.alignment: Qt.AlignHCenter
                    text: "queue_music"
                    iconSize: 48
                    color: root.colTextSecondary
                    opacity: 0.5 
                }
                
                StyledText { 
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Queue is empty")
                    color: root.colTextSecondary 
                } 
            }
        }
    }

    component AccountView: ColumnLayout {
        spacing: 10

        // === HOW IT WORKS ===
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: howItWorksContent.implicitHeight + 20
            radius: root.radiusSmall
            color: ColorUtils.transparentize(Appearance.colors.colTertiaryContainer, 0.5)
            
            ColumnLayout {
                id: howItWorksContent
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                
                RowLayout {
                    spacing: 8
                    MaterialSymbol { 
                        text: "info"
                        iconSize: 18
                        color: Appearance.colors.colOnTertiaryContainer
                    }
                    StyledText { 
                        Layout.fillWidth: true
                        text: Translation.tr("How it works")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnTertiaryContainer
                    }
                }
                
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 26
                    text: Translation.tr("YT Music reads cookies from your browser. Log in to music.youtube.com in your browser, then select it here. No passwords are stored.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnTertiaryContainer
                    opacity: 0.9
                    wrapMode: Text.WordWrap
                }
                
                // Quick action: Open YouTube Music
                RippleButton {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 36
                    buttonRadius: root.radiusSmall
                    colBackground: Appearance.colors.colTertiaryContainer
                    colBackgroundHover: Qt.darker(Appearance.colors.colTertiaryContainer, 1.1)
                    onClicked: YtMusic.openYtMusicInBrowser()
                    
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { 
                            text: "open_in_new"
                            iconSize: 18
                            color: Appearance.colors.colOnTertiaryContainer
                        }
                        StyledText { 
                            text: Translation.tr("Open YouTube Music to log in")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnTertiaryContainer
                        }
                    }
                }
            }
        }

        // === ERROR MESSAGE ===
        Loader {
            Layout.fillWidth: true
            active: YtMusic.googleError !== ""
            visible: active
            
            sourceComponent: Rectangle {
                implicitHeight: errorContent.implicitHeight + 16
                radius: root.radiusSmall
                color: ColorUtils.transparentize(Appearance.colors.colErrorContainer, 0.5)
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.colors.colError, 0.5)
                
                RowLayout {
                    id: errorContent
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    
                    MaterialSymbol { 
                        text: "error"
                        iconSize: 20
                        color: Appearance.colors.colError
                    }
                    
                    StyledText {
                        Layout.fillWidth: true
                        text: YtMusic.googleError
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnErrorContainer
                        wrapMode: Text.WordWrap
                    }
                    
                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                        onClicked: YtMusic.retryConnection()
                        
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 18
                            color: Appearance.colors.colError
                        }
                        
                        StyledToolTip { text: Translation.tr("Retry") }
                    }
                }
            }
        }

        // === CONNECTION STATUS CARD ===
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: connectionContent.implicitHeight + 24
            radius: root.radiusNormal
            color: YtMusic.googleConnected 
                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                : YtMusic.googleChecking
                ? ColorUtils.transparentize(Appearance.colors.colSecondary, 0.85)
                : root.colLayer2
            border.width: YtMusic.googleConnected ? 0 : root.borderWidth
            border.color: root.colBorder

            ColumnLayout {
                id: connectionContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: YtMusic.googleConnected 
                            ? Appearance.colors.colPrimary 
                            : YtMusic.googleChecking
                            ? Appearance.colors.colSecondary
                            : ColorUtils.transparentize(root.colTextSecondary, 0.8)
                        
                        MaterialSymbol { 
                            anchors.centerIn: parent
                            text: YtMusic.googleConnected ? "check_circle" 
                                : YtMusic.googleChecking ? "sync" 
                                : "account_circle"
                            iconSize: 26
                            fill: YtMusic.googleConnected ? 1 : 0
                            color: YtMusic.googleConnected || YtMusic.googleChecking 
                                ? Appearance.colors.colOnPrimary 
                                : root.colTextSecondary
                            
                            RotationAnimation on rotation {
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: YtMusic.googleChecking
                            }
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        StyledText { 
                            text: YtMusic.googleConnected 
                                ? Translation.tr("Connected") 
                                : YtMusic.googleChecking
                                ? Translation.tr("Checking...")
                                : Translation.tr("Not Connected")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: YtMusic.googleConnected ? Appearance.colors.colPrimary : root.colText
                        }
                        
                        StyledText { 
                            visible: YtMusic.googleConnected
                            text: Translation.tr("Using %1 cookies").arg(YtMusic.getBrowserDisplayName(YtMusic.googleBrowser))
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary
                        }
                        
                        StyledText { 
                            visible: !YtMusic.googleConnected
                            text: Translation.tr("Select a browser below")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary
                        }
                    }
                    
                    RippleButton {
                        visible: YtMusic.googleConnected
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: 16
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                        onClicked: YtMusic.disconnectGoogle()
                        
                        contentItem: MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "logout"
                            iconSize: 18
                            color: Appearance.colors.colError
                        }
                        
                        StyledToolTip { text: Translation.tr("Disconnect") }
                    }
                }
            }
        }

        // === BROWSER SELECTION ===
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            
            RowLayout {
                Layout.fillWidth: true
                StyledText { 
                    text: Translation.tr("Browser")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: root.colTextSecondary
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    visible: YtMusic.defaultBrowser !== ""
                    text: Translation.tr("Default: %1").arg(YtMusic.defaultBrowser)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                    opacity: 0.7
                }
            }
            
            // Detected browsers
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: YtMusic.detectedBrowsers.length > 0
                
                Repeater {
                    model: YtMusic.detectedBrowsers
                    
                    RippleButton {
                        required property string modelData
                        implicitWidth: Math.max(70, buttonContent.implicitWidth + 16)
                        implicitHeight: 34
                        buttonRadius: root.radiusSmall
                        
                        readonly property bool isSelected: YtMusic.googleBrowser === modelData
                        
                        colBackground: isSelected ? root.colPrimary : root.colLayer2
                        colBackgroundHover: isSelected ? Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimaryHover : root.colLayer2Hover
                        
                        onClicked: YtMusic.connectGoogle(modelData)
                        
                        contentItem: RowLayout {
                            id: buttonContent
                            anchors.centerIn: parent
                            spacing: 6
                            
                            StyledText {
                                text: (YtMusic.browserInfo[modelData]?.icon ?? "🌐")
                                font.pixelSize: 14
                            }
                            
                            StyledText {
                                text: (YtMusic.browserInfo[modelData]?.name ?? modelData)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: isSelected ? Appearance.colors.colOnPrimary : root.colText
                            }
                        }
                    }
                }
            }
            
            // Browser Grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                visible: YtMusic.detectedBrowsers.length > 0
                
                Repeater {
                    model: YtMusic.detectedBrowsers
                    
                    Rectangle {
                        required property string modelData
                        required property int index
                        
                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: root.radiusNormal
                        
                        readonly property bool isSelected: YtMusic.googleBrowser === modelData
                        readonly property bool isDefault: YtMusic.defaultBrowser === modelData
                        readonly property var browserData: YtMusic.browserInfo[modelData] ?? {}
                        
                        color: isSelected 
                            ? root.colPrimary
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : root.colLayer2
                        border.width: isSelected ? 0 : (Appearance.auroraEverywhere ? 0 : 1)
                        border.color: root.colBorder
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        
                        // Hover shadow effect
                        StyledRectangularShadow {
                            target: parent
                            visible: !Appearance.auroraEverywhere && !Appearance.inirEverywhere && browserMouseArea.containsMouse
                        }
                        
                        MouseArea {
                            id: browserMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: YtMusic.connectGoogle(modelData)
                            onPressed: parent.scale = 0.97
                            onReleased: parent.scale = 1.0
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            // Browser Icon
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 18
                                color: isSelected 
                                    ? ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.85)
                                    : ColorUtils.transparentize(root.colPrimary, 0.85)
                                
                                StyledText {
                                    anchors.centerIn: parent
                                    text: browserData.icon ?? "🌐"
                                    font.pixelSize: 20
                                }
                            }
                            
                            // Browser Name
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                
                                StyledText {
                                    text: browserData.name ?? modelData
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: isSelected ? Appearance.colors.colOnPrimary : root.colText
                                }
                                
                                StyledText {
                                    visible: isDefault && !isSelected
                                    text: Translation.tr("Default")
                                    font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                                    color: root.colPrimary
                                }
                            }
                            
                            // Check icon
                            MaterialSymbol {
                                visible: isSelected && YtMusic.googleConnected
                                text: "check_circle"
                                iconSize: 20
                                fill: 1
                                color: Appearance.colors.colOnPrimary
                                
                                SequentialAnimation on scale {
                                    running: visible
                                    NumberAnimation { from: 0; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                                }
                            }
                        }
                    }
                }
            }
            
            // Manual browser input with enhanced styling
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: !YtMusic.googleConnected
                
                StyledText {
                    text: Translation.tr("Or enter manually")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colTextSecondary
                    opacity: 0.8
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: root.radiusNormal
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                         : root.colLayer2
                    border.width: customBrowserInput.activeFocus ? 2 : (Appearance.auroraEverywhere ? 0 : 1)
                    border.color: customBrowserInput.activeFocus ? root.colPrimary : root.colBorder
                    
                    Behavior on border.width { NumberAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 10
                        
                        MaterialSymbol {
                            text: "search"
                            iconSize: 20
                            color: customBrowserInput.activeFocus ? root.colPrimary : root.colTextSecondary
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        TextField {
                            id: customBrowserInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Browser name (e.g., firefox)")
                            text: ""
                            color: root.colText
                            placeholderTextColor: root.colTextSecondary
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.main
                            background: Item {}
                            selectByMouse: true
                            
                            onAccepted: {
                                if (text.trim()) {
                                    YtMusic.connectGoogle(text.trim().toLowerCase())
                                    text = ""
                                }
                            }
                        }
                        
                        RippleButton {
                            visible: customBrowserInput.text.length > 0
                            opacity: visible ? 1 : 0
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: root.colPrimary
                            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimaryHover
                            onClicked: {
                                if (customBrowserInput.text.trim()) {
                                    YtMusic.connectGoogle(customBrowserInput.text.trim().toLowerCase())
                                    customBrowserInput.text = ""
                                }
                            }
                            
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_forward"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
                
                // Supported browsers hint
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("💡 Supported: firefox, chrome, chromium, brave, opera, vivaldi, edge, zen, librewolf, floorp")
                    font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                    color: root.colTextSecondary
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }
            }
            
            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                height: 1
                color: ColorUtils.transparentize(root.colTextSecondary, 0.9)
                visible: !YtMusic.googleConnected
            }
            
            // === CUSTOM COOKIES FILE ===
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !YtMusic.googleConnected
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Rectangle {
                        width: 4
                        height: 20
                        radius: 2
                        color: Appearance.colors.colSecondary
                    }
                    
                    StyledText {
                        text: Translation.tr("Advanced: Custom Cookies")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.colText
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: 14
                        colBackground: "transparent"
                        colBackgroundHover: root.colLayer2Hover
                        onClicked: Qt.openUrlExternally("https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp")
                        
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "help"
                            iconSize: 18
                            color: root.colTextSecondary
                        }
                        
                        StyledToolTip { text: Translation.tr("How to export cookies") }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: root.radiusNormal
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                         : root.colLayer2
                    border.width: customCookiesInput.activeFocus ? 2 : (Appearance.auroraEverywhere ? 0 : 1)
                    border.color: customCookiesInput.activeFocus ? Appearance.colors.colSecondary : root.colBorder
                    
                    Behavior on border.width { NumberAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 10
                        
                        MaterialSymbol {
                            text: "description"
                            iconSize: 20
                            color: customCookiesInput.activeFocus ? Appearance.colors.colSecondary : root.colTextSecondary
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        TextField {
                            id: customCookiesInput
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("/path/to/cookies.txt")
                            text: YtMusic.customCookiesPath
                            color: root.colText
                            placeholderTextColor: root.colTextSecondary
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.main
                            background: Item {}
                            selectByMouse: true
                            
                            onAccepted: {
                                if (text.trim()) {
                                    YtMusic.setCustomCookiesPath(text.trim())
                                }
                            }
                        }
                        
                        RippleButton {
                            visible: customCookiesInput.text !== YtMusic.customCookiesPath
                            opacity: visible ? 1 : 0
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: 16
                            colBackground: Appearance.colors.colSecondary
                            colBackgroundHover: Qt.darker(Appearance.colors.colSecondary, 1.1)
                            onClicked: {
                                if (customCookiesInput.text.trim()) {
                                    YtMusic.setCustomCookiesPath(customCookiesInput.text.trim())
                                }
                            }
                            
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "save"
                                iconSize: 18
                                color: Appearance.colors.colOnSecondary
                            }
                        }
                    }
                }
            }
        }

        // === YOUTUBE MUSIC PLAYLISTS (when connected) ===
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: YtMusic.googleConnected
            visible: active
            
            Behavior on opacity { NumberAnimation { duration: 300 } }

            sourceComponent: ColumnLayout {
                spacing: 12
                
                // Header with gradient
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ytMusicHeader.implicitHeight + 20
                    radius: root.radiusNormal
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: ColorUtils.transparentize(root.colPrimary, 0.85) }
                        GradientStop { position: 1.0; color: ColorUtils.transparentize(root.colPrimary, 0.95) }
                    }
                    
                    border.width: 1
                    border.color: ColorUtils.transparentize(root.colPrimary, 0.7)
                    
                    RowLayout {
                        id: ytMusicHeader
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10
                        
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: root.colPrimary
                            
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "cloud_done"
                                iconSize: 24
                                fill: 1
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            StyledText {
                                text: Translation.tr("Your Library")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: root.colText
                            }
                            
                            StyledText {
                                text: Translation.tr("Synced with YouTube Music")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.colTextSecondary
                            }
                        }
                        
                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: 18
                            colBackground: ColorUtils.transparentize(root.colPrimary, 0.85)
                            colBackgroundHover: ColorUtils.transparentize(root.colPrimary, 0.7)
                            onClicked: YtMusic.fetchLibrary()
                            
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: YtMusic.libraryLoading ? "hourglass_empty" : "refresh"
                                iconSize: 20
                                color: root.colPrimary
                                
                                RotationAnimation on rotation {
                                    from: 0; to: 360
                                    duration: 1000
                                    loops: Animation.Infinite
                                    running: YtMusic.libraryLoading
                                }
                            }
                            
                            StyledToolTip { text: Translation.tr("Refresh library") }
                        }
                    }
                }
                
                // Quick Actions Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        buttonRadius: root.radiusNormal
                        colBackground: ColorUtils.transparentize(Appearance.colors.colError, 0.9)
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                        onClicked: YtMusic.fetchLikedSongs()
                        enabled: !YtMusic.libraryLoading
                        
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            MaterialSymbol {
                                text: "favorite"
                                iconSize: 22
                                fill: 1
                                color: Appearance.colors.colError
                            }
                            
                            ColumnLayout {
                                spacing: 0
                                
                                StyledText {
                                    text: Translation.tr("Liked Songs")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colError
                                }
                                
                                StyledText {
                                    text: Translation.tr("Import top 100")
                                    font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                                    color: ColorUtils.transparentize(Appearance.colors.colError, 0.3)
                                }
                            }
                        }
                    }
                }
                
                // Playlists Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Rectangle {
                        width: 3
                        height: 18
                        radius: 1.5
                        color: root.colPrimary
                    }
                    
                    StyledText {
                        text: Translation.tr("Playlists")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.colText
                    }
                    
                    Rectangle {
                        visible: YtMusic.ytMusicPlaylists.length > 0
                        implicitWidth: countText.implicitWidth + 12
                        implicitHeight: 20
                        radius: 10
                        color: ColorUtils.transparentize(root.colPrimary, 0.9)
                        
                        StyledText {
                            id: countText
                            anchors.centerIn: parent
                            text: YtMusic.ytMusicPlaylists.length.toString()
                            font.pixelSize: Appearance.font.pixelSize.smallest ?? 10
                            font.weight: Font.Bold
                            color: root.colPrimary
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                }

                // Playlists List
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: YtMusic.ytMusicPlaylists
                    spacing: 6
                    
                    // Loading indicator
                    header: Loader {
                        width: parent?.width ?? 0
                        active: YtMusic.libraryLoading
                        height: active ? 60 : 0
                        visible: active
                        
                        Behavior on height { NumberAnimation { duration: 200 } }
                        
                        sourceComponent: Rectangle {
                            radius: root.radiusNormal
                            color: ColorUtils.transparentize(root.colPrimary, 0.95)
                            
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 12
                                
                                BusyIndicator {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    running: true
                                }
                                
                                StyledText {
                                    text: Translation.tr("Loading playlists...")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: root.colTextSecondary
                                }
                            }
                        }
                    }
                    
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        
                        width: ListView.view.width
                        implicitHeight: 68
                        radius: root.radiusNormal
                        color: playlistMouseArea.containsMouse 
                            ? root.colSurfaceHover
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : root.colLayer2
                        border.width: Appearance.auroraEverywhere ? 0 : 1
                        border.color: playlistMouseArea.containsMouse 
                            ? root.colPrimary
                            : ColorUtils.transparentize(root.colBorder, 0.5)
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        
                        StyledRectangularShadow {
                            target: parent
                            visible: !Appearance.auroraEverywhere && !Appearance.inirEverywhere && playlistMouseArea.containsMouse
                        }
                        
                        MouseArea {
                            id: playlistMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: YtMusic.importYtMusicPlaylist(modelData.url, modelData.title)
                            onPressed: parent.scale = 0.98
                            onReleased: parent.scale = 1.0
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            
                            // Playlist Icon
                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: root.radiusSmall
                                
                                gradient: Gradient {
                                    GradientStop { 
                                        position: 0.0
                                        color: ColorUtils.transparentize(root.colPrimary, 0.85)
                                    }
                                    GradientStop { 
                                        position: 1.0
                                        color: ColorUtils.transparentize(root.colPrimary, 0.7)
                                    }
                                }
                                
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "queue_music"
                                    iconSize: 24
                                    color: root.colPrimary
                                }
                            }
                            
                            // Playlist Info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.title ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: root.colText
                                    elide: Text.ElideRight
                                }
                                
                                RowLayout {
                                    spacing: 6
                                    
                                    MaterialSymbol {
                                        text: "music_note"
                                        iconSize: 14
                                        color: root.colTextSecondary
                                    }
                                    
                                    StyledText {
                                        text: Translation.tr("%1 tracks").arg(modelData.count ?? "?")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.colTextSecondary
                                    }
                                }
                            }
                            
                            // Download Icon
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 18
                                color: playlistMouseArea.containsMouse
                                    ? root.colPrimary
                                    : ColorUtils.transparentize(root.colPrimary, 0.9)
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "download"
                                    iconSize: 18
                                    color: playlistMouseArea.containsMouse
                                        ? Appearance.colors.colOnPrimary
                                        : root.colPrimary
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        visible: YtMusic.ytMusicPlaylists.length === 0 && !YtMusic.libraryLoading
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 16
                            
                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: "playlist_add"
                                iconSize: 56
                                color: root.colTextSecondary
                                opacity: 0.4
                            }
                            
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("No playlists found")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: root.colText
                            }
                            
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("Create playlists on YouTube Music")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: root.colTextSecondary
                            }
                            
                            RippleButton {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 140
                                implicitHeight: 40
                                buttonRadius: 20
                                colBackground: root.colPrimary
                                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimaryHover
                                onClicked: YtMusic.fetchLibrary()
                                
                                contentItem: RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    
                                    MaterialSymbol {
                                        text: "refresh"
                                        iconSize: 18
                                        color: Appearance.colors.colOnPrimary
                                    }
                                    
                                    StyledText {
                                        text: Translation.tr("Refresh")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; visible: !YtMusic.googleConnected }
    }
}
