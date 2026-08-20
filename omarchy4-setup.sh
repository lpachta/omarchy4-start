#!/usr/bin/env bash
# Omarchy 4 personal setup script
#
# Turns a fresh Omarchy installation into this machine's personal setup.
# Based on the checklist in "Obsidian Vault/1. Prchavé poznámky/Omarchy Quattro Start.md".
#
# Idempotent: safe to re-run. Uses omarchy CLI commands where possible.
# Requires: a sudo user on Omarchy (Hyprland optional for hyprctl reload at the end).

set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"

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

# ---------------------------------------------------------------------------
# Chromium extension IDs
# ---------------------------------------------------------------------------
EXTENSION_IDS=(
  "ghmbeldphafepmbegfdlkpapadhbakde" # Proton Pass
  "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
  "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
  "khncfooichmfjbepaaaebmommgaepoid" # Unhook
  "ccnheoamhddmjhgpmgganjnibcnhkndp" # Vimium
)

# ---------------------------------------------------------------------------
# 1. Remove all preinstalled apps
# ---------------------------------------------------------------------------
step_remove_preinstalls() {
  info "1. Remove all preinstalled apps"
  if [[ -f "$HOME/.local/state/omarchy/preinstalls-removed" ]]; then
    skip "preinstalls already removed"
  else
    run omarchy remove preinstalls
  fi
}

# ---------------------------------------------------------------------------
# 2. Install browser extensions + 9. DuckDuckGo default search engine
#    (Chromium managed policy)
# ---------------------------------------------------------------------------
step_chromium_policies() {
  info "2/9. Chromium policies (DuckDuckGo + extensions)"

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

  run sudo mkdir -p "$policy_dir"
  local policy_json
  policy_json=$(printf '{\n  "DefaultSearchProviderEnabled": true,\n  "DefaultSearchProviderName": "DuckDuckGo",\n  "DefaultSearchProviderIconURL": "https://duckduckgo.com/favicon.ico",\n  "DefaultSearchProviderEncodings": ["UTF-8"],\n  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}",\n  "DefaultSearchProviderSuggestURL": "https://duckduckgo.com/ac/?q={searchTerms}&type=list",\n  "DefaultSearchProviderNewTabURL": "https://duckduckgo.com/chrome_newtab",\n  "ExtensionSettings": {\n%b\n  }\n}\n' "$ext_json")
  printf '%s\n' "$policy_json" | write_file_sudo "$policy_file"
  ok "wrote $policy_file"
}

# ---------------------------------------------------------------------------
# 3. Install web apps
# ---------------------------------------------------------------------------
step_web_apps() {
  info "3. Install web apps"
  local apps=("GitHub:https://github.com/" "Discord:https://discord.com/app" "WhatsApp:https://web.whatsapp.com/" "YouTube:https://youtube.com/")
  for entry in "${apps[@]}"; do
    local name="${entry%%:*}"
    local url="${entry#*:}"
    if [[ -f "$HOME/.local/share/applications/$name.desktop" ]]; then
      skip "$name web app already installed"
    else
      run omarchy webapp install "$name" "$url" "$name" && ok "installed $name web app"
    fi
  done
}

