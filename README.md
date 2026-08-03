# Reach Collective CLI installer

Public bootstrap installer for the private `reachcollective-cli` repository.
The installer contains no credentials or private application code.

## Requirements

- `git`
- Access to `ackwest/reachcollective-cli` through SSH or HTTPS

The macOS and Linux installer also requires `curl`. The Windows installer runs
in Windows PowerShell 5.1 or PowerShell 7 and requires Git for Windows.

Python and `uv` do not need to be installed in advance. The installer installs
`uv` when it is missing, and `uv` manages the Python runtime used by RCLI.

## Install on macOS or Linux

```bash
curl -fsSL \
  https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.sh \
  | sh
```

Interactive installations can select SSH or HTTPS. Non-interactive
installations use the first protocol that already has working credentials.

The version installed is the stable version declared in `latest.json`.

## Install on Windows

Run the native installer from PowerShell:

```powershell
irm https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.ps1 | iex
```

The installer supports both Windows PowerShell 5.1 and PowerShell 7. It installs
`uv` when needed, adds the uv tool directory to `PATH`, and verifies the result
with `rcli --version`.

To select a protocol without an interactive prompt:

```powershell
$env:RCLI_GIT_PROTOCOL = "https"
irm https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.ps1 | iex
```

Use `ssh` instead of `https` to select SSH. To inspect the installer before
running it:

```powershell
$installer = Join-Path $env:TEMP "rcli-install.ps1"
irm https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.ps1 -OutFile $installer
notepad $installer
powershell -ExecutionPolicy Bypass -File $installer
```

## Release contract

`latest.json` must reference a stable Git tag in the private CLI repository:

```json
{
  "version": "0.2.0"
}
```

Publish the matching `v0.2.0` tag before changing this manifest.
