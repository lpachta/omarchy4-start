# Omarchy 4 Setup

Personal setup script for a fresh Omarchy installation.

Based on the checklists in `Omarchy Quattro Start.md` and `~/Documents/omarchy-start.md`.

## Usage

```bash
# Interactive: pick steps from a numbered list, confirm once, then run
./omarchy4-setup.sh

# Unattended: run every step (no list, no prompts)
./omarchy4-setup.sh --noconfirm

# Just print the numbered step list
./omarchy4-setup.sh --list

# Preview without making changes
DRY_RUN=true ./omarchy4-setup.sh
```

Instead of asking after every step, the script prints the whole list and lets
you choose what to run, pacman-style:

- `Enter` (or `all`) runs everything
- `1 3 5-8` runs only those steps
- `^4 ^10-12` (or `-4 -10-12`) runs everything except those
- `1-10 ^4` includes a range, then excludes from it

It then shows the selected steps and asks once: `Proceed?`. With `--noconfirm`
(or `DRY_RUN=true`) it runs straight through, and if there is no interactive
terminal it refuses to choose steps unless `--noconfirm` is set.

## What it does

| # | Task | Method |
|---|------|--------|
| 1 | Remove all preinstalled apps | `omarchy remove preinstalls` |
| 2 | Chromium policies: DuckDuckGo default, extensions, no password manager, smooth scrolling off | Chromium managed policy |
| 3 | Install web apps (auto-fetched icons) | `omarchy webapp install` |
| 4 | Install desktop apps (incl. `felix-rs` TUI file manager) | `omarchy pkg add` |
| 5 | Remove ufw-docker + docker | `omarchy pkg drop` |
| 6 | batctl-tui-bin | `omarchy pkg aur add` |
| 7 | Remove `~/Wallpapers` and `~/Work/tries` | `rm -rf` |
| 8 | Monitor scaling 1x | `monitors.lua` |
| 9 | Disable Hyprland animations | `looknfeel.lua` |
| 10 | SUPER+Q close window | `bindings.lua` |
| 11 | Keyboard & touchpad | `input.lua` |
| 12 | SUPER+SHIFT+O: Obsidian | `bindings.lua` |
| 13 | Foot font size 14 | `foot.ini` |
| 14 | Nvim relative line numbers | `init.lua` |
| 15 | Nvim indentation 4 spaces (editor + formatters) | `options.lua`, `formatting.lua`, `stylua.toml`, `.editorconfig`, `.clang-format` |
| 16 | Install LazyExtras: clangd + dap.core | `lazyvim.json` |
| 17 | Disable Neovim spell checking | `autocmds.lua` |
| 18 | Gruvbox theme | `omarchy theme set` |
| 19 | Enable Active Window plugin | `omarchy plugin enable` |
| 20 | Disable Omarchy menu plugin | `omarchy plugin disable` |
| 21 | Remove Elsewhen (world clock) plugin | `omarchy plugin disable` |
| 22 | Remove Agents plugin | `omarchy plugin disable` |
| 23 | Remove Superwhisper package + shell plugin | `omarchy plugin remove`, `omarchy pkg drop` |
| 24 | Move keyboard layout next to the clock | `omarchy bar move` |
| 25 | Screensaver off | `omarchy toggle screensaver off` |
| 26 | SSH key (ed25519) + route `github.com` to it only | `ssh-keygen` + `~/.ssh/config` |
| 27 | Fingerprint authentication | `omarchy setup security fingerprint` |
| 28 | Global Node.js version in mise (fixes the `node` shim) | `mise use -g --pin node` |
| 29 | Default agent OpenCode | `omarchy default agent` |
| 30 | fzf skips hidden folders except `.config` | `~/.bashrc` |

The browser extensions force-installed via policy are: Proton Pass, uBlock
Origin Lite, SponsorBlock, Unhook, Vimium, and Dark Reader.

## Manual steps after running

When run interactively, the script offers the runnable ones as the same
numbered list (open Chromium, copy the SSH key and open GitHub, and configure
battery thresholds in a floating terminal), so you can pick them with the same
number/range/`^` syntax and confirm once. With `--noconfirm` they are only
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
