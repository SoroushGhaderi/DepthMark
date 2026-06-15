# Telegram Module Redesign — Implementation Plan

## Problem Statement

The current Telegram notification system has three disconnected sending paths, zero
templates (all inline f-string concatenation), duplicated utilities, configuration
read from 4 sources (only 2 used), 25+ dead kwargs on `send_daily_report()`, no
type safety, and messages that are verbose but lack actionable detail. Email and
Slack channels exist but are unused. The module needs a clean architectural reset.

## Accepted Decisions

| # | Decision | Resolution |
|---|---|---|
| 1 | Responsibility boundary | Thin transport (`TelegramClient`) + shared Jinja2 templates |
| 2 | Terminal output | Clean stdout summary line only; full formatted message to Telegram |
| 3 | Channels | Telegram only — remove email, Slack, `AlertManager` orchestration |
| 4 | Template format | Jinja2 `.html.j2` files rendering HTML (`<b>`, `<i>`) |
| 5 | Configuration | `config.settings` (Pydantic, reads `.env`) as single source of truth |
| 6 | Module layout | `src/services/telegram/` package |
| 7 | Message data | Dataclasses per family (`DailyReportData`, `LayerAlertData`, etc.) |
| 8 | Silent mode | Field on each dataclass, caller decides per message |
| 9 | AlertManager | Clean break — remove entirely, update all callers to `TelegramClient` |
| 10 | Message content | Table layouts, concise, only show available data, actionable error hints |

## Target File Structure

```
src/services/telegram/
  __init__.py              → exports TelegramClient, all dataclasses
  client.py                → TelegramClient (transport: send_message)
  messages.py              → dataclasses for all 5 message families
  templates/
    base.html.j2           → shared layout (header, separator, footer)
    daily_report.html.j2   → Family 1: daily scrape report
    monthly_report.html.j2 → Family 5: monthly summary
    layer_alert.html.j2    → Family 2: layer completion (bronze/silver/gold/quality)
    pipeline_summary.html.j2 → Family 4: pipeline completion (NEW)
    error_alert.html.j2    → Family 3: error/failure alerts
```

## Dataclasses (`messages.py`)

```python
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class DailyReportData:
    date: str                              # "2026-02-18"
    matches_scraped: int = 0
    matches_total: int = 0
    skipped: int = 0
    errors: int = 0
    duration_seconds: float = 0.0
    bronze_files: int = 0
    bronze_size_mb: float = 0.0
    # Performance (optional — only shown if > 0)
    avg_response_time: float = 0.0
    max_response_time: float = 0.0
    retries: int = 0
    failed_retries: int = 0
    cache_hits: int = 0
    # Storage (optional)
    s3_uploaded: bool = False
    s3_size_mb: float = 0.0
    clickhouse_rows: int = 0
    # Control
    silent: bool = True

@dataclass
class MonthlyReportData:
    year_month: str                        # "2026-02"
    dates_processed: int = 0
    dates_total: int = 0
    total_matches: int = 0
    matches_scraped: int = 0
    errors: int = 0
    duration_seconds: float = 0.0
    bronze_files: int = 0
    bronze_size_mb: float = 0.0
    s3_archives: int = 0
    s3_size_mb: float = 0.0
    silent: bool = True

@dataclass
class LayerAlertData:
    layer: str                             # "bronze" | "silver" | "gold" | "quality"
    success: bool
    scope: str                             # date range or "dry-run" or "checks=..."
    duration_seconds: float = 0.0
    # Layer-specific details (flexible dict for template)
    details: dict = field(default_factory=dict)
    insights: dict = field(default_factory=dict)
    # Quality-specific (reconciliation breakdown)
    entity_coverage: list = field(default_factory=list)  # [{"name", "bronze", "silver", "coverage"}]
    missing_count: int = 0
    avg_coverage: float = 0.0
    min_coverage: float = 0.0
    silent: bool = False

@dataclass
class PipelineSummaryData:
    date: str                              # "2026-02-18"
    success: bool
    total_duration_seconds: float = 0.0
    steps: list = field(default_factory=list)  # [{"name", "layer", "success", "duration_seconds", "error"}]
    dates_processed: int = 0
    dates_total: int = 0
    silent: bool = False

@dataclass
class ErrorAlertData:
    level: str                             # "ERROR" | "CRITICAL" | "WARNING"
    title: str                             # e.g. "Pipeline Step Failed"
    message: str                           # human-readable error description
    timestamp: str = ""                    # "14:32:05 UTC"
    context: dict = field(default_factory=dict)  # structured key-value details
    action_hint: str = ""                  # suggested remediation
    silent: bool = False
```

