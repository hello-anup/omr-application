from __future__ import annotations

from typing import Any

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


OPTION_LABELS = ("ক", "খ", "গ", "ঘ")


# ============================================================================
# Image decoding
# ============================================================================

def _decode_image(data: bytes) -> np.ndarray:
    """
    Decode uploaded image bytes into an OpenCV BGR image.
    """

    if not data:
        raise ValueError("Uploaded image is empty.")

    array = np.frombuffer(data, dtype=np.uint8)

    image = cv2.imdecode(array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("The uploaded file is not a valid image.")

    return image


# ============================================================================
# Corner marker detection
# ============================================================================

def _find_corner_markers(
    image: np.ndarray,
) -> list[tuple[float, float]]:
    """
    Detect the four black registration markers around the OMR sheet.

    Returned order:

        TL, TR, BR, BL
    """

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    blurred = cv2.GaussianBlur(
        gray,
        (5, 5),
        0,
    )

    _, binary = cv2.threshold(
        blurred,
        0,
        255,
        cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU,
    )

    kernel = cv2.getStructuringElement(
        cv2.MORPH_RECT,
        (5, 5),
    )

    binary = cv2.morphologyEx(
        binary,
        cv2.MORPH_CLOSE,
        kernel,
    )

    contours, _ = cv2.findContours(
        binary,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE,
    )

    height, width = gray.shape
    image_area = float(width * height)

    candidates: list[dict[str, float]] = []

    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)

        area = float(w * h)

        if area <= 0:
            continue

        # Ignore tiny noise.
        if area < image_area * 0.00015:
            continue

        # Ignore very large regions.
        if area > image_area * 0.025:
            continue

        aspect = w / float(max(h, 1))

        if not 0.65 <= aspect <= 1.35:
            continue

        contour_area = cv2.contourArea(contour)

        fill_ratio = contour_area / max(area, 1.0)

        if fill_ratio < 0.65:
            continue

        perimeter = cv2.arcLength(
            contour,
            True,
        )

        if perimeter <= 0:
            continue

        approx = cv2.approxPolyDP(
            contour,
            0.04 * perimeter,
            True,
        )

        if len(approx) < 4 or len(approx) > 6:
            continue

        cx = x + (w / 2.0)
        cy = y + (h / 2.0)

        candidates.append(
            {
                "x": float(cx),
                "y": float(cy),
                "w": float(w),
                "h": float(h),
                "area": area,
                "fill": float(fill_ratio),
            }
        )

    if len(candidates) < 4:
        raise ValueError(
            "Could not find four corner markers. "
            f"Only {len(candidates)} suitable candidates were found."
        )

    # ------------------------------------------------------------------------
    # Expected corner positions
    # ------------------------------------------------------------------------

    expected = {
        "tl": np.array(
            [0.06 * width, 0.06 * height],
            dtype=np.float32,
        ),
        "tr": np.array(
            [0.94 * width, 0.06 * height],
            dtype=np.float32,
        ),
        "br": np.array(
            [0.94 * width, 0.94 * height],
            dtype=np.float32,
        ),
        "bl": np.array(
            [0.06 * width, 0.94 * height],
            dtype=np.float32,
        ),
    }

    image_diagonal = float(
        np.hypot(width, height)
    )

    # ------------------------------------------------------------------------
    # Select unique candidate for each corner.
    # ------------------------------------------------------------------------

    assignments: list[
        tuple[float, str, dict[str, float]]
    ] = []

    for candidate in candidates:
        point = np.array(
            [
                candidate["x"],
                candidate["y"],
            ],
            dtype=np.float32,
        )

        for corner_name, target in expected.items():
            distance = float(
                np.linalg.norm(point - target)
            )

            normalized_distance = (
                distance / max(image_diagonal, 1.0)
            )

            if normalized_distance <= 0.30:
                assignments.append(
                    (
                        normalized_distance,
                        corner_name,
                        candidate,
                    )
                )

    assignments.sort(
        key=lambda item: item[0]
    )

    selected: dict[str, dict[str, float]] = {}

    used_candidate_ids: set[int] = set()

    for _, corner_name, candidate in assignments:
        candidate_id = id(candidate)

        if corner_name in selected:
            continue

        if candidate_id in used_candidate_ids:
            continue

        selected[corner_name] = candidate
        used_candidate_ids.add(candidate_id)

        if len(selected) == 4:
            break

    # ------------------------------------------------------------------------
    # Fallback: geometric extreme points
    # ------------------------------------------------------------------------

    if len(selected) < 4:
        points = np.array(
            [
                [
                    candidate["x"],
                    candidate["y"],
                ]
                for candidate in candidates
            ],
            dtype=np.float32,
        )

        sums = points[:, 0] + points[:, 1]
        differences = points[:, 0] - points[:, 1]

        tl_index = int(
            np.argmin(sums)
        )

        tr_index = int(
            np.argmin(
                points[:, 1] - points[:, 0]
            )
        )

        br_index = int(
            np.argmax(sums)
        )

        bl_index = int(
            np.argmax(differences)
        )

        selected = {
            "tl": candidates[tl_index],
            "tr": candidates[tr_index],
            "br": candidates[br_index],
            "bl": candidates[bl_index],
        }

    # ------------------------------------------------------------------------
    # Validate uniqueness.
    # ------------------------------------------------------------------------

    points = np.array(
        [
            [
                selected["tl"]["x"],
                selected["tl"]["y"],
            ],
            [
                selected["tr"]["x"],
                selected["tr"]["y"],
            ],
            [
                selected["br"]["x"],
                selected["br"]["y"],
            ],
            [
                selected["bl"]["x"],
                selected["bl"]["y"],
            ],
        ],
        dtype=np.float32,
    )

    unique_points = np.unique(
        np.round(
            points,
            decimals=1,
        ),
        axis=0,
    )

    if len(unique_points) != 4:
        raise ValueError(
            "Corner marker detection produced duplicate markers."
        )

    # ------------------------------------------------------------------------
    # Geometry validation.
    # ------------------------------------------------------------------------

    tl = points[0]
    tr = points[1]
    br = points[2]
    bl = points[3]

    top_width = float(
        np.linalg.norm(tr - tl)
    )

    bottom_width = float(
        np.linalg.norm(br - bl)
    )

    left_height = float(
        np.linalg.norm(bl - tl)
    )

    right_height = float(
        np.linalg.norm(br - tr)
    )

    if min(
        top_width,
        bottom_width,
        left_height,
        right_height,
    ) < 1.0:
        raise ValueError(
            "Invalid corner marker geometry."
        )

    width_ratio = (
        min(top_width, bottom_width)
        / max(top_width, bottom_width)
    )

    height_ratio = (
        min(left_height, right_height)
        / max(left_height, right_height)
    )

    if width_ratio < 0.50 or height_ratio < 0.50:
        raise ValueError(
            "Detected corner markers do not form "
            "a valid sheet quadrilateral."
        )

    return [
        (
            float(tl[0]),
            float(tl[1]),
        ),
        (
            float(tr[0]),
            float(tr[1]),
        ),
        (
            float(br[0]),
            float(br[1]),
        ),
        (
            float(bl[0]),
            float(bl[1]),
        ),
    ]


