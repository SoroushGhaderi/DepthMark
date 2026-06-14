# Gold Signal Query Contexts

Signals are tactical/statistical triggers with focused single-condition logic.

- `clickhouse/gold/dml/signals/{match,team,player}/sig_*.sql`: signal SQL definitions executed through
  `scripts/gold/run_sql_job.py`
- `scripts/gold/signal/catalogs/sig_*.md`: markdown catalogs with frontmatter
  metadata and output schema documentation

Signal SQL jobs populate `gold_signals.sig_*` tables. Active catalogs sync to
MongoDB through `scripts/mongodb/sync_signal_catalogs.py`.
