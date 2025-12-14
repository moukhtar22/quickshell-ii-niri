# Setup & Updates

## Install

```bash
git clone https://github.com/snowarch/quickshell-ii-niri.git
cd quickshell-ii-niri
./setup install
```

Add `-y` for non-interactive mode.

## Update

```bash
git pull
./setup update
```

Updates QML code only. Your configs stay untouched. If there are new optional features (migrations), you'll be asked if you want to apply them.

## What Gets Installed

| Source | Destination |
|--------|-------------|
| QML code | `~/.config/quickshell/ii/` |
| Niri config | `~/.config/niri/config.kdl` |
| ii config | `~/.config/illogical-impulse/config.json` |
| GTK/Qt themes | `~/.config/gtk-*/`, `~/.config/kdeglobals` |

On first install, existing configs are backed up as `.old`. On updates, new defaults go to `.new` files - your configs are never overwritten.

## Commands

```bash
./setup              # Interactive menu
./setup install      # Full install
./setup update       # Sync QML code
./setup status       # Show versions and pending migrations
./setup migrate      # Apply optional config migrations
./setup restore      # Restore from backup
./setup changelog    # Show recent changes
```

## Migrations

Some features need config changes (new keybinds, layer rules, etc). These are optional and handled separately:

- After `update`, you're asked if you want to apply pending migrations
- Each migration shows exactly what will change
- Automatic backup before any change
- Skip if you prefer to manage configs manually

## Backups

Backups are created automatically before config changes:
```
~/.config/illogical-impulse/backups/<timestamp>/
```

Restore with `./setup restore <timestamp>`.

## Uninstall

```bash
# Stop ii from starting
# Comment out in ~/.config/niri/config.kdl:
# spawn-at-startup "qs" "-c" "ii"

# Remove configs
rm -rf ~/.config/quickshell/ii
rm -rf ~/.config/illogical-impulse
```
