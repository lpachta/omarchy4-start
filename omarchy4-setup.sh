#!/usr/bin/env bash
# Omarchy 4 personal setup script
#
# Turns a fresh Omarchy installation into this machine's personal setup.
# Based on the checklist in "Obsidian Vault/1. Prchavé poznámky/Omarchy Quattro Start.md"
# and the follow-up list in "~/Documents/omarchy-start.md".
#
# Idempotent: safe to re-run. Uses omarchy CLI commands where possible.
# Requires: a sudo user on Omarchy (Hyprland optional for hyprctl reload at the end).
#
# Usage:
#   ./omarchy4-setup.sh              # ask before every change (gum confirm)
#   ./omarchy4-setup.sh --noconfirm  # unattended, like the original script
#   DRY_RUN=true ./omarchy4-setup.sh # preview commands without executing them

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES=false

GITHUB_EMAIL="lukin.pachta@proton.me"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '\033[1;38;5;75m>>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;38;5;114m  ✓\033[0m %s\n' "$*"; }
skip()  { printf '\033[1;38;5;243m  - %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;38;5;214m  ! %s\033[0m\n' "$*"; }

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '\033[1;38;5;243m  [dry-run] %s\033[0m\n' "$*"
  else
    "$@"
  fi
}

# Ask for confirmation the omarchy way (gum confirm, themed by the active theme).
# Autopilot when --noconfirm/DRY_RUN is set; otherwise require an interactive
# terminal so a piped/CI run cannot make changes silently.
confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" == true || "$DRY_RUN" == true ]]; then
    return 0
  fi
  if [[ -t 0 && -t 1 ]] && command -v gum &>/dev/null; then
    gum confirm "$prompt"
  else
    warn "refusing to continue without confirmation; re-run with --noconfirm"
    exit 1
  fi
}

write_file() {
  local file="$1"
  if [[ "$DRY_RUN" == true ]]; then
    printf '\033[1;38;5;243m  [dry-run] write %s\033[0m\n' "$file"
    cat
  else
    cat > "$file"
  fi
}

append_file() {
  local file="$1"
  if [[ "$DRY_RUN" == true ]]; then
    printf '\033[1;38;5;243m  [dry-run] append %s\033[0m\n' "$file"
    cat
  else
    cat >> "$file"
  fi
}

write_file_sudo() {
  local file="$1"
  if [[ "$DRY_RUN" == true ]]; then
    printf '\033[1;38;5;243m  [dry-run] write %s (sudo)\033[0m\n' "$file"
    cat
  else
    sudo bash -c 'cat > "$1"' _ "$file"
  fi
}

# Export the active theme's gum styling so prompts match the theme even after a
# theme switch (the session environment is captured once at login).
if command -v omarchy-restart-gum &>/dev/null; then
  # shellcheck disable=SC1091
  source omarchy-restart-gum 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Chromium extension IDs
# ---------------------------------------------------------------------------
EXTENSION_IDS=(
  "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
  "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
  "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
  "khncfooichmfjbepaaaebmommgaepoid" # Unhook
  "ccnheoamhddmjhgpmgganjnibcnhkndp" # Vimium
  "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
)

# ---------------------------------------------------------------------------
# 1. Remove all preinstalled apps
# ---------------------------------------------------------------------------
step_remove_preinstalls() {
  info "1. Remove all preinstalled apps"
  if [[ -f "$HOME/.local/state/omarchy/preinstalls-removed" ]]; then
    skip "preinstalls already removed"
    return 0
  fi
  confirm "Remove all preinstalled apps?" || { skip "skipped"; return 0; }
  run omarchy remove preinstalls
}

