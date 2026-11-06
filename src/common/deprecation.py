"""One deprecation notice for deprecated command options (ADR 0024).

Every deprecated option announces the same removal version, so the
compatibility surface shrinks on a schedule instead of growing.
"""

import sys

# Deprecated options are removed in this DepthMark release.
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
