from __future__ import annotations

import logging
from itertools import product
from typing import Any, NamedTuple

import cv2
import numpy as np

from app.core.template_omr001 import (
    ANSWER_X_LEFT,
    ANSWER_X_RIGHT,
    ANSWER_Y,
    BUBBLE_INNER_RADIUS,
    IMAGE_HEIGHT,
    IMAGE_WIDTH,
    MARKER_CENTRES,
)

logger = logging.getLogger(__name__)

TEMPLATE_ID = "OMR-001"
OPTION_LABELS = ("ক", "খ", "গ", "ঘ")

PAPER_AREA_RANGE = (0.20, 0.95)
PAPER_ASPECT_RANGE = (0.45, 1.15)
PAPER_EDGE_MARGIN = 15

MARKER_AREA_RANGE = (0.0003, 0.025)
MARKER_ASPECT_RANGE = (0.65, 1.35)
MARKER_MIN_FILL = 0.65
MARKER_CORNER_COUNT_RANGE = (4, 6)
MARKER_SIMILAR_SIZE_RATIO = 0.50
MARKERS_TRIED_PER_CORNER = 4
MIN_SIDE_LENGTH_RATIO = 0.50

DARKNESS_WEIGHT = 0.75
BLACK_RATIO_WEIGHT = 0.25
BLACK_RATIO_SCALE = 80.0

MARKED_MIN_GAP = 35
MARKED_MIN_SCORE = 140


class Candidate(NamedTuple):
    x: float
    y: float
    area: float


