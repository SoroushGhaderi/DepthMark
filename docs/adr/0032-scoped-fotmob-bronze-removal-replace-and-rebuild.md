# ADR 0032: Scoped FotMob Bronze Removal, Replace, and Staged Rebuild

## Status

Accepted

## Context

`load-fotmob-bronze --truncate` was the only way to clear FotMob Bronze data. It
truncated all 15 tables, whatever the selected scope, and then loaded: the
documented `--date 20251113 --truncate` emptied every date in history to reload
one day. Truncation ran before loading, so any failure afterwards left Bronze
empty or partial, and readers (Silver loads, quality checks, reports) saw that
state for the whole load. There was no way to remove one date's data.

Three facts shaped the design:

- **Bronze has two dates.** The loader's `--date D` selects the Source Date, the
  Historical folder `matches/YYYYMM/D/` the payloads are stored under. Bronze
  tables store only the Match Date, the UTC kickoff date. They differ at day
  boundaries (the 2026-06-27 folder holds 164 matches; 178 Bronze rows have that
  Match Date).
- **Most Bronze tables cannot drop a date's partition.** 11 of 15 tables are
  partitioned by `toYYYYMM(inserted_at)`, the load time, so one Source Date's
  rows are spread across partitions and must be deleted by `match_id`.
- **Only scheduled jobs took a lock.** A manual rebuild or removal could run
  while the nightly job loads Bronze, and a rebuild would then swap away the
  nightly rows.

## Decision

1. **Every FotMob Bronze command is scoped by Source Date**, the folder name. A
   Source Date's matches are the `general.matchId` values of the payloads stored
   under its folder, read with the loader's own reader, so removal deletes
   exactly what a load of the same date inserts. No column records the Source
   Date; ADR 0012 retains the files that resolve it. If a date's files were
   deleted, its rows cannot be identified, and removing or replacing it is a
   Date-Level Failure.
2. **`remove-fotmob-bronze` removes data.** With `--date`, `--month`, or a range
   it deletes each Source Date's matches from all 15 tables
   (`ALTER TABLE ... DELETE`, waited for synchronously) using the Application
   Identity. `--full-history` truncates the tables using the Maintenance Identity;
   truncation is removal of every date. `--dry-run` reports the rows per table
   that would be removed and changes nothing.
3. **Removal touches only Bronze.** It does not cascade into Silver or Gold,
   whose loaders own their tables and whose scopes are Match Dates. It reports
   the Match Dates of the removed matches and the Silver and Gold commands that
   rebuild those now-stale scopes.
4. **`load-fotmob-bronze --replace` reloads a scope.** For each Source Date it
   reads and admits the payloads first, then removes the date's matches, then
   inserts. A date that fails admission keeps its existing rows.
5. **`load-fotmob-bronze --full-history --rebuild` is truncate-and-reload
   without the empty window.** It loads every Source Date into copies of the
   warehouse tables in the Staging Database (`CREATE TABLE ... AS bronze.<table>`)
   and swaps them in with `EXCHANGE TABLES` only if every date loaded and at
   least one row did. Otherwise the copies are dropped and Bronze is unchanged.
   It fails closed on Schema Drift and never changes a table definition (ADR
   0026), and it uses the Maintenance Identity (ADR 0029).
6. **`--truncate` is deprecated.** With `--full-history` it warns and runs a
   rebuild. With any narrower scope it is rejected and names `--replace` and
   `remove-fotmob-bronze`, because it would erase every date to reload a few.
7. **One FotMob Bronze write lock.** Load, replace, rebuild, and removal take an
   exclusive, non-blocking lock (`data/locks/fotmob_bronze.lock`) for the whole
   run. A second writer fails immediately, as a Run-Level Failure, naming the
   holder's command, process, host, and start time. A scheduled job that meets
   the lock fails visibly rather than skipping. `--dry-run` takes no lock.

## Consequences

Clearing data is now as narrow as the problem: one date, a month, a range, or
everything. Reloading a scope never empties it first, and a full rebuild keeps
the old Bronze readable until the new one is complete.

A rebuild needs disk for a second copy of Bronze while it runs. Each
`EXCHANGE TABLES` is atomic per table but not across the 15 tables; a crash
during the swap loop can leave them mixed until the rebuild is rerun, the same
trade-off ADR 0028 accepts for Silver and Gold.

`--truncate` with a date, month, or range scope now fails. Scripts that used it
must switch to `--replace` (reload a scope) or `remove-fotmob-bronze` (clear
it).

Removal and replace depend on retained source files. Deleting a date's files
under ADR 0012 also removes the ability to remove that date's Bronze rows by
Source Date; only a full-history removal or rebuild covers it afterwards.