## `TelegramClient` (`client.py`)

```python
from config.settings import settings

class TelegramClient:
    """Thin transport layer for Telegram Bot API."""

    def __init__(self):
        self._bot_token = settings.telegram_bot_token
        self._chat_id = settings.telegram_chat_id
        self._base_url = f"https://api.telegram.org/bot{self._bot_token}"

    @property
    def is_configured(self) -> bool:
        return bool(self._bot_token and self._chat_id)

    def send_message(self, html: str, silent: bool = False) -> bool:
        """Send an HTML message to the configured chat."""
        if not self.is_configured:
            logger.warning("Telegram not configured, skipping send")
            return False
        payload = {
            "chat_id": self._chat_id,
            "text": html,
            "parse_mode": "HTML",
            "disable_notification": silent,
        }
        try:
            resp = requests.post(f"{self._base_url}/sendMessage", json=payload, timeout=30)
            resp.raise_for_status()
            return True
        except requests.RequestException as e:
            logger.error(f"Telegram send failed: {e}")
            return False

    def render_and_send(self, template_name: str, data, silent: bool = False) -> bool:
        """Render a Jinja2 template with data and send."""
        html = self._render(template_name, data)
        return self.send_message(html, silent=silent or getattr(data, "silent", False))

    def _render(self, template_name: str, data) -> str:
        template = self._jinja_env.get_template(template_name)
        return template.render(data=data)
```

## Templates

All templates extend `base.html.j2`. Example structure:

**`base.html.j2`** — shared header/footer/separator:
```html+jinja
{{ caller() if caller is defined else "" }}
```

**`daily_report.html.j2`** — daily scrape report:
```html+jinja
<b>📅 FotMob Scrape — {{ data.date }}</b>

<b>📊 Pipeline</b>
  Matches    <b>{{ data.matches_scraped }}/{{ data.matches_total }}</b> scraped ({{ "%.1f"|format(data.matches_scraped / data.matches_total * 100 if data.matches_total else 0) }}%)
{% if data.skipped > 0 %}
  Skipped    <b>{{ data.skipped }}</b> already cached
{% endif %}
{% if data.errors > 0 %}
  Errors     <b>{{ data.errors }}</b>
{% endif %}

{% if data.avg_response_time > 0 %}
<b>⚡ Performance</b>
  Duration   <b>{{ data.duration_seconds | format_duration }}</b>
  Avg resp   <b>{{ "%.2f"|format(data.avg_response_time) }}s</b>
{% if data.retries > 0 %}
  Retries    <b>{{ data.retries }}</b>{% if data.failed_retries > 0 %} ({{ data.failed_retries }} failed){% endif %}
{% endif %}
{% else %}
<b>⏱️ Duration</b>  <b>{{ data.duration_seconds | format_duration }}</b>
{% endif %}

<b>📦 Storage</b>
  Bronze     <b>{{ data.bronze_files }}</b> files · <b>{{ "%.1f"|format(data.bronze_size_mb) }} MB</b>
{% if data.s3_uploaded %}
  S3         ✅ uploaded
{% endif %}
{% if data.clickhouse_rows > 0 %}
  ClickHouse ✅ <b>{{ data.clickhouse_rows }}</b> rows
{% endif %}

{% if data.errors == 0 %}
✅ <b>All matches scraped successfully.</b>
{% elif data.matches_total > 0 and data.matches_scraped / data.matches_total >= 0.95 %}
⚠️ <b>Completed with {{ data.errors }} errors.</b>
{% else %}
🔴 <b>Review required — {{ data.errors }} failures.</b>
{% endif %}
```

