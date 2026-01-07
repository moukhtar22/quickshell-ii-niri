pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * YT Music service - Search and play music from YouTube using yt-dlp + mpv.
 * 
 * Features:
 * - MPRIS integration (mpv exposes controls, synced with MprisController)
 * - Playlist management (save/load custom playlists)
 * - Google account sync (via browser cookies for YouTube Music playlists)
 * - Queue management with persistence
 */
Singleton {
    id: root

    // === Public State ===
    property bool available: false
    property bool searching: false
    property bool loading: false
    property bool libraryLoading: false
    property string error: ""
    
    // Current track info (synced with MPRIS when available)
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentThumbnail: ""
    property string currentUrl: ""
    property string currentVideoId: ""
    property real currentDuration: 0
    property real currentPosition: 0
    
    // Playback state (from MPRIS)
    property bool isPlaying: _mpvPlayer?.isPlaying ?? false
    property bool canPause: _mpvPlayer?.canPause ?? false
    property bool canSeek: _mpvPlayer?.canSeek ?? false
    property real volume: _mpvPlayer?.volume ?? 1.0
    
    // Collections
    property var searchResults: []
    property var recentSearches: []
    property var queue: []
    property var playlists: []  // Local playlists
    
    // Google account
    property bool googleConnected: false
    property bool googleChecking: false
    property string googleError: ""
    property string googleBrowser: Config.options?.sidebar?.ytmusic?.browser ?? "firefox"
    property string customCookiesPath: Config.options?.sidebar?.ytmusic?.cookiesPath ?? ""
    
    // Cloud Library
    property var ytMusicPlaylists: []
    property var ytMusicMixes: []
    property var ytMusicLiked: []
    property list<string> detectedBrowsers: [] 
    
    readonly property int maxRecentSearches: 10
    readonly property int maxSearchResults: 20
    
    // Supported browsers with their cookie paths
    readonly property var browserInfo: ({
        "firefox": { name: "Firefox", icon: "🦊", configPath: "~/.mozilla/firefox" },
        "chrome": { name: "Chrome", icon: "🌐", configPath: "~/.config/google-chrome" },
        "chromium": { name: "Chromium", icon: "🔵", configPath: "~/.config/chromium" },
        "brave": { name: "Brave", icon: "🦁", configPath: "~/.config/BraveSoftware" },
        "vivaldi": { name: "Vivaldi", icon: "🎼", configPath: "~/.config/vivaldi" },
        "opera": { name: "Opera", icon: "🔴", configPath: "~/.config/opera" },
        "edge": { name: "Edge", icon: "🔷", configPath: "~/.config/microsoft-edge" },
        "zen": { name: "Zen", icon: "☯️", configPath: "~/.zen" },
        "librewolf": { name: "LibreWolf", icon: "🐺", configPath: "~/.librewolf" },
        "floorp": { name: "Floorp", icon: "🌊", configPath: "~/.floorp" },
        "waterfox": { name: "Waterfox", icon: "💧", configPath: "~/.waterfox" }
    })

    // === MPRIS Player Reference ===
    property MprisPlayer _mpvPlayer: {
        for (const player of Mpris.players.values) {
            if (player.identity === "mpv" || player.desktopEntry === "mpv") {
                return player
            }
        }
        return null
    }

    // Sync position from MPRIS
    Timer {
        interval: 1000
        running: root._mpvPlayer !== null && root.isPlaying
        repeat: true
        onTriggered: {
            if (root._mpvPlayer) {
                root.currentPosition = root._mpvPlayer.position
            }
        }
    }

    // === Public Functions ===
    
    // Search
    function search(query): void {
        if (!query.trim() || !root.available) return
        root.error = ""
        root.searching = true
        root.searchResults = []
        _searchQuery = query.trim()
        _searchProc.running = true
        _addToRecentSearches(query.trim())
    }

    // Playback control
    function play(item): void {
        if (!item?.videoId || !root.available) return
        root.error = ""
        root.loading = true
        root.currentTitle = item.title || ""
        root.currentArtist = item.artist || ""
        root.currentVideoId = item.videoId || ""
        root.currentThumbnail = _getThumbnailUrl(item.videoId)
        root.currentUrl = item.url || `https://www.youtube.com/watch?v=${item.videoId}`
        root.currentDuration = item.duration || 0
        root.currentPosition = 0
        
        _stopProc.running = true
        _playUrl = root.currentUrl
        _playDelayTimer.restart()
    }

    function playFromSearch(index): void {
        if (index >= 0 && index < searchResults.length) {
            play(searchResults[index])
        }
    }

    function stop(): void {
        _playProc.running = false
        root.loading = false
    }

    function togglePlaying(): void {
        if (root._mpvPlayer) {
            root._mpvPlayer.togglePlaying()
        }
    }

    function seek(position): void {
        if (root._mpvPlayer && root.canSeek) {
            root._mpvPlayer.position = position
        }
    }

    function setVolume(vol): void {
        if (root._mpvPlayer) {
            root._mpvPlayer.volume = Math.max(0, Math.min(1, vol))
        }
    }

    // Queue management
    function addToQueue(item): void {
        if (!item?.videoId) return
        root.queue = [...root.queue, item]
        _persistQueue()
    }

    function removeFromQueue(index): void {
        if (index >= 0 && index < root.queue.length) {
            let q = [...root.queue]
            q.splice(index, 1)
            root.queue = q
            _persistQueue()
        }
    }

    function clearQueue(): void {
        root.queue = []
        _persistQueue()
    }

    function playNext(): void {
        if (root.queue.length > 0) {
            const next = root.queue[0]
            root.queue = root.queue.slice(1)
            _persistQueue()
            play(next)
        }
    }

    function playQueue(): void {
        if (root.queue.length > 0) {
            playNext()
        }
    }

    function shuffleQueue(): void {
        if (root.queue.length < 2) return
        let q = [...root.queue]
        // Fisher-Yates shuffle
        for (let i = q.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [q[i], q[j]] = [q[j], q[i]]
        }
        root.queue = q
        _persistQueue()
    }

    // Playlist management
    function createPlaylist(name): void {
        if (!name.trim()) return
        root.playlists = [...root.playlists, { name: name.trim(), items: [] }]
        _persistPlaylists()
    }

    function deletePlaylist(index): void {
        if (index >= 0 && index < root.playlists.length) {
            let p = [...root.playlists]
            p.splice(index, 1)
            root.playlists = p
            _persistPlaylists()
        }
    }

    function addToPlaylist(playlistIndex, item): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        if (!item?.videoId) return
        
        let p = [...root.playlists]
        // Avoid duplicates
        if (!p[playlistIndex].items.find(i => i.videoId === item.videoId)) {
            p[playlistIndex].items = [...p[playlistIndex].items, {
                videoId: item.videoId,
                title: item.title,
                artist: item.artist,
                duration: item.duration,
                thumbnail: _getThumbnailUrl(item.videoId)
            }]
            root.playlists = p
            _persistPlaylists()
        }
    }

    function removeFromPlaylist(playlistIndex, itemIndex): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        let p = [...root.playlists]
        if (itemIndex >= 0 && itemIndex < p[playlistIndex].items.length) {
            p[playlistIndex].items.splice(itemIndex, 1)
            root.playlists = p
            _persistPlaylists()
        }
    }

    function playPlaylist(playlistIndex, shuffle): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        let items = [...root.playlists[playlistIndex].items]
        if (items.length === 0) return
        
        if (shuffle) {
            // Fisher-Yates shuffle
            for (let i = items.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [items[i], items[j]] = [items[j], items[i]]
            }
        }
        
        root.queue = items.slice(1)
        _persistQueue()
        play(items[0])
    }

    // Google account / YouTube Music
    function connectGoogle(browser): void {
        root.googleBrowser = browser || "firefox"
        root.googleError = ""
        root.googleChecking = true
        // Clear custom cookies if switching to browser
        if (root.customCookiesPath) {
            root.customCookiesPath = ""
            Config.setNestedValue('sidebar.ytmusic.cookiesPath', "")
        }
        Config.setNestedValue('sidebar.ytmusic.browser', root.googleBrowser)
        _checkGoogleConnection()
    }

    function setCustomCookiesPath(path): void {
        if (!path) return
        root.customCookiesPath = path
        root.googleError = ""
        root.googleChecking = true
        Config.setNestedValue('sidebar.ytmusic.cookiesPath', path)
        _checkGoogleConnection()
    }

    function disconnectGoogle(): void {
        root.googleConnected = false
        root.googleError = ""
        root.ytMusicPlaylists = []
        root.ytMusicMixes = []
        root.ytMusicLiked = []
    }
    
    function openYtMusicInBrowser(): void {
        Qt.openUrlExternally("https://music.youtube.com")
    }
    
    function retryConnection(): void {
        root.googleError = ""
        root.googleChecking = true
        _googleCheckProc.running = true
    }
    
    function getBrowserDisplayName(browserId): string {
        return root.browserInfo[browserId]?.name ?? browserId
    }

    function fetchLibrary(): void {
        if (!root.googleConnected) return
        root.libraryLoading = true
        _ytPlaylistsProc.running = true
        _likedSongsProc.running = true
        // _mixesProc.running = true // TODO: Implement mixes fetching
    }

    function importYtMusicPlaylist(playlistUrl, name): void {
        if (!root.googleConnected || !playlistUrl) return
        root.searching = true
        _importPlaylistUrl = playlistUrl
        _importPlaylistName = name || "Imported Playlist"
        _importPlaylistProc.running = true
    }

    // Recent searches
    function clearRecentSearches(): void {
        root.recentSearches = []
        _persistRecentSearches()
    }

    // === Private ===
    property string _searchQuery: ""
    property string _playUrl: ""
    property string _importPlaylistUrl: ""
    property string _importPlaylistName: ""
    
    property var _cookieArgs: root.customCookiesPath 
        ? ["--cookies", root.customCookiesPath] 
        : ["--cookies-from-browser", root.googleBrowser]

    property string _mpvCookieArgs: root.customCookiesPath
        ? "cookies=" + root.customCookiesPath
        : "cookies-from-browser=" + root.googleBrowser

    function _getThumbnailUrl(videoId): string {
        if (!videoId) return ""
        // Validate videoId - should be 11 chars and not a channel ID (UC prefix)
        if (videoId.length !== 11 || videoId.startsWith("UC")) return ""
        return `https://i.ytimg.com/vi/${videoId}/mqdefault.jpg`
    }

    Component.onCompleted: {
        _checkAvailability.running = true
        _detectDefaultBrowserProc.running = true
        _detectBrowsersProc.running = true
        _loadData()
    }

    function _loadData(): void {
        root.recentSearches = Config.options?.sidebar?.ytmusic?.recentSearches ?? []
        root.queue = Config.options?.sidebar?.ytmusic?.queue ?? []
        root.playlists = Config.options?.sidebar?.ytmusic?.playlists ?? []
        // Use saved browser, or wait for default detection
        const savedBrowser = Config.options?.sidebar?.ytmusic?.browser
        if (savedBrowser) {
            root.googleBrowser = savedBrowser
        }
        // Check Google connection after a delay
        Qt.callLater(_checkGoogleConnection)
    }

    // Detect system default browser
    Process {
        id: _detectDefaultBrowserProc
        command: ["/usr/bin/xdg-settings", "get", "default-web-browser"]
        stdout: SplitParser {
            onRead: line => {
                // Parse "firefox.desktop" -> "firefox", "google-chrome.desktop" -> "chrome"
                const desktop = line.trim().toLowerCase()
                let browser = ""
                if (desktop.includes("firefox")) browser = "firefox"
                else if (desktop.includes("google-chrome")) browser = "chrome"
                else if (desktop.includes("chromium")) browser = "chromium"
                else if (desktop.includes("brave")) browser = "brave"
                else if (desktop.includes("vivaldi")) browser = "vivaldi"
                else if (desktop.includes("opera")) browser = "opera"
                else if (desktop.includes("edge")) browser = "edge"
                else if (desktop.includes("zen")) browser = "zen"
                
                if (browser && !Config.options?.sidebar?.ytmusic?.browser) {
                    root.googleBrowser = browser
                    root.defaultBrowser = browser
                }
            }
        }
    }
    
    property string defaultBrowser: ""

    // Detect installed browsers by checking config folders
    Process {
        id: _detectBrowsersProc
        command: ["/bin/bash", "-c", `
            for path in ~/.mozilla/firefox ~/.config/google-chrome ~/.config/chromium ~/.config/BraveSoftware ~/.config/vivaldi ~/.config/opera ~/.config/microsoft-edge ~/.zen ~/.librewolf ~/.floorp ~/.waterfox; do
                [ -d "$path" ] && echo "$path"
            done
        `]
        stdout: SplitParser {
            onRead: line => {
                const path = line.trim()
                if (path.includes("firefox") || path.includes("mozilla")) root.detectedBrowsers.push("firefox")
                else if (path.includes("google-chrome")) root.detectedBrowsers.push("chrome")
                else if (path.includes("chromium")) root.detectedBrowsers.push("chromium")
                else if (path.includes("BraveSoftware")) root.detectedBrowsers.push("brave")
                else if (path.includes("vivaldi")) root.detectedBrowsers.push("vivaldi")
                else if (path.includes("opera")) root.detectedBrowsers.push("opera")
                else if (path.includes("microsoft-edge")) root.detectedBrowsers.push("edge")
                else if (path.includes(".zen")) root.detectedBrowsers.push("zen")
                else if (path.includes("librewolf")) root.detectedBrowsers.push("librewolf")
                else if (path.includes("floorp")) root.detectedBrowsers.push("floorp")
                else if (path.includes("waterfox")) root.detectedBrowsers.push("waterfox")
            }
        }
    }

    function _addToRecentSearches(query): void {
        let recent = root.recentSearches.filter(s => s.toLowerCase() !== query.toLowerCase())
        recent.unshift(query)
        if (recent.length > root.maxRecentSearches) {
            recent = recent.slice(0, root.maxRecentSearches)
        }
        root.recentSearches = recent
        _persistRecentSearches()
    }

    function _persistRecentSearches(): void {
        Config.setNestedValue('sidebar.ytmusic.recentSearches', root.recentSearches)
    }

    function _persistQueue(): void {
        Config.setNestedValue('sidebar.ytmusic.queue', root.queue)
    }

    function _persistPlaylists(): void {
        Config.setNestedValue('sidebar.ytmusic.playlists', root.playlists)
    }

    function _checkGoogleConnection(): void {
        _googleCheckProc.running = true
    }

    Timer {
        id: _playDelayTimer
        interval: 200
        onTriggered: _playProc.running = true
    }

    // Auto-play next when track ends
    Connections {
        target: root._mpvPlayer
        enabled: root._mpvPlayer !== null
        
        function onPlaybackStateChanged() {
            // When mpv stops and we have queue items, play next
            if (root._mpvPlayer && !root._mpvPlayer.isPlaying && 
                root.currentVideoId && root.queue.length > 0) {
                // Small delay to distinguish between pause and track end
                _autoNextTimer.restart()
            } else {
                _autoNextTimer.stop()
            }
        }
    }

    Timer {
        id: _autoNextTimer
        interval: 500
        onTriggered: {
            // Double-check mpv is really stopped (not just paused)
            if (root._mpvPlayer && !root._mpvPlayer.isPlaying && root.queue.length > 0) {
                root.playNext()
            }
        }
    }

    // Check if yt-dlp is available
    Process {
        id: _checkAvailability
        command: ["/usr/bin/which", "yt-dlp"]
        onExited: (code) => {
            root.available = (code === 0)
        }
    }

    // Check Google account connection using Python helper script
    Process {
        id: _googleCheckProc
        property string outputData: ""
        command: ["/usr/bin/python3",
            Quickshell.workingDirectory + "/scripts/ytmusic_auth.py",
            root.customCookiesPath ? "" : root.googleBrowser  // Empty if using custom cookies
        ]
        stdout: SplitParser {
            onRead: line => {
                _googleCheckProc.outputData += line
            }
        }
        onStarted: { 
            outputData = ""
            root.googleChecking = true
        }
        onExited: (code) => {
            root.googleChecking = false
            try {
                const result = JSON.parse(outputData)
                if (result.status === "success") {
                    root.googleConnected = true
                    root.googleError = ""
                    // Auto-fetch library on successful connection
                    root.fetchLibrary()
                } else {
                    root.googleConnected = false
                    root.googleError = result.message || Translation.tr("Connection failed")
                }
            } catch (e) {
                root.googleConnected = false
                root.googleError = Translation.tr("Failed to verify connection. Make sure yt-dlp is installed.")
            }
        }
    }

    // Search YouTube
    Process {
        id: _searchProc
        command: ["/usr/bin/yt-dlp",
            ...(root.googleConnected ? root._cookieArgs : []),
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            `ytsearch${root.maxSearchResults}:${root._searchQuery}`
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id) {
                        root.searchResults = [...root.searchResults, {
                            videoId: data.id,
                            title: data.title || "Unknown",
                            artist: data.channel || data.uploader || "",
                            duration: data.duration || 0,
                            thumbnail: root._getThumbnailUrl(data.id),
                            url: data.url || `https://www.youtube.com/watch?v=${data.id}`
                        }]
                    }
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (!running) root.searching = false
        }
        onExited: (code) => {
            if (code !== 0 && root.searchResults.length === 0) {
                root.error = Translation.tr("Search failed. Check your connection.")
            }
        }
    }

    // Stop any existing mpv playback
    Process {
        id: _stopProc
        command: ["/usr/bin/pkill", "-f", "mpv.*--no-video"]
    }

    // Play audio via mpv (exposes MPRIS)
    Process {
        id: _playProc
        command: ["/usr/bin/mpv",
            "--no-video",
            "--really-quiet",
            "--force-media-title=" + root.currentTitle,
            "--script-opts=ytdl_hook-ytdl_path=yt-dlp",
            ...(root.googleConnected ? ["--ytdl-raw-options=" + root._mpvCookieArgs] : []),
            root._playUrl
        ]
        onRunningChanged: {
            if (running) {
                root.loading = false
            }
        }
        onExited: (code) => {
            root.loading = false
            if (code !== 0 && code !== 4 && code !== 9 && code !== 15) { // 9=KILL, 15=TERM
                root.error = Translation.tr("Playback failed")
            }
        }
    }

    // Fetch YouTube Music playlists from account
    Process {
        id: _ytPlaylistsProc
        property var results: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            "https://music.youtube.com/library/playlists"
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id && data.title) {
                        _ytPlaylistsProc.results.push({
                            id: data.id,
                            title: data.title,
                            url: data.url || `https://music.youtube.com/playlist?list=${data.id}`,
                            count: data.playlist_count || 0
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { results = [] }
        onRunningChanged: {
            if (!running) {
                root.ytMusicPlaylists = results
                // Only stop library loading if liked songs is also done
                if (!_likedSongsProc.running) root.libraryLoading = false
            }
        }
    }

    // Import a YouTube Music playlist
    Process {
        id: _importPlaylistProc
        property var items: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            root._importPlaylistUrl
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id) {
                        _importPlaylistProc.items.push({
                            videoId: data.id,
                            title: data.title || "Unknown",
                            artist: data.channel || data.uploader || "",
                            duration: data.duration || 0,
                            thumbnail: root._getThumbnailUrl(data.id)
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { items = [] }
        onRunningChanged: {
            if (!running && items.length > 0) {
                root.playlists = [...root.playlists, {
                    name: root._importPlaylistName,
                    items: items
                }]
                root._persistPlaylists()
                root.searching = false
            }
        }
    }
    
    // Fetch Liked Songs from YouTube Music
    Process {
        id: _likedSongsProc
        property var items: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            "-I", "1:100",  // Limit to first 100 liked songs for performance
            "https://music.youtube.com/playlist?list=LM"
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id) {
                        _likedSongsProc.items.push({
                            videoId: data.id,
                            title: data.title || "Unknown",
                            artist: data.channel || data.uploader || "",
                            duration: data.duration || 0,
                            thumbnail: root._getThumbnailUrl(data.id)
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { items = [] }
        onRunningChanged: {
            if (!running) {
                if (items.length > 0) {
                    // Check if "Liked Songs" playlist already exists
                    const existingIdx = root.playlists.findIndex(p => p.name === "Liked Songs")
                    if (existingIdx >= 0) {
                        // Update existing
                        let p = [...root.playlists]
                        p[existingIdx].items = items
                        root.playlists = p
                    } else {
                        // Create new
                        root.playlists = [...root.playlists, {
                            name: "Liked Songs",
                            items: items
                        }]
                    }
                    root._persistPlaylists()
                }
                // Only stop library loading if playlists is also done
                if (!_ytPlaylistsProc.running) root.libraryLoading = false
            }
        }
    }
}
