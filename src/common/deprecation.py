"""One deprecation notice for compatibility scripts and CLI aliases (ADR 0024).

Every deprecated script and ``depthmark`` alias announces the same removal
version, so the compatibility surface shrinks on a schedule instead of growing.
"""

import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

from src.common.paths import PROJECT_ROOT

# Compatibility scripts and CLI aliases are removed in this DepthMark release.
REMOVAL_VERSION = "3.0.0"


def deprecation_message(old: str, replacement: str) -> str:
    """Return the standard notice for a deprecated entry point."""
    return (
        f"Warning: {old} is deprecated and will be removed in DepthMark {REMOVAL_VERSION}; "
        f"use {replacement} instead."
    )


def warn_deprecated(old: str, replacement: str) -> None:
    """Print the standard deprecation notice to stderr."""
    print(deprecation_message(old, replacement), file=sys.stderr)


def run_deprecated_script(
    script_file: str,
    replacement: str,
    main: Callable[..., Any],
    *args: Any,
    **kwargs: Any,
) -> Any:
    """Warn that ``script_file`` is deprecated, then run its replacement's ``main``."""
    script_path = Path(script_file).resolve()
    try:
        old = script_path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        old = script_path.name
    warn_deprecated(old, replacement)
    return main(*args, **kwargs)
