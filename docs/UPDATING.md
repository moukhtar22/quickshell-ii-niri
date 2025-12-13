# Updating ii-niri

ii-niri respects your configurations. Updates never modify your personal settings without explicit consent.

## Quick Update

```bash
cd ~/path/to/ii-niri
git pull
./setup update
```

That's it. Your shell code is updated, your configs are untouched.

## Smart Updates

The update system is intelligent:

```bash
./setup update
```

- Compares your installed version with the repository
- Only syncs files if there are actual changes
- Shows what version you're updating from/to
- Never touches your personal configs

If you're already up to date:
```
✓ Already up to date
  Version: 2.1.0 (abc1234)
```

## Check Status

```bash
./setup status
```

Shows:
- Installed version and commit
- Repository version (what you have locally)
- Remote version (latest on GitHub)
- Pending migrations
- Available backups

Example output:
```
ii-niri Version Status

  Installed:  2.0.0 (abc1234)
  Repository: 2.1.0 (def5678)

  → Repository has newer version
    Run: ./setup update

Checking remote...
  ✓ Latest release: v2.1.0

Migration Status

  ✓ 001-gamemode-animation-toggle
  ✓ 002-backdrop-layer-rules
  ● 009-new-feature (pending)

Applied: 8 | Skipped: 0 | Pending: 1

Backups:
  - 2025-12-13-143052
  - 2025-12-10-091500
```

## View Changelog

```bash
./setup changelog
```

Shows recent changes and release notes. Useful to see what's new before updating.

```bash
./setup changelog 100  # Show more lines
```

## What `update` Does

1. **Compares versions** - checks if update is needed
2. **Syncs QML code** to `~/.config/quickshell/ii/`
3. **Checks for new dependencies** and installs them
4. **Updates version tracking** for future comparisons
5. **Shows pending migrations** (if any)

What it does NOT do:
- Modify `~/.config/niri/config.kdl`
- Modify `~/.config/illogical-impulse/config.json`
- Change any of your personal settings

## Optional Migrations

New features sometimes need config changes. These are handled separately:

```bash
./setup migrate
```

This shows you:
- What each migration does
- Exactly what will change in your files
- Lets you choose which to apply

### Example Migration Flow

```
╔══════════════════════════════════════════════════════════════╗
║              ii-niri Configuration Migrations                ║
╚══════════════════════════════════════════════════════════════╝

Found 3 pending migration(s).

┌─ Migration: 004-audio-keybinds-ipc
│
│  Title: Audio Keybinds with OSD
│  File:  ~/.config/niri/config.kdl
│
│  Updates audio keybinds to use ii-niri IPC instead of wpctl.
│  This shows an on-screen display when changing volume.
│
│  Changes:
│    - XF86AudioRaiseVolume { spawn "wpctl" ... }
│    + XF86AudioRaiseVolume { spawn "qs" "-c" "ii" "ipc" "call" "audio" "volumeUp" }
│
└──────────────────────────────

Apply this migration? [y/n/v/a/q]
```

Options:
- `y` - Apply this migration
- `n` - Skip (won't ask again)
- `v` - View full diff
- `a` - Apply all remaining
- `q` - Quit (can continue later)

## Automatic Backups

Before any config change, ii-niri creates a backup:

```
~/.config/illogical-impulse/backups/
└── 2025-12-13-143052/
    ├── niri-config.kdl
    └── config.json
```

### Restore from Backup

```bash
# List available backups
./setup restore

# Restore specific backup
./setup restore 2025-12-13-143052
```

## TUI Mode

Run `./setup` without arguments for an interactive menu:

```
┌──────────────────────────────────────────────┐
│     illogical-impulse on Niri                │
│     Setup & Management                       │
└──────────────────────────────────────────────┘

What would you like to do?
> Install
  Update
  Status
  Migrate Configs
  Changelog
  Help
  Exit
```

## Philosophy

1. **Your configs are yours** - We never modify them without asking
2. **Transparency** - You see exactly what will change before it happens
3. **Reversibility** - Automatic backups, easy restore
4. **Opt-in features** - New features via migrations are optional
5. **Smart updates** - Only sync when there are actual changes

## Troubleshooting

### Something broke after update

```bash
# Restore your configs
./setup restore

# Or manually restore from backup
cp ~/.config/illogical-impulse/backups/TIMESTAMP/niri-config.kdl ~/.config/niri/config.kdl
```

### Want to re-apply a skipped migration

Edit `~/.config/illogical-impulse/migrations.json` and remove the migration ID from the "skipped" array, then run `./setup migrate` again.

### Force update even if versions match

```bash
# Pull latest changes first
git pull

# Force reinstall of files
./setup install-files
```

### Check what version you have

```bash
./setup status
# or
cat ~/.config/illogical-impulse/version.json
```

### Force fresh install behavior

```bash
./setup install --firstrun
```

This will backup existing configs and install fresh defaults.
