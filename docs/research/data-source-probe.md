# Data Source Probe Plan

## Current Assumption

Codex is the first provider, but a stable local quota source is not yet proven.

The project must not assume that a CLI command or local file exposes quota data. The first milestone is a read-only probe that records what is available and what is missing.

## Required Fields

The ideal source adapter returns:

- provider
- source status: `ok`, `stale`, or `error`
- fetched time
- short-window used percent
- short-window remaining percent
- short-window reset time
- weekly used percent, if available
- weekly remaining percent, if available
- weekly reset time, if available
- reset count, if available

## Probe Rules

- Read-only only.
- Do not log secrets.
- Do not copy auth files.
- Do not call `codex logout`.
- Do not reinstall or replace Codex.
- Treat missing fields as missing, not zero.
- Treat stale fields as stale.

## First Probe

The first local probe records:

- `codex --version`
- available top-level CLI commands from `codex --help`
- available debug commands from `codex debug --help`
- whether a usage/quota command appears to exist

This is intentionally modest. It establishes whether the public local CLI surface exposes a structured usage path before deeper investigation.

