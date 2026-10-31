"""Contract tests for the FotMob pipeline plan and runner (no subprocesses)."""

import pytest

from src.common.run_scope import RunScope
from src.fotmob.commands import run_pipeline as pipeline


def _plan(argv: list[str]) -> list[list[list[tuple[str, tuple[str, ...]]]]]:
    args = pipeline.parse_arguments(argv)
    plan = pipeline.build_plan(args.scope, pipeline.options_from_args(args))
    return [[[(step.stage.key, step.argv) for step in phase] for phase in chain] for chain in plan]


def _run(argv: list[str], failing: set[str]) -> tuple[list[str], pipeline.PipelineReport]:
    calls: list[str] = []

    def runner(step: pipeline.Step, _timeout: float | None) -> int:
        calls.append(f"{step.stage.key} {' '.join(step.argv)}")
        return 1 if step.stage.key in failing else 0

    args = pipeline.parse_arguments(argv)
    options = pipeline.options_from_args(args)
    report = pipeline.run_plan(pipeline.build_plan(args.scope, options), options, runner=runner)
    return calls, report


def test_single_date_runs_every_stage_in_order() -> None:
    assert _plan(["20251208", "--force", "--debug"]) == [
        [
            [("scrape", ("20251208", "--force", "--debug"))],
            [("bronze", ("--date", "20251208", "--force"))],
            [("silver", ("--date", "20251208"))],
            [("gold", ("--date", "20251208"))],
        ]
    ]


def test_range_runs_one_independent_chain_per_date() -> None:
    plan = _plan(["--start-date", "20251207", "--end-date", "20251208", "--gold-only"])

    assert plan == [
        [[("gold", ("--date", "20251207"))]],
        [[("gold", ("--date", "20251208"))]],
    ]


def test_month_silver_only_is_one_month_scoped_step() -> None:
    assert _plan(["--month", "202512", "--silver-only"]) == [[[("silver", ("--month", "202512"))]]]


def test_month_scrapes_every_date_before_month_scoped_loads() -> None:
    [chain] = _plan(["--month", "202602"])

    assert [argv[0] for _, argv in chain[0]] == [f"202602{day:02d}" for day in range(1, 29)]
    assert chain[1:] == [
        [("bronze", ("--month", "202602"))],
        [("silver", ("--month", "202602"))],
        [("gold", ("--month", "202602"))],
    ]


def test_full_history_never_scrapes() -> None:
    assert _plan(["--full-history"]) == [
        [
            [("bronze", ("--full-history",))],
            [("silver", ("--full-history",))],
            [("gold", ("--full-history",))],
        ]
    ]


@pytest.mark.parametrize(
    ("flag", "stages"),
    [
        ("--skip-bronze", ["bronze", "silver", "gold"]),
        ("--skip-clickhouse", ["scrape", "silver", "gold"]),
        ("--skip-silver", ["scrape", "bronze", "gold"]),
        ("--skip-gold", ["scrape", "bronze", "silver"]),
        ("--bronze-only", ["scrape"]),
    ],
)
def test_stage_flags_select_stages(flag, stages) -> None:
    [chain] = _plan(["20251208", flag])

    assert [phase[0][0] for phase in chain] == stages


def test_deprecated_skip_fotmob_plans_nothing(capsys) -> None:
    assert _plan(["20251208", "--skip-fotmob"]) == []
    assert "removed in DepthMark" in capsys.readouterr().err


def test_failed_scrape_skips_the_rest_of_that_date_only() -> None:
    calls, report = _run(["--start-date", "20251207", "--end-date", "20251208"], {"scrape"})

    assert calls == ["scrape 20251207", "scrape 20251208"]
    assert report.exit_code == 1
    assert len(report.skipped) == 6


def test_failed_silver_skips_gold() -> None:
    calls, report = _run(["20251208"], {"silver"})

    assert calls == ["scrape 20251208", "bronze --date 20251208", "silver --date 20251208"]
    assert [step.stage.key for step in report.skipped] == ["gold"]


def test_any_failed_month_scrape_stops_month_loads() -> None:
    calls, report = _run(["--month", "202602"], {"scrape"})

    assert len(calls) == 28
    assert [step.stage.key for step in report.skipped] == ["bronze", "silver", "gold"]


def test_full_history_load_failure_skips_silver_and_gold() -> None:
    calls, report = _run(["--full-history"], {"bronze"})

    assert calls == ["bronze --full-history"]
    assert report.exit_code == 1


def test_timeout_reaches_the_runner_and_zero_disables_it() -> None:
    seen = []

    def runner(_step, timeout):
        seen.append(timeout)
        return 0

    for minutes, expected in (("2", 120.0), ("0", None)):
        args = pipeline.parse_arguments(["--full-history", "--stage-timeout-minutes", minutes])
        options = pipeline.options_from_args(args)
        pipeline.run_plan(pipeline.build_plan(args.scope, options), options, runner=runner)
        assert seen[-1] == expected


def test_named_date_selectors_fold_into_one_scope() -> None:
    assert pipeline.parse_arguments(["--date", "20251208"]).scope == RunScope.for_date("20251208")
    with pytest.raises(SystemExit):
        pipeline.parse_arguments(["20251208", "--single-date", "20251209"])


def test_subprocess_runner_cancels_a_step_that_times_out(monkeypatch, tmp_path) -> None:
    script = tmp_path / "sleep.py"
    script.write_text("import time\ntime.sleep(30)\n")
    monkeypatch.setattr(pipeline, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(pipeline, "CANCEL_GRACE_SECONDS", 5)
    step = pipeline.Step(pipeline.Stage("slow", "Slow", "sleep.py"), "x", ())

    assert pipeline.run_step_subprocess(step, 0.5) == pipeline.TIMEOUT_EXIT_CODE
