#!/bin/sh

set -eu

LATEST_URL="https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/latest.json"
SSH_REPOSITORY="ssh://git@github.com/minayaleon/reachcollective-cli.git"
HTTPS_REPOSITORY="https://github.com/minayaleon/reachcollective-cli.git"

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'rcli installer: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 is required."
}

find_uv() {
    if command -v uv >/dev/null 2>&1; then
        command -v uv
        return
    fi
    for candidate in "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return
        fi
    done
    return 1
}

install_uv() {
    uv_path=$(find_uv || true)
    if [ -n "$uv_path" ]; then
        printf '%s\n' "$uv_path"
        return
    fi

    say "Installing uv..." >&2
    temporary_directory=$(mktemp -d 2>/dev/null || mktemp -d -t rcli-installer)
    trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
    curl -fsSL https://astral.sh/uv/install.sh -o "$temporary_directory/install-uv.sh"
    sh "$temporary_directory/install-uv.sh" >/dev/null

    uv_path=$(find_uv || true)
    [ -n "$uv_path" ] || fail "uv was installed but its executable could not be found."
    printf '%s\n' "$uv_path"
}

fetch_latest_version() {
    manifest=$(curl -fsSL "$LATEST_URL") || fail "unable to download latest.json."
    version=$(
        printf '%s\n' "$manifest" |
            sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)"[[:space:]]*[,]*[[:space:]]*$/\1/p'
    )
    [ -n "$version" ] || fail "latest.json does not contain a version."
    printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
        fail "latest.json contains an invalid version: $version"
    printf '%s\n' "$version"
}

choose_protocol() {
    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        printf '\nGit protocol:\n  1) SSH\n  2) HTTPS\nSelect [1]: ' >/dev/tty
        choice=""
        IFS= read -r choice </dev/tty || true
        case "$choice" in
            "" | 1 | ssh | SSH) printf 'ssh\n' ;;
            2 | https | HTTPS) printf 'https\n' ;;
            *) fail "invalid Git protocol selection: $choice" ;;
        esac
        return
    fi

    if GIT_TERMINAL_PROMPT=0 git ls-remote "$SSH_REPOSITORY" HEAD >/dev/null 2>&1; then
        printf 'ssh\n'
    elif GIT_TERMINAL_PROMPT=0 git ls-remote "$HTTPS_REPOSITORY" HEAD >/dev/null 2>&1; then
        printf 'https\n'
    else
        fail "unable to access the private CLI repository with SSH or HTTPS."
    fi
}

verify_repository_access() {
    repository=$1
    say "Checking access to $repository..."
    git ls-remote "$repository" HEAD >/dev/null ||
        fail "unable to access the private CLI repository."
}

main() {
    require_command curl
    require_command git

    uv_path=$(install_uv)
    version=$(fetch_latest_version)
    protocol=$(choose_protocol)

    case "$protocol" in
        ssh) repository=$SSH_REPOSITORY ;;
        https) repository=$HTTPS_REPOSITORY ;;
        *) fail "unsupported Git protocol: $protocol" ;;
    esac

    verify_repository_access "$repository"
    requirement="reachcollective-cli @ git+$repository@v$version"

    say "Installing rcli $version with $protocol..."
    "$uv_path" tool install --force "$requirement"

    bin_directory=$("$uv_path" tool dir --bin 2>/dev/null || true)
    rcli_path="${bin_directory:-$HOME/.local/bin}/rcli"
    if [ -x "$rcli_path" ]; then
        "$rcli_path" --version
    elif command -v rcli >/dev/null 2>&1; then
        rcli --version
    else
        fail "rcli was installed but could not be found. Add ${bin_directory:-$HOME/.local/bin} to PATH."
    fi

    say "rcli was installed successfully."
}

main "$@"