# ---------------------------------------------------------------------------
# 2. Install browser extensions + DuckDuckGo default search engine
#    Plus: disable the Chromium password manager, disable smooth scrolling
#    (for Vimium) -- Chromium managed policy
# ---------------------------------------------------------------------------
step_chromium_policies() {
  info "2. Chromium policies (DuckDuckGo + extensions + privacy)"

  local policy_dir="/etc/chromium/policies/managed"
  local policy_file="$policy_dir/omarchy-setup.json"

  local ext_json=""
  local total=${#EXTENSION_IDS[@]} i=0
  for id in "${EXTENSION_IDS[@]}"; do
    i=$((i + 1))
    if (( i < total )); then
      ext_json+="    \"$id\": {\"installation_mode\": \"force_installed\", \"update_url\": \"https://clients2.google.com/service/update2/crx\"},\n"
    else
      ext_json+="    \"$id\": {\"installation_mode\": \"force_installed\", \"update_url\": \"https://clients2.google.com/service/update2/crx\"}\n"
    fi
  done

  confirm "Write Chromium managed policies (search, extensions, no password manager, no smooth scroll)?" || { skip "skipped"; return 0; }

  run sudo mkdir -p "$policy_dir"
  local policy_json
  policy_json=$(printf '{\n  "DefaultSearchProviderEnabled": true,\n  "DefaultSearchProviderName": "DuckDuckGo",\n  "DefaultSearchProviderIconURL": "https://duckduckgo.com/favicon.ico",\n  "DefaultSearchProviderEncodings": ["UTF-8"],\n  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",\n  "DefaultSearchProviderSuggestURL": "https://duckduckgo.com/ac/?q={searchTerms}&type=list",\n  "DefaultSearchProviderNewTabURL": "https://duckduckgo.com/chrome_newtab",\n  "PasswordManagerEnabled": false,\n  "PasswordLeakDetectionEnabled": false,\n  "AutofillAddressEnabled": false,\n  "AutofillCreditCardEnabled": false,\n  "SmoothScrollingEnabled": false,\n  "ExtensionSettings": {\n%b\n  }\n}\n' "$ext_json")
  printf '%s\n' "$policy_json" | write_file_sudo "$policy_file"
  ok "wrote $policy_file"
}

# ---------------------------------------------------------------------------
# 3. Install web apps (auto-fetch site icons so launcher images are not broken)
# ---------------------------------------------------------------------------
step_web_apps() {
  info "3. Install web apps (auto-fetched icons)"
  confirm "Install web apps (GitHub, Discord, WhatsApp, YouTube)?" || { skip "skipped"; return 0; }

  local apps=("GitHub:https://github.com/" "Discord:https://discord.com/app" "WhatsApp:https://web.whatsapp.com/" "YouTube:https://youtube.com/")
  local icon_dir="$HOME/.local/share/icons/hicolor"
  for entry in "${apps[@]}"; do
    local name="${entry%%:*}"
    local url="${entry#*:}"
    local desktop="$HOME/.local/share/applications/$name.desktop"
    local slug="${name,,}"

    # A web app is only "installed" if its launcher and its downloaded icon both
    # exist. The old script passed the app name as the icon, which resolved to
    # nothing and left the launcher with a broken image.
    if [[ -f "$desktop" ]] && ls "$icon_dir"/*/apps/"$slug".* &>/dev/null; then
      skip "$name web app already installed"
      continue
    fi

    [[ -f "$desktop" ]] && run rm -f "$desktop"
    # Empty icon argument -> omarchy fetches the site's own favicon.
    run omarchy webapp install "$name" "$url" "" && ok "installed $name web app"
  done
}

# ---------------------------------------------------------------------------
# 4. Install desktop apps
# ---------------------------------------------------------------------------
step_desktop_apps() {
  info "4. Install desktop apps"
  confirm "Install desktop apps (anki, obsidian, libreoffice, signal, felix-rs)?" || { skip "skipped"; return 0; }
  for pkg in anki obsidian libreoffice-fresh signal-desktop felix-rs; do
    if pacman -Qi "$pkg" &>/dev/null; then
      skip "$pkg already installed"
    else
      run omarchy pkg add "$pkg"
    fi
  done
}

# ---------------------------------------------------------------------------
# 5. Enable Quickshell plugin: Active Window
# 6. Disable Quickshell plugin: Omarchy menu
# ---------------------------------------------------------------------------
step_plugins() {
  info "5. Enable plugin: Active Window"
  if confirm "Enable the Active Window plugin?"; then
    run omarchy plugin enable omarchy.active-window 2>/dev/null || skip "active-window already enabled"
  else
    skip "skipped"
  fi

  info "6. Disable plugin: Omarchy menu"
  if confirm "Disable the Omarchy menu plugin?"; then
    run omarchy plugin disable omarchy.menu 2>/dev/null || skip "menu already disabled"
  else
    skip "skipped"
  fi
}

# ---------------------------------------------------------------------------
# 7. Set all monitor scaling to 1x
# ---------------------------------------------------------------------------
step_monitors() {
  info "7. Monitor scaling to 1"
  local mon="$HOME/.config/hypr/monitors.lua"
  if [[ -f "$mon" ]] && grep -q 'omarchy_monitor_scale = 1' "$mon"; then
    skip "monitor scaling already 1x"
    return 0
  fi
  confirm "Set monitor scaling to 1x?" || { skip "skipped"; return 0; }
  write_file "$mon" << 'EOF'
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
EOF
  ok "monitor scaling set to 1"
}

# ---------------------------------------------------------------------------
# 8. Set terminal font size to 14
# ---------------------------------------------------------------------------
step_terminal_font() {
  info "8. Foot font size 14"
  local ini="$HOME/.config/foot/foot.ini"
  [[ -f "$ini" ]] || { skip "foot config missing: $ini"; return 0; }
  if grep -q 'font=.*:size=14' "$ini"; then
    skip "font size already 14"
    return 0
  fi
  confirm "Set Foot font size to 14?" || { skip "skipped"; return 0; }
  run cp "$ini" "$ini.bak.$(date +%Y%m%d_%H%M%S)"
  run sed -i 's/font=.*:size=[0-9]*/font=JetBrainsMono Nerd Font:size=14/' "$ini"
  ok "foot font size set to 14"
}

# ---------------------------------------------------------------------------
# 9. Disable Hyprland animations
# ---------------------------------------------------------------------------
step_animations() {
  info "9. Disable Hyprland animations"
  local look="$HOME/.config/hypr/looknfeel.lua"
  [[ -f "$look" ]] || { skip "looknfeel.lua missing: $look"; return 0; }
  # Only an *uncommented* `animations = { ... enabled = false ... }` counts; the
  # stock file ships the same lines commented out as an example.
  if awk '
    /^[[:space:]]*animations[[:space:]]*=[[:space:]]*\{/ { inblock = 1 }
    inblock && /enabled[[:space:]]*=[[:space:]]*false/ { found = 1 }
    inblock && /^[[:space:]]*\}/ { inblock = 0 }
    END { exit(found ? 0 : 1) }
  ' "$look"; then
    skip "animations already disabled"
    return 0
  fi
  confirm "Disable Hyprland animations?" || { skip "skipped"; return 0; }
  run cp "$look" "$look.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$look" << 'EOF'

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
hl.config({
  animations = {
    -- Disable all animations.
    enabled = false,
  },
})
EOF
  ok "Hyprland animations disabled"
}

# ---------------------------------------------------------------------------
# 10. SUPER+Q to close window, unbind SUPER+W
# ---------------------------------------------------------------------------
step_close_window() {
  info "10. Close window: SUPER+Q"
  local bindings="$HOME/.config/hypr/bindings.lua"
  [[ -f "$bindings" ]] || { skip "bindings.lua missing: $bindings"; return 0; }
  if grep -q 'SUPER + Q.*Close window' "$bindings" 2>/dev/null; then
    skip "SUPER+Q already configured to close window"
    return 0
  fi
  confirm "Bind SUPER+Q to close window?" || { skip "skipped"; return 0; }
  run cp "$bindings" "$bindings.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$bindings" << 'EOF'

-- Close window: SUPER+Q (unbind defaults first)
hl.unbind("SUPER + Q")
hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
EOF
  ok "SUPER+Q bound to close window"
}

# ---------------------------------------------------------------------------
# 11. Remove ufw-docker and docker
# ---------------------------------------------------------------------------
step_docker() {
  info "11. Remove docker"
  confirm "Remove docker and ufw-docker?" || { skip "skipped"; return 0; }
  run omarchy pkg drop ufw-docker && \
  run omarchy pkg drop docker docker-buildx docker-compose && \
  ok "docker removed"
}

# ---------------------------------------------------------------------------
# 12. SSH key + config for GitHub
# ---------------------------------------------------------------------------
step_ssh() {
  info "12. SSH key (ed25519) + github.com config"
  confirm "Generate the GitHub SSH key and configure ~/.ssh/config?" || { skip "skipped"; return 0; }

  mkdir -p "$HOME/.ssh"
  run chmod 700 "$HOME/.ssh"

  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    skip "~/.ssh/id_ed25519 already exists"
  else
    run ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null
    ok "key generated"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    run eval 'ssh-agent -s'
    run ssh-add "$HOME/.ssh/id_ed25519"
  else
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true
  fi
  ok "key added to ssh-agent"

  # Use id_ed25519 (and only it) for github.com.
  local cfg="$HOME/.ssh/config"
  if [[ -f "$cfg" ]] && grep -q 'IdentityFile ~/.ssh/id_ed25519' "$cfg"; then
    skip "~/.ssh/config already routes github.com to id_ed25519"
    return 0
  fi
  [[ -f "$cfg" ]] && run cp "$cfg" "$cfg.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$cfg" << 'EOF'

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
  run chmod 600 "$cfg"
  ok "~/.ssh/config updated for github.com"
}

# ---------------------------------------------------------------------------
# 13. Keyboard & touchpad
# ---------------------------------------------------------------------------
step_input() {
  info "13. Keyboard & touchpad settings"
  local input="$HOME/.config/hypr/input.lua"
  [[ -f "$input" ]] || { skip "input.lua missing: $input"; return 0; }
  if grep -q 'caps:escape' "$input" 2>/dev/null; then
    skip "keyboard/touchpad settings already configured"
    return 0
  fi
  confirm "Apply Czech QWERTY keyboard and touchpad settings?" || { skip "skipped"; return 0; }
  run cp "$input" "$input.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$input" << 'EOF'

-- Czech QWERTY layout, Caps=Esc, Ins=Compose, Lv3=Ralt, natural scroll
hl.config({
  input = {
    kb_layout = "us,cz",
    kb_variant = ",qwerty",
    kb_options = "caps:escape,compose:ins,grp:alt_shift_toggle,lv3:ralt_switch",
    touchpad = {
      natural_scroll = true,
    },
  },
})
EOF
  ok "keyboard/touchpad settings applied"
}

# ---------------------------------------------------------------------------
# 14. Toggle screensaver to off
# ---------------------------------------------------------------------------
step_screensaver() {
  info "14. Disable screensaver"
  confirm "Disable the screensaver?" || { skip "skipped"; return 0; }
  run omarchy toggle screensaver off
}

# ---------------------------------------------------------------------------
# 15. Add frequent apps shortcuts: Super+Shift+O -> Obsidian
# ---------------------------------------------------------------------------
step_obsidian_shortcut() {
  info "15. Obsidian shortcut: SUPER+SHIFT+O"
  local bindings="$HOME/.config/hypr/bindings.lua"
  [[ -f "$bindings" ]] || { skip "bindings.lua missing: $bindings"; return 0; }
  if grep -q 'SUPER + SHIFT + O' "$bindings" 2>/dev/null; then
    skip "SUPER+SHIFT+O already bound to Obsidian"
    return 0
  fi
  confirm "Bind SUPER+SHIFT+O to Obsidian?" || { skip "skipped"; return 0; }
  run cp "$bindings" "$bindings.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$bindings" << 'EOF'

-- Frequent apps
hl.unbind("SUPER + O")
o.bind("SUPER + SHIFT + O", "Obsidian", "omarchy launch or focus obsidian obsidian")
EOF
  ok "SUPER+SHIFT+O bound to Obsidian"
}

# ---------------------------------------------------------------------------
# 16. Nvim: Enable relative line numbering
# ---------------------------------------------------------------------------
step_nvim() {
  info "16. Nvim relative line numbers"
  local init="$HOME/.config/nvim/init.lua"
  [[ -f "$init" ]] || { skip "nvim init.lua missing: $init"; return 0; }
  if grep -q 'relativenumber' "$init" 2>/dev/null; then
    skip "relative line numbers already enabled"
    return 0
  fi
  confirm "Enable relative line numbers in Neovim?" || { skip "skipped"; return 0; }
  run cp "$init" "$init.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$init" << 'EOF'
vim.wo.relativenumber = true
EOF
  ok "relative line numbers enabled"
}

# ---------------------------------------------------------------------------
# 17. Nvim: indentation size 8 (editor options + formatters)
# ---------------------------------------------------------------------------
step_nvim_indent() {
  info "17. Nvim indentation to 8 spaces (formatters included)"
  local nvim="$HOME/.config/nvim"
  [[ -d "$nvim" ]] || { skip "nvim config missing: $nvim"; return 0; }
  confirm "Set Neovim and its formatters to 8-space indentation?" || { skip "skipped"; return 0; }

  # Global editor options (append so Omarchy's own options are preserved).
  local options="$nvim/lua/config/options.lua"
  if [[ -f "$options" ]] && grep -q 'shiftwidth = 8' "$options"; then
    skip "options.lua already 8-space"
  elif [[ -f "$options" ]]; then
    run cp "$options" "$options.bak.$(date +%Y%m%d_%H%M%S)"
    append_file "$options" << 'EOF'

-- Indentation: 8 spaces everywhere
vim.opt.expandtab = true
vim.opt.tabstop = 8
vim.opt.shiftwidth = 8
vim.opt.softtabstop = 8

-- Keep the Python/YAML ftplugins from overriding the options above
vim.g.python_recommended_style = 0
vim.g.yaml_recommended_style = 0
EOF
    ok "options.lua updated"
  else
    skip "options.lua missing: $options"
  fi

  # conform.nvim formatter args (LazyVim defaults to 2 spaces).
  local fmt="$nvim/lua/plugins/formatting.lua"
  if [[ -f "$fmt" ]] && grep -q '"--indent-width", "8"' "$fmt"; then
    skip "formatting.lua already 8-space"
  else
    [[ -f "$fmt" ]] && run cp "$fmt" "$fmt.bak.$(date +%Y%m%d_%H%M%S)"
    write_file "$fmt" << 'EOF'
-- Make the formatters (conform.nvim) use 8-space indentation too.
-- LazyVim's defaults are 2 spaces, so these args override them.
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        stylua = { prepend_args = { "--indent-type", "Spaces", "--indent-width", "8" } },
        shfmt = { prepend_args = { "-i", "8" } },
        prettier = { prepend_args = { "--tab-width", "8", "--use-tabs", "false" } },
      },
    },
  },
}
EOF
    ok "formatting.lua updated"
  fi

  # stylua.toml
  local stylua="$nvim/stylua.toml"
  if [[ -f "$stylua" ]] && grep -q 'indent_width = 8' "$stylua"; then
    skip "stylua.toml already 8-space"
  else
    [[ -f "$stylua" ]] && run cp "$stylua" "$stylua.bak.$(date +%Y%m%d_%H%M%S)"
    write_file "$stylua" << 'EOF'
