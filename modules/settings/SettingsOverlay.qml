import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

/**
 * Settings UI as a layer shell overlay panel.
 * Allows users to see live changes to the shell (sidebars, bar, etc.)
 * without opening a separate window. Loaded by the main shell when
 * Config.options.settingsUi.overlayMode is true.
 */
Scope {
    id: root

    property bool settingsOpen: GlobalStates.settingsOverlayOpen ?? false

    // Keep alive after first open for instant re-open
    property bool _everOpened: false

    // ── Search system ──
    property string overlaySearchText: ""
    property var overlaySearchResults: []
    
    Timer {
        id: searchDebounceTimer
        interval: 200  // 200ms debounce for settings search
        onTriggered: root.recomputeOverlaySearchResults()
    }
    
    // Simple search index based on pages
    property var overlaySearchIndex: [
        { pageIndex: 0, pageName: Translation.tr("Quick"), keywords: ["quick", "wallpaper", "colors", "bar", "position"] },
        { pageIndex: 1, pageName: Translation.tr("General"), keywords: ["general", "audio", "battery", "language", "time", "sounds"] },
        { pageIndex: 2, pageName: Translation.tr("Bar"), keywords: ["bar", "position", "workspaces", "tray", "weather", "modules"] },
        { pageIndex: 3, pageName: Translation.tr("Background"), keywords: ["background", "wallpaper", "parallax", "blur", "dim", "effects"] },
        { pageIndex: 4, pageName: Translation.tr("Themes"), keywords: ["themes", "colors", "palette", "aurora", "inir", "material", "fonts", "icons"] },
        { pageIndex: 5, pageName: Translation.tr("Interface"), keywords: ["interface", "dock", "notifications", "lock", "sidebars", "overview", "overlay"] },
        { pageIndex: 6, pageName: Translation.tr("Services"), keywords: ["services", "ai", "music", "weather", "search", "night", "light", "gamemode"] },
        { pageIndex: 7, pageName: Translation.tr("Advanced"), keywords: ["advanced", "performance", "colors", "terminal", "scrolling"] },
        { pageIndex: 8, pageName: Translation.tr("Shortcuts"), keywords: ["shortcuts", "keyboard", "keybindings", "hotkeys", "cheatsheet"] },
        { pageIndex: 9, pageName: Translation.tr("Modules"), keywords: ["modules", "panels", "enable", "disable"] },
        { pageIndex: 10, pageName: Translation.tr("Waffle Style"), keywords: ["waffle", "windows", "taskbar", "start", "menu"] },
        { pageIndex: 11, pageName: Translation.tr("About"), keywords: ["about", "version", "credits", "info"] }
    ]

    function recomputeOverlaySearchResults() {
        var q = String(overlaySearchText || "").toLowerCase().trim();
        if (!q.length) {
            overlaySearchResults = [];
            return;
        }

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var results = [];

        for (var i = 0; i < overlaySearchIndex.length; i++) {
            var entry = overlaySearchIndex[i];
            var pageName = (entry.pageName || "").toLowerCase();
            var keywords = (entry.keywords || []).join(" ").toLowerCase();

            var matchCount = 0;
            var score = 0;

            for (var j = 0; j < terms.length; j++) {
                var term = terms[j];
                if (pageName.indexOf(term) >= 0 || keywords.indexOf(term) >= 0) {
                    matchCount++;
                    if (pageName.indexOf(term) === 0) score += 100;
                    else if (pageName.indexOf(term) > 0) score += 50;
                    if (keywords.indexOf(term) >= 0) score += 30;
                }
            }

            if (matchCount === terms.length) {
                results.push({
                    pageIndex: entry.pageIndex,
                    pageName: entry.pageName,
                    score: score
                });
            }
        }

        results.sort((a, b) => b.score - a.score);
        overlaySearchResults = results.slice(0, 20);
    }

    function openOverlaySearchResult(entry) {
        if (!entry || entry.pageIndex === undefined || entry.pageIndex < 0) {
            overlaySearchText = "";
            return;
        }

        overlaySearchText = "";
        
        if (overlayCurrentPage !== entry.pageIndex) {
            overlayCurrentPage = entry.pageIndex;
        }
    }

    Connections {
        target: GlobalStates
        function onSettingsOverlayOpenChanged() {
            if (GlobalStates.settingsOverlayOpen) {
                root._everOpened = true
            }
        }
    }

    Loader {
        id: panelLoader
        active: root._everOpened

        sourceComponent: PanelWindow {
            id: settingsPanel

            visible: GlobalStates.settingsOverlayOpen ?? false

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:settingsOverlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Focus grab for Hyprland
            CompositorFocusGrab {
                id: grab
                windows: [settingsPanel]
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.settingsOverlayOpen = false
                }
            }

            Connections {
                target: GlobalStates
                function onSettingsOverlayOpenChanged() {
                    grabTimer.restart()
                }
            }

            Timer {
                id: grabTimer
                interval: 100
                onTriggered: grab.active = (GlobalStates.settingsOverlayOpen ?? false)
            }

            // ── Scrim backdrop ──
            Rectangle {
                id: scrimBg
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: (GlobalStates.settingsOverlayOpen ?? false) ? (Config.options?.overlay?.scrimDim ?? 35) / 100 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.settingsOverlayOpen = false
                }
            }

            // ── Floating settings card ──
            Rectangle {
                id: settingsCard

                readonly property real maxCardWidth: Math.min(1100, settingsPanel.width * 0.88)
                readonly property real maxCardHeight: Math.min(850, settingsPanel.height * 0.88)

                anchors.centerIn: parent
                width: maxCardWidth
                height: maxCardHeight
                radius: Appearance.rounding.windowRounding
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer0
                     : Appearance.auroraEverywhere ? Appearance.colors.colLayer0Base
                     : Appearance.m3colors.m3background
                clip: true

                border.width: Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.inirEverywhere
                    ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer0Border)
                    : "transparent"

                // Scale + fade animation
                opacity: (GlobalStates.settingsOverlayOpen ?? false) ? 1 : 0
                scale: (GlobalStates.settingsOverlayOpen ?? false) ? 1.0 : 0.92

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }

                // Shadow - hidden in aurora, visible in material/inir
                layer.enabled: Appearance.effectsEnabled && !Appearance.auroraEverywhere
                layer.effect: DropShadow {
                    color: Appearance.colors.colShadow
                    radius: 24
                    samples: 25
                    verticalOffset: 8
                    horizontalOffset: 0
                }

                // Prevent clicks from closing
                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                // ── Main content ──
                ColumnLayout {
                    id: mainLayout
                    anchors {
                        fill: parent
                        margins: 8
                    }
                    spacing: 8

                    // ── Title bar ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 4
                        spacing: 8

                        MaterialSymbol {
                            text: "settings"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.m3colors.m3primary
                        }

                        StyledText {
                            text: Translation.tr("Settings")
                            font {
                                family: Appearance.font.family.title
                                pixelSize: Appearance.font.pixelSize.title
                                variableAxes: Appearance.font.variableAxes.title
                            }
                            color: Appearance.colors.colOnLayer0
                            Layout.fillWidth: true
                        }

                        // Search field
                        Rectangle {
                            Layout.preferredWidth: Math.min(300, settingsCard.width * 0.3)
                            Layout.preferredHeight: 36
                            radius: Appearance.rounding.full
                            color: overlaySearchField.activeFocus
                                ? Appearance.colors.colLayer1
                                : (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                  : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                  : Appearance.m3colors.m3surfaceContainerLow)
                            border.width: overlaySearchField.activeFocus ? 2 : (Appearance.inirEverywhere ? 1 : 0)
                            border.color: overlaySearchField.activeFocus
                                ? Appearance.colors.colPrimary
                                : (Appearance.inirEverywhere ? Appearance.inir.colBorderMuted
                                  : Appearance.m3colors.m3outlineVariant)

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                            Behavior on border.color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                MaterialSymbol {
                                    text: "search"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colSubtext
                                }

                                TextInput {
                                    id: overlaySearchField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    verticalAlignment: Text.AlignVCenter
                                    color: Appearance.colors.colOnLayer1
                                    font {
                                        family: Appearance.font.family.main
                                        pixelSize: Appearance.font.pixelSize.small
                                    }
                                    clip: true

                                    property string placeholderText: Translation.tr("Search settings...")

                                    text: root.overlaySearchText
                                    onTextChanged: {
                                        root.overlaySearchText = text;
                                        searchDebounceTimer.restart();
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Down && root.overlaySearchResults.length > 0) {
                                            overlayResultsList.forceActiveFocus();
                                            if (overlayResultsList.currentIndex < 0) {
                                                overlayResultsList.currentIndex = 0;
                                            }
                                            event.accepted = true;
                                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.overlaySearchResults.length > 0) {
                                            var idx = (overlayResultsList.currentIndex >= 0 && overlayResultsList.currentIndex < root.overlaySearchResults.length)
                                                ? overlayResultsList.currentIndex
                                                : 0;
                                            root.openOverlaySearchResult(root.overlaySearchResults[idx]);
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.openOverlaySearchResult({});
                                            event.accepted = true;
                                        }
                                    }
                                }

                                StyledText {
                                    visible: overlaySearchField.text.length === 0 && !overlaySearchField.activeFocus
                                    text: overlaySearchField.placeholderText
                                    font {
                                        family: Appearance.font.family.main
                                        pixelSize: Appearance.font.pixelSize.small
                                    }
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }

                        // Close button
                        RippleButton {
                            buttonRadius: Appearance.rounding.full
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: GlobalStates.settingsOverlayOpen = false
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "close"
                                iconSize: 20
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    // ── Navigation + Content ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        // Navigation rail (compact)
                        Rectangle {
                            id: navColumn
                            Layout.fillHeight: true
                            Layout.preferredWidth: 56
                            radius: Appearance.rounding.normal
                            color: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                 : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                 : Appearance.m3colors.m3surfaceContainerLow
                            border.width: Appearance.inirEverywhere ? 1 : 0
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : "transparent"

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 4
                                contentHeight: navCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                
                                ScrollBar.vertical: StyledScrollBar {
                                    policy: ScrollBar.AsNeeded
                                }

                                ColumnLayout {
                                    id: navCol
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: overlayPages
                                        delegate: RippleButton {
                                            id: navBtn
                                            required property int index
                                            required property var modelData

                                            Layout.fillWidth: true
                                            implicitHeight: 48
                                            buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                                            toggled: overlayCurrentPage === index
                                            
                                            // Tri-style background for selected state - subtle for material
                                            colBackground: toggled
                                                ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                                  : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                                  : CF.ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.92))
                                                : "transparent"
                                            
                                            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                                                              : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                                              : Appearance.colors.colLayer2

                                            onClicked: overlayCurrentPage = index

                                            contentItem: ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 2

                                                MaterialSymbol {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: modelData.icon
                                                    iconSize: 20
                                                    color: navBtn.toggled
                                                        ? (Appearance.inirEverywhere ? Appearance.inir.colText
                                                          : Appearance.colors.colOnSecondaryContainer)
                                                        : Appearance.colors.colOnSurfaceVariant
                                                    rotation: modelData.iconRotation || 0
                                                }

                                                StyledText {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: modelData.shortName || ""
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: navBtn.toggled
                                                        ? (Appearance.inirEverywhere ? Appearance.inir.colText
                                                          : Appearance.colors.colOnSecondaryContainer)
                                                        : Appearance.colors.colOnSurfaceVariant
                                                    visible: text.length > 0
                                                }
                                            }

                                            StyledToolTip {
                                                text: modelData.name
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Content area
                        Rectangle {
                            id: overlayContentContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.normal
                            color: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                 : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                 : Appearance.m3colors.m3surfaceContainerLow
                            border.width: Appearance.inirEverywhere ? 1 : 0
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : "transparent"
                            clip: true

                            // Loading indicator
                            CircularProgress {
                                anchors.centerIn: parent
                                visible: {
                                    // Show when current page is loading
                                    for (var i = 0; i < overlayPagesRepeater.count; i++) {
                                        var loader = overlayPagesRepeater.itemAt(i);
                                        if (loader && loader.index === overlayCurrentPage && loader.status !== Loader.Ready) {
                                            return true;
                                        }
                                    }
                                    return false;
                                }
                            }

                            // Page stack
                            Item {
                                id: overlayPagesStack
                                anchors.fill: parent

                                property var visitedPages: ({})
                                property int preloadIndex: 0

                                Connections {
                                    target: root
                                    function onSettingsOpenChanged() {
                                        if (root.settingsOpen) {
                                            // Mark current page when overlay opens
                                            overlayPagesStack.visitedPages[overlayCurrentPage] = true
                                            overlayPagesStack.visitedPagesChanged()
                                            // Start preloading other pages
                                            overlayPreloadTimer.start()
                                        }
                                    }
                                }

                                // CRITICAL: Mark new page as visited when switching pages
                                Connections {
                                    target: root
                                    function onOverlayCurrentPageChanged() {
                                        overlayPagesStack.visitedPages[overlayCurrentPage] = true
                                        overlayPagesStack.visitedPagesChanged()
                                    }
                                }

                                // Use a tiny timer so the Repeater delegates exist before we mark pages
                                Timer {
                                    id: initialLoadTimer
                                    interval: 1
                                    onTriggered: {
                                        overlayPagesStack.visitedPages[overlayCurrentPage] = true
                                        overlayPagesStack.visitedPagesChanged()
                                    }
                                }

                                Component.onCompleted: {
                                    initialLoadTimer.start()
                                }

                                Timer {
                                    id: overlayPreloadTimer
                                    interval: 200
                                    repeat: true
                                    onTriggered: {
                                        if (overlayPagesStack.preloadIndex < overlayPages.length) {
                                            if (!overlayPagesStack.visitedPages[overlayPagesStack.preloadIndex]) {
                                                overlayPagesStack.visitedPages[overlayPagesStack.preloadIndex] = true
                                                overlayPagesStack.visitedPagesChanged()
                                            }
                                            overlayPagesStack.preloadIndex++
                                        } else {
                                            overlayPreloadTimer.stop()
                                        }
                                    }
                                }

                                Repeater {
                                    id: overlayPagesRepeater
                                    model: overlayPages.length
                                    delegate: Loader {
                                        id: overlayPageLoader
                                        required property int index
                                        anchors.fill: parent
                                        active: Config.ready && (overlayPagesStack.visitedPages[index] === true)
                                        asynchronous: index !== overlayCurrentPage
                                        source: overlayPages[index].component
                                        visible: index === overlayCurrentPage && status === Loader.Ready
                                        opacity: visible ? 1 : 0

                                        Behavior on opacity {
                                            enabled: Appearance.animationsEnabled
                                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Search results overlay ──
                Rectangle {
                    id: overlaySearchResultsOverlay
                    anchors.fill: parent
                    visible: root.overlaySearchText.length > 0 && root.overlaySearchResults.length > 0
                    color: "transparent"
                    z: 100

                    // Click outside to close
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openOverlaySearchResult({})
                    }

                    // Results card
                    Rectangle {
                        id: overlaySearchResultsCard
                        width: Math.min(parent.width - 40, 400)
                        height: Math.min(overlayResultsList.contentHeight + 16, 300)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 60
                        radius: Appearance.rounding.normal
                        color: Appearance.auroraEverywhere ? Appearance.colors.colLayer1Base
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.colors.colLayer1
                        border.width: Appearance.inirEverywhere ? 1 : 0
                        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : "transparent"

                        layer.enabled: Appearance.effectsEnabled && !Appearance.auroraEverywhere
                        layer.effect: DropShadow {
                            color: Qt.rgba(0, 0, 0, 0.3)
                            radius: 12
                            samples: 13
                            verticalOffset: 4
                        }

                        ListView {
                            id: overlayResultsList
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            model: root.overlaySearchResults
                            clip: true
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up) {
                                    if (overlayResultsList.currentIndex > 0) {
                                        overlayResultsList.currentIndex--;
                                    } else {
                                        overlaySearchField.forceActiveFocus();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (overlayResultsList.currentIndex < overlayResultsList.count - 1) {
                                        overlayResultsList.currentIndex++;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (overlayResultsList.currentIndex >= 0) {
                                        root.openOverlaySearchResult(root.overlaySearchResults[overlayResultsList.currentIndex]);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openOverlaySearchResult({});
                                    overlaySearchField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            delegate: RippleButton {
                                id: resultItem
                                required property var modelData
                                required property int index

                                width: overlayResultsList.width
                                implicitHeight: 48
                                buttonRadius: Appearance.rounding.small

                                colBackground: ListView.isCurrentItem
                                    ? (Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                      : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                      : Appearance.colors.colPrimaryContainer)
                                    : "transparent"
                                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                                                  : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                                  : Appearance.colors.colLayer2

                                Keys.forwardTo: [overlayResultsList]
                                onClicked: root.openOverlaySearchResult(modelData)

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    MaterialSymbol {
                                        text: {
                                            var icons = ["instant_mix", "browse", "toast", "texture", "palette",
                                                        "bottom_app_bar", "settings", "construction", "keyboard",
                                                        "extension", "window", "info"];
                                            return icons[resultItem.modelData.pageIndex] || "settings";
                                        }
                                        iconSize: 20
                                        color: resultItem.ListView.isCurrentItem
                                            ? (Appearance.inirEverywhere ? Appearance.inir.colText
                                              : Appearance.colors.colOnPrimaryContainer)
                                            : Appearance.colors.colPrimary
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: resultItem.modelData.pageName || ""
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.normal
                                            weight: Font.Medium
                                        }
                                        color: resultItem.ListView.isCurrentItem
                                            ? (Appearance.inirEverywhere ? Appearance.inir.colText
                                              : Appearance.colors.colOnPrimaryContainer)
                                            : Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // Escape key handler
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.settingsOverlayOpen = false
                        event.accepted = true
                    } else if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                            overlayCurrentPage = (overlayCurrentPage + 1) % overlayPages.length
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                            overlayCurrentPage = (overlayCurrentPage - 1 + overlayPages.length) % overlayPages.length
                            event.accepted = true
                        }
                    }
                }

                // Grab focus when opened
                Connections {
                    target: GlobalStates
                    function onSettingsOverlayOpenChanged() {
                        if (GlobalStates.settingsOverlayOpen) {
                            settingsCard.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ── Page definitions (same as settings.qml) ──
    property int overlayCurrentPage: 0

    property var overlayPages: [
        {
            name: Translation.tr("Quick"),
            shortName: "",
            icon: "instant_mix",
            component: Quickshell.shellPath("modules/settings/QuickConfig.qml")
        },
        {
            name: Translation.tr("General"),
            shortName: "",
            icon: "browse",
            component: Quickshell.shellPath("modules/settings/GeneralConfig.qml")
        },
        {
            name: Translation.tr("Bar"),
            shortName: "",
            icon: "toast",
            iconRotation: 180,
            component: Quickshell.shellPath("modules/settings/BarConfig.qml")
        },
        {
            name: Translation.tr("Background"),
            shortName: "",
            icon: "texture",
            component: Quickshell.shellPath("modules/settings/BackgroundConfig.qml")
        },
        {
            name: Translation.tr("Themes"),
            shortName: "",
            icon: "palette",
            component: Quickshell.shellPath("modules/settings/ThemesConfig.qml")
        },
        {
            name: Translation.tr("Interface"),
            shortName: "",
            icon: "bottom_app_bar",
            component: Quickshell.shellPath("modules/settings/InterfaceConfig.qml")
        },
        {
            name: Translation.tr("Services"),
            shortName: "",
            icon: "settings",
            component: Quickshell.shellPath("modules/settings/ServicesConfig.qml")
        },
        {
            name: Translation.tr("Advanced"),
            shortName: "",
            icon: "construction",
            component: Quickshell.shellPath("modules/settings/AdvancedConfig.qml")
        },
        {
            name: Translation.tr("Shortcuts"),
            shortName: "",
            icon: "keyboard",
            component: Quickshell.shellPath("modules/settings/CheatsheetConfig.qml")
        },
        {
            name: Translation.tr("Modules"),
            shortName: "",
            icon: "extension",
            component: Quickshell.shellPath("modules/settings/ModulesConfig.qml")
        },
        {
            name: Translation.tr("Waffle Style"),
            shortName: "",
            icon: "window",
            component: Quickshell.shellPath("modules/settings/WaffleConfig.qml")
        },
        {
            name: Translation.tr("About"),
            shortName: "",
            icon: "info",
            component: Quickshell.shellPath("modules/settings/About.qml")
        }
    ]

    // ── IPC handler — settings target is in shell.qml but we provide toggle ──
    // The shell.qml IPC handler decides which mode to use based on config.
}
