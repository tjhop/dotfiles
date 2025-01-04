# load extension systems 
# (prompt, completion, version control systems, history prediction, command line editing)
autoload -Uz promptinit
autoload -Uz compinit
autoload -Uz vcs_info
autoload predict-on
autoload -U edit-command-line

# initialize extension systems
promptinit
compinit

# syntax highlighting, etc
case "$OSTYPE" in
    linux*)
        source "$(find /usr/share -name 'zsh-syntax-highlighting.zsh' -print 2>/dev/null)"
        source "$(find /usr/share -name 'zsh-autosuggestions.zsh' -print 2>/dev/null)"

        ;;
    darwin*)
        source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        ;;
esac

# still use emacs style keybinds on shell command line
bindkey -e

# allow reverse menu completions
bindkey '^[[Z' reverse-menu-complete

# accept current autosuggestion
bindkey '^ ' autosuggest-accept

# allow editing command line in editor (ie, vim)
export EDITOR='vim'
zle -N edit-command-line
bindkey '^xe' edit-command-line
bindkey '^x^e' edit-command-line

# setup git status prompt info
setopt prompt_subst
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )

# build prompt
PROMPT="%F{cyan}%~%f %F{green}\$vcs_info_msg_0_%(!.=>.->)%f "
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' actionformats '%F{blue}(%b | %a [ %c%u ])%f '
zstyle ':vcs_info:*' formats '%F{blue}(%b [ %c%u ])%f '

PROMPT=$'${(r:$COLUMNS::\u2500:)}'$PROMPT

# set history 
HISTFILE="$HOME/.history"
HISTSIZE=10000
SAVEHIST=10000
setopt INC_APPEND_HISTORY HIST_IGNORE_DUPS HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS

# if local shell configs file is found for shell configs specific to this system, source them too
if [[ -f "$HOME/.zshrc.local" ]]; then
        source "$HOME/.zshrc.local"
fi

# source main alias file
if [[ -f "$HOME/.aliases" ]]; then
        source "$HOME/.aliases"
fi

# if local aliases file is found for aliases specific to this machine, source them too
if [[ -f "$HOME/.aliases.local" ]]; then
        source "$HOME/.aliases.local"
fi

# source environment variables file
if [[ -f "$HOME/.env_vars" ]]; then
        source "$HOME/.env_vars"
fi

# if local env_vars file is found for env_vars specific to this machine, source them too
if [[ -f "$HOME/.env_vars.local" ]]; then
        source "$HOME/.env_vars.local"
fi

# if there's a ~/bin directory, add it to path
if [[ -d "$HOME/bin" ]]; then
     export PATH="$HOME/bin:$PATH"
fi

# add XDG spec bin dir
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
if [[ -d "$HOME/.local/bin" ]]; then
       export PATH="$HOME/.local/bin:$PATH"
fi

# if there's a Rust Cargo bin directory, add it to path
 if [[ -d "$HOME/.cargo/bin" ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
 fi

 # export work scripts to path
 if [ -d $HOME/work/scripts ]; then
   export PATH=$PATH:$HOME/work/scripts
 fi

 # if go installed, set GOBIN
 command -v go &>/dev/null && \
     export GOBIN="$(go env GOPATH)/bin" && \
     export PATH="$PATH:$GOBIN"

# if z script is installed, source it
if [ -f "$HOME/github/z/z.sh" ]; then
    source "$HOME/github/z/z.sh"
fi

# if asdf installed, source it
ASDF="$HOME/github/asdf/asdf.sh"
if [ -f $ASDF ]; then
    source $ASDF
fi

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh) || echo "Failed to set up fzf zsh shell integrations"

eval "$(direnv hook zsh)"

# ensure tmux session is spawned and attached
TMUX_SESSION_NAME="$(whoami)"
if [ ! -n "${TMUX+set}" ]; then
    tmux attach -t ${TMUX_SESSION_NAME} 2>/dev/null || \
        tmux new-session -s ${TMUX_SESSION_NAME}
fi
