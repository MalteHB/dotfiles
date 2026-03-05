# Silence direnv output before instant prompt so it doesn't produce console I/O during init
export DIRENV_LOG_FORMAT=

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git docker direnv zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# Hooks
source <(fzf --zsh)

# Optional extras
[[ -r ~/.kube/profile ]] && source ~/.kube/profile

# Powerlevel10k config
[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Per-workspace local overrides (e.g. extra PATH entries)
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