indent_type = "Spaces"
indent_width = 8
column_width = 120
EOF
    ok "stylua.toml updated"
  fi

  # Home-wide fallback read by Neovim and many formatters.
  local ec="$HOME/.editorconfig"
  if [[ -f "$ec" ]] && grep -q 'indent_size = 8' "$ec"; then
    skip ".editorconfig already 8-space"
  else
    [[ -f "$ec" ]] && run cp "$ec" "$ec.bak.$(date +%Y%m%d_%H%M%S)"
    write_file "$ec" << 'EOF'
# Applies to files below your home directory that don't have a closer
# .editorconfig of their own. Neovim and many formatters read this.
root = true

[*]
indent_style = space
indent_size = 8
tab_width = 8

[Makefile]
indent_style = tab

[*.{mak,mk}]
indent_style = tab
EOF
    ok ".editorconfig updated"
  fi

  # clangd / clang-format style.
  local cf="$HOME/.clang-format"
  if [[ -f "$cf" ]] && grep -q 'IndentWidth: 8' "$cf"; then
    skip ".clang-format already 8-space"
  else
    [[ -f "$cf" ]] && run cp "$cf" "$cf.bak.$(date +%Y%m%d_%H%M%S)"
    write_file "$cf" << 'EOF'
BasedOnStyle: LLVM
IndentWidth: 8
TabWidth: 8
UseTab: Never
EOF
    ok ".clang-format updated"
  fi
}

