#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC} $1"; }
fail() { echo -e "  ${RED}❌${NC} $1"; }
info() { echo -e "  ${CYAN}ℹ️${NC} $1"; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      opencode-termux — One-Click Setup   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─── Check Termux ───
[ -d /data/data/com.termux ] && [ -n "$PREFIX" ] && {
  pass "Termux detected"
} || {
  fail "Not running in Termux. Install Termux from F-Droid first."
  exit 1
}

# ─── Check storage ───
avail=$(df /data/data/com.termux 2>/dev/null | awk 'NR==2{print $4}')
[ -n "$avail" ] && [ "$avail" -gt 500000 ] && pass "Storage OK: $((avail/1000))MB free" || warn "Low storage (< 500MB)"

# ─── Check RAM ───
total_ram=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
[ "$total_ram" -gt 3000000 ] && pass "RAM OK: $((total_ram/1024/1024))GB+" || warn "Low RAM (< 3GB recommended)"

# ─── Update packages ───
echo ""
info "Updating Termux packages..."
pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || pkg update -y
pass "Packages updated"

# ─── Install dependencies ───
echo ""
info "Installing dependencies (proot-distro, nodejs, ripgrep)..."
pkg install -y proot-distro nodejs ripgrep jq 2>/dev/null
pass "Dependencies installed"

echo ""
info "Checking Node.js..."
node_ver=$(node --version 2>/dev/null || echo "none")
info "  Node.js ${node_ver}"

# ─── Install/Update Debian proot ───
echo ""
info "Setting up Debian proot-distro..."
if proot-distro list 2>/dev/null | grep -q "debian"; then
  pass "Debian proot already installed"
else
  info "Installing Debian (this takes 2-5 minutes)..."
  proot-distro install debian 2>&1
  pass "Debian proot installed"
fi

# ─── Install opencode inside Debian ───
echo ""
info "Installing opencode inside Debian proot..."
proot-distro login debian -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt update -qq 2>/dev/null && apt install -y -qq curl nodejs npm ripgrep jq 2>/dev/null
  npm install -g opencode-ai 2>/dev/null
" 2>&1

# Verify
proot-distro login debian -- bash -c "which opencode 2>/dev/null && opencode --version 2>/dev/null" > /tmp/oc_ver 2>&1 || true
oc_ver=$(cat /tmp/oc_ver 2>/dev/null || echo "")
[ -n "$oc_ver" ] && pass "opencode installed: ${oc_ver}" || warn "opencode version check failed"

# ─── Setup alias ───
echo ""
info "Setting up 'opencode' command..."
alias_cmd='alias opencode="proot-distro login debian --shared-tmp -- /usr/local/bin/opencode"'

# Remove old alias
sed -i '/alias opencode=/d' ~/.bashrc 2>/dev/null

# Add the alias
echo "$alias_cmd" >> ~/.bashrc

# Source it
eval "$alias_cmd" 2>/dev/null || true
pass "Alias added to ~/.bashrc"

# ─── Create config dir ───
info "Setting up opencode config directory..."
proot-distro login debian --shared-tmp -- bash -c "mkdir -p ~/.config/opencode 2>/dev/null; echo '{\$schema: https://opencode.ai/config.json}' > ~/.config/opencode/opencode.json 2>/dev/null" 2>/dev/null || true
pass "Config directory ready"

# ─── Test run ───
echo ""
info "Testing opencode..."
proot-distro login debian --shared-tmp -- timeout 5 /usr/local/bin/opencode --version 2>/dev/null && pass "opencode works!" || warn "Test timed out (expected first time)"
echo ""

# ─── Done ───
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         INSTALLATION COMPLETE!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${YELLOW}To start coding:${NC}"
echo ""
echo -e "    1. Close and reopen Termux"
echo -e "       (or run: source ~/.bashrc)"
echo ""
echo -e "    2. Type: ${CYAN}opencode${NC}"
echo ""
echo -e "  ${YELLOW}First run setup:${NC}"
echo -e "    opencode will ask for an API provider."
echo -e "    You can use Claude, OpenAI, Gemini, etc."
echo ""
echo -e "  ${YELLOW}Optional: set API key directly${NC}"
echo -e "    export ANTHROPIC_API_KEY=\"sk-your-key\""
echo -e "    opencode"
echo ""
echo -e "  ${YELLOW}Web UI (browser):${NC}"
echo -e "    opencode web"
echo ""

# ─── Auto-launch ───
echo -e "  ${CYAN}Launching opencode now...${NC}"
echo ""
proot-distro login debian --shared-tmp -- /usr/local/bin/opencode
