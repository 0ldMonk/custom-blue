# root has no ~/.zshrc, so nothing else runs compinit; must precede fzf/zoxide
autoload -U compinit
compinit

# EDITOR=vim makes zsh default to vi mode. Must precede fzf, whose ^R/^T bind into main.
bindkey -e

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS

if command -v fzf > /dev/null 2>&1
then
	source <(fzf --zsh)
fi

if command -v zoxide > /dev/null 2>&1
then
	eval "$(zoxide init zsh)"
fi

if command -v starship > /dev/null 2>&1
then
	# starship has no system-wide config path
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

# if, not &&: a trailing false $? would flag starship's first prompt
if [[ -f ~/git/common-config/home-links/alias.sh ]]
then
	source ~/git/common-config/home-links/alias.sh
fi
