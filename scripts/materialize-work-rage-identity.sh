#!/bin/sh
set -eu

identity_path=${DOTFILES_WORK_RAGE_IDENTITY:?missing work rage identity path}
identity_reference=${DOTFILES_WORK_RAGE_REFERENCE:?missing work rage identity reference}

if [ -s "$identity_path" ]; then
    chmod 0600 "$identity_path"
    exit 0
fi

if ! command -v op >/dev/null 2>&1; then
    printf '%s\n' 'Work configuration requires the 1Password CLI before chezmoi can decrypt it.' >&2
    printf '%s\n' 'Install Homebrew and 1Password CLI, authenticate op, then retry chezmoi.' >&2
    exit 1
fi
if ! command -v rage-keygen >/dev/null 2>&1; then
    printf '%s\n' 'Work configuration requires rage before chezmoi can decrypt it.' >&2
    printf '%s\n' 'Install Homebrew and rage, then retry chezmoi.' >&2
    exit 1
fi

identity_dir=$(dirname "$identity_path")
mkdir -p "$identity_dir"
chmod 0700 "$identity_dir"
umask 077
identity_tmp=$(mktemp "$identity_dir/.work-rage-identity.XXXXXX")
trap 'rm -f "$identity_tmp"' EXIT HUP INT TERM

op read "$identity_reference" >"$identity_tmp"
rage-keygen -y "$identity_tmp" >/dev/null
chmod 0600 "$identity_tmp"
mv -f "$identity_tmp" "$identity_path"
trap - EXIT HUP INT TERM
