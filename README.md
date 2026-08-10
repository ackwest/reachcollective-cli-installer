# Reach Collective CLI installer

Installer for the Reach Collective CLI on macOS, Linux, and Windows.

## Requirements

- [Git](https://git-scm.com/downloads)
- Homebrew on macOS when [GitHub CLI](https://cli.github.com/) is not already installed

The installer installs `uv` and GitHub CLI (`gh`) when they are missing. It does
not authenticate with GitHub. The first `rcli install` that needs access to a
private workspace opens GitHub's browser authentication flow.

## Install on macOS or Linux

```bash
curl -fsSL \
  https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.sh \
  | sh
```

## Install on Windows with PowerShell

```powershell
irm https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.ps1 | iex
```

## Release contract

`latest.json` publishes the public wheel URL and its SHA-256 checksum:

```json
{
  "version": "0.4.0",
  "wheel_url": "https://github.com/ackwest/reachcollective-cli-installer/releases/download/v0.4.0/reachcollective_cli-0.4.0-py3-none-any.whl",
  "sha256": "<64 hexadecimal characters>"
}
```

The CLI release workflow uploads the wheel to this public repository before it
updates the manifest. Installers verify the checksum before passing the wheel to
`uv tool install`. A version-only manifest remains supported temporarily so the
currently published release can still use the legacy private-repository path.
