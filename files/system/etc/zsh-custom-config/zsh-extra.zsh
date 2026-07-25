# Sourced from /etc/zshrc (appended by the common-cli module) so every
# interactive zsh shell gets these, independent of any per-user .zshrc.

# Fedora runs compinit only from ~/.zshrc (shipped via /etc/skel), so root — which
# has none — gets no completion at all. Must precede fzf/zoxide, which call compdef.
autoload -U compinit
compinit

# EDITOR=vim makes zsh default to vi mode. Must precede fzf, whose ^R/^T bind into main.
bindkey -e

# History: persist to the invoking user's home dir, since this file is
# sourced by every account (root, desktop users, VM's cloud-init pi user).
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
	# Starship has no system-wide config path, so point every account (incl.
	# root) at the shared one; a per-user ~/.config/starship.toml still wins.
	if [[ -z "$STARSHIP_CONFIG" && ! -f "$HOME/.config/starship.toml" && -f /etc/zsh-custom-config/starship.toml ]]
	then
		export STARSHIP_CONFIG=/etc/zsh-custom-config/starship.toml
	fi
	eval "$(starship init zsh)"
fi

if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]
then
	source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
