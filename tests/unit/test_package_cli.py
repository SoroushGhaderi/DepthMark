"""Contract tests for the package-level DepthMark command registry."""

import subprocess
import sys
from pathlib import Path

from src import cli

EXPECTED_CANONICAL_COMMANDS = {
    "health-check": "health_check.py",
    "report-scraping": "report_scraping.py",
    "scrape-fotmob": "fotmob/scrape_fotmob.py",
    "load-fotmob-bronze": "fotmob/load_fotmob_bronze.py",
    "remove-fotmob-bronze": "fotmob/remove_fotmob_bronze.py",
    "load-fotmob-silver": "fotmob/load_fotmob_silver.py",
    "load-fotmob-gold": "fotmob/load_fotmob_gold.py",
    "run-fotmob-gold-jobs": "fotmob/run_fotmob_gold_jobs.py",
    "build-fotmob-signal-activations": "fotmob/build_fotmob_signal_activations.py",
    "check-signal-catalogs": "quality/check_signal_catalogs.py",
    "run-fotmob-pipeline": "fotmob/run_fotmob_pipeline.py",
    "setup-fotmob-warehouse": "fotmob/setup_fotmob_warehouse.py",
    "discover-oddspedia-events": "oddspedia/discover_oddspedia_events.py",
    "prioritize-oddspedia-events": "oddspedia/prioritize_oddspedia_events.py",
    "scrape-oddspedia-matches": "oddspedia/scrape_oddspedia_matches.py",
    "run-oddspedia-pipeline": "oddspedia/run_oddspedia_pipeline.py",
    "setup-oddspedia-warehouse": "oddspedia/setup_oddspedia_warehouse.py",
    "load-oddspedia-bronze": "oddspedia/load_oddspedia_bronze.py",
    "resolve-oddspedia-events": "oddspedia/resolve_oddspedia_events.py",
}


def test_canonical_commands_use_existing_scripts() -> None:
    assert {
        command: spec.script for command, spec in cli.COMMANDS.items()
    } == EXPECTED_CANONICAL_COMMANDS

    for script_name in EXPECTED_CANONICAL_COMMANDS.values():
        assert (cli.SCRIPTS_DIR / script_name).is_file()


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


def test_every_command_target_resolves_to_a_callable() -> None:
    for command, spec in cli.COMMANDS.items():
        assert callable(cli.resolve_target(spec.target)), command


def test_canonical_scripts_are_thin_shims_around_the_command_target() -> None:
    for command, spec in cli.COMMANDS.items():
        module, function = spec.target.split(":")
        shim = (cli.SCRIPTS_DIR / spec.script).read_text(encoding="utf-8")
        assert f"from {module} import {function}" in shim, command
        assert "sys.path" not in shim, command


def test_run_command_requires_a_source_checkout(monkeypatch, tmp_path, capsys) -> None:
    monkeypatch.setattr(cli, "PROJECT_ROOT", Path(tmp_path))
    monkeypatch.setattr(cli, "CLICKHOUSE_SQL_DIR", Path(tmp_path) / "clickhouse")

    assert cli.run_command(cli.COMMANDS["health-check"], []) == 2
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