Similar templates for other families following the same pattern.

## Caller Migration

### Files to update

| Current file | Current call | New call |
|---|---|---|
| `scripts/bronze/scrape_fotmob.py` | `send_daily_report(...)` | `client.render_and_send("daily_report.html.j2", DailyReportData(...))` |
| `scripts/bronze/scrape_fotmob.py` | `send_monthly_report(...)` | `client.render_and_send("monthly_report.html.j2", MonthlyReportData(...))` |
| `scripts/bronze/scrape_fotmob.py` | `send_layer_completion_alert(layer="bronze", ...)` | `client.render_and_send("layer_alert.html.j2", LayerAlertData(layer="bronze", ...))` |
| `scripts/bronze/load_clickhouse.py` | `AlertManager.send_alert(ERROR, ...)` | `client.render_and_send("error_alert.html.j2", ErrorAlertData(...))` |
| `scripts/bronze/load_clickhouse.py` | *(missing)* | Add `client.render_and_send("layer_alert.html.j2", LayerAlertData(layer="bronze", ...))` |
| `scripts/silver/load_clickhouse.py` | `send_layer_completion_alert(layer="silver", ...)` | `client.render_and_send("layer_alert.html.j2", LayerAlertData(layer="silver", ...))` |
| `scripts/gold/load_clickhouse_gold.py` | `send_layer_completion_alert(layer="gold", ...)` | `client.render_and_send("layer_alert.html.j2", LayerAlertData(layer="gold", ...))` |
| `scripts/quality/check_bronze_to_silver_reconciliation.py` | `send_layer_completion_alert(layer="quality", ...)` | `client.render_and_send("layer_alert.html.j2", LayerAlertData(layer="quality", ...))` |
| `scripts/orchestration/pipeline.py` | `AlertManager.send_alert(ERROR, ...)` per step failure | `client.render_and_send("error_alert.html.j2", ErrorAlertData(...))` |
| `scripts/orchestration/pipeline.py` | *(missing)* | Add `client.render_and_send("pipeline_summary.html.j2", PipelineSummaryData(...))` |
| `src/orchestrator.py` | `alert_manager.alert_failed_scrape(...)` | `client.render_and_send("error_alert.html.j2", ErrorAlertData(...))` |
| `src/orchestrator.py` | `alert_manager.alert_data_quality_issue(...)` | `client.render_and_send("error_alert.html.j2", ErrorAlertData(...))` |
| `src/utils/health_check.py` | `alert_manager.alert_health_check_failure(...)` | `client.render_and_send("error_alert.html.j2", ErrorAlertData(...))` |

### Data enrichment opportunities

| Caller | Currently passes | Should also pass |
|---|---|---|
| `scrape_fotmob.py` | 7 params | Add: `matches_total` (from `metrics.total_matches`), `avg_response_time`, `max_response_time`, `retries`, `cache_hits` from `ScraperMetrics` |
| `load_clickhouse.py` | Nothing | Add: per-table row counts as `LayerAlertData.details` |
| `pipeline.py` | Nothing | Add: `PipelineSummaryData` with per-step results from `PipelineResults` |
| `gold/load_clickhouse_gold.py` | Basic info | Add: `failed_jobs` list to `details` |

## Files to Delete

| File | Reason |
|---|---|
| `src/utils/metrics_alerts.py` | Replaced by `src/services/telegram/` |
| `src/utils/alerting.py` | `AlertManager`, `TelegramChannel`, `EmailChannel`, `LoggingChannel` — all removed |
| `src/utils/layer_completion_alerts.py` | Replaced by `LayerAlertData` + template |