def _decode_image(data: bytes) -> np.ndarray:
    if not data:
        raise ValueError("Uploaded image is empty.")

    image = cv2.imdecode(np.frombuffer(data, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("The uploaded file is not a valid image.")
    return image


def _distance(candidate: Candidate, point: tuple[float, float]) -> float:
    return float(np.hypot(candidate.x - point[0], candidate.y - point[1]))


def _find_paper_box(blurred: np.ndarray) -> tuple[int, int, int, int] | None:
    image_area = float(blurred.shape[0] * blurred.shape[1])

    _, mask = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None

    largest = max(contours, key=cv2.contourArea)
    min_area, max_area = PAPER_AREA_RANGE
    if not min_area * image_area <= cv2.contourArea(largest) <= max_area * image_area:
        return None

    x, y, w, h = cv2.boundingRect(largest)
    min_aspect, max_aspect = PAPER_ASPECT_RANGE
    if min_aspect <= w / float(max(h, 1)) <= max_aspect:
        return x, y, w, h
    return None


def _find_marker_candidates(
    binary: np.ndarray,
    region: tuple[int, int, int, int],
    must_be_inside: bool,
) -> list[Candidate]:
    rx, ry, rw, rh = region
    region_area = float(rw * rh)
    contours, _ = cv2.findContours(binary, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)

    candidates = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        box_area = float(w * h)

        min_ratio, max_ratio = MARKER_AREA_RANGE
        if not min_ratio * region_area <= box_area <= max_ratio * region_area:
            continue

        min_aspect, max_aspect = MARKER_ASPECT_RANGE
        if not min_aspect <= w / float(max(h, 1)) <= max_aspect:
            continue

        if cv2.contourArea(contour) / box_area < MARKER_MIN_FILL:
            continue

        perimeter = cv2.arcLength(contour, True)
        if perimeter <= 0:
            continue

        outline = cv2.approxPolyDP(contour, 0.04 * perimeter, True)
        min_corners, max_corners = MARKER_CORNER_COUNT_RANGE
        if not min_corners <= len(outline) <= max_corners:
            continue

        centre_x = x + w / 2.0
        centre_y = y + h / 2.0
        if must_be_inside:
            inside_x = rx - PAPER_EDGE_MARGIN <= centre_x <= rx + rw + PAPER_EDGE_MARGIN
            inside_y = ry - PAPER_EDGE_MARGIN <= centre_y <= ry + rh + PAPER_EDGE_MARGIN
            if not (inside_x and inside_y):
                continue

        candidates.append(Candidate(centre_x, centre_y, box_area))

    return candidates


def _group_by_corner(
    candidates: list[Candidate],
    corners: list[tuple[float, float]],
) -> list[list[Candidate]]:
    (left, top), _, (right, bottom), _ = corners
    mid_x = (left + right) / 2.0
    mid_y = (top + bottom) / 2.0

    corner_index = {
        (False, False): 0,
        (True, False): 1,
        (True, True): 2,
        (False, True): 3,
    }

    groups: list[list[Candidate]] = [[], [], [], []]
    for candidate in candidates:
        key = (candidate.x >= mid_x, candidate.y >= mid_y)
        groups[corner_index[key]].append(candidate)

    if not all(groups):
        raise ValueError("Corner markers could not be identified in all four quadrants.")

    for group, corner in zip(groups, corners):
        group.sort(key=lambda c: _distance(c, corner))
    return groups


def _pick_best_markers(
    groups: list[list[Candidate]],
    corners: list[tuple[float, float]],
) -> tuple[Candidate, ...]:
    best = tuple(group[0] for group in groups)
    best_distance = float("inf")

    shortlists = [group[:MARKERS_TRIED_PER_CORNER] for group in groups]
    for combo in product(*shortlists):
        areas = [c.area for c in combo]
        if min(areas) / max(areas) < MARKER_SIMILAR_SIZE_RATIO:
            continue

        total = sum(_distance(c, corner) for c, corner in zip(combo, corners))
        if total < best_distance:
            best, best_distance = combo, total

    return best


def _check_sheet_shape(points: np.ndarray) -> None:
    if len(np.unique(np.round(points, 1), axis=0)) != 4:
        raise ValueError("Corner marker detection produced duplicate markers.")

    tl, tr, br, bl = points
    top = float(np.linalg.norm(tr - tl))
    bottom = float(np.linalg.norm(br - bl))
    left = float(np.linalg.norm(bl - tl))
    right = float(np.linalg.norm(br - tr))

    if min(top, bottom, left, right) < 1.0:
        raise ValueError("Invalid corner marker geometry.")

    width_ratio = min(top, bottom) / max(top, bottom)
    height_ratio = min(left, right) / max(left, right)
    if min(width_ratio, height_ratio) < MIN_SIDE_LENGTH_RATIO:
        raise ValueError("Detected corner markers do not form a valid sheet quadrilateral.")


def _find_corner_markers(image: np.ndarray) -> list[tuple[float, float]]:
    height, width = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    paper_box = _find_paper_box(blurred)
    region = paper_box or (0, 0, width, height)
    x, y, w, h = region
    corners = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]

    candidates = _find_marker_candidates(binary, region, must_be_inside=paper_box is not None)
    if len(candidates) < 4:
        raise ValueError(
            f"Could not find four corner markers. Only {len(candidates)} suitable candidates were found."
        )

    groups = _group_by_corner(candidates, corners)
    best = _pick_best_markers(groups, corners)

    points = np.array([[c.x, c.y] for c in best], dtype=np.float32)
    _check_sheet_shape(points)

    return [(float(px), float(py)) for px, py in points]


def _warp_to_template(
    image: np.ndarray,
    markers: list[tuple[float, float]],
) -> np.ndarray:
    if len(markers) != 4:
        raise ValueError("Exactly four corner markers are required.")

    top_left, top_right, bottom_left, bottom_right = MARKER_CENTRES
    source = np.array(markers, dtype=np.float32)
    target = np.array(
        [top_left, top_right, bottom_right, bottom_left],
        dtype=np.float32,
    )

    matrix = cv2.getPerspectiveTransform(source, target)
    return cv2.warpPerspective(
        image,
        matrix,
        (IMAGE_WIDTH, IMAGE_HEIGHT),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )


def _bubble_patch(gray: np.ndarray, x: float, y: float) -> np.ndarray:
    radius = int(BUBBLE_INNER_RADIUS)
    cx, cy = int(round(x)), int(round(y))
    return gray[
        max(0, cy - radius): min(gray.shape[0], cy + radius + 1),
        max(0, cx - radius): min(gray.shape[1], cx + radius + 1),
    ]


def _bubble_score(gray: np.ndarray, x: float, y: float) -> float:
    patch = _bubble_patch(gray, x, y)
    if patch.size == 0:
        return 0.0

    mean = float(np.mean(patch))
    std = float(np.std(patch))

    darkness = max(0.0, 255.0 - mean)

    dark_threshold = max(60.0, min(180.0, mean - 0.35 * std))
    black_ratio = np.count_nonzero(patch < dark_threshold) / patch.size

    return float(
        darkness * DARKNESS_WEIGHT
        + black_ratio * BLACK_RATIO_SCALE * BLACK_RATIO_WEIGHT
    )


def _classify_answer(scores: list[float]) -> tuple[str | None, str, float]:
    if len(scores) != 4:
        raise ValueError("Expected exactly four bubble scores.")

    darkest, runner_up = sorted(scores, reverse=True)[:2]
    gap = float(darkest - runner_up)

    if gap >= MARKED_MIN_GAP and darkest >= MARKED_MIN_SCORE:
        return OPTION_LABELS[int(np.argmax(scores))], "marked", gap
    return None, "blank", gap


def _read_question(gray: np.ndarray, number: int, xs: tuple[float, ...], y: float) -> dict[str, Any]:
    scores = [_bubble_score(gray, x, y) for x in xs]
    answer, status, gap = _classify_answer(scores)

    return {
        "question": number,
        "answer": answer,
        "status": status,
        "confidence_gap": round(gap, 2),
        "scores": {
            label: round(float(score), 2)
            for label, score in zip(OPTION_LABELS, scores)
        },
    }


def _decode_answers(gray: np.ndarray) -> tuple[list[dict[str, Any]], dict[str, int]]:
    answers = []
    for column_xs in (ANSWER_X_LEFT, ANSWER_X_RIGHT):
        for y in ANSWER_Y:
            answers.append(_read_question(gray, len(answers) + 1, column_xs, y))

    statuses = [item["status"] for item in answers]
    summary = {
        "total_questions": len(answers),
        "marked": statuses.count("marked"),
        "blank": statuses.count("blank"),
        "ambiguous": statuses.count("ambiguous"),
    }
    return answers, summary


def process_omr_image(data: bytes) -> dict[str, Any]:
    image = _decode_image(data)
    logger.debug("Decoded image with shape: %s", image.shape)

    markers = _find_corner_markers(image)
    warped = _warp_to_template(image, markers)
    gray = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)

    answers, summary = _decode_answers(gray)
    logger.info("OMR processing complete: %d answers decoded", len(answers))

    return {
        "template_id": TEMPLATE_ID,
        "image": {
            "input_width": int(image.shape[1]),
            "input_height": int(image.shape[0]),
            "normalized_width": int(IMAGE_WIDTH),
            "normalized_height": int(IMAGE_HEIGHT),
        },
        "corner_markers": [{"x": round(x, 2), "y": round(y, 2)} for x, y in markers],
        "answers": answers,
        "summary": summary,
        "note": (
            "Currently processing only the 30 objective answer bubbles. "
            "Roll number, registration number, subject code and set code "
            "are temporarily disabled."
        ),
    }
