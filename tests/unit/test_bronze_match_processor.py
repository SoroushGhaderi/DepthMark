from src.fotmob.bronze.match_processor import FotMobBronzeMatchProcessor


def test_processor_initialization_does_not_create_validated_response_directory(
    tmp_path, monkeypatch
):
    monkeypatch.chdir(tmp_path)

    FotMobBronzeMatchProcessor()

    assert not (tmp_path / "data" / "validated_responses").exists()
