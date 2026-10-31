#!/usr/bin/env python3
"""Check logging style conventions.

Rules:
1. No emoji in runtime logger messages.
2. Status-like logger messages should use bracket tags such as:
   [OK], [WARN], [ERROR], [INFO], [DEBUG], [NEXT], [STATS], [CANCELLED].
3. Logger messages are constant strings: values go in %-style arguments or
   structlog key/value fields, never in f-strings.
4. No stdlib ``extra={...}`` dicts; pass structlog key/value fields instead.

Telegram/email formatting modules are excluded.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECK_DIRS = [ROOT / "src", ROOT / "scripts", ROOT / "config"]
EXCLUDE_PATH_PARTS = {"metrics_alerts.py", "alerting.py"}

LOGGER_CALL_RE = re.compile(
    r"""logger\.(?:debug|info|warning|error|critical|exception)\(\s*(?:f)?["']([^"']*)["']""",
    re.MULTILINE,
)
EMOJI_RE = re.compile(r"[✅❌⚠️📊💡✓✗⚡🏠ℹ️🚨⏭️⏱️🗄️☁️]")
STATUS_WORD_RE = re.compile(r"\b(OK|WARN|WARNING|ERROR|INFO|DEBUG|SUCCESS|FAILED|NEXT|STATS)\b")
LOG_METHODS = {"debug", "info", "warning", "warn", "error", "critical", "exception"}


def should_exclude(path: Path) -> bool:
    return any(part in path.name for part in EXCLUDE_PATH_PARTS)


def iter_python_files() -> list[Path]:
    files: list[Path] = []
    for base in CHECK_DIRS:
        if not base.exists():
            continue
        files.extend(sorted(base.rglob("*.py")))
    return files


def is_logger_call(node: ast.AST) -> bool:
    """Return True for ``<something log-like>.<level>(...)`` calls."""
    if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Attribute):
        return False
    return node.func.attr in LOG_METHODS and "log" in ast.unparse(node.func.value).lower()


def structured_call_violations(path: Path, content: str) -> list[str]:
    """Return f-string message and stdlib ``extra=`` violations in ``content``."""
    violations: list[str] = []
    for node in ast.walk(ast.parse(content, filename=str(path))):
        if not is_logger_call(node):
            continue
        if node.args and isinstance(node.args[0], ast.JoinedStr):
            violations.append(f"{path}:{node.lineno}: f-string logger message")
        if any(keyword.arg == "extra" for keyword in node.keywords):
            violations.append(f"{path}:{node.lineno}: extra={{...}} instead of key/value fields")
    return violations


def main() -> int:
    violations: list[str] = []

    for path in iter_python_files():
        if should_exclude(path):
            continue

        content = path.read_text(encoding="utf-8")
        violations.extend(structured_call_violations(path, content))
        for match in LOGGER_CALL_RE.finditer(content):
            msg = match.group(1)
            if EMOJI_RE.search(msg):
                violations.append(f"{path}: emoji in logger message -> {msg}")
                continue
            normalized = msg.replace("\\n", "").lstrip()
            if STATUS_WORD_RE.search(msg) and not normalized.startswith("["):
                violations.append(f"{path}: status message missing [] tag -> {msg}")

    if violations:
        print("[ERROR] Logging style violations found:")
        for item in violations:
            print(f"  - {item}")
        return 1

    print("[OK] Logging style check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
