# Context

## Layer Inventory

DepthMark's medallion layers are FotMob-only and ClickHouse-backed from Silver
upward.

### Silver (`silver.*`)

Eight cleaned analytical tables with paired DDL and DML:

- `match`
- `period_stat`
- `player_match_stat`
- `momentum`
- `shot`
- `card`
- `match_personnel`
- `team_form`

Runtime contracts are enforced through `assert_silver_layer_contracts` in
`src/utils/layer_contracts.py`.

### Gold

Gold materializes product-facing scenario and signal outputs across three
ClickHouse namespaces:

| Namespace | Purpose | Current inventory |
| --- | --- | --- |
| `gold_scenarios.*` | Scenario outputs at team/match or player grain | 48 tables (23 team, 25 player) |
| `gold_signals.*` | Signal outputs at match, team, or player grain | 344 `sig_*` tables |
| `gold.*` | Shared activation serving metadata | `signal_activations` |

Gold setup DDL lives under `clickhouse/gold/ddl/`; transforms live under
`clickhouse/gold/dml/`:

- `ddl/00_create_database.sql`
- `ddl/01_create_scenario_tables.sql`
- `ddl/create_table_signal_activations.sql`
- `ddl/signals/{match,team,player}/create_table_{entity}_{family}_{subfamily}.sql`
- `ddl/activations/create_table_signal_activations_stage.sql`
- `dml/scenarios/{team,player}/scenario_*.sql`
- `dml/signals/{match,team,player}/sig_*.sql`
- `dml/activations/signal_activation_final_insert.sql`

Signal metadata is authored in `scripts/gold/signal/catalogs/*.md`. Scenario
narrative docs live in `scripts/gold/scenario/scenarios_catalog.md`.

## Glossary

### Bronze S3 Sync

An operator-invoked, date-scoped transfer of FotMob Bronze artifacts between
canonical local storage and S3-compatible object storage. It is independent of
scraping and warehouse orchestration: neither scraping nor the pipeline starts
an upload or download, and their success never depends on S3 availability.

Avoid saying: automatic S3 backup, post-scrape upload, pipeline S3 stage.
Related terms: Bronze Layer, Bronze Retention.

### Signal Activation

A Gold serving fact row that records one triggered signal output row for one
match, team, or player occurrence. It includes stable activation identity,
signal catalog metadata, common fixture/team/player context, match-level
activation summary fields, and a JSON payload copied from the source
`gold_signals.sig_*` row.

Related terms: Signal, Signal Catalog, Signal Activation ID.

### Gold Activation Rebuild

The process that regenerates Gold activation metadata from active signal
catalogs and `gold_signals.sig_*` output tables. The canonical rebuild strategy
is full-table: rebuild the single serving table `gold.signal_activations` from
all active signal output rows.

Avoid saying: incremental activation patch, scoped activation patch.
Related terms: Signal Activation, Signal Activation ID.

### Signal Activation ID

A deterministic identifier for one signal activation. It is derived from the
activation identity scheme version, `signal_id`, and the catalog `row_identity`
values. It identifies the activated row occurrence, not the version of the
signal's football logic.

Avoid saying: signal version, catalog version.
Related terms: Signal Activation, Signal Identity Scheme Version, Signal
Definition Version.

### Signal Identity Scheme Version

The version prefix used in signal activation ID hashing, currently `v1`. It
changes only when DepthMark intentionally changes the activation identity
contract, such as hash serialization, required identity fields, null handling,
or the meaning of one activation row.

Avoid saying: signal definition version.
Related terms: Signal Activation ID, row_identity.

### Signal Definition Version

A future catalog concern for tracking changes to a signal's football logic,
thresholds, SQL implementation, or authored metadata. It is separate from signal
activation identity.

Related terms: Signal Catalog, Signal Activation ID.

### Signal Catalog

A markdown-authored description of one Gold signal, including frontmatter
metadata and human-readable explanation. The catalog frontmatter is the
canonical source for signal metadata that is synchronized into MongoDB.

Related terms: Signal Activation, Signal Catalog Sync.

### Signal Catalog Sync

The process that reads markdown signal catalogs and writes derivative documents
to the MongoDB `signals` collection for serving and querying.

Avoid saying: Mongo catalog authoring.
Related terms: Signal Catalog.

### Bronze Retention