# ============================================================================
# Perspective correction
# ============================================================================

def _warp_to_template(
    image: np.ndarray,
    source_points: list[tuple[float, float]],
) -> np.ndarray:
    """
    Transform photographed/scanned OMR into OMR-001 coordinates.

    source order:
        TL, TR, BR, BL

    MARKER_CENTRES order:
        TL, TR, BL, BR
    """

    if len(source_points) != 4:
        raise ValueError(
            "Exactly four corner markers are required."
        )

    source = np.array(
        source_points,
        dtype=np.float32,
    )

    destination = np.array(
        [
            MARKER_CENTRES[0],  # TL
            MARKER_CENTRES[1],  # TR
            MARKER_CENTRES[3],  # BR
            MARKER_CENTRES[2],  # BL
        ],
        dtype=np.float32,
    )

    matrix = cv2.getPerspectiveTransform(
        source,
        destination,
    )

    warped = cv2.warpPerspective(
        image,
        matrix,
        (
            IMAGE_WIDTH,
            IMAGE_HEIGHT,
        ),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )

    return warped


# ============================================================================
# Bubble measurement
# ============================================================================

def _get_bubble_patch(
    gray: np.ndarray,
    x: float,
    y: float,
) -> np.ndarray:
    """
    Extract the inner region of one bubble.
    """

    radius = int(BUBBLE_INNER_RADIUS)

    cx = int(round(x))
    cy = int(round(y))

    x1 = max(
        0,
        cx - radius,
    )

    y1 = max(
        0,
        cy - radius,
    )

    x2 = min(
        gray.shape[1],
        cx + radius + 1,
    )

    y2 = min(
        gray.shape[0],
        cy + radius + 1,
    )

    patch = gray[
        y1:y2,
        x1:x2,
    ]

    return patch


