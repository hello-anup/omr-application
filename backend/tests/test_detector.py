from pathlib import Path
import pytest

from app.services.omr_detector import process_omr_image

REFERENCE = (
    Path(__file__).resolve().parents[1]
    / "reference"
    / "Universsal Omr Sheet.png"
)


def test_reference_sheet_detects_four_markers_and_30_questions():
    """Verify reference template sheet detection."""
    data = REFERENCE.read_bytes()
    result = process_omr_image(data)

    assert result["template_id"] == "OMR-001"
    assert len(result["corner_markers"]) == 4
    assert len(result["answers"]) == 30
    assert all(item["answer"] is None for item in result["answers"])


def test_empty_image_data_raises_value_error():
    """Verify empty byte input raises ValueError."""
    with pytest.raises(ValueError, match="Uploaded image is empty"):
        process_omr_image(b"")


def test_corrupted_image_data_raises_value_error():
    """Verify corrupted text input raises ValueError."""
    with pytest.raises(ValueError, match="not a valid image"):
        process_omr_image(b"not an image binary data")


def test_random_bytes_payload_raises_value_error():
    """Verify non-image binary payload raises ValueError."""
    with pytest.raises(ValueError, match="not a valid image"):
        process_omr_image(b"\x00\x01\x02\x03\x04\x05")
