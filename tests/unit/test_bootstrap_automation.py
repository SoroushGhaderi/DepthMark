import fcntl
import json
import os
import shutil
import subprocess
from datetime import date
from pathlib import Path
from types import SimpleNamespace

import pytest

from scripts.orchestration import run_scheduled_job

PROJECT_ROOT = Path(__file__).resolve().parents[2]
GENERATED_KEYS = ("CLICKHOUSE_PASSWORD", "CLICKHOUSE_MAINTENANCE_PASSWORD", "MONGODB_PASSWORD")


def _dotenv(path: Path) -> dict:
    values = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            values[key] = value
    return values


@pytest.fixture
def checkout(tmp_path: Path) -> Path:
    (tmp_path / "scripts").mkdir()
    for name in ("bootstrap.sh", "install_schedule.sh"):
        shutil.copy2(PROJECT_ROOT / "scripts" / name, tmp_path / "scripts" / name)
    shutil.copy2(PROJECT_ROOT / ".env.example", tmp_path / ".env.example")
    return tmp_path


def _bootstrap_env(checkout: Path, *args: str, **env: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(checkout / "scripts" / "bootstrap.sh"), "--env-only", *args],
        cwd=checkout,
        env={**os.environ, **env},
        capture_output=True,
        text=True,
        check=True,
    )


def test_scheduled_jobs_compute_their_own_dates(monkeypatch):
    monkeypatch.setattr(run_scheduled_job, "_local_yesterday", lambda: date(2026, 10, 9))
    monkeypatch.setattr(run_scheduled_job, "_utc_two_days_ago", lambda: date(2026, 1, 2))

    fotmob = run_scheduled_job.build_command("fotmob-daily")
    oddspedia = run_scheduled_job.build_command("oddspedia-daily")

    assert fotmob[1].endswith("scripts/orchestration/run_fotmob_pipeline.py")
    assert fotmob[2:] == ["20261009"]
    assert oddspedia[2:] == ["--date", "20260102", "--silver-reference-window-ready"]
    for command in (fotmob, oddspedia):
        assert Path(command[1]).is_file()


def test_scheduled_job_returns_the_command_exit_code(monkeypatch, tmp_path):
    monkeypatch.setattr(run_scheduled_job, "LOCK_DIR", tmp_path)
    calls = []
    monkeypatch.setattr(
        run_scheduled_job.subprocess,
        "run",
        lambda command, cwd: calls.append(command) or SimpleNamespace(returncode=3),
    )

    assert run_scheduled_job.run(["fotmob-daily"]) == 3
    assert len(calls) == 1


def test_scheduled_job_skips_while_a_previous_run_holds_the_lock(monkeypatch, tmp_path):
    monkeypatch.setattr(run_scheduled_job, "LOCK_DIR", tmp_path)
    monkeypatch.setattr(
        run_scheduled_job.subprocess,
        "run",
        lambda *args, **kwargs: pytest.fail("a locked job must not start"),
    )

    with open(tmp_path / "oddspedia-daily.lock", "w") as held:
        fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert run_scheduled_job.run(["oddspedia-daily"]) == 0


def test_bootstrap_env_generates_secrets_once_and_sets_mode(checkout):
    _bootstrap_env(checkout, FOTMOB_X_MAS_TOKEN="token-from-env")
    first = _dotenv(checkout / ".env")

    assert first["DEPTHMARK_ENV"] == "production"
    assert first["FOTMOB_X_MAS_TOKEN"] == "token-from-env"
    for key in GENERATED_KEYS:
        assert len(first[key]) == 48 and "your_" not in first[key]
    assert first["MONGODB_PASSWORD"] in first["MONGODB_URI"]
    assert oct((checkout / ".env").stat().st_mode & 0o777) == "0o600"

    _bootstrap_env(checkout, "--local")
    second = _dotenv(checkout / ".env")

    assert second["DEPTHMARK_ENV"] == "local"
    assert {key: second[key] for key in GENERATED_KEYS} == {
        key: first[key] for key in GENERATED_KEYS
    }


def test_bootstrap_env_keeps_real_values_and_adds_missing_keys(checkout):
    (checkout / ".env").write_text("CLICKHOUSE_PASSWORD=an-existing-real-secret\n")

    _bootstrap_env(checkout)
    values = _dotenv(checkout / ".env")

    assert values["CLICKHOUSE_PASSWORD"] == "an-existing-real-secret"
    assert values["CLICKHOUSE_MAINTENANCE_USER"] == "depthmark_admin"
    assert len(values["CLICKHOUSE_MAINTENANCE_PASSWORD"]) == 48


def test_bootstrap_creates_bind_mount_files_instead_of_docker_directories(checkout):
    _bootstrap_env(checkout)

    credentials = checkout / "credentials.json"
    assert credentials.is_file()
    assert json.loads(credentials.read_text()) == {"cookies": {}}
    assert (checkout / "data").is_dir() and (checkout / "logs" / "scheduler").is_dir()

    credentials.write_text('{"cookies": {"turnstile_verified": "abc"}}\n')
    _bootstrap_env(checkout)
    assert "turnstile_verified" in credentials.read_text()


def test_bootstrap_replaces_an_empty_credentials_directory_made_by_docker(checkout):
    (checkout / "credentials.json").mkdir()

    _bootstrap_env(checkout)

    assert (checkout / "credentials.json").is_file()


def test_schedule_install_is_idempotent_and_removable(checkout, tmp_path):
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    (fake_bin / "crontab").write_text(
        '#!/usr/bin/env bash\ncase "$1" in\n'
        '  -l) [ -f "$FAKE_CRONTAB" ] && cat "$FAKE_CRONTAB" || exit 1 ;;\n'
        '  -) cat > "$FAKE_CRONTAB" ;;\nesac\n'
    )
    (fake_bin / "docker").write_text("#!/bin/sh\nexit 0\n")
    for tool in fake_bin.iterdir():
        tool.chmod(0o755)
    crontab = tmp_path / "crontab.txt"
    crontab.write_text("15 * * * * /usr/bin/true\n")
    env = {**os.environ, "PATH": f"{fake_bin}:{os.environ['PATH']}", "FAKE_CRONTAB": str(crontab)}
    installer = ["bash", str(checkout / "scripts" / "install_schedule.sh")]

    for _ in range(2):
        subprocess.run(installer, env=env, check=True, capture_output=True)
    installed = crontab.read_text()

    assert installed.startswith("15 * * * * /usr/bin/true\n")
    assert installed.count(">>> depthmark schedule") == 1
    assert installed.count("run_scheduled_job.py fotmob-daily") == 1
    assert installed.count("run_scheduled_job.py oddspedia-daily") == 1

    subprocess.run([*installer, "--remove"], env=env, check=True, capture_output=True)
    assert crontab.read_text().strip() == "15 * * * * /usr/bin/true"
