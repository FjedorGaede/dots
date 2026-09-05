# Load common shell rc commands shared with other shell
source $HOME/.commonshellrc

# Completion
autoload -Uz compinit && compinit

# dots completion
_dots() {
    local -a subs
    subs=($(dots --subcommands))
    _describe 'subcommands' subs
}
compdef _dots dots

# Spell correction
setopt CORRECT

# History settings
HISTFILE=~/.zsh_history   # persist history to file
SAVEHIST=10000            # number of entries to save
setopt HIST_IGNORE_DUPS   # ignore duplicate commands
setopt HIST_IGNORE_SPACE  # ignore commands starting with a space
setopt SHARE_HISTORY      # share history across all open terminals

# Autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Starship prompt
eval "$(starship init zsh)"

# Zoxide (jump to directories)
eval "$(zoxide init --cmd j zsh)"

# FZF (fuzzy finder)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(fzf --zsh)"

# Word navigation
bindkey "^[[1;5C" forward-word   # Ctrl+Right: jump word forward
bindkey "^[[1;5D" backward-word  # Ctrl+Left: jump word backward

# Key bindings
# Ctrl+P: command palette (zsh requires wrapping functions as widgets)
function _custom-commands-widget() { custom-commands; zle reset-prompt }
zle -N _custom-commands-widget
bindkey '^p' _custom-commands-widget


# Thefuck
eval "$(thefuck --alias)"

# Syntax highlighting (must be sourced last)
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH="$HOME/.node_modules/bin:$PATH"
# pi personal assistant
alias pai="cd ~/TheVoid/Pai && pi"

# pi coding agent
export PI_CODING_AGENT_DIR="$HOME/.config/pi/agent"

# bun completions
[ -s "/home/fjedor/.bun/_bun" ] && source "/home/fjedor/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"


# Load Angular CLI autocompletion.
source <(ng completion script)
