# Changelog

All notable changes to iNiR will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.0] - 2026-01-03

### Added
- **Reddit tab**: Browse subreddits in sidebar left (disabled by default)
- **Anime Schedule tab**: View anime schedule, seasonal, and top airing from Jikan API (disabled by default)
- **NerdIconMap entries**: Added collections, photo_library, live_tv, tv, movie icons

### Changed
- Wallhaven tab icon changed to `collections` for better Nerd Font glyph in inir style
- Card style toggle now available for inir global style

### Fixed
- Inir button colors in Reddit/Anime tabs using valid color properties
- AnimeCard type badge and genre tags with proper inir container colors
- Optional chaining in Workspaces.qml (`bar?.workspaces`)
- Number style selector disabled when 'Always show numbers' is off

## [2.4.0] - 2026-01-02

### Added
- **Timer pause persistence**: Pomodoro, stopwatch, and countdown now persist pause state across restarts
- **ContextCard timer idle view**: Navigate between Focus/Timer/Stopwatch with slide animations
- **Dock showOnDesktop option**: Control dock visibility when no window is focused
- **Quick Launch editor**: Inline editor in settings to customize quick launch shortcuts
- **Context card weather toggle**: Option to hide weather in context card
- **Cover art blur transition**: Smooth blur effect when track changes

### Changed
- Region search now uses 0x0.st (uguu.se was down)
- Settings search includes Global Style entries
- Faster settings page preloading for search indexing
- Search results show breadcrumb path with chevron icons

### Fixed
- Dock context menu now keeps dock visible while open
- StyledPopup supports buttonHovered fallback for RippleButton
- WeekStrip scroll fixed with acceptedButtons: Qt.NoButton
- NotificationAppIcon safer image error handling
- Aurora colors for workspaces occupied indicator
- Calendar other-month text color in aurora style
- ConfigSelectionArray includes option names in search

## [2.3.0] - 2026-01-01

### Added
- **Dock multi-position**: Dock can now be placed at top, bottom, left, or right
- **Aurora style**: Glass effect with wallpaper blur for panels and popups
- **Inir style**: TUI-inspired style with accent borders and darker colors
- **Voice search**: Voice input with Gemini transcription
- **QuickWallpaper widget**: Quick wallpaper picker in sidebar
- **Wallpaper fill modes**: Stretch, fit, fill, tile options
- **Free OpenRouter models**: Dynamically loaded free AI models
- **Weather forecast**: wttr.in fallback with forecast display
- **Separate dock icon theme**: Independent icon theme for dock

### Changed
- Sidebar animations improved with slide effects
- Lock screen now falls back to swaylock on Niri (avoids crash)
- Cover art download now has retry with exponential backoff
- Improved transparency system for aurora style

### Fixed
- Cover art URLs no longer use query strings (Qt Image compatibility)
- Sidebar widget buttons now work during drag detection
- Aurora style uses solid colors for popups without blur
- Weather retries on startup network issues
- NiriKeybinds config watcher debounced
- Network monitor delayed until component ready
- Dock binding loops and hover behavior
- Lock activates before suspend when configured
- Calendar respects locale's firstDayOfWeek

## [2.2.0] - 2025-12-14

### Added
- Snapshot system for time-machine style rollbacks
- `./setup rollback` command to restore previous states
- Auto git fetch and pull in update command
- Doctor now auto-starts shell if not running
- Fish shell added to core dependencies
- EasyEffects added to audio dependencies

### Changed
- Simplified setup to 4 commands: install, update, doctor, rollback
- Update now checks remote for new commits before syncing
- Update creates snapshot automatically before applying changes
- Doctor now fixes issues automatically (uv pip, version tracking, manifest)
- Removed redundant commands (install-deps, migrate, status, changelog, restore)

### Fixed
- Doctor now uses `uv pip` instead of `pip` for Python package checks
- Update now properly restarts shell after sync
- Backup directory no longer created when empty

## [2.1.0] - 2025-12-14

### Added
- New versioning system with proper version tracking
- `./setup status` command shows installed vs available version
- `./setup changelog` command to view recent changes
- Smart update detection - only syncs when there are actual changes
- Version comparison with remote repository
- Cached remote version checks (1 hour TTL)

### Changed
- Improved `./setup update` to check for changes before syncing
- Better migration system with clearer separation from installation
- Enhanced status output with pending migrations count

### Fixed
- Pomodoro timer now properly syncs with Config changes
- Volume slider maintains sync with external changes (keybinds)
- GameMode state now persists across shell restarts

## [2.0.0] - 2025-12-10

### Added
- Migration system for safe config updates
- `./setup migrate` command for interactive config migrations
- Automatic backups before any config modification
- `./setup restore` command to restore from backups
- Support for both Material (ii) and Fluent (waffle) panel families

### Changed
- `./setup update` now only syncs QML code, never touches user configs
- Migrations are now optional and interactive
- Improved first-run detection and handling

### Philosophy
- User configs are sacred - never modified without explicit consent
- Transparency - users see exactly what will change
- Reversibility - automatic backups, easy restore

## [1.0.0] - 2025-11-01

### Added
- Initial release of iNiR
- Material Design (ii) panel family
- Windows 11 style (waffle) panel family
- System tray with smart activation
- Notifications with Do Not Disturb
- Media controls (MPRIS)
- Workspace management
- Quick settings panel
- Lockscreen
- Game mode for reduced latency
- Hot-reload for development

---

For older changes, see git history: `git log --oneline`
