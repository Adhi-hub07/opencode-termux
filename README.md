# 🚀 opencode-termux

**OpenCode AI coding agent on your Android phone — one command install.**

```bash
curl -sL https://raw.githubusercontent.com/Adhi-hub07/opencode-termux/main/install.sh | bash
```

After install → close & reopen Termux → type **`opencode`**

---

## 💾 Storage Breakdown

| Component | Size |
|---|---|
| proot-distro + Debian base | ~500 MB |
| Node.js + npm | ~150 MB |
| opencode-ai (npm) | ~250 MB |
| ripgrep + jq + deps | ~50 MB |
| **Total** | **~950 MB** |
| **Space needed during install** | **~1.5 GB** (includes temp files) |

Make sure you have **at least 2 GB free** before installing.

---

## 📋 Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| **RAM** | 4 GB | **6 GB+** |
| **Free Storage** | **2 GB** | **5 GB+** |
| **Android** | 11+ | 12+ |
| **Termux** | From **[F-Droid](https://f-droid.org/packages/com.termux/)** | Latest version |
| **Internet** | Yes (downloads ~1 GB) | WiFi |

⚠️ **Use F-Droid version** — Play Store Termux is outdated and broken.

---

## 🚀 One-Click Install

```bash
curl -sL https://raw.githubusercontent.com/Adhi-hub07/opencode-termux/main/install.sh | bash
```

### What happens step-by-step

| # | Step | Time |
|---|---|---|
| 1 | Checks Termux environment | 1s |
| 2 | Updates Termux packages | 30s |
| 3 | Installs proot-distro, nodejs, ripgrep | 1-2 min |
| 4 | Downloads & installs Debian proot | 2-5 min |
| 5 | Installs opencode inside Debian | 2-3 min |
| 6 | Creates `opencode` alias in .bashrc | 1s |
| 7 | **Auto-launches opencode** | — |

**Total: ~5-10 minutes** (depends on internet speed)

---

## 📱 Usage

```bash
# Start coding
opencode

# Start in a project folder
cd my-project
opencode

# Web UI (open in Chrome browser)
opencode web
# → http://localhost:4096

# Set API key (or opencode will prompt you)
export ANTHROPIC_API_KEY="sk-ant-..."
opencode
```

**Supported AI providers**: Claude (Anthropic), OpenAI, Gemini (Google), Grok (xAI), and more.

---

## 📦 What Gets Installed

```
/data/data/com.termux/files/home/
├── .bashrc
│   └── alias opencode = "proot-distro login debian --shared-tmp -- opencode"
│
/data/data/com.termux/files/usr/var/lib/proot-distro/containers/
└── debian/  (~500 MB)
    └── rootfs/
        ├── usr/local/bin/opencode  (opencode binary)
        ├── usr/lib/node_modules/opencode-ai/  (~250 MB)
        ├── usr/bin/node  (Node.js)
        ├── usr/bin/rg  (ripgrep)
        └── root/.config/opencode/
            └── opencode.json
```

---

## ⚙️ How It Works

OpenCode is built for **glibc Linux** — Android uses **Bionic libc** instead, so it can't run natively in Termux.

This script uses **proot-distro** (a chroot-like tool) to run a full Debian Linux inside Termux. The `opencode` alias automatically enters Debian and runs opencode — so it feels like a single command.

No root required. No bootloader unlock. No risk of bricking.

---

## 🗑️ Uninstall

```bash
# Step 1: Remove the alias
sed -i '/alias opencode=/d' ~/.bashrc

# Step 2: Remove Debian proot (frees ~500 MB)
proot-distro remove debian

# Step 3: Remove packages (frees ~200 MB)
pkg uninstall proot-distro ripgrep jq
```

---

## 🆘 Troubleshooting

| Problem | Fix |
|---|---|
| `command not found: opencode` | Run `source ~/.bashrc` or close & reopen Termux |
| Install hangs / times out | Poor internet — retry on WiFi with `curl ... \| bash` again (it resumes) |
| `Permission denied` | You're in `/sdcard` — run `cd ~` first (internal storage) |
| `proot-distro: command not found` | Run `pkg install proot-distro` manually |
| opencode shows `e_type: 2` error | Your CPU is not ARM64 — this script only supports aarch64 |
| opencode crashes | Close Termux completely, reopen, try again |
| "Can't find API key" | Run `export ANTHROPIC_API_KEY="sk-..."` before `opencode` |

---

## 📂 Related

- [Adhi-hub07/andro-diag](https://github.com/Adhi-hub07/andro-diag) — Android device health diagnostics CLI
- [guysoft/opencode-termux](https://github.com/guysoft/opencode-termux) — Native binary (no proot needed, experimental)
- [rajbreno/PocketCode](https://github.com/rajbreno/PocketCode) — AI coding on Android guide

---

**Made by [Adhi-hub07](https://github.com/Adhi-hub07)**
