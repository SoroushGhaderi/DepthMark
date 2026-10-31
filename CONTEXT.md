# Context

## Layer Inventory

DepthMark has two explicit source domains, FotMob and Oddspedia. Each source
follows its own Bronze → Silver → Gold medallion path with isolated raw
contracts. FotMob remains the canonical fixture-reference source for the
cross-source match relationship; that relationship does not replace Oddspedia
Silver or Gold.

### FotMob Silver (`silver.*`)

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

### Oddspedia Silver

Oddspedia Silver owns cleaned event/odds entities and the auditable
`silver.oddspedia_match_resolution` relationship. It may read the canonical
FotMob `silver.match` reference for matching, but it does not rewrite FotMob
rows. Additional Oddspedia Silver outputs remain source-specific as they are
implemented.

### FotMob Gold

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

Signal metadata is authored in `catalogs/signals/*.md`. Scenario
narrative docs live in `catalogs/scenarios/SCENARIOS_CATALOG.md`.

### Oddspedia Gold

Oddspedia Gold is the source-owned product layer for odds-derived scenarios,
signals, and serving outputs. It follows the same responsibility boundary as
FotMob Gold but must not reuse FotMob Gold SQL or silently write to FotMob
signal tables. Its detailed DDL, SQL, catalogs, and loaders are follow-up
implementation work.

## Glossary

### Scraping Report Interface

The single read-only operational surface for reconciling FotMob and Oddspedia
scraping state: `scripts/report_scraping.py` or `depthmark report-scraping`.
It owns date/month/range scope, common summary fields, aggregation, rendering, and
automation exit policy. Explicit source adapters own source-specific artifact
reads; they do not merge raw contracts or create a provider abstraction.

Avoid saying: status script, provider report framework.
Related terms: Historical Scrape, Live Scrape, Bronze Layer.

### Oddspedia Artifact Contract

The immutable top-level and nested JSON structures for Oddspedia daily
listings, per-event payloads, and scrape manifests. Runtime models validate new
writes while external schemas under `schemas/oddspedia/` document compatibility.
Validation never serializes its model back over raw source data; manifest
updates preserve unknown compatible fields.

Avoid saying: normalized payload, migrated raw JSON.
Related terms: Source Event, Bronze Layer, Scraping Report Interface.

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

A signal's Row Identity is one chain: the catalog `row_identity`, the DDL
`signal_instance_id` default hash (`row_identity` in catalog order, with
`match_id` prepended when absent), and the Signal Activation ID must all use the same columns in
the same order. The DDL `ORDER BY` is a physical sort key, not the Row Identity;
it only has to end with `signal_instance_id`.

Related terms: Logical Duplicate Identity, Physical Row Version, Signal
Activation ID.

### Bronze Admission

The fail-closed step that turns processed FotMob rows into the exact shape of
their Bronze table, driven by the table's setup DDL under `clickhouse/bronze/`
(`src/fotmob/bronze/admission.py`). Every table of a date is admitted before
anything is inserted. A value is converted only when the conversion is
lossless; anything else, including an undeclared key, an out-of-range integer,
or a `NULL` in a non-`Nullable` column, fails the date with the table, column,
rule, and `match_id` examples. Exact duplicate rows collapse; rows that share a
Row Identity but differ fail.

Avoid saying: schema fixing, type repair, clipping, default filling.
Related terms: Row Identity, Schema Drift, Bronze Layer, Date-Level Failure.

### Date-Level Failure

A Bronze load failure confined to one date's source: an unreadable payload, a
processor error, or a value that fails Bronze Admission. The date is recorded as
failed and nothing is inserted for it; the run continues with the remaining dates
and exits non-zero with every failed date and its cause.

Avoid saying: skipped date, partial success.
Related terms: Run-Level Failure, Bronze Admission.

### Run-Level Failure

A Bronze load failure that would affect every remaining date: a missing or
drifted table, a failed truncate, a lost connection, or a failed insert. The run
stops immediately and exits non-zero.

Avoid saying: fatal error, crash.
Related terms: Date-Level Failure, Schema Drift.

### Schema Drift

A difference between an existing warehouse table and its setup DDL in column
names, column types, or `ORDER BY` sorting key. Normal setup fails closed on
schema drift instead of changing the table. A change confined to a `DEFAULT`
expression, such as an activation identity scheme version, is not schema drift;
applying it is a deliberate operator action.