def _bubble_darkness(
    gray: np.ndarray,
    x: float,
    y: float,
) -> float:
    """
    Calculate mean darkness inside a bubble.

    0   = white
    255 = black
    """

    patch = _get_bubble_patch(
        gray,
        x,
        y,
    )

    if patch.size == 0:
        return 0.0

    mean_darkness = (
        255.0 - float(np.mean(patch))
    )

    return max(
        0.0,
        mean_darkness,
    )


def _bubble_black_ratio(
    gray: np.ndarray,
    x: float,
    y: float,
) -> float:
    """
    Estimate the ratio of genuinely dark pixels
    inside the bubble.
    """

    patch = _get_bubble_patch(
        gray,
        x,
        y,
    )

    if patch.size == 0:
        return 0.0

    mean_value = float(
        np.mean(patch)
    )

    std_value = float(
        np.std(patch)
    )

    threshold = min(
        180.0,
        mean_value - (0.35 * std_value),
    )

    # Prevent an excessively low threshold.
    threshold = max(
        60.0,
        threshold,
    )

    dark_pixels = np.count_nonzero(
        patch < threshold
    )

    return float(
        dark_pixels / patch.size
    )


def _bubble_score(
    gray: np.ndarray,
    x: float,
    y: float,
) -> float:
    """
    Combined score for one bubble.

    Darkness is the primary signal.
    Black-pixel ratio is the secondary signal.
    """

    darkness = _bubble_darkness(
        gray,
        x,
        y,
    )

    black_ratio = _bubble_black_ratio(
        gray,
        x,
        y,
    )

    ratio_component = (
        black_ratio * 80.0
    )

    score = (
        darkness * 0.75
        + ratio_component * 0.25
    )

    return float(score)


# ============================================================================
# Answer grid
# ============================================================================

def _score_answer_row(
    gray: np.ndarray,
    xs: tuple[float, ...],
    y: float,
) -> list[float]:
    """
    Calculate four bubble scores for one question.
    """

    return [
        _bubble_score(
            gray,
            x,
            y,
        )
        for x in xs
    ]


def _score_grid(
    gray: np.ndarray,
    xs: tuple[float, ...],
    ys: tuple[float, ...],
) -> list[list[float]]:
    """
    Calculate darkness/mark scores for every bubble
    in an answer grid.

    Result:

        [
            [ক, খ, গ, ঘ],
            [ক, খ, গ, ঘ],
            ...
        ]

    Each row represents one question.
    """

    return [
        _score_answer_row(
            gray,
            xs,
            y,
        )
        for y in ys
    ]


# ============================================================================
# Answer classification
# ============================================================================

def _classify_answer(
    scores: list[float],
) -> tuple[str | None, str, float]:
    """
    Classify one question's four answer bubbles.

    Decision rules:
    - A clearly dominant bubble is marked.
    - A very small difference means blank.
    - Borderline cases remain blank for now.
    """

    if len(scores) != 4:
        raise ValueError("Expected exactly four bubble scores.")

    best_index = int(np.argmax(scores))
    ordered = sorted(scores, reverse=True)

    best_score = float(ordered[0])
    second_score = float(ordered[1])

    confidence_gap = best_score - second_score

    # Clearly no bubble is significantly darker.
    if confidence_gap < 20:
        return None, "blank", confidence_gap

    # Strongly marked bubble.
    #
    # The gap is the primary signal because an actually filled
    # bubble should be substantially darker than the other options.
    if confidence_gap >= 35 and best_score >= 140:
        return OPTION_LABELS[best_index], "marked", confidence_gap

    # Borderline region.
    #
    # We do not guess here. This can later be exposed as
    # "ambiguous" for manual review.
    return None, "blank", confidence_gap


# ============================================================================
# Answer decoding
# ============================================================================