# ---------------------------------------------------------------------------
# 4. Install desktop apps
# ---------------------------------------------------------------------------
step_desktop_apps() {
  info "4. Install desktop apps"
  for pkg in anki obsidian libreoffice-fresh signal-desktop; do
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
  run omarchy plugin enable omarchy.active-window 2>/dev/null || skip "active-window already enabled"

  info "6. Disable plugin: Omarchy menu"
  run omarchy plugin disable omarchy.menu 2>/dev/null || skip "menu already disabled"
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
# 8. Set terminal font size to 12
# ---------------------------------------------------------------------------
step_terminal_font() {
  info "8. Foot font size 12"
  local ini="$HOME/.config/foot/foot.ini"
  [[ -f "$ini" ]] || { skip "foot config missing: $ini"; return 0; }
  if grep -q 'font=.*:size=12' "$ini"; then
    skip "font size already 12"
    return 0
  fi
  run cp "$ini" "$ini.bak.$(date +%Y%m%d_%H%M%S)"
  run sed -i 's/font=.*:size=[0-9]*/font=JetBrainsMono Nerd Font:size=12/' "$ini"
  ok "foot font size set to 12"
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
  run omarchy pkg drop ufw-docker && \
  run omarchy pkg drop docker docker-buildx docker-compose && \
  ok "docker removed"
}

# ---------------------------------------------------------------------------
# 12. SSH key for GitHub
# ---------------------------------------------------------------------------
step_ssh() {
  info "12. SSH key (ed25519)"
  mkdir -p "$HOME/.ssh"
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
}

# ---------------------------------------------------------------------------
# 12-16. Keyboard & touchpad
# ---------------------------------------------------------------------------
step_input() {
  info "12-16. Keyboard & touchpad settings"
  local input="$HOME/.config/hypr/input.lua"
  [[ -f "$input" ]] || { skip "input.lua missing: $input"; return 0; }
  if grep -q 'caps:escape' "$input" 2>/dev/null; then
    skip "keyboard/touchpad settings already configured"
    return 0
  fi
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
# 17. Toggle screensaver to off
# ---------------------------------------------------------------------------
step_screensaver() {
  info "17. Disable screensaver"
  run omarchy toggle screensaver off
}

# ---------------------------------------------------------------------------
# 18. Add frequent apps shortcuts: Super+Shift+O -> Obsidian
# ---------------------------------------------------------------------------
step_obsidian_shortcut() {
  info "18. Obsidian shortcut: SUPER+SHIFT+O"
  local bindings="$HOME/.config/hypr/bindings.lua"
  [[ -f "$bindings" ]] || { skip "bindings.lua missing: $bindings"; return 0; }
  if grep -q 'SUPER + SHIFT + O' "$bindings" 2>/dev/null; then
    skip "SUPER+SHIFT+O already bound to Obsidian"
    return 0
  fi
  run cp "$bindings" "$bindings.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$bindings" << 'EOF'

-- Frequent apps
hl.unbind("SUPER + O")
o.bind("SUPER + SHIFT + O", "Obsidian", "omarchy launch or focus obsidian obsidian")
EOF
  ok "SUPER+SHIFT+O bound to Obsidian"
}

# ---------------------------------------------------------------------------
# 19. Nvim: Enable relative line numbering
# ---------------------------------------------------------------------------
step_nvim() {
  info "19. Nvim relative line numbers"
  local init="$HOME/.config/nvim/init.lua"
  [[ -f "$init" ]] || { skip "nvim init.lua missing: $init"; return 0; }
  if grep -q 'relativenumber' "$init" 2>/dev/null; then
    skip "relative line numbers already enabled"
    return 0
  fi
  run cp "$init" "$init.bak.$(date +%Y%m%d_%H%M%S)"
  append_file "$init" << 'EOF'
vim.wo.relativenumber = true
EOF
  ok "relative line numbers enabled"
}

# ---------------------------------------------------------------------------
# 20. Install batctl-tui-bin from AUR (thresholds: manual config)
# ---------------------------------------------------------------------------
step_batctl() {
  info "20. Install batctl-tui-bin"
  if pacman -Qi batctl-tui-bin &>/dev/null; then
    skip "batctl-tui-bin already installed"
  else
    run omarchy pkg aur add batctl-tui-bin
  fi
  printf '\n\033[1;38;5;214m  ! Configure bat thresholds (40-80%%) manually:\033[0m\n'
  printf '    sudo batctl\n'
}

# ---------------------------------------------------------------------------
# 21. Set theme to Gruvbox
# ---------------------------------------------------------------------------
step_theme() {
  info "21. Set theme to Gruvbox"
  run omarchy theme set gruvbox
}

# ---------------------------------------------------------------------------
# 22. Set default agent to OpenCode
# ---------------------------------------------------------------------------
step_default_agent() {
  info "22. Set default agent to OpenCode"
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
  printf '  1. Open Chromium once so policies apply (DuckDuckGo default + extensions).\n'
  printf '     Then sign in to Proton Pass and pin it.\n'
  printf '  2. Configure bat thresholds: sudo batctl\n'
  printf '  3. Add SSH key to GitHub:\n'
  printf '         cat ~/.ssh/id_ed25519.pub\n'
  printf '     copy the output, then: https://github.com/settings/ssh/new  (title: OMARCHY)\n'
  printf '\n'
}

# ---------------------------------------------------------------------------
main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    printf "Usage: DRY_RUN=true ./omarchy4-setup.sh\n"
    printf "  Set DRY_RUN=true to preview commands without executing them.\n"
    exit 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    info "Omarchy 4 personal setup (DRY RUN — no changes will be made)"
  else
    info "Omarchy 4 personal setup starting"
  fi
  [[ $EUID -eq 0 ]] && { echo "Do not run as root." >&2; exit 1; }

  step_remove_preinstalls
  step_chromium_policies
  step_web_apps
  step_desktop_apps
  step_plugins
  step_monitors
  step_terminal_font
  step_close_window
  step_docker
  step_ssh
  step_input
  step_screensaver
  step_obsidian_shortcut
  step_nvim
  step_batctl
  step_theme
  step_default_agent
  step_apply

  ok "Setup complete"
  manual_steps
}

main "$@"
