#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC} $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; }
info() { echo -e "  ${CYAN}ℹ️${NC} $1"; }
sep() { echo ""; }
header() {
  echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║       opencode-termux — One-Click Setup  ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
}

OPENCODE_BIN=""

# ──────────────────────────────────────────────
# STEP 1: Environment check
# ──────────────────────────────────────────────
check_env() {
  info "[1/7] Checking environment..."
  [ -d /data/data/com.termux ] && [ -n "$PREFIX" ] && { pass "Termux detected"; return 0; }
  fail "Not running in Termux. Install Termux from F-Droid first."
  return 1
}

# ──────────────────────────────────────────────
# STEP 2: Resources check
# ──────────────────────────────────────────────
check_resources() {
  info "[2/7] Checking device resources..."
  local ok=0

  avail=$(df /data/data/com.termux 2>/dev/null | awk 'NR==2{print $4}')
  if [ -n "$avail" ] && [ "$avail" -gt 500000 ]; then
    pass "Storage: $((avail/1000))MB free"; ok=1
  else
    warn "Low storage (< 500MB free)"
  fi

  total_ram=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
  if [ "$total_ram" -gt 3000000 ]; then
    pass "RAM: $((total_ram/1024/1024))GB+"
  else
    warn "Low RAM (< 3GB, opencode may lag)"
  fi

  return $ok
}

# ──────────────────────────────────────────────
# STEP 3: Termux packages
# ──────────────────────────────────────────────
setup_termux_pkgs() {
  info "[3/7] Checking Termux packages..."
  local pkgs="proot-distro nodejs ripgrep jq"
  local missing=""
  local need_update=0

  for pkg in $pkgs; do
    if ! dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok"; then
      missing="$missing $pkg"
    fi
  done

  if [ -n "$missing" ]; then
    info "  Installing missing:${missing}"
    pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || pkg update -y
    pkg install -y $missing 2>/dev/null
    pass "Packages installed"
  else
    pass "All Termux packages already installed"
  fi

  node_ver=$(node --version 2>/dev/null || echo "none")
  info "  Node.js ${node_ver}"
}

# ──────────────────────────────────────────────
# STEP 4: Debian proot
# ──────────────────────────────────────────────
setup_debian() {
  info "[4/7] Checking Debian proot..."
  if proot-distro list 2>/dev/null | grep -q "debian"; then
    pass "Debian proot already installed"
  else
    info "  Installing Debian (2-5 minutes)..."
    proot-distro install debian || {
      fail "Debian install failed"
      return 1
    }
    pass "Debian proot installed"
  fi
}

# ──────────────────────────────────────────────
# STEP 5: opencode inside Debian
# ──────────────────────────────────────────────
setup_opencode() {
  info "[5/7] Checking opencode in Debian..."

  # Check if already installed
  for path in /usr/local/bin/opencode /usr/bin/opencode; do
    if proot-distro login debian --shared-tmp -- test -x "$path" 2>/dev/null; then
      OPENCODE_BIN="$path"
      OC_VER=$(proot-distro login debian --shared-tmp -- bash -c '"$1" --version 2>/dev/null' _ "$OPENCODE_BIN" 2>/dev/null || echo "")
      pass "opencode already installed: ${OC_VER:-$OPENCODE_BIN}"
      return 0
    fi
  done

  # Try 'which'
  OPENCODE_BIN=$(proot-distro login debian --shared-tmp -- bash -c 'which opencode 2>/dev/null' 2>/dev/null || echo "")
  if [ -n "$OPENCODE_BIN" ]; then
    pass "opencode found at $OPENCODE_BIN"
    return 0
  fi

  info "  Installing opencode-ai via npm (1-2 minutes)..."
  proot-distro login debian -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    apt update -qq 2>/dev/null
    apt install -y -qq curl nodejs npm ripgrep jq 2>/dev/null
    npm install -g opencode-ai 2>/dev/null
  "

  # Find binary
  for path in /usr/local/bin/opencode /usr/bin/opencode; do
    if proot-distro login debian --shared-tmp -- test -x "$path" 2>/dev/null; then
      OPENCODE_BIN="$path"
      break
    fi
  done

  if [ -z "$OPENCODE_BIN" ]; then
    OPENCODE_BIN=$(proot-distro login debian --shared-tmp -- bash -c 'which opencode 2>/dev/null' 2>/dev/null || echo "")
  fi

  if [ -z "$OPENCODE_BIN" ]; then
    warn "npm install failed, retrying without quiet..."
    proot-distro login debian -- bash -c "
      npm cache clean --force 2>/dev/null
      npm install -g opencode-ai
    "
    OPENCODE_BIN=$(proot-distro login debian --shared-tmp -- bash -c 'which opencode 2>/dev/null' 2>/dev/null || echo "")
  fi

  if [ -z "$OPENCODE_BIN" ]; then
    fail "opencode installation failed"
    fail "Manual fix: proot-distro login debian -- npm install -g opencode-ai"
    return 1
  fi

  OC_VER=$(proot-distro login debian --shared-tmp -- bash -c '"$1" --version 2>/dev/null' _ "$OPENCODE_BIN" 2>/dev/null || echo "")
  pass "opencode installed: ${OC_VER:-$OPENCODE_BIN}"
}