# ---------------------------------------------------------------------------
# 18. Nvim: enable the clangd and dap.core LazyExtras (the LazyExtras way is
#     the "extras" array in lazyvim.json)
# ---------------------------------------------------------------------------
step_nvim_extras() {
  info "18. Nvim LazyExtras: clangd + dap.core"
  local lazyjson="$HOME/.config/nvim/lazyvim.json"
  [[ -f "$lazyjson" ]] || { skip "lazyvim.json missing: $lazyjson"; return 0; }

  local -a wanted=(
    "lazyvim.plugins.extras.lang.clangd"
    "lazyvim.plugins.extras.dap.core"
  )
  local -a missing=()
  local extra
  for extra in "${wanted[@]}"; do
    if ! jq -e --arg e "$extra" '(.extras // []) | index($e)' "$lazyjson" >/dev/null 2>&1; then
      missing+=("$extra")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    skip "clangd and dap.core extras already enabled"
    return 0
  fi
  confirm "Enable LazyExtras: ${missing[*]}?" || { skip "skipped"; return 0; }

  run cp "$lazyjson" "$lazyjson.bak.$(date +%Y%m%d_%H%M%S)"
  if [[ "$DRY_RUN" == true ]]; then
    printf '\033[1;38;5;243m  [dry-run] add to lazyvim.json extras: %s\033[0m\n' "${missing[*]}"
  else
    local tmp
    tmp=$(jq --args '.extras = ((.extras // []) + $ARGS.positional | unique | sort)' "${missing[@]}" < "$lazyjson") \
      && printf '%s\n' "$tmp" > "$lazyjson"
  fi
  ok "enabled: ${missing[*]}"
}

