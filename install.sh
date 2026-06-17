#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC} $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; }
info() { echo -e "  ${CYAN}ℹ️${NC} $1"; }
sep() { echo ""; }

export OPENCODE_BIN=""

# ──────────────────────────────────────────────
# CHECK functions — only check, no install
# ──────────────────────────────────────────────

check_termux() {
  [ -d /data/data/com.termux ] && [ -n "$PREFIX" ]
}

check_storage() {
  local avail=$(df /data/data/com.termux 2>/dev/null | awk 'NR==2{print $4}')
  [ -n "$avail" ] && [ "$avail" -gt 500000 ]
}

check_ram() {
  local total=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
  [ "$total" -gt 3000000 ]
}

check_pkg_installed() {
  dpkg -s "$1" 2>/dev/null | grep -q "Status: install ok"
}

check_debian_exists() {
  [ -d "$PREFIX/var/lib/proot-distro/containers/debian" ] || proot-distro login debian -- true 2>/dev/null
}

check_opencode_binary() {
  local paths="/usr/local/bin/opencode /usr/bin/opencode /usr/lib/node_modules/.bin/opencode"
  for p in $paths; do
    if proot-distro login debian --shared-tmp -- test -x "$p" 2>/dev/null; then
      OPENCODE_BIN="$p"; return 0
    fi
  done
  local w=$(proot-distro login debian --shared-tmp -- bash -c 'which opencode 2>/dev/null' 2>/dev/null || echo "")
  if [ -n "$w" ]; then
    OPENCODE_BIN="$w"; return 0
  fi
  return 1
}

check_opencode_npm() {
  proot-distro login debian --shared-tmp -- bash -c 'npm list -g opencode-ai 2>/dev/null' 2>/dev/null | grep -q "opencode-ai"
}

check_alias_correct() {
  local want="alias opencode='proot-distro login debian --shared-tmp -- ${OPENCODE_BIN}'"
  local have=$(grep '^alias opencode=' ~/.bashrc 2>/dev/null || echo "")
  [ "$have" = "$want" ]
}

# ──────────────────────────────────────────────
# STATUS REPORT — check everything, show table
# ──────────────────────────────────────────────

show_status() {
  sep
  echo -e "${CYAN}  ┌────────────────────────────────────┐${NC}"
  echo -e "${CYAN}  │       SYSTEM STATUS REPORT         │${NC}"
  echo -e "${CYAN}  └────────────────────────────────────┘${NC}"
  sep

  local items=""
  local n=0; local total=7

  # 1: Environment
  if check_termux; then items="${items}  ${GREEN}✅${NC} Termux environment\n"; n=$((n+1)); else items="${items}  ${RED}❌${NC} Termux environment\n"; fi

  # 2: Storage
  local avail=$(df /data/data/com.termux 2>/dev/null | awk 'NR==2{print $4}')
  if check_storage; then items="${items}  ${GREEN}✅${NC} Storage: $((avail/1000))MB free\n"; n=$((n+1)); else items="${items}  ${RED}❌${NC} Storage: ${avail:-?}KB free (need >500MB)\n"; fi

  # 3: RAM
  local ram=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
  if check_ram; then items="${items}  ${GREEN}✅${NC} RAM: $((ram/1024/1024))GB\n"; n=$((n+1)); else items="${items}  ${RED}❌${NC} RAM: $((ram/1024/1024))GB (need >3GB)\n"; fi

  # 4: Termux packages
  local mpkgs="proot-distro nodejs ripgrep jq"; local missing_pkgs=""
  for p in $mpkgs; do check_pkg_installed "$p" || missing_pkgs="$missing_pkgs $p"; done
  if [ -z "$missing_pkgs" ]; then
    items="${items}  ${GREEN}✅${NC} Termux packages: all installed\n"; n=$((n+1))
  else
    items="${items}  ${RED}❌${NC} Missing packages:${missing_pkgs}\n"
  fi

  # 5: Debian proot
  if check_debian_exists; then
    items="${items}  ${GREEN}✅${NC} Debian proot: installed\n"; n=$((n+1))
  else
    items="${items}  ${RED}❌${NC} Debian proot: not installed\n"
  fi

  # 6: opencode binary
  if check_opencode_binary; then
    local ver=$(proot-distro login debian --shared-tmp -- bash -c '"$1" --version 2>/dev/null | head -1' _ "$OPENCODE_BIN" 2>/dev/null || echo "")
    items="${items}  ${GREEN}✅${NC} opencode: ${ver:-$OPENCODE_BIN}\n"; n=$((n+1))
  else
    check_opencode_npm && items="${items}  ${YELLOW}⚠️${NC} opencode npm package exists but binary not found\n" \
                     || items="${items}  ${RED}❌${NC} opencode: not installed\n"
  fi

  # 7: Alias
  if [ -n "$OPENCODE_BIN" ] && check_alias_correct; then
    items="${items}  ${GREEN}✅${NC} Alias: configured\n"; n=$((n+1))
  elif [ -n "$OPENCODE_BIN" ]; then
    items="${items}  ${YELLOW}⚠️${NC} Alias: wrong or missing\n"
  else
    items="${items}  ${YELLOW}⚠️${NC} Alias: pending (opencode not installed)\n"
  fi

  echo -e "$items"
  echo -e "  ${CYAN}${n}/${total} checks passed${NC}"
  sep
}

