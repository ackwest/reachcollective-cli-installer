#!/bin/sh

set -eu

LATEST_URL="https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/latest.json"
SSH_REPOSITORY="ssh://git@github.com/ackwest/reachcollective-cli.git"
HTTPS_REPOSITORY="https://github.com/ackwest/reachcollective-cli.git"

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
    curl -fsSL https://astral.sh/uv/install.sh -o "$temporary_directory/install-uv.sh"
    sh "$temporary_directory/install-uv.sh" >/dev/null

    uv_path=$(find_uv || true)
    [ -n "$uv_path" ] || fail "uv was installed but its executable could not be found."
    printf '%s\n' "$uv_path"
}

install_gh() {
    if command -v gh >/dev/null 2>&1; then
        return
    fi

    say "Installing GitHub CLI..."
    case "$(uname -s)" in
        Darwin)
            command -v brew >/dev/null 2>&1 ||
                fail "Homebrew is required to install GitHub CLI on macOS. Install it from https://brew.sh and run this installer again."
            brew install gh
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                if [ "$(id -u)" -eq 0 ]; then
                    apt-get update
                    apt-get install -y gh
                elif command -v sudo >/dev/null 2>&1; then
                    sudo apt-get update
                    sudo apt-get install -y gh
                else
                    fail "Administrator access is required to install GitHub CLI."
                fi
            elif command -v dnf >/dev/null 2>&1; then
                if [ "$(id -u)" -eq 0 ]; then
                    dnf install -y gh
                elif command -v sudo >/dev/null 2>&1; then
                    sudo dnf install -y gh
                else
                    fail "Administrator access is required to install GitHub CLI."
                fi
            elif command -v brew >/dev/null 2>&1; then
                brew install gh
            else
                fail "GitHub CLI is required. Install it from https://cli.github.com and run this installer again."
            fi
            ;;
        *)
            fail "GitHub CLI is required. Install it from https://cli.github.com and run this installer again."
            ;;
    esac

    command -v gh >/dev/null 2>&1 || fail "GitHub CLI was installed but its executable could not be found."
}

fetch_release_manifest() {
    manifest=$(curl -fsSL "$LATEST_URL") || fail "unable to download latest.json."
    version=$(
        printf '%s\n' "$manifest" |
            sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)"[[:space:]]*[,]*[[:space:]]*$/\1/p'
    )
    [ -n "$version" ] || fail "latest.json does not contain a version."
    printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
        fail "latest.json contains an invalid version: $version"
    wheel_url=$(
        printf '%s\n' "$manifest" |
            sed -n 's/^[[:space:]]*"wheel_url"[[:space:]]*:[[:space:]]*"\([^"]*\)"[[:space:]]*[,]*[[:space:]]*$/\1/p'
    )
    wheel_sha256=$(
        printf '%s\n' "$manifest" |
            sed -n 's/^[[:space:]]*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)"[[:space:]]*[,]*[[:space:]]*$/\1/p'
    )
    if [ -n "$wheel_url" ] || [ -n "$wheel_sha256" ]; then
        [ -n "$wheel_url" ] && [ -n "$wheel_sha256" ] ||
            fail "latest.json must contain both wheel_url and sha256."
        printf '%s\n' "$wheel_url" | grep -Eq '^https://' ||
            fail "latest.json wheel_url must use HTTPS."
        printf '%s\n' "$wheel_sha256" | grep -Eq '^[0-9a-fA-F]{64}$' ||
            fail "latest.json contains an invalid sha256."
    fi
}

verify_sha256() {
    file_path=$1
    expected_sha256=$2
    if command -v shasum >/dev/null 2>&1; then
        actual_sha256=$(shasum -a 256 "$file_path" | awk '{print $1}')
    elif command -v sha256sum >/dev/null 2>&1; then
        actual_sha256=$(sha256sum "$file_path" | awk '{print $1}')
    else
        fail "shasum or sha256sum is required to verify the RCLI download."
    fi
    [ "$actual_sha256" = "$expected_sha256" ] || fail "RCLI download checksum verification failed."
}

install_public_wheel() {
    wheel_path="$temporary_directory/$(basename "$wheel_url")"
    say "Downloading rcli $version..."
    curl -fsSL "$wheel_url" -o "$wheel_path" || fail "unable to download the RCLI wheel."
    verify_sha256 "$wheel_path" "$wheel_sha256"
    say "Installing rcli $version..."
    "$uv_path" tool install --force "$wheel_path"
}

choose_protocol() {
    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        printf '\nGit protocol:\n  1) HTTPS\n  2) SSH\nSelect [1]: ' >/dev/tty
        choice=""
        IFS= read -r choice </dev/tty || true
        case "$choice" in
            "" | 1 | https | HTTPS) printf 'https\n' ;;
            2 | ssh | SSH) printf 'ssh\n' ;;
            *) fail "invalid Git protocol selection: $choice" ;;
        esac
        return
    fi

    if GIT_TERMINAL_PROMPT=0 git ls-remote "$HTTPS_REPOSITORY" HEAD >/dev/null 2>&1; then
        printf 'https\n'
    elif GIT_TERMINAL_PROMPT=0 git ls-remote "$SSH_REPOSITORY" HEAD >/dev/null 2>&1; then
        printf 'ssh\n'
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

    temporary_directory=$(mktemp -d 2>/dev/null || mktemp -d -t rcli-installer)
    trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

    uv_path=$(install_uv)
    install_gh
    fetch_release_manifest

    if [ -n "$wheel_url" ]; then
        install_public_wheel
    else
        say "This release uses the legacy private-repository installer."
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
    fi

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
