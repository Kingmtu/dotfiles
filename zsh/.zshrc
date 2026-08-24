# ==============================================================================
# 1. ENVIRONMENT VARIABLES & PATH
# ==============================================================================
export EDITOR="nvim"
export DISPLAY=":0"
export STARSHIP_CONFIG="$HOME/.config/starship/nerd-font-symbols.toml"

# Grouping and exporting all PATH variables cleanly
export PATH="$HOME/.local/bin:$HOME/.bin:$HOME/.local/bin/eww:$HOME/.local/bin/go/bin:$HOME/.cargo/bin:/home/jarvis/.opencode/bin:$PATH"

# ==============================================================================
# 2. ZSH AUTOCOMPLETION & SETTINGS
# ==============================================================================
# Initialize Zsh's powerful autocompletion system
autoload -Uz compinit
compinit

# Standard Zsh history configuration (highly recommended)
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS # Do not save duplicates to history
setopt HIST_FIND_NO_DUPS    # Do not display duplicates in search

# ==============================================================================
# 3. ALIASES
# ==============================================================================
# General & System
alias c="clear"
alias n="nitch"
alias hx="helix"
alias play="ncmpcpp"

# Catnip
alias fox="catnip -c ~/.config/catnip/config_fox.toml"
alias fox2="catnip -c ~/.config/catnip/config_fox2.toml"
alias fox3="catnip -c ~/.config/catnip/config_fox3.toml"

# File Management
alias icat="kitten icat"
alias cat="bat"

# Note: 'exa' is unmaintained. You may want to switch to 'eza' in the future.
alias ls="exa --icons -a"
alias la="exa -a --color=always --group-directories-first"
alias tr="exa --tree --level=1"
alias tr2="exa --tree --level=2"
alias tr3="exa --tree --level=3"

# Arch Linux Package Management (Pacman/Pacseek)
alias p="pacseek"
alias update="sudo pacman -Syu"
alias install="sudo pacman -S"
alias uninstall="sudo pacman -Rns"
alias pacmandir="pacman -Ql"
alias pacmanR="pacman -Rs"
alias pacmanQ="pacman -Qs"
alias pacmanQi="pacman -Qi"
alias clean="sudo pacman -Sc"
# Fixed from fish syntax (command) to zsh syntax $(command)
alias cleanup="sudo pacman -Rns \$(pacman -Qtdq)" 

# ==============================================================================
# 4. FUNCTIONS
# ==============================================================================
# Yazi wrapper adapted for Zsh[cite: 1]
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# ==============================================================================
# 5. TOOL INITIALIZATION
# ==============================================================================
# Boot up x-cmd (Adapted for zsh paths instead of fish)[cite: 1]
test ! -e "$HOME/.x-cmd.root/local/data/zsh/rc.zsh" || source "$HOME/.x-cmd.root/local/data/zsh/rc.zsh"

# Starship prompt[cite: 1]
eval "$(starship init zsh)"

# Zoxide (Note: zoxide provides native autocompletion for zsh via init)[cite: 1]
eval "$(zoxide init --cmd cd zsh)"

# Fzf[cite: 1]
eval "$(fzf --zsh)"

# ==============================================================================
# 6. PLUGINS (Auto-suggestions)
# ==============================================================================
# Check for Arch Linux pacman installation path
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# Check for manual Git clone path
elif [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Optional: Customize the suggestion highlight color (default is often too faint)
# ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#848cb5,bold,underline"
