# Omarchy 4 Setup

Personal setup script for a fresh Omarchy installation.

Based on the checklist in `Omarchy Quattro Start.md`.

## Usage

```bash
# Run the setup
./omarchy4-setup.sh

# Preview without making changes
DRY_RUN=true ./omarchy4-setup.sh
```

## What it does

| # | Task | Method |
|---|------|--------|
| 1 | Remove all preinstalled apps | `omarchy remove preinstalls` |
| 2 | Install browser extensions | Chromium managed policy |
| 3 | Install web apps | `omarchy webapp install` |
| 4 | Install desktop apps | `omarchy pkg add` |
| 5 | Enable Active Window plugin | `omarchy plugin enable` |
| 6 | Disable Omarchy menu plugin | `omarchy plugin disable` |
| 7 | Monitor scaling 1x | `monitors.lua` |
| 8 | Terminal font size 12 | `foot.ini` |
| 9 | DuckDuckGo default search | Chromium policy |
| 10 | SUPER+Q close window | `bindings.lua` |
| 11 | Remove ufw-docker + docker | `omarchy pkg drop` |
| 12 | SSH key (ed25519) | `ssh-keygen` + `ssh-add` |
| 13-16 | Keyboard & touchpad | `input.lua` |
| 17 | Screensaver off | `omarchy toggle screensaver off` |
| 18 | SUPER+SHIFT+O: Obsidian | `bindings.lua` |
| 19 | Nvim relative numbers | `init.lua` |
| 20 | batctl-tui-bin | `omarchy pkg aur add` |
| 21 | Gruvbox theme | `omarchy theme set` |
| 22 | Default agent OpenCode | `omarchy default agent` |

## Manual steps after running

1. Open Chromium once so policies apply (DuckDuckGo default + extensions), then sign in to Proton Pass and pin it
2. Configure bat thresholds: `sudo batctl`
3. Add SSH key to GitHub:
   ```
   cat ~/.ssh/id_ed25519.pub
   ```
   Then go to https://github.com/settings/ssh/new (title: OMARCHY)