## Files to Update (imports only)

| File | Change |
|---|---|
| `src/utils/__init__.py` | Remove `AlertManager`, `AlertLevel`, `Alert`, `get_alert_manager`, `set_alert_manager`, `LoggingChannel`, `EmailChannel` exports |

## Configuration Changes

| File | Change |
|---|---|
| `config.yaml` | Remove `alerting.telegram_enabled`, `alerting.slack_enabled`, `alerting.email_enabled` (dead config) |
| `config/settings.py` | Add `telegram_enabled: bool = True` field |
| `.env.example` | Keep `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (already there) |

## Implementation Order

### Step 1: Create `src/services/telegram/` package
- `__init__.py` — exports
- `messages.py` — all 5 dataclasses
- `client.py` — `TelegramClient` transport
- `templates/` — all 6 Jinja2 templates

### Step 2: Add `telegram_enabled` to `config.settings`
- Add field, update `.env.example` comment

### Step 3: Migrate `scripts/bronze/scrape_fotmob.py`
- Replace `send_daily_report()`, `send_monthly_report()`, `send_layer_completion_alert()`
- Enrich data from `ScraperMetrics` (add `total_matches`, performance metrics)

### Step 4: Migrate `scripts/bronze/load_clickhouse.py`
- Replace `AlertManager.send_alert()` calls
- Add `LayerAlertData` completion alert (currently missing)

### Step 5: Migrate `scripts/silver/load_clickhouse.py`
- Replace `send_layer_completion_alert()` calls

### Step 6: Migrate `scripts/gold/load_clickhouse_gold.py`
- Replace `send_layer_completion_alert()` calls
- Enrich with `failed_jobs` list

### Step 7: Migrate `scripts/quality/check_bronze_to_silver_reconciliation.py`
- Replace `send_layer_completion_alert()` calls
- Enrich with per-entity coverage breakdown

### Step 8: Migrate `scripts/orchestration/pipeline.py`
- Replace `AlertManager.send_alert()` calls
- Add `PipelineSummaryData` completion message (currently missing)

### Step 9: Migrate `src/orchestrator.py`
- Replace `alert_manager.alert_failed_scrape()`, `alert_data_quality_issue()`, `send_alert()`

### Step 10: Migrate `src/utils/health_check.py`
- Replace `alert_manager.alert_health_check_failure()`

### Step 11: Delete old files
- Delete `src/utils/metrics_alerts.py`
- Delete `src/utils/alerting.py`
- Delete `src/utils/layer_completion_alerts.py`
- Update `src/utils/__init__.py` exports

### Step 12: Clean up config
- Remove dead `alerting.*` keys from `config.yaml`

### Step 13: Verify
```bash
python -c "from src.services.telegram import TelegramClient, DailyReportData, LayerAlertData, PipelineSummaryData, ErrorAlertData, MonthlyReportData"
python scripts/quality/check_logging_style.py
pytest
```

## Risks

- **Jinja2 dependency** — not currently in `requirements.txt`. Must be added.
- **Caller migration breadth** — 10+ files import from the old modules. Each must be updated or imports break.
- **Data enrichment gaps** — some callers (e.g., `scrape_fotmob.py`) don't currently collect all the data we want to surface. Enrichment may require changes to `ScraperMetrics` or `FotMobOrchestrator`.
- **No Telegram integration tests** — `TelegramClient.send_message()` makes real HTTP calls. Testing requires mocking `requests.post`.

## Success Criteria

1. `src/services/telegram/` is the only Telegram code in the project
2. All 5 message families render correctly via Jinja2 templates
3. All callers import from `src.services.telegram`, not from old modules
4. Old files (`metrics_alerts.py`, `alerting.py`, `layer_completion_alerts.py`) are deleted
5. `config.settings` is the only config source for Telegram
6. Messages are concise, table-formatted, and only show available data
7. Pipeline summary message exists (currently missing)
8. Bronze ClickHouse load completion message exists (currently missing)
