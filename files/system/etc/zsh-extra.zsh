# Sourced from /etc/zshrc (appended by the common-cli module) so every
# interactive zsh shell gets these, independent of any per-user .zshrc.

# History: persist to the invoking user's home dir, since this file is
# sourced by every account (root, proart/desk users, VM's cloud-init pi user).
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS

# Set up fzf key bindings and fuzzy completion
if command -v fzf > /dev/null 2>&1
then
	source <(fzf --zsh)
fi

# Set up zoxide to move between folders efficiently
if command -v zoxide > /dev/null 2>&1
then
	eval "$(zoxide init zsh)"
fi

# Set up the Starship prompt
if command -v starship > /dev/null 2>&1
then
	eval "$(starship init zsh)"
fi

if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]
then
	source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
