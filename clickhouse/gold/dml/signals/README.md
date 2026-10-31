# Gold Signal Query Contexts

Signals are tactical/statistical triggers with focused single-condition logic.

- `clickhouse/gold/dml/signals/{match,team,player}/sig_*.sql`: signal SQL definitions executed through
  `scripts/gold/run_fotmob_gold_jobs.py`
- `catalogs/signals/sig_*.md`: markdown catalogs with frontmatter
  metadata and output schema documentation

Signal SQL jobs populate `gold_signals.sig_*` tables. Every signal SQL file
needs a catalog, and only active catalog signals run. Authoring rules, including
the DML rules for this directory, are in `catalogs/signals/contracts/SQL.md`.
`scripts/mongodb/sync_signal_catalogs.py` mirrors every catalog to MongoDB.