def _decode_answers(
    gray: np.ndarray,
) -> tuple[
    list[dict[str, Any]],
    dict[str, Any],
]:
    """
    Decode all 30 objective questions.

    Questions 1-15:
        ANSWER_X_LEFT

    Questions 16-30:
        ANSWER_X_RIGHT
    """

    left_scores = _score_grid(
        gray,
        ANSWER_X_LEFT,
        ANSWER_Y,
    )

    right_scores = _score_grid(
        gray,
        ANSWER_X_RIGHT,
        ANSWER_Y,
    )

    answers: list[dict[str, Any]] = []

    marked_count = 0
    blank_count = 0
    ambiguous_count = 0

    # ------------------------------------------------------------------------
    # Questions 1-15
    # ------------------------------------------------------------------------

    for question_number, scores in enumerate(
        left_scores,
        start=1,
    ):
        answer, status, confidence_gap = (
            _classify_answer(scores)
        )

        if status == "marked":
            marked_count += 1
        elif status == "blank":
            blank_count += 1
        elif status == "ambiguous":
            ambiguous_count += 1

        answers.append(
            {
                "question": question_number,
                "answer": answer,
                "status": status,
                "confidence_gap": round(
                    confidence_gap,
                    2,
                ),
                "scores": {
                    OPTION_LABELS[index]: round(
                        float(scores[index]),
                        2,
                    )
                    for index in range(4)
                },
            }
        )

    # ------------------------------------------------------------------------
    # Questions 16-30
    # ------------------------------------------------------------------------

    for question_number, scores in enumerate(
        right_scores,
        start=16,
    ):
        answer, status, confidence_gap = (
            _classify_answer(scores)
        )

        if status == "marked":
            marked_count += 1
        elif status == "blank":
            blank_count += 1
        elif status == "ambiguous":
            ambiguous_count += 1

        answers.append(
            {
                "question": question_number,
                "answer": answer,
                "status": status,
                "confidence_gap": round(
                    confidence_gap,
                    2,
                ),
                "scores": {
                    OPTION_LABELS[index]: round(
                        float(scores[index]),
                        2,
                    )
                    for index in range(4)
                },
            }
        )

    summary = {
        "total_questions": len(answers),
        "marked": marked_count,
        "blank": blank_count,
        "ambiguous": ambiguous_count,
    }

    debug = {
        "summary": summary,
        "left_scores": left_scores,
        "right_scores": right_scores,
    }

    return answers, debug


# ============================================================================
# Main OMR processing
# ============================================================================

def process_omr_image(
    data: bytes,
) -> dict[str, Any]:
    """
    Main OMR processing entry point.

    CURRENT MILESTONE:

        Only the 30 objective answer bubbles
        are processed.

    Disabled for now:

        - Roll number
        - Registration number
        - Subject code
        - Set code
    """

    # ------------------------------------------------------------------------
    # 1. Decode uploaded image
    # ------------------------------------------------------------------------

    image = _decode_image(
        data
    )

    # ------------------------------------------------------------------------
    # 2. Detect four corner markers
    # ------------------------------------------------------------------------

    markers = _find_corner_markers(
        image
    )

    # ------------------------------------------------------------------------
    # 3. Perspective correction
    # ------------------------------------------------------------------------

    warped = _warp_to_template(
        image,
        markers,
    )

    # ------------------------------------------------------------------------
    # 4. Grayscale
    # ------------------------------------------------------------------------

    gray = cv2.cvtColor(
        warped,
        cv2.COLOR_BGR2GRAY,
    )

    # ------------------------------------------------------------------------
    # 5. Decode only 30 answers
    # ------------------------------------------------------------------------

    answers, answer_debug = _decode_answers(
        gray
    )

    # ------------------------------------------------------------------------
    # 6. Return API response
    # ------------------------------------------------------------------------

    return {
        "template_id": "OMR-001",

        "image": {
            "input_width": int(
                image.shape[1]
            ),
            "input_height": int(
                image.shape[0]
            ),
            "normalized_width": int(
                IMAGE_WIDTH
            ),
            "normalized_height": int(
                IMAGE_HEIGHT
            ),
        },

        "corner_markers": [
            {
                "x": round(
                    x,
                    2,
                ),
                "y": round(
                    y,
                    2,
                ),
            }
            for x, y in markers
        ],

        "answers": answers,

        "summary": answer_debug["summary"],

        "note": (
            "Currently processing only the 30 objective "
            "answer bubbles. Roll number, registration "
            "number, subject code and set code are "
            "temporarily disabled."
        ),
    }
