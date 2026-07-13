"""Regression tests for source and shared-module boundaries."""

from src.fotmob.bronze import BronzeService
from src.fotmob.gold import GoldService
from src.fotmob.silver import SilverService
from src.integrations.clickhouse.client import ClickHouseClient
from src.oddspedia.bronze import OddspediaBronzeLoader
from src.oddspedia.silver import OddspediaResolutionService
from src.warehouse.scope import WarehouseExecutionScope


def test_source_and_shared_modules_have_explicit_ownership() -> None:
    """Keep source workflows separate from shared warehouse infrastructure."""
    assert BronzeService.__module__ == "src.fotmob.bronze.loader"
    assert GoldService.__module__ == "src.fotmob.gold.service"
    assert SilverService.__module__ == "src.fotmob.silver.service"
    assert OddspediaBronzeLoader.__module__ == "src.oddspedia.bronze.loader"
    assert OddspediaResolutionService.__module__ == "src.oddspedia.silver.match_resolution"
    assert ClickHouseClient.__module__ == "src.integrations.clickhouse.client"
    assert WarehouseExecutionScope.__module__ == "src.warehouse.scope"
