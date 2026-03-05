#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
MARKER="# >>> dotfiles zsh-switch >>>"

# 1. Install Oh My Zsh (unattended, skip if present)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 2. Clone Powerlevel10k theme
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
  echo "Installing Powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# 3. Clone zsh-autosuggestions plugin
AUTOSUG_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [[ ! -d "$AUTOSUG_DIR" ]]; then
  echo "Installing zsh-autosuggestions..."
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$AUTOSUG_DIR"
fi

# 4. Clone zsh-syntax-highlighting plugin
SYNHL_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
if [[ ! -d "$SYNHL_DIR" ]]; then
  echo "Installing zsh-syntax-highlighting..."
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNHL_DIR"
fi

# 5. Copy zshrc (repo is source of truth)
echo "Installing .zshrc..."
cp "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"

# 6. Copy p10k config
echo "Installing .p10k.zsh..."
cp "$DOTFILES_DIR/p10k.zsh" "$HOME/.p10k.zsh"

# 7. Append bash-to-zsh switch (marker-guarded, idempotent)
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  if [[ -f "$rc" ]] && ! grep -qF "$MARKER" "$rc"; then
    echo "Appending zsh-switch to $rc..."
    printf '\n' >> "$rc"
    cat "$DOTFILES_DIR/bashrc.append" >> "$rc"
  fi
done

# 8. Set default shell to zsh
ZSH_PATH="$(command -v zsh || true)"
if [[ -n "$ZSH_PATH" ]]; then
  current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
  if [[ "$current_shell" != "$ZSH_PATH" ]]; then
    echo "Setting default shell to zsh..."
    if command -v chsh >/dev/null 2>&1; then
      chsh -s "$ZSH_PATH" 2>/dev/null || echo "Warning: chsh failed (may need sudo). Shell not changed."
    else
      echo "Warning: chsh not available. Default shell not changed."
    fi
  fi
fi

echo "Dotfiles installed successfully!"
