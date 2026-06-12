# ADR 0005: Local Dev Credentials Vs Production Policy

## Status

Accepted

## Context

DepthMark needs a fast local setup for ClickHouse and MongoDB because the
standard development workflow starts services from the tracked Docker Compose
files and then runs setup scripts against them.

Those tracked compose files historically included local defaults such as
`fotmob_pass` and `orbit_pass`. That is convenient for development, but it is
dangerous if the same manifests or setup behavior are treated as production
guidance. The ClickHouse setup helper could also recover by logging in as the
`default` ClickHouse user with an empty password and then creating or granting
the configured user. That bootstrap path is useful for local containers but is
not acceptable as a general production fallback.

Fully removing local defaults would make the documented local workflow more
cumbersome. Leaving the current behavior undocumented and unenforced would keep
production credential risk hidden.

## Decision

The tracked Docker Compose files are local-development manifests. They may keep
documented local defaults for fast bootstrap, but they must not be used as
production deployment manifests.

DepthMark uses `DEPTHMARK_ENV` to mark the runtime credential policy. Values
`local`, `development`, and `dev` allow local-only bootstrap behavior. Any other
value, including `production`, requires non-empty, non-placeholder,
non-local-default ClickHouse credentials for setup.

ClickHouse setup must refuse empty, placeholder, or known local-development
passwords outside local development. It must also limit the empty-password
`default` user bootstrap and grant-reconciliation path to explicit local
development.

Production deployments must provide secrets through their deployment platform or
environment management, set `DEPTHMARK_ENV=production`, and avoid reusing the
tracked compose files as production manifests.

## Consequences

Local Docker onboarding stays simple: developers can copy `.env.example`, keep
`DEPTHMARK_ENV=local`, and use documented local defaults while bootstrapping.

Production-like runs fail earlier when credentials are placeholders or local
defaults, reducing the chance that insecure setup paths are silently accepted.

The setup helper now owns a small amount of credential-policy enforcement in
addition to connection orchestration. If DepthMark later adds dedicated
production deployment manifests, those manifests should set
`DEPTHMARK_ENV=production` and provide their own secrets.