# ---------------------------------------------------------------------------
# 19. Install batctl-tui-bin from AUR (thresholds: manual config)
# ---------------------------------------------------------------------------
step_batctl() {
  info "19. Install batctl-tui-bin"
  if pacman -Qi batctl-tui-bin &>/dev/null; then
    skip "batctl-tui-bin already installed"
  else
    confirm "Install batctl-tui-bin from the AUR?" || { skip "skipped"; return 0; }
    run omarchy pkg aur add batctl-tui-bin
  fi
  printf '\n\033[1;38;5;214m  ! Configure bat thresholds (40-80%%) manually:\033[0m\n'
  printf '    sudo batctl\n'
}

# ---------------------------------------------------------------------------
# 20. Remove the Wallpapers and Work/tries directories
# ---------------------------------------------------------------------------
step_remove_dirs() {
  info "20. Remove Wallpapers and Work/tries directories"
  local -a dirs=("$HOME/Wallpapers" "$HOME/Work/tries")
  local any=false
  for d in "${dirs[@]}"; do
    [[ -e "$d" ]] && any=true
  done
  if [[ "$any" == false ]]; then
    skip "Wallpapers and Work/tries already absent"
    return 0
  fi
  confirm "Remove ~/Wallpapers and ~/Work/tries?" || { skip "skipped"; return 0; }
  for d in "${dirs[@]}"; do
    if [[ -e "$d" ]]; then
      run rm -rf "$d" && ok "removed $d"
    else
      skip "$d not present"
    fi
  done
}