# ──────────────────────────────────────────────
# FIX functions — idempotent, only if needed
# ──────────────────────────────────────────────

fix_termux_pkgs() {
  local missing_pkgs=""
  for p in proot-distro nodejs ripgrep jq; do
    check_pkg_installed "$p" || missing_pkgs="$missing_pkgs $p"
  done
  if [ -z "$missing_pkgs" ]; then
    pass "All Termux packages already installed"
  else
    info "Installing:${missing_pkgs}"
    pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || pkg update -y
    pkg install -y $missing_pkgs 2>/dev/null
    pass "Termux packages installed"
  fi
}

fix_debian() {
  if check_debian_exists; then
    pass "Debian proot already installed"
  else
    info "Installing Debian proot (2-5 min)..."
    proot-distro install debian 2>&1
    pass "Debian proot installed"
  fi
}

fix_opencode() {
  # Shortcut: binary already exists
  if check_opencode_binary; then
    local ver=$(proot-distro login debian --shared-tmp -- bash -c '"$1" --version 2>/dev/null | head -1' _ "$OPENCODE_BIN" 2>/dev/null || echo "")
    pass "opencode already installed: ${ver:-$OPENCODE_BIN}"
    return 0
  fi

  # Shortcut: npm package exists but binary not in PATH
  if check_opencode_npm; then
    OPENCODE_BIN=$(proot-distro login debian --shared-tmp -- bash -c 'which opencode 2>/dev/null || find /usr -name opencode -type f 2>/dev/null | head -1' 2>/dev/null || echo "")
    if [ -n "$OPENCODE_BIN" ]; then
      pass "opencode npm package already installed (binary at $OPENCODE_BIN)"
      return 0
    fi
  fi

  info "Installing opencode-ai via npm..."

  proot-distro login debian -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    NEEDED=
    for p in curl nodejs npm ripgrep jq; do
      dpkg -s \$p 2>/dev/null | grep -q 'Status: install ok' || NEEDED=\"\$NEEDED \$p\"
    done
    if [ -n \"\$NEEDED\" ]; then
      apt update -qq 2>/dev/null
      apt install -y -qq \$NEEDED 2>/dev/null
    fi
    echo '  Downloading opencode-ai...'
    npm install -g opencode-ai 2>&1 | tail -5
  "

  # Locate binary
  check_opencode_binary || {
    OPENCODE_BIN=$(proot-distro login debian --shared-tmp -- bash -c 'find /usr -name opencode -type f 2>/dev/null | head -1' 2>/dev/null || echo "")
  }

  if [ -z "$OPENCODE_BIN" ]; then
    fail "opencode install failed"
    fail "Try: proot-distro login debian -- npm install -g opencode-ai"
    return 1
  fi

  local ver=$(proot-distro login debian --shared-tmp -- bash -c '"$1" --version 2>/dev/null | head -1' _ "$OPENCODE_BIN" 2>/dev/null || echo "")
  pass "opencode installed: ${ver:-$OPENCODE_BIN}"
}

fix_alias() {
  if [ -z "$OPENCODE_BIN" ]; then
    warn "No opencode binary found, skipping alias"
    return 1
  fi

  if check_alias_correct; then
    pass "Alias already correct"
    return 0
  fi

  local alias_cmd="alias opencode='proot-distro login debian --shared-tmp -- ${OPENCODE_BIN}'"
  sed -i '/^alias opencode=/d' ~/.bashrc 2>/dev/null
  echo "$alias_cmd" >> ~/.bashrc
  eval "$alias_cmd" 2>/dev/null || true
  pass "Alias added to ~/.bashrc"
}

fix_config() {
  if proot-distro login debian --shared-tmp -- test -d ~/.config/opencode 2>/dev/null; then
    pass "Config directory exists"
  else
    proot-distro login debian --shared-tmp -- mkdir -p ~/.config/opencode 2>/dev/null
    pass "Config directory created"
  fi
}

# ──────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       opencode-termux — One-Click Setup  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

# ── Phase 1: Status ──
sep
echo -e "  ${YELLOW}◆ PHASE 1: Checking your device...${NC}"
show_status

# ── Phase 2: Fix ──
sep
echo -e "  ${YELLOW}◆ PHASE 2: Applying fixes...${NC}"
sep

check_termux || { fail "Not in Termux"; exit 1; }

echo -e "  ${CYAN}[1] Termux packages${NC}"
fix_termux_pkgs
sep

echo -e "  ${CYAN}[2] Debian proot${NC}"
fix_debian || exit 1
sep

echo -e "  ${CYAN}[3] opencode${NC}"
fix_opencode || exit 1
sep

echo -e "  ${CYAN}[4] Alias + config${NC}"
fix_alias; fix_config
sep

# ── Phase 3: Verify ──
echo -e "  ${YELLOW}◆ PHASE 3: Verifying...${NC}"
sep
show_status

sep
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         INSTALLATION COMPLETE!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}opencode${NC}          Start coding"
echo -e "  ${CYAN}opencode web${NC}      Web UI at localhost:4096"
echo ""

# ── Auto-launch ──
echo -e "  ${CYAN}Launching opencode now...${NC}"
echo ""
proot-distro login debian --shared-tmp -- "$OPENCODE_BIN"
