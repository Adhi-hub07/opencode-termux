#!/usr/bin/env bash
set -uo pipefail

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'
ok()  { echo -e "  ${G}✅${N} $1"; }
warn() { echo -e "  ${Y}⚠️${N} $1"; }
fail() { echo -e "  ${R}❌${N} $1"; }
info() { echo -e "  ${C}ℹ️${N} $1"; }

OC_BIN=""

termux_env()  { [ -d /data/data/com.termux ] && [ -n "$PREFIX" ]; }
pkg_has()     { dpkg -s "$1" 2>/dev/null | grep -q "Status: install ok"; }
debian_ok()   { [ -d "$PREFIX/var/lib/proot-distro/containers/debian" ] || proot-distro login debian -- true 2>/dev/null; }
pdexec()      { proot-distro login debian --shared-tmp -- "$@"; }

find_oc_bin() {
  for p in /usr/local/bin/opencode /usr/bin/opencode /usr/lib/node_modules/.bin/opencode; do
    pdexec test -x "$p" 2>/dev/null && { OC_BIN="$p"; return 0; }
  done
  local w=$(pdexec bash -c 'which opencode 2>/dev/null' 2>/dev/null)
  [ -n "$w" ] && { OC_BIN="$w"; return 0; }
  return 1
}

oc_ver() {
  pdexec bash -c '"$1" --version 2>/dev/null | head -1' _ "$OC_BIN" 2>/dev/null || echo ""
}

echo ""
echo -e "${C}╔════════════════════════════════════════╗${N}"
echo -e "${C}║    opencode-termux — Perfect Setup     ║${N}"
echo -e "${C}╚════════════════════════════════════════╝${N}"

# ═══════════════════════ PHASE 1: SCAN ═══════════════════════
echo ""
echo -e "  ${Y}◆ Phase 1: Scanning your device...${N}"
echo ""

termux_env || { fail "Not in Termux (install from F-Droid)"; exit 1; }
ok "Termux environment"

avail=$(df /data/data/com.termux 2>/dev/null | awk 'NR==2{print $4}')
[ -n "$avail" ] && [ "$avail" -gt 500000 ] && ok "Storage: $((avail/1000))MB free" || warn "Storage low"

ram=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null || echo "0")
[ "$ram" -gt 3000000 ] && ok "RAM: $((ram/1024/1024))GB" || warn "RAM <3GB"

mpkgs="proot-distro nodejs ripgrep jq"; MISSING=""
for p in $mpkgs; do pkg_has "$p" || MISSING="$MISSING $p"; done
[ -z "$MISSING" ] && ok "Termux packages: all present" || warn "Missing:${MISSING}"

if debian_ok; then ok "Debian proot: installed"
else warn "Debian proot: missing"
fi

if find_oc_bin; then
  v=$(oc_ver); ok "opencode: ${v:-$OC_BIN}"
elif pdexec bash -c 'npm list -g opencode-ai 2>/dev/null' 2>/dev/null | grep -q "opencode-ai"; then
  warn "opencode npm pkg exists, binary missing"
else
  warn "opencode: not installed"
fi

WANT="alias opencode='proot-distro login debian --shared-tmp -- ${OC_BIN}'"
HAVE=""
[ -f ~/.bashrc ] && HAVE=$(grep '^alias opencode=' ~/.bashrc 2>/dev/null || echo "")
[ -n "$OC_BIN" ] && [ "$HAVE" = "$WANT" ] && ok "Alias: correct" || warn "Alias: needs update"

[ -d ~/.config/opencode ] 2>/dev/null && ok "Config dir: exists" || warn "Config dir: missing"

# ═══════════════════════ PHASE 2: INSTALL ═══════════════════════
echo ""
echo -e "  ${Y}◆ Phase 2: Installing what's needed...${N}"
echo ""

NEED_DEBIAN=0; NEED_OC=0; NEED_ALIAS=0; NEED_CONF=0; NEED_PKGS=0

for p in $mpkgs; do pkg_has "$p" || NEED_PKGS=1; done
debian_ok    || NEED_DEBIAN=1
find_oc_bin  || NEED_OC=1
WANT="alias opencode='proot-distro login debian --shared-tmp -- ${OC_BIN}'"
HAVE=""; [ -f ~/.bashrc ] && HAVE=$(grep '^alias opencode=' ~/.bashrc 2>/dev/null || echo "")
[ -n "$OC_BIN" ] && [ "$HAVE" = "$WANT" ] || NEED_ALIAS=1
pdexec test -d ~/.config/opencode 2>/dev/null || NEED_CONF=1

