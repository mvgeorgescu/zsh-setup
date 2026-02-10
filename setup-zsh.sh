#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up Zsh environment..."

OS="$(uname -s)"

# -----------------------------
# Helpers
# -----------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

append_if_missing() {
  local line="$1"
  local file="$2"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >>"$file"
}

ensure_line_replaced() {
  # Replace first match of regex in file; if no match, append replacement line.
  local regex="$1"
  local replacement="$2"
  local file="$3"
  touch "$file"
  if grep -Eq "$regex" "$file"; then
    # macOS sed requires a backup extension; GNU sed tolerates it.
    sed -E -i.bak "s|$regex|$replacement|" "$file"
  else
    echo "$replacement" >>"$file"
  fi
}

# -----------------------------
# Files
# -----------------------------
ZSHRC="$HOME/.zshrc"
ZPROFILE="$HOME/.zprofile"

touch "$ZSHRC"
touch "$ZPROFILE"

# -----------------------------
# Homebrew (macOS only)
# -----------------------------
install_homebrew_macos() {
  if command_exists brew; then
    echo "✅ Homebrew already installed"
    return 0
  fi

  echo "🍺 Installing Homebrew (macOS only)..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for current process + future login shells
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    append_if_missing 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$ZPROFILE"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    append_if_missing 'eval "$(/usr/local/bin/brew shellenv)"' "$ZPROFILE"
  else
    echo "⚠️ Homebrew installed but brew not found in expected locations."
    echo "   Try restarting your terminal and re-running this script."
  fi
}

if [[ "$OS" == "Darwin" ]]; then
  install_homebrew_macos
fi

# -----------------------------
# Oh My Zsh
# -----------------------------
if ! command_exists zsh; then
  echo "❌ zsh not installed. Please install zsh first."
  exit 1
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "📦 Installing Oh My Zsh..."
  # Prevent installer from launching zsh and from overwriting existing .zshrc
  RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "✅ Oh My Zsh already installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Ensure .zshrc sources OMZ if user has a minimal file
ensure_line_replaced '^\s*export\s+ZSH=.*$' 'export ZSH="$HOME/.oh-my-zsh"' "$ZSHRC"
append_if_missing 'ZSH_THEME="robbyrussell"' "$ZSHRC" # starship will override prompt; theme mostly irrelevant

# Make sure OMZ is actually sourced
if ! grep -q 'source \$ZSH/oh-my-zsh.sh' "$ZSHRC"; then
  append_if_missing '' "$ZSHRC"
  append_if_missing '# Load Oh My Zsh' "$ZSHRC"
  append_if_missing 'source $ZSH/oh-my-zsh.sh' "$ZSHRC"
fi

# -----------------------------
# zsh-syntax-highlighting
# -----------------------------
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  echo "📦 Installing zsh-syntax-highlighting..."
  mkdir -p "$ZSH_CUSTOM/plugins"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
  echo "✅ zsh-syntax-highlighting already installed"
fi

# Prefer enabling via OMZ plugins list (cleaner than manual source), but do it safely.
# If plugins=(...) exists, add it if missing; otherwise create a minimal plugins list.
if grep -Eq '^\s*plugins=\(' "$ZSHRC"; then
  if ! grep -Eq '^\s*plugins=\([^)]*\bzsh-syntax-highlighting\b' "$ZSHRC"; then
    # Insert after opening paren
    sed -E -i.bak 's/^\s*plugins=\(\s*/plugins=(zsh-syntax-highlighting /' "$ZSHRC"
  fi
else
  append_if_missing '' "$ZSHRC"
  append_if_missing '# Oh My Zsh plugins' "$ZSHRC"
  append_if_missing 'plugins=(zsh-syntax-highlighting)' "$ZSHRC"
fi

# -----------------------------
# Starship (portable install; avoids /usr/local/bin issues)
# -----------------------------
STARSHIP_BIN="$HOME/.local/bin"
mkdir -p "$STARSHIP_BIN"

# Ensure ~/.local/bin is on PATH for both login + interactive shells
append_if_missing 'export PATH="$HOME/.local/bin:$PATH"' "$ZPROFILE"
append_if_missing 'export PATH="$HOME/.local/bin:$PATH"' "$ZSHRC"

if ! command_exists starship; then
  echo "✨ Installing Starship to $STARSHIP_BIN..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$STARSHIP_BIN"
else
  echo "✅ Starship already installed"
fi

# Initialize Starship in zsh (safe to re-run)
if ! grep -q 'starship init zsh' "$ZSHRC"; then
  append_if_missing '' "$ZSHRC"
  append_if_missing '# Starship prompt' "$ZSHRC"
  append_if_missing 'eval "$(starship init zsh)"' "$ZSHRC"
fi

# -----------------------------
# FiraCode Nerd Font
# -----------------------------
install_firacode_macos() {
  echo "🔤 Installing FiraCode Nerd Font (macOS via Homebrew)..."
  if ! command_exists brew; then
    echo "⚠️ brew not found; skipping font install."
    return 0
  fi
  brew tap homebrew/cask-fonts >/dev/null 2>&1 || true
  brew install --cask font-fira-code-nerd-font >/dev/null 2>&1 || true
  echo "✅ Font install attempted. Set your terminal font to 'FiraCode Nerd Font'."
}

install_firacode_linux() {
  echo "🔤 Installing FiraCode Nerd Font (Linux)..."
  if ! command_exists curl || ! command_exists unzip; then
    echo "❌ curl and unzip are required for font install on Linux."
    echo "   Install them (e.g., sudo apt-get install -y curl unzip) and re-run."
    return 1
  fi

  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  ( cd /tmp
    curl -fLo FiraCode.zip \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
    unzip -o FiraCode.zip -d "$font_dir" >/dev/null
  )
  if command_exists fc-cache; then
    fc-cache -fv >/dev/null 2>&1 || true
  fi
  echo "✅ Installed fonts into $font_dir. Set your terminal font to a FiraCode Nerd Font variant."
}

if [[ "$OS" == "Darwin" ]]; then
  install_firacode_macos
elif [[ "$OS" == "Linux" ]]; then
  install_firacode_linux
else
  echo "⚠️ Unsupported OS for font install: $OS"
fi

# -----------------------------
# Wrap up
# -----------------------------
echo ""
echo "✅ Setup complete!"
echo ""
echo "👉 Next steps:"
echo "  1) Restart your terminal OR run: exec zsh"
echo "  2) Set your terminal font to: FiraCode Nerd Font"
echo "  3) (Optional) Configure Starship: ~/.config/starship.toml"
echo ""
echo "Notes:"
echo "  - Homebrew is installed/used on macOS only."
echo "  - Starship is installed to ~/.local/bin to avoid /usr/local/bin issues."