# ---------------------------------------------------------------------------
# 21. Set up fingerprint authentication
# ---------------------------------------------------------------------------
step_fingerprint() {
  info "21. Fingerprint setup"
  if [[ "$ASSUME_YES" == true ]]; then
    # Enrollment needs the user to touch the sensor; leave it to the manual steps.
    skip "fingerprint enrollment needs interaction (see manual steps)"
    return 0
  fi
  if ! omarchy-hw-fingerprint &>/dev/null; then
    warn "No fingerprint sensor detected"
    return 0
  fi
  if ! confirm "Set up fingerprint authentication (sudo, polkit, lock screen)?"; then
    skip "skipped"
    return 0
  fi
  run omarchy setup security fingerprint
}

# ---------------------------------------------------------------------------
# 22. Set theme to Gruvbox
# ---------------------------------------------------------------------------
step_theme() {
  info "22. Set theme to Gruvbox"
  confirm "Set the theme to Gruvbox?" || { skip "skipped"; return 0; }
  run omarchy theme set gruvbox
}

# ---------------------------------------------------------------------------
# 23. Set a global Node.js version in mise
# ---------------------------------------------------------------------------
step_mise_node() {
  info "23. Set global Node.js version in mise"
  if ! command -v mise &>/dev/null; then
    skip "mise not installed"
    return 0
  fi
  # Omarchy declares node as a lazy mise tool, so it gets installed on demand
  # but no global version is set. The node shim then fails with "No version is
  # set for shim: node" (OpenCode is npm-backed, so this bites its users too).
  if mise ls -g node 2>/dev/null | grep -qE '^node[[:space:]]'; then
    skip "global Node.js version already set"
    return 0
  fi
  confirm "Set a global Node.js version in mise (fixes the node shim)?" || { skip "skipped"; return 0; }
  # Reuse the newest installed Node (or install the latest if there is none)
  # and pin it, so a future major release does not silently take over.
  run mise use -g --pin node
  ok "global Node.js version set"
}

