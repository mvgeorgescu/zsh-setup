# zsh-bootstrap

Bootstrap a modern Zsh environment on macOS and Linux.

This repository provides a single script to set up a clean, usable Zsh shell with sensible defaults and modern tooling. It is designed to be re-runnable, explicit, and portable across macOS and Linux.

---

## What this sets up

The script installs and configures:

- **Zsh** (must already be installed)
- **Oh My Zsh** – plugin and configuration framework
- **Starship** – fast, cross-shell prompt
- **zsh-syntax-highlighting** – command syntax feedback
- **FiraCode Nerd Font** – icons and ligatures for prompts

### Platform-specific behavior

**macOS**
- Installs **Homebrew** (interactive; requires sudo)
- Installs FiraCode Nerd Font via Homebrew

**Linux**
- Installs FiraCode Nerd Font manually into `~/.local/share/fonts`

Starship is always installed into `~/.local/bin` to avoid system-level paths like `/usr/local/bin`.

---

## Requirements

- `zsh`
- `curl`
- `git`
- `unzip` (Linux only, for font installation)
- Administrator privileges on macOS (for Homebrew)

---

## Usage

Clone the repo and run the script:

```bash
git clone https://github.com/<your-username>/zsh-bootstrap.git
cd zsh-bootstrap
chmod +x setup-zsh.sh
./setup-zsh.sh
