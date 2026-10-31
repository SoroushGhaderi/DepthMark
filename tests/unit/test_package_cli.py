"""Contract tests for the package-level DepthMark command registry."""

import subprocess
import sys
from pathlib import Path

from src import cli

EXPECTED_CANONICAL_COMMANDS = {
    "health-check": "health_check.py",
    "report-scraping": "report_scraping.py",
    "scrape-fotmob": "bronze/scrape_fotmob.py",
    "load-fotmob-bronze": "bronze/load_fotmob_bronze.py",
    "remove-fotmob-bronze": "bronze/remove_fotmob_bronze.py",
    "load-fotmob-silver": "silver/load_fotmob_silver.py",
    "load-fotmob-gold": "gold/load_fotmob_gold.py",
    "run-fotmob-gold-jobs": "gold/run_fotmob_gold_jobs.py",
    "build-fotmob-signal-activations": "gold/build_fotmob_signal_activations.py",
    "check-signal-catalogs": "quality/check_signal_catalogs.py",
    "run-fotmob-pipeline": "orchestration/run_fotmob_pipeline.py",
    "setup-fotmob-warehouse": "orchestration/setup_fotmob_warehouse.py",
    "discover-oddspedia-events": "oddspedia/discover_oddspedia_events.py",
    "prioritize-oddspedia-events": "oddspedia/prioritize_oddspedia_events.py",
    "scrape-oddspedia-matches": "oddspedia/scrape_oddspedia_matches.py",
    "run-oddspedia-pipeline": "oddspedia/run_oddspedia_pipeline.py",
    "setup-oddspedia-warehouse": "oddspedia/setup_oddspedia_warehouse.py",
    "load-oddspedia-bronze": "oddspedia/load_oddspedia_bronze.py",
    "resolve-oddspedia-events": "oddspedia/resolve_oddspedia_events.py",
}

EXPECTED_SCRIPT_COMPATIBILITY = {
    "bronze/load_clickhouse.py": "load_fotmob_bronze.py",
    "silver/load_clickhouse.py": "load_fotmob_silver.py",
    "gold/load_clickhouse_gold.py": "load_fotmob_gold.py",
    "gold/activations/build_signal_activations.py": "build_fotmob_signal_activations.py",
    "gold/run_gold_sql_jobs.py": "run_fotmob_gold_jobs.py",
    "orchestration/pipeline.py": "run_fotmob_pipeline.py",
    "orchestration/setup_clickhouse.py": "setup_fotmob_warehouse.py",
    "oddspedia/discover_events.py": "discover_oddspedia_events.py",
    "oddspedia/prioritize_events.py": "prioritize_oddspedia_events.py",
    "oddspedia/scrape_matches.py": "scrape_oddspedia_matches.py",
    "oddspedia/run_pipeline.py": "run_oddspedia_pipeline.py",
    "oddspedia/status_oddspedia.py": "report_scraping.py",
    "oddspedia/report_oddspedia.py": "report_scraping.py",
    "oddspedia/status.py": "report_scraping.py",
    "oddspedia/report.py": "report_scraping.py",
    "oddspedia/setup_warehouse.py": "setup_oddspedia_warehouse.py",
    "oddspedia/load_bronze.py": "load_oddspedia_bronze.py",
    "oddspedia/resolve_events.py": "resolve_oddspedia_events.py",
    "oddspedia/events.py": "source-qualified",
    "oddspedia/football.py": "run_oddspedia_pipeline.py",
    "oddspedia/setup_clickhouse.py": "setup_oddspedia_warehouse.py",
    "oddspedia/load_clickhouse.py": "load_oddspedia_bronze.py",
    "oddspedia/resolve_matches.py": "resolve_oddspedia_events.py",
}


def test_canonical_commands_use_existing_scripts() -> None:
    assert {
        command: spec.script for command, spec in cli.CANONICAL_COMMANDS.items()
    } == EXPECTED_CANONICAL_COMMANDS

    for script_name in EXPECTED_CANONICAL_COMMANDS.values():
        assert (cli.SCRIPTS_DIR / script_name).is_file()


def test_simple_compatibility_aliases_dispatch_to_canonical_scripts() -> None:
    aliases = {
        "scrape": "scrape-fotmob",
        "load": "load-fotmob-bronze",
        "pipeline": "run-fotmob-pipeline",
        "setup-clickhouse": "setup-fotmob-warehouse",
        "oddspedia-discover-events": "discover-oddspedia-events",
        "oddspedia-prioritize-events": "prioritize-oddspedia-events",
        "oddspedia-scrape-matches": "scrape-oddspedia-matches",
        "oddspedia-run-pipeline": "run-oddspedia-pipeline",
        "oddspedia-setup-warehouse": "setup-oddspedia-warehouse",
        "oddspedia-load-bronze": "load-oddspedia-bronze",
        "oddspedia-resolve-events": "resolve-oddspedia-events",
    }

    for alias, canonical in aliases.items():
        alias_spec = cli.COMPATIBILITY_COMMANDS[alias]
        canonical_spec = cli.CANONICAL_COMMANDS[canonical]
        assert alias_spec.script == canonical_spec.script
        assert alias_spec.replacement == canonical


