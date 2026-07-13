# Context

## Layer Inventory

DepthMark's analytical medallion path is FotMob-canonical and ClickHouse-backed
from Silver upward. Oddspedia is an isolated source domain with
`oddspedia_bronze.*` facts and an auditable relationship to `silver.match`; it
does not alter the canonical FotMob entities or Gold outputs.

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
`src/warehouse/contracts.py`.

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
narrative docs live in `scripts/gold/scenario/SCENARIOS_CATALOG.md`.

## Glossary

### Logical Duplicate Identity

More than one current row for the same declared row identity in ClickHouse's
logical `FINAL` view. Logical duplicates are data-correctness failures and may
fail the strict warehouse quality gate.

Avoid saying: physical duplicate, unmerged version.
Related terms: Physical Row Version, Row Identity.

### Physical Row Version

One of multiple stored `ReplacingMergeTree` rows sharing a declared identity
before background merging collapses older versions. Extra physical versions
are storage and merge-health diagnostics, not logical duplicate failures.
Routine setup does not compact these versions; operators use quality diagnostics
to decide whether explicit maintenance is needed.

Avoid saying: logical duplicate, duplicate business row.
Related terms: Logical Duplicate Identity, Row Identity.

### Row Identity

The ordered columns that identify one row at its declared table grain. Bronze
and Silver identities come from layer contracts, scenario identities from DDL
sorting keys, signal identities from catalog `row_identity`, and activation
identity from `signal_instance_id`.

Related terms: Logical Duplicate Identity, Physical Row Version.

### Historical Scrape

A FotMob Bronze scrape whose scope contains only completed calendar dates,
strictly before the machine's current local date. Historical selectors exclude
today and reject future dates. Historical payloads and listings belong under
`data/fotmob/historical/` and retain the existing completed-date compression
behavior.

Avoid saying: current scrape, live scrape.
Related terms: Live Scrape.

### Live Scrape

A FotMob Bronze scrape explicitly selected by `--today` and scoped to the
machine's current local calendar date. Live payloads and listings belong under
`data/fotmob/live/`, remain uncompressed, and are not currently inputs to other
medallion-layer flows. The date boundary comes from the system clock rather
than the FotMob API timezone configuration.

Avoid saying: historical scrape, latest-date scrape, today scrape.
Related terms: Historical Scrape.

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
signal catalog metadata, common fixture, league, venue, team, and player
context, match-level activation summary fields, and a JSON payload copied from the source
`gold_signals.sig_*` row.

Related terms: Signal, Signal Catalog, Signal Activation ID.

### Gold Activation Rebuild

The process that regenerates Gold activation metadata from active signal
catalogs and `gold_signals.sig_*` output tables. The canonical rebuild strategy
matches the selected warehouse execution scope: replace activation rows only
for the selected date or month during a scoped run, and rebuild the complete
table only during an explicit full-history run. Scoped replacement reads all
upstream context required to calculate correct results but must not replace
activation rows outside the selected output scope.

Avoid saying: unbounded activation rebuild, incremental activation patch.
Related terms: Signal Activation, Signal Activation ID, Warehouse Execution
Scope.

### Warehouse Execution Scope

The explicit match-date output boundary selected for a Silver or Gold run. A
scope is one calendar date, one calendar month, or full history. A scoped job
may read earlier historical context when its analytical logic requires it, but
it replaces only rows whose match-date lineage belongs to the selected output
boundary.

Avoid saying: inserted-at window, implicit full load.
Related terms: Gold Activation Rebuild, Historical Scrape.

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

### Canonical FotMob Fixture Reference

The record in `silver.match` that is authoritative for FotMob match identity,
UTC kickoff, teams, league context, and FotMob coverage level. An Oddspedia
event may be linked to this reference but cannot change it.

Avoid saying: shared raw event, merged source payload.
Related terms: Source Event, Match Resolution, Coverage Category.

### Source Event

An event as recorded by one provider. An Oddspedia Source Event owns its
Oddspedia identity, source URL, discovered metadata, and extracted odds; it is
not itself a FotMob match.

Avoid saying: canonical match, merged fixture.
Related terms: Canonical FotMob Fixture Reference, Match Resolution.

### Match Resolution

The auditable relationship from one Oddspedia Source Event to at most one
Canonical FotMob Fixture Reference. A resolution records its evidence,
confidence, and rule version rather than rewriting either source record.

Related terms: Resolution Status, Coverage Category.

### Resolution Status

The state of a Match Resolution: `matched` for one confirmed FotMob fixture,
`ambiguous` for more than one plausible candidate, `unmatched` when a complete
reference window safely contains no matching fixture, and `unresolved` when
source data or evidence is insufficient.

Avoid saying: not covered when the source window is incomplete.
Related terms: Match Resolution, Coverage Category.

### Coverage Category

The business classification of a resolved Oddspedia Source Event derived from
the linked FotMob coverage level: `xG`, `ratings`, or `lower`. `not_covered`
is allowed only for an `unmatched` event with a complete FotMob reference
window; unresolved events have no Coverage Category.

Related terms: Canonical FotMob Fixture Reference, Resolution Status.

### Bronze Retention

Historical and Live Bronze filesystem files beneath `data/fotmob/` are retained
indefinitely by default.
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

A stable source-specific or warehouse coordination module that sits behind a
script entry point. Workflow modules own reusable workflow
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
explicit selector, and every run also requires a Warehouse Execution Scope.

Avoid saying: scenario bulk disabled, scenario opt-in, scenario validation pending.
Related terms: Gold Bulk Loading, Gold Service, Scenario SQL Job.

### Source Domain Scope

DepthMark has two explicit source domains: FotMob and Oddspedia. FotMob remains
the canonical fixture reference and continues through Gold; Oddspedia owns
source artifacts, `oddspedia_bronze.*` facts, and its audited Silver resolution
to `silver.match`. There is no generic provider abstraction boundary. Code that
looks reusable, such as `BaseBronzeStorage`, remains a FotMob implementation
detail rather than an invitation to add a provider plugin framework.

Avoid saying: generic provider framework, provider plugin, provider abstraction.
Related terms: Bronze Layer, FotMob API, Oddspedia.

### DLQ Retention

DLQ files (`data/dlq/`) follow the same retention rule as Bronze filesystem
files: indefinitely retained, manual cleanup only. DLQ files are small and
infrequent, created only on ClickHouse insertion failure, and carry audit value.

Avoid saying: DLQ TTL, DLQ rotation, automatic DLQ cleanup.
Related terms: Dead Letter Queue, Bronze Retention, DLQ Replay.

### Telegram Client

A thin transport layer under `src/integrations/telegram/client.py` that handles
Bot API communication. All Telegram message sending goes through this single
client. It reads configuration from `config.settings` (Pydantic, reads `.env`).

Avoid saying: TelegramMetricsReporter, AlertManager, TelegramChannel,
send_raw_telegram_message.
Related terms: Telegram Message Template, Telegram Message Data.

### Telegram Message Template

A Jinja2 `.html.j2` file under `src/integrations/telegram/templates/` that defines
the HTML structure of one message family. Templates render to HTML for
Telegram's `parse_mode="HTML"`. Five families exist: daily report, monthly
report, layer alert, pipeline summary, and error alert.

Avoid saying: inline f-string formatting, HTML string concatenation.
Related terms: Telegram Client, Telegram Message Data.

### Telegram Message Data

A Python dataclass under `src/integrations/telegram/messages.py` that carries the
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
