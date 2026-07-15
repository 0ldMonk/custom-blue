# Sourced from /etc/zshrc (appended by the common-cli module) so every
# interactive zsh shell gets these, independent of any per-user .zshrc.

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
