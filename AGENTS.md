# Repository workflow

This repository is not part of the Reach Collective SDD delivery lifecycle.

- Do not invoke `lifecycle:*` skills for work in this repository unless the user explicitly requests that workflow.
- Do not require a Jira ticket, RCP identifier, lifecycle artifact, or evidence bundle before making changes.
- Work directly from the user's request and this repository's local conventions.
- Validate changes with this repository's own automated tests and documented checks.

## Local RCLI installation

The globally installed `rcli` is reserved for end-user installation and update
testing. Do not run `uv tool install`, `uv tool uninstall`, `install.sh`,
`rcli update`, or `uv sync` without explicit user confirmation.

Use `.venv/bin/python` and `.venv/bin/rcli` for development validation.
