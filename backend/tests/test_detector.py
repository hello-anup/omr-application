from pathlib import Path
import pytest

from app.services.omr_detector import _classify_answer, process_omr_image

REFERENCE = (
    Path(__file__).resolve().parents[1]
    / "reference"
    / "Universsal Omr Sheet.png"
)


def test_reference_sheet_detects_four_markers_and_30_questions():
    data = REFERENCE.read_bytes()
    result = process_omr_image(data)

    assert result["template_id"] == "OMR-001"
    assert len(result["corner_markers"]) == 4
    assert len(result["answers"]) == 30
    assert all(item["answer"] is None for item in result["answers"])


def test_real_photo_with_background_detects_markers_and_answers():
    fixture_path = Path(__file__).resolve().parent / "fixtures" / "omr_real_background.png"
    if not fixture_path.exists():
        pytest.skip("Fixture not present")

    data = fixture_path.read_bytes()
    result = process_omr_image(data)

    assert result["template_id"] == "OMR-001"
    assert len(result["corner_markers"]) == 4
    assert len(result["answers"]) == 30

    marked = [a for a in result["answers"] if a["status"] == "marked"]
    assert len(marked) == 9
    assert result["answers"][0]["answer"] == "ক"
    assert result["answers"][1]["answer"] == "ঘ"


def test_empty_image_data_raises_value_error():
    with pytest.raises(ValueError, match="Uploaded image is empty"):
        process_omr_image(b"")


def test_corrupted_image_data_raises_value_error():
    with pytest.raises(ValueError, match="not a valid image"):
        process_omr_image(b"not an image binary data")


def test_random_bytes_payload_raises_value_error():
    with pytest.raises(ValueError, match="not a valid image"):
        process_omr_image(b"\x00\x01\x02\x03\x04\x05")


def test_classify_answer_handles_blank_single_and_multiple_marks():
    assert _classify_answer([90.0, 95.0, 88.0, 92.0])[:2] == (None, "blank")
    assert _classify_answer([185.0, 92.0, 90.0, 91.0])[:2] == ("ক", "marked")
    assert _classify_answer([185.0, 182.0, 90.0, 91.0])[:2] == (None, "ambiguous")
    assert _classify_answer([195.0, 145.0, 90.0, 91.0])[:2] == (None, "ambiguous")


def test_health_endpoint_supports_get_and_head():
    import asyncio
    from app.main import app

    async def call(method: str) -> int:
        messages = []

        async def receive():
            return {"type": "http.request", "body": b"", "more_body": False}

        async def send(message):
            messages.append(message)

        scope = {
            "type": "http",
            "asgi": {"version": "3.0"},
            "http_version": "1.1",
            "method": method,
            "scheme": "http",
            "path": "/health",
            "raw_path": b"/health",
            "query_string": b"",
            "headers": [],
        }
        await app(scope, receive, send)
        return messages[0]["status"]

    assert asyncio.run(call("GET")) == 200
    assert asyncio.run(call("HEAD")) == 200
