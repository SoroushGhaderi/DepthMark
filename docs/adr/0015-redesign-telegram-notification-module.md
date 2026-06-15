# ADR 0015: Redesign Telegram Notification Module

## Status

Accepted

## Context

The Telegram notification system has three disconnected sending paths
(`TelegramMetricsReporter`, `AlertManager.TelegramChannel`,
`send_layer_completion_alert()`), zero templates (all inline f-string
concatenation), duplicated utilities (`_format_duration()`), configuration read
from 4 sources (only 2 actually used), 25+ dead kwargs on `send_daily_report()`,
no type safety, and email/Slack channels that are unused. Messages are verbose
but lack actionable detail — performance metrics, row counts, failed job names,
and reconciliation breakdowns are either empty or not surfaced.

There is also no pipeline-level summary message and no Bronze ClickHouse load
completion alert, despite these being critical pipeline steps.

## Decision

Replace the entire Telegram subsystem with a new `src/services/telegram/`
package following these principles:

1. **Thin transport layer**: A single `TelegramClient` class handles Bot API
   communication. All callers use this one client.

2. **Jinja2 templates**: Message formatting lives in `.html.j2` template files,
   not inline Python strings. Templates render HTML for Telegram's
   `parse_mode="HTML"`.

3. **Typed dataclasses**: Each message family has a dedicated dataclass
   (`DailyReportData`, `MonthlyReportData`, `LayerAlertData`,
   `PipelineSummaryData`, `ErrorAlertData`) replacing the 25+ kwargs pattern.

4. **Single config source**: `config.settings` (Pydantic, reads `.env`) is the
   only configuration source. Duplicate `os.getenv()` calls are removed.

5. **Clean break**: `AlertManager`, `EmailChannel`, `LoggingChannel`, and all
   old modules (`metrics_alerts.py`, `alerting.py`,
   `layer_completion_alerts.py`) are deleted. Callers migrate to
   `TelegramClient` directly.

6. **Terminal = stdout summary only**: Scripts print a one-line status to stdout.
   Full formatted messages go to Telegram only.

7. **Silent mode on dataclass**: Each dataclass has a `silent: bool` field.
   The transport layer reads it; callers decide per message.

8. **New message families**: Pipeline summary and Bronze ClickHouse load
   completion messages are added. Existing messages get table layouts with
   only available data shown.

## Consequences

**Benefits:**
- Single, testable transport layer
- Template-driven formatting (change message design without touching Python)
- Type-safe message construction with IDE autocomplete
- Consistent config source
- Cleaner, more insightful messages with table layouts
- Two new message families fill current visibility gaps

**Costs:**
- Jinja2 dependency must be added to `requirements.txt`
- 10+ caller files must be migrated (import changes + dataclass construction)
- Three old modules must be deleted
- No existing Telegram integration tests — mocking required

**Follow-up constraints:**
- New message families or format changes require only template edits
- Adding a second notification channel (e.g., Slack) would require a new
  transport class, but the template/dataclass pattern is reusable
- `config.settings.telegram_enabled` controls whether messages are sent