# ---------------------------------------------------------------------------
# 24. Set default agent to OpenCode
# ---------------------------------------------------------------------------
step_default_agent() {
  info "24. Set default agent to OpenCode"
  confirm "Set the default coding agent to OpenCode?" || { skip "skipped"; return 0; }
  run omarchy default agent opencode
}

# ---------------------------------------------------------------------------
# Final: reload Hyprland + restart shell
# ---------------------------------------------------------------------------
step_apply() {
  info "Applying changes"
  if command -v hyprctl &>/dev/null; then
    run hyprctl reload >/dev/null 2>&1 || true
    if hyprctl configerrors 2>/dev/null | grep -q .; then
      warn "Hyprland reported config errors (run: hyprctl configerrors)"
    else
      ok "Hyprland config clean"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Manual steps
# ---------------------------------------------------------------------------
manual_steps() {
  printf '\n\033[1;38;5;75m=== Manual steps ===\033[0m\n'
  printf '  1. Open Chromium once so the policies apply (DuckDuckGo default, extensions,\n'
  printf '     no password manager, smooth scrolling off), then sign in to Proton Pass and\n'
  printf '     Dark Reader and pin the extensions.\n'
  printf '  2. Add your SSH key to GitHub (title: OMARCHY):\n'
  printf '         cat ~/.ssh/id_ed25519.pub\n'
  printf '     then open https://github.com/settings/ssh/new\n'
  printf '  3. Enroll your fingerprint (also done interactively by the script):\n'
  printf '         omarchy setup security fingerprint\n'
  printf '  4. Configure battery charge thresholds (40-80%%):\n'
  printf '         sudo batctl\n'

  # In interactive mode, walk through the runnable steps one by one.
  if [[ "$ASSUME_YES" == true || "$DRY_RUN" == true || ! -t 0 ]]; then
    printf '\n'
    return 0
  fi

  printf '\n\033[1;38;5;75m  Walk through the manual steps now?\033[0m\n'

  if confirm "Open Chromium now?"; then
    run omarchy launch browser || true
  fi

  if confirm "Copy the SSH public key to the clipboard and open the GitHub keys page?"; then
    if command -v wl-copy &>/dev/null && [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
      run wl-copy < "$HOME/.ssh/id_ed25519.pub"
    fi
    run xdg-open "https://github.com/settings/ssh/new" >/dev/null 2>&1 || true
  fi

  if confirm "Configure battery thresholds (batctl) in a floating terminal?"; then
    run omarchy launch floating-terminal-with-presentation "sudo batctl" || true
  fi

  printf '\n'
}

# ---------------------------------------------------------------------------
main() {
  case "${1:-}" in
    -h|--help)
      cat << 'EOF'
Usage: omarchy4-setup.sh [--noconfirm]

  --noconfirm   Run unattended (answer yes to every prompt), like the original script.
  -h, --help    Show this help.

Environment:
  DRY_RUN=true  Preview commands without executing them.
EOF
      exit 0
      ;;
    -y|--yes|--noconfirm)
      ASSUME_YES=true
      ;;
    "")
      ;;
    *)
      echo "Unknown option: $1 (try --help)" >&2
      exit 1
      ;;
  esac

  if [[ "$DRY_RUN" == true ]]; then
    info "Omarchy 4 personal setup (DRY RUN — no changes will be made)"
  elif [[ "$ASSUME_YES" == true ]]; then
    info "Omarchy 4 personal setup starting (--noconfirm)"
  else
    info "Omarchy 4 personal setup starting (interactive — confirm each step)"
  fi
  [[ $EUID -eq 0 ]] && { echo "Do not run as root." >&2; exit 1; }

  step_remove_preinstalls
  step_chromium_policies
  step_web_apps
  step_desktop_apps
  step_plugins
  step_monitors
  step_terminal_font
  step_animations
  step_close_window
  step_docker
  step_ssh
  step_input
  step_screensaver
  step_obsidian_shortcut
  step_nvim
  step_nvim_indent
  step_nvim_extras
  step_batctl
  step_remove_dirs
  step_fingerprint
  step_theme
  step_mise_node
  step_default_agent
  step_apply

  ok "Setup complete"
  manual_steps
}

main "$@"