Bronze filesystem files (`data/fotmob/`) are retained indefinitely by default.
Cleanup of raw match files, daily listings, and compressed archives is
operator-initiated and manual only. No automated deletion scripts or TTL
mechanisms apply to Bronze filesystem artifacts. Before deleting, the operator
queries ClickHouse `bronze.*` tables directly to verify the data is loaded — no
filesystem-side load-confirmation marker is used because it would go stale on
re-runs, truncates, or table drops.

Avoid saying: automatic cleanup, TTL-based expiry, retention policy, load
marker, loaded lock.
Related terms: Bronze Layer, DLQ.

### DLQ Replay

Dead Letter Queue replay is a manual operator workflow. When ClickHouse
insertion failures produce DLQ files under `data/dlq/`, the operator inspects
the JSONL records, fixes the root cause, and re-runs the Bronze loader for the
affected date. No automated retry or reprocessing script exists or is planned.

Avoid saying: automated replay, DLQ retry, reprocessing pipeline.
Related terms: Dead Letter Queue, Bronze Retention.

### Application Service

A stable, layer-specific coordination module under `src/services/` that sits
behind a script entry point. Application services own reusable workflow
coordination: SQL job discovery and execution, client setup, contract checks,
validation, alerts, and deterministic summaries. They must not own Silver or Gold
analytical logic, which belongs in ClickHouse SQL.

Avoid saying: business logic, analytical service, domain service.
Related terms: Script Entry Point, Layer.

### Gold Scenario Bulk Loading

The execution of all scenario SQL jobs through the bulk Gold loader
(`scripts/gold/load_clickhouse_gold.py`). Scenarios follow the same failure
pattern as signals: a scenario failure blocks signal activation builders and
produces a non-zero exit code. The `--part` flag accepts `scenarios` as an
explicit selector.

Avoid saying: scenario bulk disabled, scenario opt-in, scenario validation pending.
Related terms: Gold Bulk Loading, Gold Service, Scenario SQL Job.

### FotMob Provider Scope

DepthMark currently supports FotMob only. There is no provider abstraction
boundary. Code that looks generic (e.g., `BaseBronzeStorage` ABC, `--skip-fotmob`
flag) is a FotMob-specific implementation detail, not an invitation to add new
providers. A second provider abstraction will be added only when a concrete
second provider needs to be supported.

Avoid saying: multi-provider pipeline, provider plugin, provider abstraction.
Related terms: Bronze Layer, FotMob API.

### DLQ Retention

DLQ files (`data/dlq/`) follow the same retention rule as Bronze filesystem
files: indefinitely retained, manual cleanup only. DLQ files are small and
infrequent, created only on ClickHouse insertion failure, and carry audit value.

Avoid saying: DLQ TTL, DLQ rotation, automatic DLQ cleanup.
Related terms: Dead Letter Queue, Bronze Retention, DLQ Replay.

### Telegram Client

A thin transport layer under `src/services/telegram/client.py` that handles
Bot API communication. All Telegram message sending goes through this single
client. It reads configuration from `config.settings` (Pydantic, reads `.env`).

Avoid saying: TelegramMetricsReporter, AlertManager, TelegramChannel,
send_raw_telegram_message.
Related terms: Telegram Message Template, Telegram Message Data.

### Telegram Message Template

A Jinja2 `.html.j2` file under `src/services/telegram/templates/` that defines
the HTML structure of one message family. Templates render to HTML for
Telegram's `parse_mode="HTML"`. Five families exist: daily report, monthly
report, layer alert, pipeline summary, and error alert.

Avoid saying: inline f-string formatting, HTML string concatenation.
Related terms: Telegram Client, Telegram Message Data.

### Telegram Message Data

A Python dataclass under `src/services/telegram/messages.py` that carries the
typed payload for one message family. Callers construct a dataclass instance and
pass it to `TelegramClient.render_and_send()`. Five dataclasses exist:
`DailyReportData`, `MonthlyReportData`, `LayerAlertData`,
`PipelineSummaryData`, `ErrorAlertData`.

Avoid saying: kwargs dict, **kwargs, send_daily_report parameters.
Related terms: Telegram Client, Telegram Message Template.

### Pipeline Summary

A Telegram message family (currently missing) that reports per-step status,
duration, and success/failure for the full pipeline run. Emitted by
`scripts/orchestration/pipeline.py` after all steps complete.

Avoid saying: pipeline completion alert, pipeline final message.
Related terms: Telegram Message Template, Layer Alert.