# ──────────────────────────────────────────────
# STEP 6: Alias + config
# ──────────────────────────────────────────────
setup_alias() {
  info "[6/7] Setting up alias and config..."

  # Check if alias already correct
  local want_cmd="alias opencode='proot-distro login debian --shared-tmp -- ${OPENCODE_BIN}'"
  local have_cmd=""
  [ -f ~/.bashrc ] && have_cmd=$(grep '^alias opencode=' ~/.bashrc 2>/dev/null || echo "")

  if [ "$have_cmd" = "$want_cmd" ] && [ -f ~/.bashrc ]; then
    pass "Alias already set up correctly"
  else
    sed -i '/^alias opencode=/d' ~/.bashrc 2>/dev/null
    echo "$want_cmd" >> ~/.bashrc
    eval "$want_cmd" 2>/dev/null || true
    pass "Alias added to ~/.bashrc"
  fi

  # Config dir
  local config_ok=0
  proot-distro login debian --shared-tmp -- test -d ~/.config/opencode 2>/dev/null && config_ok=1
  if [ "$config_ok" -eq 1 ]; then
    pass "Config directory already exists"
  else
    proot-distro login debian --shared-tmp -- mkdir -p ~/.config/opencode 2>/dev/null
    pass "Config directory created"
  fi
}

# ──────────────────────────────────────────────
# STEP 7: Verify
# ──────────────────────────────────────────────
verify() {
  info "[7/7] Verifying installation..."

  local ok=0
  if proot-distro login debian --shared-tmp -- timeout 10 "$OPENCODE_BIN" --version 2>/dev/null; then
    OC_VER=$(proot-distro login debian --shared-tmp -- timeout 10 "$OPENCODE_BIN" --version 2>/dev/null)
    pass "opcode works! (${OC_VER})"
    ok=1
  fi

  # Verify alias too
  if [ "$(type -t opencode 2>/dev/null)" = "alias" ]; then
    pass "opencode command ready"
  else
    warn "Run 'source ~/.bashrc' to activate the alias"
  fi

  return $ok
}

# ──────────────────────────────────────────────
# INSTALL FLOW
# ──────────────────────────────────────────────
header
sep
check_env || exit 1
sep
check_resources || true
sep
setup_termux_pkgs
sep
setup_debian || exit 1
sep
setup_opencode || exit 1
sep
setup_alias
sep
verify
sep

# ─── DONE ───
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         INSTALLATION COMPLETE!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}How to use:${NC}"
echo ""
echo -e "    ${CYAN}opencode${NC}            Start coding"
echo -e "    ${CYAN}opencode web${NC}        Web UI (browser at localhost:4096)"
echo -e "    ${CYAN}cd project && opencode${NC}  Open project"
echo ""
echo -e "  ${YELLOW}Set API key:${NC}"
echo -e "    export ANTHROPIC_API_KEY=\"sk-your-key\""
echo ""

# ─── Auto-launch ───
echo -e "  ${CYAN}Launching opencode now...${NC}"
echo ""
proot-distro login debian --shared-tmp -- "$OPENCODE_BIN"
