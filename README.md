# 🚀 opencode-termux

**Run OpenCode AI coding agent on your Android phone via Termux — one command install.**

```bash
curl -sL https://raw.githubusercontent.com/Adhi-hub07/opencode-termux/main/install.sh | bash
```

After install → close & reopen Termux → type **`opencode`**

---

## ✨ Features

| Feature | How |
|---|---|
| 🔥 **One-line install** | `curl ... \| bash` — auto-everything |
| 📦 **Full proot Debian setup** | Isolated Linux environment inside Android |
| ⚡ **Auto alias** | Just type `opencode` in Termux |
| 🌐 **Web UI mode** | `opencode web` → browser at localhost:4096 |
| 🔧 **Auto-updates via npm** | Latest opencode always |
| 🧹 **No root required** | Works in standard Termux |

---

## 📋 Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| **Phone** | Any Android | 6GB+ RAM |
| **Storage** | 2GB free | 5GB+ free |
| **Termux** | From F-Droid | Latest version |
| **Internet** | Required for install | Broadband/WiFi |

Install Termux from [F-Droid](https://f-droid.org/packages/com.termux/) (NOT Play Store — it's outdated).

---

## 🚀 Quick Start

```bash
# 1. Install (5-10 minutes)
curl -sL https://raw.githubusercontent.com/Adhi-hub07/opencode-termux/main/install.sh | bash

# 2. Close & reopen Termux, then:
opencode
```

**First run**: opencode will ask for an AI provider API key.

---

## 🔧 Usage

```bash
# Start opencode (terminal chat)
opencode

# Start with a project directory
cd my-project
opencode

# Web UI mode
opencode web
# Then open Chrome → http://localhost:4096

# Set API key (optional — opencode will prompt otherwise)
export ANTHROPIC_API_KEY="sk-ant-..."
opencode
```

---

## 📦 What Gets Installed

```
Termux
├── proot-distro
│   └── Debian Linux
│       ├── nodejs + npm
│       ├── opencode-ai (npm global)
│       ├── ripgrep + jq
│       └── ~/.config/opencode/opencode.json
└── ~/.bashrc
    └── alias opencode="proot-distro login debian --shared-tmp -- opencode"
```

---

## ⚙️ How It Works

OpenCode doesn't run natively on Android/Termux (the binary is built for glibc Linux, not Bionic libc). This script:

1. Installs **proot-distro** — a chroot-like tool for Termux
2. Sets up **Debian Linux** inside it
3. Installs **Node.js** + **opencode** inside Debian
4. Creates an **alias** so typing `opencode` automatically enters proot + runs the command

No root needed, no bootloop risk, fully reversible.

---

## 🗑️ Uninstall

```bash
# Remove the alias
sed -i '/alias opencode=/d' ~/.bashrc

# Remove opencode from Debian
proot-distro login debian -- npm uninstall -g opencode-ai

# Remove Debian entirely (if you want)
proot-distro remove debian

# Remove dependencies
pkg uninstall proot-distro ripgrep jq
```

---

## 🆘 Troubleshooting

| Problem | Fix |
|---|---|
| `command not found: opencode` | Run `source ~/.bashrc` or reopen Termux |
| Install hangs | Poor internet — try again on WiFi |
| `proot-distro: command not found` | Run `pkg install proot-distro` manually |
| `Permission denied` | You're in /sdcard — run `cd ~` first |
| opencode crashes | Close Termux, reopen, try `opencode` again |

---

## 📂 Related Projects

- [Adhi-hub07/andro-diag](https://github.com/Adhi-hub07/andro-diag) — Android device diagnostics CLI
- [guysoft/opencode-termux](https://github.com/guysoft/opencode-termux) — Native opencode binary for Termux (alternative)
- [rajbreno/PocketCode](https://github.com/rajbreno/PocketCode) — PocketCode: AI coding on Android

---

**Made by [Adhi-hub07](https://github.com/Adhi-hub07)**
