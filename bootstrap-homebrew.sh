#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
Usage: sh bootstrap-homebrew.sh [--install] [--work]

Without --install this script only discovers a supported Homebrew installation.
--install runs Homebrew's official installer when Homebrew is absent.
--work also installs the macOS 1Password CLI bootstrap prerequisite.
EOF
}

install_homebrew=0
work_bootstrap=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --install) install_homebrew=1 ;;
        --work) work_bootstrap=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 64 ;;
    esac
    shift
done

find_brew() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return
    fi
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return
        fi
    done
    return 1
}

brew_bin=$(find_brew || true)
if [ -z "$brew_bin" ]; then
    if [ "$install_homebrew" -ne 1 ]; then
        printf '%s\n' 'Homebrew not found. Review this script, then rerun with --install.' >&2
        exit 1
    fi
    if [ "$(uname -s)" = Linux ] && [ "$(id -u)" -eq 0 ]; then
        printf '%s\n' 'Homebrew does not support running as root; use a non-root container user.' >&2
        exit 1
    fi
    installer=$(mktemp "${TMPDIR:-/tmp}/homebrew-install.XXXXXX")
    trap 'rm -f "$installer"' EXIT HUP INT TERM
    curl --proto '=https' --tlsv1.2 --fail --silent --show-error \
        --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
        --output "$installer"
    /bin/bash "$installer"
    trap - EXIT HUP INT TERM
    rm -f "$installer"
    brew_bin=$(find_brew)
fi

eval "$("$brew_bin" shellenv)"
brew update
brew install chezmoi rage
if [ "$work_bootstrap" -eq 1 ]; then
    if [ "$(uname -s)" != Darwin ]; then
        printf '%s\n' 'Work secret bootstrap is intentionally disabled on non-macOS hosts.' >&2
        exit 1
    fi
    brew install --cask 1password-cli
fi

printf 'Homebrew bootstrap ready: %s\n' "$brew_bin"