# ── Packages ──
if [ "$NEED_PKGS" -eq 1 ]; then
  echo -e "  ${C}[1/4] Termux packages...${N}"
  pkg update -y 2>/dev/null || pkg update -y
  for p in $mpkgs; do pkg_has "$p" || pkg install -y "$p" 2>/dev/null; done
  for p in $mpkgs; do pkg_has "$p" || { fail "Failed to install $p"; exit 1; }; done
  ok "Packages installed"
else
  ok "[1/4] Termux packages: skipped (already done)"
fi

# ── Debian ──
if [ "$NEED_DEBIAN" -eq 1 ]; then
  echo -e "  ${C}[2/4] Debian proot...${N}"
  proot-distro install debian 2>&1 || { fail "Debian install failed"; exit 1; }
  ok "Debian installed"
else
  ok "[2/4] Debian proot: skipped (already done)"
fi

# ── opencode ──
if [ "$NEED_OC" -eq 1 ]; then
  echo -e "  ${C}[3/4] opencode...${N}"
  proot-distro login debian -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    for p in curl nodejs npm ripgrep jq; do
      dpkg -s \$p 2>/dev/null | grep -q 'Status: install ok' || NEED=\"\$NEED \$p\"
    done
    [ -n \"\$NEED\" ] && { apt update -qq 2>/dev/null; apt install -y -qq \$NEED 2>/dev/null; }
    npm install -g opencode-ai 2>&1
  " || { fail "npm install failed"; exit 1; }
  find_oc_bin || { fail "opencode binary not found after install"; exit 1; }
  ok "opencode installed ($(oc_ver))"
else
  ok "[3/4] opencode: skipped (already done)"
fi

# ── Alias + config ──
if [ "$NEED_ALIAS" -eq 1 ]; then
  echo -e "  ${C}[4/4] Alias + config...${N}"
  WANT="alias opencode='proot-distro login debian --shared-tmp -- ${OC_BIN}'"
  sed -i '/^alias opencode=/d' ~/.bashrc 2>/dev/null
  echo "$WANT" >> ~/.bashrc
  eval "$WANT" 2>/dev/null || true
  ok "Alias configured"
else
  ok "[4/4] Alias: skipped (already correct)"
fi

if [ "$NEED_CONF" -eq 1 ]; then
  pdexec mkdir -p ~/.config/opencode 2>/dev/null
  ok "Config dir created"
fi

# ═══════════════════════ PHASE 3: CONFIRM ═══════════════════════
echo ""
echo -e "  ${Y}◆ Phase 3: Final check...${N}"
echo ""

ALL_GOOD=0
for p in $mpkgs; do pkg_has "$p" || { fail "Package $p missing"; ALL_GOOD=1; }; done
debian_ok    || { fail "Debian proot not found"; ALL_GOOD=1; }
find_oc_bin  || { fail "opencode not found"; ALL_GOOD=1; }
[ -n "$(oc_ver)" ] || warn "opencode version check failed"
WANT="alias opencode='proot-distro login debian --shared-tmp -- ${OC_BIN}'"
HAVE=$( [ -f ~/.bashrc ] && grep '^alias opencode=' ~/.bashrc 2>/dev/null || echo "" )
[ "$HAVE" = "$WANT" ] || { warn "Alias check failed"; ALL_GOOD=1; }

if [ "$ALL_GOOD" -eq 0 ]; then
  ok "Everything looks good!"
else
  warn "Some checks failed, but installation completed"
fi

echo ""
echo -e "${G}╔════════════════════════════════════════╗${N}"
echo -e "${G}║           SETUP COMPLETE!              ║${N}"
echo -e "${G}╚════════════════════════════════════════╝${N}"
echo ""
echo -e "  ${C}opencode${N}          Start terminal"
echo -e "  ${C}opencode web${N}      Web UI at localhost:4096"
echo ""

if [ -n "$OC_BIN" ]; then
  echo -e "  ${C}Launching opencode...${N}"
  echo ""
  proot-distro login debian --shared-tmp -- "$OC_BIN"
fi