Avoid saying: stale table, schema mismatch, outdated DDL.
Related terms: Table Recreation, Row Identity, Signal Identity Scheme Version.

### Table Recreation

An explicit operator maintenance action that drops selected warehouse tables
and creates them again, empty, from their setup DDL. It is the only supported
way to apply schema drift. Table recreation never repopulates rows; the operator
reloads the affected scope through the normal layer loader afterward.

Avoid saying: table rebuild, schema reset, schema migration.
Related terms: Schema Drift, Bronze Rebuild, Gold Activation Rebuild.

### Bronze Rebuild

Truncate-and-reload of all FotMob Bronze history without the empty window
(`load-fotmob-bronze --full-history --rebuild`): every Source Date loads into
copies of the warehouse tables in the Staging Database, which are swapped in
only if every date loaded. On any failure Bronze is left unchanged. It replaces
data, never table definitions.

Avoid saying: table recreation.
Related terms: Table Recreation, Bronze Removal, Source Date, Staging Database.

### Bronze Removal

Deleting the matches of a Source Date scope from every FotMob Bronze table
(`remove-fotmob-bronze`); full history truncates the tables. Removal touches
only Bronze and reports the Match Dates whose Silver and Gold scopes are now
stale. `load-fotmob-bronze --replace` removes and reloads each Source Date only
after its rows pass Bronze Admission.

Avoid saying: cascade delete, purge.
Related terms: Bronze Rebuild, Source Date, Match Date.

### Scope Publication

The durable status of one scoped Silver or Gold batch for one month partition
(or partition `0` for full history): `committing`, then `published` once every
target table committed, or `failed` with the tables that did commit. A
partition whose latest status is not `published` may mix table versions, and
readers must not consume it until a rerun publishes it.

Avoid saying: load status, watermark, commit marker.
Related terms: Warehouse Execution Scope, Gold Activation Rebuild.

### Application Identity

The ClickHouse user that routine loads, resolution, and quality checks run as.
It reads, inserts, and replaces or drops partitions in warehouse databases, and
creates, optimizes, and drops tables only in the Staging Database. It cannot
drop, truncate, optimize, rename, or alter columns of a warehouse table.

Avoid saying: runtime user, service account, admin user.
Related terms: Maintenance Identity, Staging Database.

### Maintenance Identity

The ClickHouse user that runs setup (which provisions the Application
Identity), full-history table swaps, Table Recreation, optimization, drop
scripts, and Bronze truncation.

Avoid saying: root user, default user, superuser.
Related terms: Application Identity, Table Recreation.

### Staging Database

`warehouse_stage`, the only database where scoped loads create calculation,
replacement, and activation staging tables. Warehouse databases hold only
setup-declared tables.

Avoid saying: temp tables, scratch schema.
Related terms: Application Identity, Scope Publication.

### Server Bootstrap

The single idempotent command, `scripts/bootstrap.sh`, that initializes or
upgrades a DepthMark host: it prepares `.env` with generated database secrets,
starts the stack, runs warehouse and MongoDB setup, checks health, and installs
the schedule. Any new initialization step belongs in it.

Avoid saying: install script, manual setup, provisioning runbook.
Related terms: Maintenance Identity, Scheduled Job.

### Scheduled Job

A recurring job (`fotmob-daily`, `oddspedia-daily`) run by
`scripts/orchestration/run_scheduled_job.py`, which computes its target date and
holds its own overlap lock. The host crontab only invokes it.

Avoid saying: cron script, timer job.
Related terms: Server Bootstrap.

### Historical Scrape

A FotMob Bronze scrape whose scope contains only completed calendar dates,
strictly before the machine's current local date. Historical selectors exclude
today and reject future dates. Historical payloads and listings belong under
`data/fotmob/historical/` and retain the existing completed-date compression
behavior.

Avoid saying: current scrape, live scrape.
Related terms: Live Scrape.

### Source Date

The calendar date of the Historical Bronze folder a FotMob match payload is
stored under, `data/fotmob/historical/matches/YYYYMM/YYYYMMDD/`, taken from the
folder name. It is the scope of every FotMob Bronze command (load, removal,
rebuild). Bronze tables do not store it: a Source Date's matches are the
`general.matchId` values of the payloads stored under its folder. It is never
read from the payload's own dates, and it can differ from the Match Date at day
boundaries.

