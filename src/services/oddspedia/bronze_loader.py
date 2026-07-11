"""Idempotent loading of Oddspedia Historical artifacts into ClickHouse."""

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd

from src.oddspedia.config import get_match_links_file, get_matches_dir, normalize_date
from src.storage.clickhouse_client import ClickHouseClient
from src.utils.logging_utils import get_logger

logger = get_logger(__name__)

ODDSPEDIA_BRONZE_DATABASE = "oddspedia_bronze"


def _load_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as source:
        return json.load(source)


@dataclass
class OddspediaBronzeLoadResult:
    """Counts emitted by one date-scoped Oddspedia Bronze load."""

    date: str
    event_rows: int = 0
    payload_rows: int = 0
    market_rows: int = 0
    dry_run: bool = False


def _parse_datetime(value: Any):
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return parsed.replace(tzinfo=None)
    except ValueError:
        return None


class OddspediaBronzeLoader:
    """Load source-faithful OddsHarvest artifacts without touching FotMob Bronze."""

    def __init__(self, client: ClickHouseClient, database: str = ODDSPEDIA_BRONZE_DATABASE):
        self.client = client
        self.database = database

    def load_date(self, date_str: str, dry_run: bool = False) -> OddspediaBronzeLoadResult:
        date_id = normalize_date(date_str)
        result = OddspediaBronzeLoadResult(date=date_id, dry_run=dry_run)
        event_rows = self._event_rows(date_id)
        payload_rows, market_rows = self._payload_rows(date_id)
        result.event_rows = len(event_rows)
        result.payload_rows = len(payload_rows)
        result.market_rows = len(market_rows)

        if dry_run:
            logger.info(
                "Oddspedia Bronze load planned",
                date=date_id,
                event_rows=result.event_rows,
                payload_rows=result.payload_rows,
                market_rows=result.market_rows,
            )
            return result

        self._insert("event", event_rows)
        self._insert("match_payload", payload_rows)
        self._insert("market", market_rows)
        logger.info(
            "Oddspedia Bronze load completed",
            date=date_id,
            event_rows=result.event_rows,
            payload_rows=result.payload_rows,
            market_rows=result.market_rows,
        )
        return result

    def _event_rows(self, date_id: str) -> List[Dict[str, Any]]:
        path = Path(get_match_links_file(date_id))
        if not path.exists():
            logger.warning("Oddspedia daily listing is absent", date=date_id, path=str(path))
            return []
        records = _load_json(path)
        if not isinstance(records, list):
            raise ValueError("Oddspedia daily listing must contain a list: %s" % path)
        discovery_date = datetime.strptime(date_id, "%Y%m%d").date()
        rows = []
        for record in records:
            if not isinstance(record, dict) or record.get("id") is None:
                continue
            rows.append(
                {
                    "oddspedia_match_id": str(record["id"]),
                    "discovery_date": discovery_date,
                    "scheduled_kickoff_utc": _parse_datetime(record.get("date")),
                    "home_team_name": record.get("home") or None,
                    "away_team_name": record.get("away") or None,
                    "league_name": record.get("league_name") or None,
                    "country": record.get("country") or None,
                    "status": record.get("status") or None,
                    "source_url": record.get("url") or None,
                    "full_source_url": record.get("full_url") or None,
                    "source_file": str(path),
                    "raw_event_json": json.dumps(record, ensure_ascii=False, sort_keys=True),
                }
            )
        return rows

    def _payload_rows(self, date_id: str):
        matches_dir = Path(get_matches_dir(date_id))
        if not matches_dir.exists():
            return [], []
        event_date = datetime.strptime(date_id, "%Y%m%d").date()
        payload_rows: List[Dict[str, Any]] = []
        market_rows: List[Dict[str, Any]] = []
        for path in sorted(matches_dir.glob("*.json")):
            payload = _load_json(path)
            if not isinstance(payload, dict) or payload.get("id") is None:
                logger.warning("Ignoring invalid Oddspedia match payload", path=str(path))
                continue
            match_id = str(payload["id"])
            payload_rows.append(
                {
                    "oddspedia_match_id": match_id,
                    "event_date": event_date,
                    "source_file": str(path),
                    "raw_payload_json": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                    "scraped_at": _parse_datetime(payload.get("scraped_at")),
                }
            )
            for market in payload.get("odds") or []:
                if not isinstance(market, dict) or not market.get("market"):
                    continue
                market_rows.append(
                    {
                        "oddspedia_match_id": match_id,
                        "event_date": event_date,
                        "market_name": str(market["market"]),
                        "lines_json": json.dumps(market.get("lines") or [], ensure_ascii=False),
                        "source_file": str(path),
                    }
                )
        return payload_rows, market_rows

    def _insert(self, table: str, rows: List[Dict[str, Any]]) -> None:
        if not rows:
            return
        self.client.insert_dataframe(table, pd.DataFrame(rows), database=self.database)
