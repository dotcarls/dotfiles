#!/usr/bin/env zsh

#
# history config
#
setopt share_history
setopt append_history
setopt extended_history
setopt hist_expire_dups_first
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_verify
setopt INC_APPEND_HISTORY
unsetopt HIST_BEEP

# keep lots of history
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help"

#
# file / dir / path / nav options
#
setopt correct              # correct spelling for commands and
unsetopt correctall         # turn off correctall for filenames

setopt pushd_ignore_dups    # don’t push duplicate directories onto the stack
setopt extended_glob        # enable more powerful glob features

#
# completion options
#
setopt ALWAYS_TO_END        # move cursor to the end of a completed word
setopt AUTO_LIST            # automatically list choices on ambiguous completion
setopt AUTO_MENU            # show completion menu on a successive tab press
setopt AUTO_PARAM_SLASH     # if completed parameter is a directory, add a trailing slash
setopt COMPLETE_IN_WORD     # complete from both ends of a word
unsetopt MENU_COMPLETE      # do not autoselect the first completion entry

# misc options
setopt INTERACTIVE_COMMENTS  # Enable comments in interactive shell.


# Long running processes should return time after they complete. Specified
# in seconds.
REPORTTIME=2
TIMEFMT="%U user %S system %P cpu %*Es total"

# disable oh-my-zsh's auto-update in favor of zgen
DISABLE_AUTO_UPDATE=true

# Expand aliases inline - see http://blog.patshead.com/2012/11/automatically-expaning-zsh-global-aliases---simplified.html
globalias() {
   if [[ $LBUFFER =~ ' [A-Z0-9]+$' ]]; then
     zle _expand_alias
     zle expand-word
   fi
   zle self-insert
}

zle -N globalias

bindkey " " globalias
bindkey "^ " magic-space           # control-space to bypass completion
bindkey -M isearch " " magic-space # normal space during searches