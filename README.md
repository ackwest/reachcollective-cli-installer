# Reach Collective CLI installer

Public bootstrap installer for the private `reachcollective-cli` repository.
The installer contains no credentials or private application code.

## Requirements

- `curl`
- `git`
- Access to `ackwest/reachcollective-cli` through SSH or HTTPS

Python and `uv` do not need to be installed in advance. The installer installs
`uv` when it is missing, and `uv` manages the Python runtime used by RCLI.

## Install

```bash
curl -fsSL \
  https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/install.sh \
  | sh
```

Interactive installations can select SSH or HTTPS. Non-interactive
installations use the first protocol that already has working credentials.

The version installed is the stable version declared in `latest.json`.

## Release contract

`latest.json` must reference a stable Git tag in the private CLI repository:

```json
{
  "version": "0.2.0"
}
```

Publish the matching `v0.2.0` tag before changing this manifest.