Avoid saying: scrape date, load date, match date.
Related terms: Match Date, Historical Scrape, Warehouse Execution Scope.

### Match Date

The UTC calendar date of a match's kickoff, read from the payload into
`bronze.match_reference.match_date`. Silver and Gold scopes (Warehouse Execution
Scope) use the Match Date; Bronze commands use the Source Date.

Avoid saying: source date, fixture day.
Related terms: Source Date, Warehouse Execution Scope.

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
Scope, Table Recreation.

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
canonical source for signal metadata that is synchronized into MongoDB. Every
consumer reads catalogs through one validated loader, and one invalid catalog
fails every consumer rather than dropping that signal.

Related terms: Signal Activation, Signal Catalog Sync, Signal Entity, Signal
Status, Signal Grain.

### Signal Entity

The subject scope of a signal: `match`, `team`, or `player`. It is the second
segment of `signal_id` (`sig_<entity>_<family>_<subfamily>_<name>`), and catalog
frontmatter `entity` must equal it. The row grain is a separate property held in
`grain`; a match signal emitted once per side has entity `match` and grain
`match_team`.

Avoid saying: entity as row grain, team entity for a match signal.
Related terms: Signal Catalog, Signal Grain.

### Signal Grain

The row grain of a signal output table, held in catalog `grain`: `match_team`
for match and team signals (one row per triggered side) and `match_player` for
player signals (one row per triggered player).

Related terms: Signal Entity, Row Identity.

### Signal Status

The lifecycle state in catalog frontmatter `status`: `active` or `deprecated`.
An active signal runs in Gold, appears in Signal Activations, and syncs to
MongoDB. A deprecated signal does not run in Gold and is excluded from Signal
Activations, but still syncs to MongoDB with its status and keeps its table and
identity checks. Deprecation applies to scopes rebuilt after the change; older
scopes keep their activations until a full-history activation rebuild.

Avoid saying: inactive, experimental, disabled signal.
Related terms: Signal Catalog, Gold Activation Rebuild.

### Signal Catalog Sync

The process that makes the MongoDB `signals` collection an exact mirror of the
validated signal catalogs: it replaces changed documents, leaves unchanged ones
untouched, and deletes documents whose signal no longer has a catalog.
Deprecated signals remain in the mirror.

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

### Approximate Team Match

A team-name comparison that recognizes an equivalent provider spelling without
requiring an exact normalized name. It canonicalizes non-identifying club
designators and equivalent second-team notation (`II` and `2`), then permits
token reordering, a reviewed alias, containment of a distinctive shortened
team name, or a unique long shared token. A unique-token comparison is valid
only when the opposite team is exact or a reviewed alias. Approximate evidence
is accepted automatically only when both home and away sides form a unique
high-confidence fixture pair.

Avoid saying: loose match, best guess.
Related terms: Match Resolution, Source Event.

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

### Link Validation

The pre-scrape comparison of one discovered Oddspedia event link against
canonical FotMob fixtures in `silver.match` within its three-day reference
window (the discovery date, one day before, and one day after). It records a
deterministic validation status and, only for a unique match, the canonical
FotMob match ID and coverage level in a separate derived priority artifact.
The window is the sole date constraint: matching evidence consists only of the
normalized home and away team names. Kickoff, league, and other provider
metadata are preserved for review but do not influence the decision.
The artifact also preserves the FotMob reference fields for the matched row,
or a clearly labelled top candidate for an ambiguous result, to make the
provider comparison reviewable without changing source facts.
It uses the same matching policy, aliases, scoring thresholds, and rule version
as the later Silver Match Resolution; the latter verifies and persists the
same decision after source payload loading rather than applying a competing
matcher.

Priority Generation fails closed unless the three-day Silver reference window
is confirmed complete. It does not emit a new priority artifact from partial
reference data, because doing so could misclassify a missing canonical fixture
as `unmatched`. The explicit readiness assertion is
`--depthmark-window-ready`; it means the operator confirms DepthMark completed
the needed Silver reference window.

When a matcher update increases the selected priority set, a rerun uses the
accepted per-event JSON payload as the completion record. It skips already
saved events and scrapes only the newly selected event IDs.

