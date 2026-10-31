"""Unified read-only reporting for the explicit FotMob and Oddspedia sources."""

from __future__ import annotations

import re
from collections.abc import Callable, Iterable, Sequence
from datetime import UTC, date, datetime
from typing import Any

from src.common.run_scope import resolve_date_scope
from src.fotmob.scraping.reporting import build_run_report as build_fotmob_report
from src.oddspedia.scraping.reporting import build_run_report as build_oddspedia_report

SOURCE_ORDER = ("fotmob", "oddspedia")
SOURCE_LABELS = {"fotmob": "FotMob", "oddspedia": "Oddspedia"}
_ATTENTION_STATUSES = {
    "attention_required",
    "not_started",
    "priority_artifact_missing",
    "priority_scope_complete",
}
_MARKDOWN_RE = re.compile(r"[*_`]+")


def resolve_report_dates(
    date_value: str | None = None,
    month: str | None = None,
    current_date: date | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> list[str]:
    """Resolve a date, month, or inclusive range for read-only reporting."""
    return resolve_date_scope(
        date_value=date_value,
        month=month,
        current_date=current_date,
        start_date=start_date,
        end_date=end_date,
    )


def build_scraping_report(source: str, dates: Sequence[str]) -> dict[str, Any]:
    """Build one report bundle through explicit source-owned adapters."""
    source_id = str(source).strip().lower()
    if source_id not in {"all", *SOURCE_ORDER}:
        raise ValueError(f"unsupported report source: {source}")
    if not dates:
        raise ValueError("at least one report date is required")

    selected_sources = SOURCE_ORDER if source_id == "all" else (source_id,)
    adapters: dict[str, Callable[[str], dict[str, Any]]] = {
        "fotmob": build_fotmob_report,
        "oddspedia": build_oddspedia_report,
    }
    normalized_dates = [_parse_date(date_id).strftime("%Y%m%d") for date_id in dates]
    reports: list[dict[str, Any]] = []
    for normalized_date in normalized_dates:
        for selected_source in selected_sources:
            try:
                reports.append(adapters[selected_source](normalized_date))
            except (OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
                reports.append(_error_report(selected_source, normalized_date, exc))

    return {
        "schema_version": "v1",
        "generated_at": datetime.now(UTC).isoformat(),
        "scope": {
            "source": source_id,
            "sources": list(selected_sources),
            "dates": normalized_dates,
        },
        "overall_status": _bundle_status(reports),
        "totals": _totals(reports),
        "reports": reports,
    }


def render_summary(bundle: dict[str, Any]) -> str:
    """Render a compact terminal report for operators."""
    reports = bundle.get("reports") or []
    rows = [_summary_row(report) for report in reports]
    headers = ("Source", "Date", "Status", "Done", "Failed", "Remaining", "Progress", "Bronze")
    widths = [len(header) for header in headers]
    for row in rows:
        widths = [max(width, len(value)) for width, value in zip(widths, row)]

    def format_row(values: Iterable[str]) -> str:
        return "  ".join(value.ljust(width) for value, width in zip(values, widths)).rstrip()

    lines = [
        "Scraping report",
        f"Overall status: {bundle.get('overall_status', 'unknown')}",
        "",
        format_row(headers),
        format_row(tuple("-" * width for width in widths)),
    ]
    lines.extend(format_row(row) for row in rows)
    lines.extend(["", "Findings"])
    findings_added = False
    for report in reports:
        label = SOURCE_LABELS.get(report.get("source"), str(report.get("source", "unknown")))
        for finding in report.get("findings") or []:
            findings_added = True
            lines.append(f"- {label} {report.get('date')}: {_plain_text(str(finding))}")
    if not findings_added:
        lines.append("- No findings recorded.")

    next_steps = _unique_next_steps(reports)
    if next_steps:
        lines.extend(["", "Next steps"])
        lines.extend(f"- {step}" for step in next_steps)
    lines.append("")
    return "\n".join(lines)


def render_markdown(bundle: dict[str, Any]) -> str:
    """Render a portable cross-source operational report in Markdown."""
    reports = bundle.get("reports") or []
    totals = bundle.get("totals") or {}
    lines = [
        "# DepthMark scraping report",
        "",
        f"Generated: `{bundle.get('generated_at', 'unknown')}`  ",
        f"Overall status: **{bundle.get('overall_status', 'unknown')}**",
        "",
        "## Executive summary",
        "",
        f"Across **{totals.get('sources', 0)} source(s)** and "
        f"**{totals.get('report_count', len(reports))} source-date report(s)**, "
        f"**{totals.get('completed', 0)}/{totals.get('discovered', 0)}** discovered "
        "events are terminal.",
        "",
        "| Source | Date | Aspect | Status | Completed | Failed | Remaining | Progress | Bronze ready |",
        "| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for report in reports:
        summary = report.get("summary") or {}
        lines.append(
            "| {source} | `{date}` | {aspect} | `{status}` | {completed}/{discovered} | "
            "{failed} | {remaining} | {progress:.2f}% | {ready} |".format(
                source=SOURCE_LABELS.get(report.get("source"), report.get("source", "unknown")),
                date=report.get("date", "unknown"),
                aspect=report.get("aspect", "unknown"),
                status=report.get("overall_status", "unknown"),
                completed=summary.get("completed", 0),
                discovered=summary.get("discovered", 0),
                failed=summary.get("failed", 0),
                remaining=summary.get("remaining", 0),
                progress=float(summary.get("progress_pct", 0.0)),
                ready="yes" if summary.get("bronze_admission_ready") else "no",
            )
        )

    lines.extend(["", "## Findings", ""])
    findings_added = False
    for report in reports:
        label = SOURCE_LABELS.get(report.get("source"), str(report.get("source", "unknown")))
        for finding in report.get("findings") or []:
            findings_added = True
            lines.append(f"- **{label} `{report.get('date')}`:** {finding}")
    if not findings_added:
        lines.append("- No findings recorded.")

    lines.extend(["", "## Source details", ""])
    for report in reports:
        _append_source_details(lines, report)

    next_steps = _unique_next_steps(reports)
    lines.extend(["", "## Next steps", ""])
    if next_steps:
        commands = [step for step in next_steps if _is_command(step)]
        guidance = [step for step in next_steps if not _is_command(step)]
        if guidance:
            lines.extend(f"- {step}" for step in guidance)
        if commands:
            if guidance:
                lines.append("")
            lines.append("```bash")
            lines.extend(commands)
            lines.append("```")
    else:
        lines.append("No operator action is currently recommended.")

    lines.extend(["", "## Evidence", ""])
    for report in reports:
        label = SOURCE_LABELS.get(report.get("source"), str(report.get("source", "unknown")))
        for key, value in (report.get("evidence") or {}).items():
            lines.append(f"- **{label} `{report.get('date')}` / {key}:** `{value}`")
    lines.append("")
    return "\n".join(lines)


def needs_attention(bundle: dict[str, Any]) -> bool:
    """Return whether an automation policy should fail for this bundle."""
    return bundle.get("overall_status") not in {"complete", "live_complete"}


def _summary_row(report: dict[str, Any]) -> tuple:
    summary = report.get("summary") or {}
    return (
        SOURCE_LABELS.get(report.get("source"), str(report.get("source", "unknown"))),
        str(report.get("date", "unknown")),
        str(report.get("overall_status", "unknown")),
        f"{summary.get('completed', 0)}/{summary.get('discovered', 0)}",
        str(summary.get("failed", 0)),
        str(summary.get("remaining", 0)),
        f"{float(summary.get('progress_pct', 0.0)):.2f}%",
        "yes" if summary.get("bronze_admission_ready") else "no",
    )


def _append_source_details(lines: list[str], report: dict[str, Any]) -> None:
    label = SOURCE_LABELS.get(report.get("source"), str(report.get("source", "unknown")))
    lines.extend([f"### {label} — {report.get('date')}", ""])
    if report.get("overall_status") == "error":
        lines.extend([f"- Report error: {report.get('error', 'unknown error')}", ""])
        return
    if report.get("source") == "fotmob":
        inventory = report.get("inventory") or {}
        storage = report.get("storage") or {}
        lines.extend(
            [
                f"- Listing present: **{inventory.get('listing_present', False)}**",
                f"- Listed fixtures: **{inventory.get('total', 0)}**; "
                f"listing captured at: **{inventory.get('scraped_at') or 'unknown'}**",
                f"- Stored listed payloads: **{storage.get('artifact_files', 0)}**",
                f"- Individual/archive payloads: **{storage.get('individual_files', 0)} / "
                f"{storage.get('archived_files', 0)}**",
                f"- Missing/unavailable/extra IDs: **"
                f"{len(storage.get('missing_match_ids') or [])} / "
                f"{len(storage.get('unavailable_match_ids') or [])} / "
                f"{len(storage.get('extra_match_ids') or [])}**",
                f"- Physical storage: **{storage.get('storage_size_mb', 0.0):.2f} MB**",
            ]
        )
    elif report.get("source") == "oddspedia":
        inventory = report.get("inventory") or {}
        priority = report.get("priority") or {}
        scrape = report.get("scrape") or {}
        audit = report.get("payload_audit") or {}
        payloads = report.get("payloads") or {}
        operations = report.get("operations") or {}
        warehouse = report.get("warehouse") or {}
        lines.extend(
            [
                f"- Discovery inventory: **{inventory.get('total', 0)}**; status: "
                f"**{inventory.get('discovery_status') or 'unknown'}**",
                f"- Selected priority: **{priority.get('selected_priority', 'unknown')}** "
                f"({priority.get('selected_count', 0)} event(s))",
                f"- Matched/unmatched events: **{priority.get('matched_count', 0)} / "
                f"{priority.get('unmatched_count', 0)}**; reference window verified: "
                f"**{priority.get('reference_window_verified', False)}**",
                f"- Full-date terminal progress: **{scrape.get('completed', 0)}/"
                f"{scrape.get('total', 0)}** completed, **{scrape.get('skipped', 0)}** "
                f"skipped, **{scrape.get('remaining', 0)}** remaining",
                f"- Selected-scope completion: **{scrape.get('selected_completed', 0)}/"
                f"{priority.get('selected_count', 0)}**",
                f"- Payload audit accepted: **{audit.get('accepted', 0)}/"
                f"{audit.get('expected', 0)}**; missing/incomplete/invalid/extra: **"
                f"{audit.get('missing', 0)} / {audit.get('incomplete', 0)} / "
                f"{audit.get('invalid', 0)} / {audit.get('extra', 0)}**",
                f"- Stored payloads: **{payloads.get('count', 0)}** "
                f"({payloads.get('storage_size_mb', 0.0):.2f} MB); odds unavailable: "
                f"**{payloads.get('odds_unavailable_count', 0)}**",
                f"- Scrape attempts found: **{len(operations.get('scrape_runs') or [])}**",
                f"- Bronze readiness reason: {warehouse.get('reason', 'not reported')}",
            ]
        )
    else:
        lines.append(f"- Error: {report.get('error', 'unknown source report error')}")
    lines.append("")


def _totals(reports: Sequence[dict[str, Any]]) -> dict[str, Any]:
    summaries = [report.get("summary") or {} for report in reports]
    return {
        "sources": len({report.get("source") for report in reports}),
        "report_count": len(reports),
        "discovered": sum(int(summary.get("discovered", 0)) for summary in summaries),
        "completed": sum(int(summary.get("completed", 0)) for summary in summaries),
        "failed": sum(int(summary.get("failed", 0)) for summary in summaries),
        "skipped": sum(int(summary.get("skipped", 0)) for summary in summaries),
        "remaining": sum(int(summary.get("remaining", 0)) for summary in summaries),
        "artifact_files": sum(int(summary.get("artifact_files", 0)) for summary in summaries),
        "storage_size_mb": round(
            sum(float(summary.get("storage_size_mb", 0.0)) for summary in summaries), 2
        ),
        "bronze_ready_reports": sum(
            bool(summary.get("bronze_admission_ready")) for summary in summaries
        ),
    }


def _bundle_status(reports: Sequence[dict[str, Any]]) -> str:
    statuses = {str(report.get("overall_status", "error")) for report in reports}
    if "error" in statuses:
        return "error"
    if statuses.intersection(_ATTENTION_STATUSES):
        return "attention_required"
    if statuses == {"live_complete"}:
        return "live_complete"
    return "complete"


def _error_report(source: str, date_id: str, exc: Exception) -> dict[str, Any]:
    return {
        "schema_version": "v1",
        "source": source,
        "date": date_id,
        "aspect": "unknown",
        "overall_status": "error",
        "summary": {
            "discovered": 0,
            "completed": 0,
            "failed": 1,
            "skipped": 0,
            "remaining": 0,
            "progress_pct": 0.0,
            "artifact_files": 0,
            "storage_size_mb": 0.0,
            "bronze_admission_ready": False,
        },
        "findings": [f"The {SOURCE_LABELS[source]} report could not be built: {exc}"],
        "next_steps": ["Inspect the source artifacts named in the error before retrying."],
        "evidence": {},
        "error": str(exc),
    }


def _unique_next_steps(reports: Sequence[dict[str, Any]]) -> list[str]:
    steps: list[str] = []
    for report in reports:
        for step in report.get("next_steps") or []:
            if step not in steps:
                steps.append(str(step))
    return steps


def _parse_date(value: str) -> date:
    date_id = str(value).strip()
    if len(date_id) != 8 or not date_id.isdigit():
        raise ValueError(f"date must use YYYYMMDD format: {value}")
    return datetime.strptime(date_id, "%Y%m%d").date()


def _plain_text(value: str) -> str:
    return _MARKDOWN_RE.sub("", value)


def _is_command(value: str) -> bool:
    return value.startswith(("python ", "python3 ", "depthmark ", "docker "))
