# Gold Signal Contracts

These contracts define how a FotMob Gold signal is authored and kept
consistent. They are organized by the artifact you are editing, plus one
lifecycle guide. Decisions behind them: ADR 0008 (catalogs in markdown),
ADR 0006 (activation identity), and ADR 0033 (one validated catalog reader).

| You are… | Read |
| --- | --- |
| adding, changing, deprecating, or renaming a signal | [`AUTHORING.md`](AUTHORING.md) |
| writing or editing a catalog (`catalogs/signals/sig_*.md`) | [`CATALOG.md`](CATALOG.md) |
| writing signal DML or an analyst query | [`SQL.md`](SQL.md) |
| writing or changing signal DDL | [`TABLE.md`](TABLE.md) |

How signal SQL is executed (the generic runner, the bulk Gold loader, scopes,
and exit codes) is defined in [`docs/SCRIPTS_CONTRACT.md`](../../../docs/SCRIPTS_CONTRACT.md)
and [`docs/data-flow/gold.md`](../../../docs/data-flow/gold.md). Signal authors do
not change the runner.

## Normative Language

- `MUST`: required for a signal to ship.
- `SHOULD`: strong default; an exception needs a stated reason in review.
- `MAY`: optional.

## Enforced And Review Rules

Every rule is one of two kinds.

- **Enforced** rules carry a tag naming the check that fails when they break.
  You do not need to verify them by hand; run the check.
  - **[catalog]**: `load_signal_catalog()` in `src/fotmob/gold/signal_catalog.py`.
    It runs in `scripts/quality/check_signal_catalogs.py`, the pytest contract
    tests, every Gold load, the activation builder, and the MongoDB sync. One
    violation fails all of them.
  - **[test]**: a named pytest contract test.
  - **[runtime]**: the post-load Gold contract (`assert_gold_layer_contracts`).
  - **[setup]**: warehouse setup, which rejects non-create DDL and fails on
    schema drift (ADR 0026).
- **Review** rules have no tag. They need judgment (football semantics,
  naming quality, similarity), so reviewers check them.

## Validation Commands

```bash
python3 scripts/quality/check_signal_catalogs.py               # every [catalog] rule, no services
python3 scripts/quality/check_signal_catalogs.py --write-index # also regenerate the index table
pytest tests/unit/test_signal_catalog.py tests/unit/test_data_quality.py
python3 scripts/gold/run_fotmob_gold_jobs.py --date 20251208 --kind signal --id <signal_id> --dry-run
```
