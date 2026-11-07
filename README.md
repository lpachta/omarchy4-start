# Omarchy 4 Setup

Personal setup script for a fresh Omarchy installation.

Based on the checklists in `Omarchy Quattro Start.md` and `~/Documents/omarchy-start.md`.

## Usage

```bash
# Interactive: confirm every change with the Omarchy-style gum prompt
./omarchy4-setup.sh

# Unattended: answer yes to everything (the original behavior)
./omarchy4-setup.sh --noconfirm

# Preview without making changes
DRY_RUN=true ./omarchy4-setup.sh
```

Each change is confirmable the Omarchy way: the script uses `gum confirm`
(themed by the active Omarchy theme) and skips any step you decline. With
`--noconfirm` (or `DRY_RUN=true`) it runs straight through, and if there is no
interactive terminal it refuses to make changes unless `--noconfirm` is set.

## What it does

| # | Task | Method |
|---|------|--------|
| 1 | Remove all preinstalled apps | `omarchy remove preinstalls` |
| 2 | Chromium policies: DuckDuckGo default, extensions, no password manager, smooth scrolling off | Chromium managed policy |
| 3 | Install web apps (auto-fetched icons) | `omarchy webapp install` |
| 4 | Install desktop apps (incl. `felix-rs` TUI file manager) | `omarchy pkg add` |
| 5 | Enable Active Window plugin | `omarchy plugin enable` |
| 6 | Disable Omarchy menu plugin | `omarchy plugin disable` |
| 7 | Remove Elsewhen (world clock) plugin | `omarchy plugin disable` |
| 8 | Monitor scaling 1x | `monitors.lua` |
| 9 | Foot font size 14 | `foot.ini` |
| 10 | Disable Hyprland animations | `looknfeel.lua` |
| 11 | SUPER+Q close window | `bindings.lua` |
| 12 | Remove ufw-docker + docker | `omarchy pkg drop` |
| 13 | SSH key (ed25519) + route `github.com` to it only | `ssh-keygen` + `~/.ssh/config` |
| 14 | Keyboard & touchpad | `input.lua` |
| 15 | Screensaver off | `omarchy toggle screensaver off` |
| 16 | SUPER+SHIFT+O: Obsidian | `bindings.lua` |
| 17 | Nvim relative line numbers | `init.lua` |
| 18 | Nvim indentation 4 spaces (editor + formatters) | `options.lua`, `formatting.lua`, `stylua.toml`, `.editorconfig`, `.clang-format` |
| 19 | Install LazyExtras: clangd + dap.core | `lazyvim.json` |
| 20 | batctl-tui-bin | `omarchy pkg aur add` |
| 21 | Remove `~/Wallpapers` and `~/Work/tries` | `rm -rf` |
| 22 | Fingerprint authentication | `omarchy setup security fingerprint` |
| 23 | Gruvbox theme | `omarchy theme set` |
| 24 | Global Node.js version in mise (fixes the `node` shim) | `mise use -g --pin node` |
| 25 | Default agent OpenCode | `omarchy default agent` |

The browser extensions force-installed via policy are: Proton Pass, uBlock
Origin Lite, SponsorBlock, Unhook, Vimium, and Dark Reader.

## Manual steps after running

When run interactively, the script offers to walk through these one by one
(opening Chromium, copying the SSH key and opening GitHub, and configuring
battery thresholds in a floating terminal). With `--noconfirm` they are only
printed.

1. Open Chromium once so the policies apply (DuckDuckGo default, extensions, no
   password manager, smooth scrolling off), then sign in to Proton Pass and Dark
   Reader and pin the extensions
2. Add your SSH key to GitHub (title: OMARCHY):
   ```
   cat ~/.ssh/id_ed25519.pub
   ```
   Then go to https://github.com/settings/ssh/new
3. Enroll your fingerprint: `omarchy setup security fingerprint`
4. Configure battery charge thresholds (40-80%): `sudo batctl`
