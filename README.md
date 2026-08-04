# Reach Collective CLI installer

Installer for the Reach Collective CLI on macOS, Linux, and Windows.

## Requirement

- [Git](https://git-scm.com/downloads)

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

`latest.json` must reference a stable Git tag in the private CLI repository:

```json
{
  "version": "0.2.0"
}
```

Publish the matching `v0.2.0` tag before changing this manifest.
