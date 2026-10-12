# ADR 0031: Fail-Closed FotMob Bronze Admission

## Status

Accepted

## Context

The FotMob Bronze loader reported success when it had lost data:

- `process_fotmob_table` and `_process_special_fotmob_table` caught every
  insert error and returned 0 rows. `insert_dataframe_with_dlq` wrote the DLQ
  and re-raised, but the callers swallowed the error, so a failed table loaded
  as "0 rows" and the run exited 0. Silver and Gold then published the scope
  without that table.
- A missing Bronze table also returned 0 rows, and `load_fotmob_data` caught
  any other exception for the whole date and returned partial counts.
- An unreadable payload file was logged and skipped. Each processor section
  caught every exception, and every row its Pydantic models rejected was logged
  and dropped. Truncation failures were logged and ignored.

Each table's shape was defined in four places: the processor's keys, a
hard-coded rename map in the loader, type coercion against a live `DESCRIBE`,
and the layer contract. The coercion changed data silently: integers outside
their type were clipped, fractional values in integer columns were rounded,
`NULL` in non-`Nullable` columns became `0` or `""`, invalid dates became
`1970-01-01`, and keys the DDL did not declare were dropped.

Synthetic event ids exposed a further loss. When FotMob omits an event id, the
processor derives one from the event's attributes. Two different events with the
same attributes received the same id, and `ReplacingMergeTree` kept only one.

## Decision

FotMob Bronze loading is fail-closed, and any failure exits non-zero. Every
table of a date is read, processed, and admitted before anything is inserted,
so those failures insert nothing. An insert failure can leave the date's
earlier tables inserted; rerunning the date converges because Bronze tables are
`ReplacingMergeTree`. Inserts are not wrapped in a cross-table transaction,
which ClickHouse does not offer.

1. **The setup DDL is the only table definition.**
   `src/fotmob/bronze/admission.py` parses `clickhouse/bronze/*.sql` into table
   specs. `BRONZE_REQUIRED_KEYS` stays the declared row identity; loading the
   specs fails if an identity column is missing from the DDL or `Nullable`.
   The processor emits the DDL column names directly, so the loader keeps no
   rename map.
2. **Bronze Admission checks every value of a date before any insert.** A value
   is converted only when the conversion is lossless: booleans to 0/1, integral
   floats and digit strings to integers, numeric text to floats, temporal values
   to ISO-8601 text in `String` columns, `NULL` to `[]` in `Array` columns. Every
   other mismatch is a violation: an undeclared key, a `NULL` in a non-`Nullable`
   column, an integer out of range or with a fraction, a container or float in a
   `String` column, an invalid date. A column absent from every row is omitted
   when the DDL gives it a `DEFAULT` (so ClickHouse fills `inserted_at`), sent as
   `NULL` when `Nullable`, and is a violation otherwise.
3. **Identity is checked before insert.** Identity values must be positive where
   numeric. Rows that repeat an identity with identical values collapse into one
   and are logged; rows that share an identity but differ are a violation,
   because ClickHouse would keep only one of them.
4. **Every failure names its cause, and its class decides its reach.**
   - A **Date-Level Failure** is confined to one Source Date's source: an
     unreadable payload (names the file), a processor section error (names the
     match, section, and source artifact), a row the source models reject (names
     the table, match, and field), or values that fail admission (each table,
     column, rule, count, and up to three `match_id` examples in one error).
     Nothing is inserted for that date. The run records it and continues with
     the remaining dates, so one run reports every broken date instead of the
     first.
   - A **Run-Level Failure** would affect every remaining date: a missing or
     drifted table, a lost connection, a failed insert (written to `data/dlq/`,
     ADR 0012), a post-load contract failure, an unexpected error, or a held
     Bronze write lock (ADR 0032). The run stops immediately.

   Either class makes the run exit non-zero; the result lists every failed date
   with its cause, and a run-level error separately. Downstream stages are
   already gated on the Bronze exit code, so continuing past a failed date never
   lets Silver or Gold consume it.
5. **The warehouse schema is checked once per run.** Every Bronze table must exist and
   match its DDL (ADR 0026 Schema Drift); otherwise the run fails before reading
   any date and names setup or Table Recreation.
6. **A requested date with no stored source is not a failure.** It is reported
   in the run result and logged, because a day may legitimately have no
   scraped matches.
7. **Known source quirks are resolved in the processor, explicitly and logged.**
   Admission stays strict; the processor, which assigns identities, owns these
   rules:
   - Fractional ball possession (for example `66.7` / `33.3`) is rounded half to
     even, keeping a pair summing to 100, because every layer stores possession
     as `Int32`. Widening the type was considered and rejected for now: it needs
     Table Recreation in Bronze and Silver and type changes in Gold for a
     one-decimal difference.
   - When two different events in a match share an `event_id` (FotMob reuses an
     `eventId`, or two events without one derive the same synthetic id), the
     first keeps the id and each later one gets a deterministic id derived from
     the match, table, repeated id, and occurrence. Ids of events that never
     collided are unchanged, so a reload adds the previously lost events without
     duplicating the others.
   - When the source lists the same player twice in one lineup, the first entry
     is kept and the rest are ignored. The share is negligible, and the source
     gives no way to tell which entry is right.

## Consequences

Loads that previously succeeded while losing rows now fail with an actionable
message. For data that fit the DDL, the stored rows do not change: three real
dates loaded through both paths produced identical rows in all 15 tables.

A source change that no longer fits the DDL, such as a new value shape, now stops
the affected dates until the processor, the source model, or the DDL is changed.
A DDL change goes through Table Recreation and a reload.

The admission path was run over every stored payload (4,719 dates, 661,837
matches) without ClickHouse. No payload was unreadable, no processor section
failed, and no value needed clipping, rounding, or filling to fit its DDL. Before
the rules in decision 7, 443 dates failed: 391 with an identity conflict and 52
with fractional possession. Each case had been silently losing data in the old
loader:

| Finding | Rows | Old loader | Now |
| --- | --- | --- | --- |
| Two different cards with the same synthetic id | 663 | One card per pair lost in `ReplacingMergeTree` | Both kept, distinct ids |
| FotMob reused an `eventId` for two goals | 52 | One goal lost | Both kept, distinct ids |
| Same player twice in one lineup | 29 | One entry kept arbitrarily | First entry kept |
| Fractional possession rejected by the model | 169 | Whole period row dropped | Rounded half to even |

With the rules applied, all 4,719 dates admit (35.9 million rows). Exact source
repeats collapse: 32 cards and 14 red cards. Reloading the affected dates
restores the lost cards, goals, and periods.

`--dry-run` still only prints the plan. Validating stored payloads without
loading is a possible follow-up.
