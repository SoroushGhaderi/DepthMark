# ADR Backlog

Use this backlog to run future architecture-decision sessions one item at a
time. Each item should become its own ADR only after the decision has been
pressure-tested against the codebase, docs, scripts contract, and operational
runbooks.

## How To Run One Session

1. Pick the highest-priority unresolved item.
2. Review the current code and docs before writing the ADR.
3. Ask one decision question, with a recommended answer.
4. If the recommendation is accepted, update code and docs in the same change
   when needed.
5. Add or update the ADR under `docs/adr/`.
6. Run the narrowest useful verification command and record any remaining risk.

## Queue

| Priority | Topic | Current status | Expected output |
| --- | --- | --- | --- |
| P0 | Script command surface and orchestration boundary | Accepted in `0002-orchestrate-layer-entrypoints-via-cli.md` | Keep docs and orchestration aligned with canonical CLI entry points. |
| P1 | Gold database namespace strategy: `gold`, `gold_signals`, `gold_scenarios` | Accepted in `0003-split-gold-clickhouse-namespaces.md` | Keep scenario, signal, and shared metadata table ownership explicit. |
| P1 | Local-dev credentials vs production credential policy | Accepted in `0005-local-dev-credentials-vs-production-policy.md` | Keep local Docker defaults documented and enforce non-local credential hardening. |
| P2 | Markdown signal catalogs as MongoDB source of truth | Accepted in `0008-author-signal-catalogs-in-markdown.md` | Keep markdown frontmatter authoritative and MongoDB derivative. |
| P2 | Deterministic signal activation ID/versioning | Accepted in `0006-version-signal-activation-identity-scheme.md` | Keep activation identity versioning separate from signal-definition versioning. |
| P2 | FotMob-only provider scope | Unresolved | ADR confirming FotMob-only scope and when provider abstraction is allowed. |
| P3 | SQL owns transformations; Python owns orchestration/validation | Accepted in `0007-sql-owns-analytical-transformations.md` | Keep Silver and Gold analytical logic in SQL, with Python owning orchestration, validation, metadata plumbing, and reporting. |

## Recommended Next Session

Start with **P2: FotMob-only provider scope**.

Recommended default decision: keep DepthMark FotMob-only and defer provider
abstraction until a second provider has concrete ingestion, schema, and
operational requirements.

Key files to inspect:

- `README.md`
- `docs/DEVELOPMENT_ARCHITECTURE.md`
- `src/scrapers/fotmob/`
- `scripts/bronze/scrape_fotmob.py`
- `scripts/bronze/load_clickhouse.py`
- `src/storage/bronze/fotmob.py`
- `src/storage/silver/fotmob.py`
- `src/storage/gold/fotmob.py`
- `clickhouse/`
- `AGENTS.md`

Suggested verification:

```bash
python scripts/bronze/scrape_fotmob.py --help
python scripts/bronze/load_clickhouse.py --help
python scripts/quality/check_logging_style.py
```