Avoid saying: Match Resolution, post-scrape match check.
Related terms: Source Event, Match Resolution, Link Priority.

### Link Priority

The inclusive scrape-selection tier assigned during Link Validation. Tiers are
ordered `xG`, `ratings`, `lower`, then `unmatched`; a selected tier includes
every higher tier. `ambiguous` and `unresolved` are not priority tiers and are
excluded from automatic scraping. The default selected tier is `lower`.

Link Priority artifacts live under the Oddspedia Historical data root, separate
from the source-faithful daily link inventory. They preserve a compact decision
ledger keyed by Oddspedia event ID, with a common provider-pair comparison and
the decision policy that controlled a scrape run. Raw Oddspedia source facts
remain only in the daily link inventory and are rehydrated by ID for scraping.
The canonical per-date snapshot is
`data/oddspedia/historical/link_priorities/YYYYMM/YYYYMMDD/prioritized_match_links.json`;
it contains the prioritized date as explicit metadata. It contains every
discovered Oddspedia event's validation result, including matched coverage tiers
and excluded `ambiguous` or `unresolved` outcomes; it is not limited to the
current scrape selection.

The per-date manifest records a `priority_run` audit section rather than
duplicating each link decision. It references the priority artifact and its
checksum, the prioritized date, matcher/policy version, selected priority tier,
selected count, and counts by validation status and tier.

Related terms: Link Validation, Coverage Category, Resolution Status.

### Priority Generation

The explicit Oddspedia workflow that produces the Link Priority artifact for a
date from an accepted source link inventory and the corresponding three-day
`silver.match` reference window. The combined workflow runs discovery, then
Priority Generation, then scraping. A priority-selected scrape requires a
current Priority artifact whose source-inventory reference still matches the
saved links.

Related terms: Link Validation, Link Priority, Source Event.

### Oddspedia Event Intake

The Oddspedia command workflow that discovers event links, generates Link
Priorities, and scrapes selected event pages. Its canonical entry points are
`discover_oddspedia_events.py`, `prioritize_oddspedia_events.py`,
`scrape_oddspedia_matches.py`, and `run_oddspedia_pipeline.py`. The earlier
umbrella and phase-only filenames are Compatibility Script Aliases, not public
process names for new automation.

Related terms: Source Event, Priority Generation.

### Canonical Source Command

A supported operational script whose filename exposes action and source using
`<verb>_<source>[_<layer-or-entity>].py`, or the equivalent hyphenated package
command. Canonical Source Commands are the only names used by current runbooks,
internal orchestration, generated operator guidance, and new automation.

Avoid saying: preferred alias, generic provider command.
Related terms: Compatibility Script Alias, Application Service, Source Domain Scope.

### Compatibility Script Alias

An earlier script path or package command retained to protect existing
automation while the Canonical Source Command is adopted. It delegates to the
same implementation, preserves arguments and exit codes, and emits a
deprecation warning naming its replacement. It is not a second canonical
interface.

Avoid saying: canonical wrapper, alternate supported name.
Related terms: Canonical Source Command, Application Service.

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
(`scripts/gold/load_fotmob_gold.py`). Scenarios follow the same failure
pattern as signals: a scenario failure blocks signal activation builders and
produces a non-zero exit code. The `--part` flag accepts `scenarios` as an
explicit selector, and every run also requires a Warehouse Execution Scope.

Avoid saying: scenario bulk disabled, scenario opt-in, scenario validation pending.
Related terms: Gold Bulk Loading, Gold Service, Scenario SQL Job.

### Source Domain Scope

DepthMark has two explicit source domains: FotMob and Oddspedia. Both own
source-specific Bronze, Silver, and Gold stages. FotMob remains the canonical
fixture reference for the explicit relationship from Oddspedia Silver to
`silver.match`; it does not own Oddspedia's entire medallion path. There is no
generic provider abstraction boundary. Code that looks reusable, such as
`BaseBronzeStorage`, remains a source implementation detail rather than an
invitation to add a provider plugin framework.

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
`scripts/orchestration/run_fotmob_pipeline.py` after all steps complete.

Avoid saying: pipeline completion alert, pipeline final message.
Related terms: Telegram Message Template, Layer Alert.