def test_reporting_compatibility_commands_target_one_unified_script() -> None:
    expected_arguments = {
        "status-oddspedia": ("--source", "oddspedia", "--format", "summary"),
        "report-oddspedia": ("--source", "oddspedia", "--format", "markdown"),
        "oddspedia-status": ("--source", "oddspedia", "--format", "summary"),
        "oddspedia-report": ("--source", "oddspedia", "--format", "markdown"),
    }

    for command, arguments in expected_arguments.items():
        spec = cli.COMPATIBILITY_COMMANDS[command]
        assert spec.script == "report_scraping.py"
        assert spec.replacement == "report-scraping"
        assert spec.arguments == arguments


def test_every_compatibility_command_has_an_existing_target_and_replacement() -> None:
    for spec in cli.COMPATIBILITY_COMMANDS.values():
        assert (cli.SCRIPTS_DIR / spec.script).is_file()
        assert spec.replacement


def test_every_canonical_command_exposes_help_without_a_deprecation_warning() -> None:
    for command in EXPECTED_CANONICAL_COMMANDS:
        result = subprocess.run(
            [sys.executable, "-m", "src.cli", command, "--help"],
            cwd=cli.PROJECT_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, (command, result.stderr)
        assert "usage:" in result.stdout.lower(), command
        assert "deprecated" not in result.stderr.lower(), command


def test_every_compatibility_script_warns_and_preserves_help() -> None:
    for script_name, replacement in EXPECTED_SCRIPT_COMPATIBILITY.items():
        result = subprocess.run(
            [sys.executable, str(cli.SCRIPTS_DIR / script_name), "--help"],
            cwd=cli.PROJECT_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, (script_name, result.stderr)
        assert "usage:" in result.stdout.lower(), script_name
        assert "deprecated" in result.stderr.lower(), script_name
        assert replacement in result.stderr, script_name


def _record_target(monkeypatch, exit_code: int) -> dict:
    invocation: dict = {}

    def fake_resolve_target(target: str):
        def run(argv: list[str]) -> int:
            invocation["target"] = target
            invocation["args"] = argv
            return exit_code

        return run

    monkeypatch.setattr(cli, "resolve_target", fake_resolve_target)
    return invocation


def test_main_runs_a_canonical_command_in_process(monkeypatch) -> None:
    invocation = _record_target(monkeypatch, 17)

    assert cli.main(["scrape-fotmob", "--today"]) == 17
    assert invocation == {"target": "src.fotmob.commands.scrape:main", "args": ["--today"]}


def test_main_warns_when_dispatching_a_compatibility_alias(monkeypatch, capsys) -> None:
    invocation = _record_target(monkeypatch, 0)

    assert cli.main(["oddspedia-status", "--date", "20260301"]) == 0

    assert invocation == {
        "target": "src.operations.commands.report_scraping:main",
        "args": [
            "--source",
            "oddspedia",
            "--format",
            "summary",
            "--date",
            "20260301",
        ],
    }
    stderr = capsys.readouterr().err
    assert "deprecated" in stderr.lower()
    assert "removed in DepthMark 3.0.0" in stderr
    assert "report-scraping" in stderr


def test_every_command_target_resolves_to_a_callable() -> None:
    for command, spec in cli.COMMANDS.items():
        assert callable(cli.resolve_target(spec.target)), command


def test_canonical_scripts_are_thin_shims_around_the_command_target() -> None:
    for command, spec in cli.CANONICAL_COMMANDS.items():
        module, function = spec.target.split(":")
        shim = (cli.SCRIPTS_DIR / spec.script).read_text(encoding="utf-8")
        assert f"from {module} import {function}" in shim, command
        assert "sys.path" not in shim, command


def test_run_command_requires_a_source_checkout(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setattr(cli, "PROJECT_ROOT", Path(tmp_path))
    monkeypatch.setattr(cli, "CLICKHOUSE_SQL_DIR", Path(tmp_path) / "clickhouse")

    assert cli.run_command(cli.CANONICAL_COMMANDS["health-check"], []) == 2
    assert "pip install -e ." in capsys.readouterr().err


def test_package_discovery_declares_every_code_directory() -> None:
    from setuptools.config.pyprojecttoml import read_configuration

    project_root = Path(cli.__file__).resolve().parents[1]
    configuration = read_configuration(project_root / "pyproject.toml", expand=True)
    packages = set(configuration["tool"]["setuptools"]["packages"])
    code_directories = {
        ".".join(directory.relative_to(project_root).parts)
        for top_level in ("src", "scripts", "config")
        for directory in [project_root / top_level, *(project_root / top_level).rglob("*")]
        if directory.is_dir()
        and "__pycache__" not in directory.parts
        and any(directory.glob("*.py"))
    }

    assert {"src.warehouse", "src.fotmob.bronze", "config"} <= packages
    assert code_directories <= packages
