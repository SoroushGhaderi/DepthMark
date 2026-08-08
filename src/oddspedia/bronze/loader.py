"""Idempotent loading of Oddspedia Historical artifacts into ClickHouse."""

import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import pandas as pd

from src.common.logging import get_logger
from src.integrations.clickhouse.client import ClickHouseClient
from src.oddspedia.scraping.audit import audit_match_payload
from src.oddspedia.scraping.config import get_match_links_file, normalize_date
from src.oddspedia.scraping.link_prioritization import source_inventory_checksum
from src.oddspedia.scraping.manifest import ManifestCorruptError, load_manifest
from src.oddspedia.scraping.match_collector import listing_matches_target_date
from src.oddspedia.scraping.storage import StoredMatchPayload, iter_match_payloads

logger = get_logger(__name__)

ODDSPEDIA_BRONZE_DATABASE = "oddspedia_bronze"


class OddspediaBronzeAdmissionError(ValueError):
    """Raised when a date does not satisfy the immutable Bronze input contract."""


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
    run_id: Optional[str] = None
    published: bool = False


def _parse_datetime(value: Any):
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            return parsed
        return parsed.astimezone(timezone.utc).replace(tzinfo=None)
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
        event_records, stored_payloads = self._validated_artifacts(date_id)
        event_rows = self._event_rows(date_id, records=event_records)
        payload_rows, market_rows = self._payload_rows(date_id, stored_payloads=stored_payloads)
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

        result.run_id = uuid.uuid4().hex
        self._publish_date(
            date_id,
            event_rows,
            payload_rows,
            market_rows,
            inventory_checksum=source_inventory_checksum(event_records),
            run_id=result.run_id,
        )
        result.published = True
        logger.info(
            "Oddspedia Bronze load completed",
            date=date_id,
            event_rows=result.event_rows,
            payload_rows=result.payload_rows,
            market_rows=result.market_rows,
        )
        return result

    def _publish_date(
        self,
        date_id: str,
        event_rows: List[Dict[str, Any]],
        payload_rows: List[Dict[str, Any]],
        market_rows: List[Dict[str, Any]],
        *,
        inventory_checksum: str,
        run_id: str,
    ) -> None:
        """Stage all three tables, then publish their date partition as one batch.

        ClickHouse does not provide a cross-table transaction for these tables.
        The load-status row is therefore the consumer-visible commit marker:
        readers must only consume a date whose latest status is ``published``.
        """
        date_iso = f"{date_id[:4]}-{date_id[4:6]}-{date_id[6:]}"
        partition = int(date_id[:6])
        specs = (
            ("event", "discovery_date", event_rows, "event_rows"),
            ("match_payload", "event_date", payload_rows, "payload_rows"),
            ("market", "event_date", market_rows, "market_rows"),
        )
        stages = []
        self._write_load_status(
            date_id,
            run_id,
            status="staging",
            inventory_checksum=inventory_checksum,
            event_rows=len(event_rows),
            payload_rows=len(payload_rows),
            market_rows=len(market_rows),
        )
        try:
            for table, date_column, rows, _count_field in specs:
                stage = f"_oddspedia_{table}_{run_id}"
                stages.append(stage)
                target = f"{self.database}.{table}"
                stage_table = f"{self.database}.{stage}"
                self.client.execute(f"CREATE TABLE {stage_table} AS {target}")
                self.client.execute(
                    f"INSERT INTO {stage_table} "
                    f"SELECT * FROM {target} FINAL "
                    f"WHERE toYYYYMM({date_column}) = {partition} "
                    f"AND {date_column} != toDate('{date_iso}')"
                )
                self._insert_stage(stage, rows)
                self._assert_stage_count(stage_table, date_column, date_iso, len(rows))

            for (table, _date_column, _rows, _count_field), stage_name in zip(specs, stages):
                stage = f"{self.database}.{stage_name}"
                self.client.execute(
                    f"ALTER TABLE {self.database}.{table} "
                    f"REPLACE PARTITION {partition} FROM {stage}"
                )

            self._write_load_status(
                date_id,
                run_id,
                status="published",
                inventory_checksum=inventory_checksum,
                event_rows=len(event_rows),
                payload_rows=len(payload_rows),
                market_rows=len(market_rows),
            )
        except Exception as exc:
            logger.error(
                "Oddspedia Bronze batch publication failed",
                date=date_id,
                run_id=run_id,
                error=str(exc),
            )
            try:
                self._write_load_status(
                    date_id,
                    run_id,
                    status="failed",
                    inventory_checksum=inventory_checksum,
                    event_rows=len(event_rows),
                    payload_rows=len(payload_rows),
                    market_rows=len(market_rows),
                    error=str(exc),
                )
            except Exception as status_exc:
                logger.error(
                    "Oddspedia Bronze failure status could not be recorded",
                    date=date_id,
                    run_id=run_id,
                    error=str(status_exc),
                )
            raise
        finally:
            for stage in stages:
                try:
                    self.client.execute(f"DROP TABLE IF EXISTS {self.database}.{stage}")
                except Exception as exc:
                    logger.warning(
                        "Oddspedia Bronze staging table cleanup failed",
                        table=f"{self.database}.{stage}",
                        error=str(exc),
                    )

    def _insert_stage(self, stage: str, rows: List[Dict[str, Any]]) -> None:
        if not rows:
            return
        self.client.insert_dataframe_qualified_table(
            stage,
            pd.DataFrame(rows),
            database=self.database,
        )

    def _assert_stage_count(
        self, stage_table: str, date_column: str, date_iso: str, expected: int
    ) -> None:
        result = self.client.execute(
            f"SELECT count() FROM {stage_table} " f"WHERE {date_column} = toDate('{date_iso}')"
        )
        actual = int(result.result_rows[0][0]) if result.result_rows else 0
        if actual != expected:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia staged row count mismatch for {stage_table}: "
                f"expected={expected}, actual={actual}"
            )

    def _write_load_status(
        self,
        date_id: str,
        run_id: str,
        *,
        status: str,
        inventory_checksum: str,
        event_rows: int,
        payload_rows: int,
        market_rows: int,
        error: Optional[str] = None,
    ) -> None:
        self._insert(
            "load_status",
            [
                {
                    "load_date": datetime.strptime(date_id, "%Y%m%d").date(),
                    "run_id": run_id,
                    "status": status,
                    "inventory_checksum": inventory_checksum,
                    "event_rows": event_rows,
                    "payload_rows": payload_rows,
                    "market_rows": market_rows,
                    "error": error,
                    "updated_at": datetime.now(timezone.utc),
                }
            ],
        )

    def _validated_artifacts(
        self, date_id: str
    ) -> Tuple[List[Dict[str, Any]], List[StoredMatchPayload]]:
        path = Path(get_match_links_file(date_id))
        if not path.exists():
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia accepted discovery inventory is missing for {date_id}: {path}"
            )
        try:
            records = _load_json(path)
        except (OSError, json.JSONDecodeError) as exc:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery inventory is unreadable for {date_id}: {exc}"
            ) from exc
        if not isinstance(records, list):
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia daily listing must contain a list: {path}"
            )

        event_ids = []
        for index, record in enumerate(records):
            if not isinstance(record, dict) or record.get("id") is None:
                raise OddspediaBronzeAdmissionError(
                    f"Oddspedia discovery row {index} has no event id for {date_id}"
                )
            event_ids.append(str(record["id"]))
        if len(set(event_ids)) != len(event_ids):
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery inventory contains duplicate event ids for {date_id}"
            )
        if records and not listing_matches_target_date(records, date_id):
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery inventory does not target {date_id}"
            )

        try:
            manifest = load_manifest(date_id, sport="football")
        except ManifestCorruptError as exc:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery manifest is corrupt for {date_id}: {exc}"
            ) from exc
        if manifest is None:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery manifest is missing for {date_id}"
            )
        if normalize_date(manifest.date) != date_id:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery manifest date does not match {date_id}"
            )
        discovery = manifest.discovery or {}
        discovery_status = discovery.get("status")
        if discovery_status not in {"accepted", "no_events"}:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery is not accepted for {date_id}: {discovery_status or 'missing'}"
            )
        if int(discovery.get("match_count", -1)) != len(records):
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery count does not match its inventory for {date_id}"
            )
        expected_checksum = source_inventory_checksum(records)
        if discovery.get("inventory_checksum") != expected_checksum:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia discovery inventory checksum is missing or stale for {date_id}"
            )
        if discovery_status == "no_events" and records:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia no-events manifest has event rows for {date_id}"
            )
        if discovery_status == "accepted" and not records:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia empty inventory lacks no-events evidence for {date_id}"
            )
        if manifest.failed or manifest.incomplete or manifest.in_progress:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia scrape scope is not terminal for {date_id}: "
                f"failed={manifest.failed_count}, incomplete={manifest.incomplete_count}, "
                f"in_progress={len(manifest.in_progress)}"
            )
        if (
            manifest.total > 0
            and manifest.completed_count + manifest.skipped_count < manifest.total
        ):
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia scrape scope is incomplete for {date_id}: "
                f"accepted={manifest.completed_count + manifest.skipped_count}, total={manifest.total}"
            )

        expected_matches = {str(record["id"]): record for record in records}
        stored_payloads = list(iter_match_payloads(date_id))
        accepted_payload_ids = set()
        for stored in stored_payloads:
            match_id = str(stored.match_id)
            expected_match = expected_matches.get(match_id)
            if expected_match is None:
                raise OddspediaBronzeAdmissionError(
                    f"Oddspedia payload {match_id} is not present in the accepted inventory for {date_id}"
                )
            audit = audit_match_payload(
                date_id,
                match_id,
                stored.payload,
                stored.source_file,
                stored.size_bytes,
                sport="football",
                expected_match=expected_match,
            )
            if not audit.accepted:
                reasons = "; ".join(audit.reasons) or audit.status
                raise OddspediaBronzeAdmissionError(
                    f"Oddspedia payload {match_id} is not accepted for {date_id}: {reasons}"
                )
            accepted_payload_ids.add(match_id)

        missing_done = sorted(set(map(str, manifest.done)) - accepted_payload_ids)
        if missing_done:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia manifest marks payloads done but they are not accepted for {date_id}: "
                + ", ".join(missing_done[:20])
            )
        state_ids = set(map(str, manifest.done)) | set(map(str, manifest.skipped))
        unknown_state_ids = sorted(state_ids - set(expected_matches))
        if unknown_state_ids:
            raise OddspediaBronzeAdmissionError(
                f"Oddspedia manifest references events outside the accepted inventory for {date_id}: "
                + ", ".join(unknown_state_ids[:20])
            )
        return records, stored_payloads

    def _event_rows(
        self, date_id: str, records: Optional[List[Dict[str, Any]]] = None
    ) -> List[Dict[str, Any]]:
        path = Path(get_match_links_file(date_id))
        if records is None:
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

    def _payload_rows(
        self,
        date_id: str,
        stored_payloads: Optional[Iterable[StoredMatchPayload]] = None,
    ):
        event_date = datetime.strptime(date_id, "%Y%m%d").date()
        payload_rows: List[Dict[str, Any]] = []
        market_rows: List[Dict[str, Any]] = []
        for stored in (
            stored_payloads if stored_payloads is not None else iter_match_payloads(date_id)
        ):
            payload = stored.payload
            if payload.get("id") is None:
                logger.warning("Ignoring invalid Oddspedia match payload", path=stored.source_file)
                continue
            if payload.get("identity_validation") == "market_salvaged":
                logger.warning(
                    "Ignoring mismatched Oddspedia match payload",
                    path=stored.source_file,
                    match_id=payload.get("id"),
                    source_event_id=payload.get("source_event_id"),
                    reason="market_salvaged",
                )
                continue
            match_id = str(payload["id"])
            payload_rows.append(
                {
                    "oddspedia_match_id": match_id,
                    "event_date": event_date,
                    "source_file": stored.source_file,
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
                        "source_file": stored.source_file,
                    }
                )
        return payload_rows, market_rows

    def _insert(self, table: str, rows: List[Dict[str, Any]]) -> None:
        if not rows:
            return
        self.client.insert_dataframe(table, pd.DataFrame(rows), database=self.database)
