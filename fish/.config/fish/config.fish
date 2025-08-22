test ! -e "$HOME/.x-cmd.root/local/data/fish/rc.fish" || source "$HOME/.x-cmd.root/local/data/fish/rc.fish" # boot up x-cmd.
#source ~/.config/lscolors.csh

#neofetch --off --block_range 0 7
#neofetch
#neofetch --block_range 0 7
alias c="clear"
# alias c="clear; neofetch --off --block_range 0 7"
# neofetch --config ~/.config/neofetch/config_def.conf
# alias c="neofetch --block_range 0 7"
# alias c="neofetch --kitty ~/Pictures/Nord/unsplash20.png"
#nitch
alias n='nitch'
alias fox='catnip -c ~/.config/catnip/config_fox.toml'
alias fox2='catnip -c ~/.config/catnip/config_fox2.toml'
alias fox3='catnip -c ~/.config/catnip/config_fox3.toml'

#alias ls='lsd -a'
#alias ll='lsd -ahl'
alias icat='kitten icat'
alias cat='bat'
alias ls='exa --icons -a'
#alias ll='exa --icons -ahl'
alias tr='exa --tree --level=1'
alias tr2='exa --tree --level=2'
alias tr3='exa --tree --level=3'

#alias c="clear; neofetch --block_range 0 7"
#export PATH="$"PATH":/home/bluebyt/.local/bin"
set -x PATH $PATH ~/.bin
set -x PATH $PATH ~/.local/bin
set -x PATH $PATH ~/.local/bin/eww
set -x PATH $PATH ~/.local/bin/go/bin/
set -x PATH $PATH ~/.cargo/bin
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias p='pacseek'
alias uninstall='sudo pacman -Rns'
alias play='ncmpcpp'
alias la='exa -a --color=always --group-directories-first' # all files and dirs
alias pacmandir='pacman -Ql' #To retrieve a list of the files installed by a package
alias pacmanR='pacman -Rs' #To remove a package and its dependencies
alias pacmanQ='pacman -Qs' #To search for already installed packages
alias pacmanQi='pacman -Qi' #To display information about locally installed packages
alias cleanup='sudo pacman -Rns (pacman -Qtdq)' # remove orphaned packages
alias clean='sudo pacman -Sc' #removing old packages from cache
#alias extract='for i in *.rar; do unrar x -o+ "$i"; end' 
#. ~/.config/fish/functions/noti.fish

set -x STARSHIP_CONFIG ~/.config/starship/nerd-font-symbols.toml
starship init fish | source
zoxide init fish | source
zoxide init --cmd cd fish | source
fzf --fish | source
#~/.x-cmd.root/bin/x fish --setup

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

function __my_zoxide_z_complete
    set -l tokens (commandline --current-process --tokenize)
    set -l curr_tokens (commandline --cut-at-cursor --current-process --tokenize)

    if test (count $tokens) -le 2 -a (count $curr_tokens) -eq 1
        set -l query $tokens[2..-1]
        zoxide query --exclude (__zoxide_pwd) --list -- $query
    else
        __zoxide_z_complete
    end
end
complete --erase --command __zoxide_z
complete --command __zoxide_z --no-files --arguments '(__my_zoxide_z_complete)'

set plugins https://github.com/kidonng/plug.fish
source (path filter $__fish_user_data_dir/plugins/plug.fish/conf.d/plugin_load.fish || curl https://raw.githubusercontent.com/kidonng/plug.fish/v3/conf.d/plugin_load.fish | psub)
