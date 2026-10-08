from __future__ import annotations

from typing import Any

import cv2
import numpy as np

from app.core.template_omr001 import (
    ANSWER_X_LEFT,
    ANSWER_X_RIGHT,
    ANSWER_Y,
    BUBBLE_INNER_RADIUS,
    FILLED_DARKNESS_THRESHOLD,
    IMAGE_HEIGHT,
    IMAGE_WIDTH,
    MARKER_CENTRES,
    MIN_SCORE_GAP,
)


# Bengali option labels used in the OMR sheet.
OPTION_LABELS = ("ক", "খ", "গ", "ঘ")


def _decode_image(data: bytes) -> np.ndarray:
    """
    Decode uploaded image bytes into an OpenCV BGR image.
    """

    array = np.frombuffer(data, dtype=np.uint8)

    image = cv2.imdecode(array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("The uploaded file is not a valid image.")

    return image


def _find_corner_markers(
    image: np.ndarray,
) -> list[tuple[float, float]]:
    """
    Find the four black square registration markers around the OMR sheet.

    Returns markers in this order:

        1. top-left
        2. top-right
        3. bottom-right
        4. bottom-left
    """

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Convert dark areas to white using Otsu thresholding.
    _, binary = cv2.threshold(
        gray,
        0,
        255,
        cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU,
    )

    contours, _ = cv2.findContours(
        binary,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE,
    )

    height, width = gray.shape

    image_area = float(height * width)

    candidates: list[
        tuple[float, float, float, float, float]
    ] = []

    for contour in contours:
        x, y, contour_width, contour_height = cv2.boundingRect(
            contour
        )

        area = float(contour_width * contour_height)

        # Ignore very small objects and very large regions.
        if (
            area < image_area * 0.0003
            or area > image_area * 0.02
        ):
            continue

        aspect = contour_width / max(contour_height, 1)

        contour_area = cv2.contourArea(contour)

        fill_ratio = contour_area / max(area, 1.0)

        # Registration markers are approximately square
        # and almost completely filled.
        if (
            0.80 <= aspect <= 1.25
            and fill_ratio >= 0.80
        ):
            candidates.append(
                (
                    x + contour_width / 2.0,
                    y + contour_height / 2.0,
                    float(contour_width),
                    float(contour_height),
                    float(fill_ratio),
                )
            )

    if len(candidates) < 4:
        raise ValueError(
            "Could not find four corner markers; "
            f"found {len(candidates)} candidates."
        )

    points = np.array(
        [(candidate[0], candidate[1]) for candidate in candidates],
        dtype=np.float32,
    )

    # Select the outermost four points using the standard
    # corner-distance combinations.
    top_left = points[
        np.argmin(points[:, 0] + points[:, 1])
    ]

    top_right = points[
        np.argmin(-points[:, 0] + points[:, 1])
    ]

    bottom_left = points[
        np.argmin(points[:, 0] - points[:, 1])
    ]

    bottom_right = points[
        np.argmax(points[:, 0] + points[:, 1])
    ]

    chosen = np.array(
        [
            top_left,
            top_right,
            bottom_right,
            bottom_left,
        ],
        dtype=np.float32,
    )

    # Make sure the selected markers are actually close
    # to the four corners of the sheet.
    margin_x = width * 0.15
    margin_y = height * 0.15

    valid = (
        chosen[0, 0] < margin_x
        and chosen[0, 1] < margin_y
        and chosen[1, 0] > width - margin_x
        and chosen[1, 1] < margin_y
        and chosen[2, 0] > width - margin_x
        and chosen[2, 1] > height - margin_y
        and chosen[3, 0] < margin_x
        and chosen[3, 1] > height - margin_y
    )

    if not valid:
        raise ValueError(
            "Four corner markers were not found "
            "at the sheet corners."
        )

    return [
        tuple(map(float, point))
        for point in chosen
    ]


def _warp_to_template(
    image: np.ndarray,
    source_points: list[tuple[float, float]],
) -> np.ndarray:
    """
    Perspective-correct the photographed/scanned sheet
    into the fixed OMR-001 template coordinate system.
    """

    # Destination order must match source order:
    #
    # source:
    #   TL, TR, BR, BL
    #
    # template:
    #   TL, TR, BR, BL
    destination = np.array(
        [
            MARKER_CENTRES[0],  # top-left
            MARKER_CENTRES[1],  # top-right
            MARKER_CENTRES[3],  # bottom-right
            MARKER_CENTRES[2],  # bottom-left
        ],
        dtype=np.float32,
    )

    source = np.array(
        source_points,
        dtype=np.float32,
    )

    matrix = cv2.getPerspectiveTransform(
        source,
        destination,
    )

    warped = cv2.warpPerspective(
        image,
        matrix,
        (IMAGE_WIDTH, IMAGE_HEIGHT),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(255, 255, 255),
    )

    return warped


def _bubble_darkness(
    gray: np.ndarray,
    x: float,
    y: float,
) -> float:
    """
    Calculate how dark the inside of a bubble is.

    0   = completely white
    255 = completely black

    We intentionally measure only the inner area of the
    bubble so that the printed circle border contributes
    as little as possible.
    """

    radius = BUBBLE_INNER_RADIUS

    center_x = int(round(x))
    center_y = int(round(y))

    y1 = center_y - radius
    y2 = center_y + radius + 1

    x1 = center_x - radius
    x2 = center_x + radius + 1

    # Make sure coordinates stay inside the image.
    image_height, image_width = gray.shape

    y1 = max(0, y1)
    y2 = min(image_height, y2)

    x1 = max(0, x1)
    x2 = min(image_width, x2)

    patch = gray[y1:y2, x1:x2]

    if patch.size == 0:
        return 0.0

    # Mean darkness:
    #
    # white pixel = 255
    # black pixel = 0
    #
    # Therefore:
    #
    # darkness = 255 - mean brightness
    darkness = 255.0 - float(np.mean(patch))

    return darkness


def _score_grid(
    gray: np.ndarray,
    xs: tuple[float, ...],
    ys: tuple[float, ...],
) -> list[list[float]]:
    """
    Calculate darkness scores for every bubble in a grid.

    Result format:

        [
            [option1, option2, option3, option4],
            ...
        ]

    Each row represents one question.
    """

    return [
        [
            _bubble_darkness(gray, x, y)
            for x in xs
        ]
        for y in ys
    ]


def _classify_answer(
    scores: list[float],
) -> tuple[str | None, float]:
    """
    Classify one question's four answer bubbles.

    Returns:

        (selected_answer, confidence_gap)

    If the mark is not strong enough or the difference between
    the strongest and second strongest bubble is too small,
    the answer is returned as None.
    """

    if not scores:
        return None, 0.0

    best_index = int(np.argmax(scores))

    ordered = sorted(
        scores,
        reverse=True,
    )

    strongest = ordered[0]

    second_strongest = (
        ordered[1]
        if len(ordered) > 1
        else 0.0
    )

    confidence_gap = strongest - second_strongest

    # Blank / ambiguous bubble.
    if strongest < FILLED_DARKNESS_THRESHOLD:
        return None, confidence_gap

    if confidence_gap < MIN_SCORE_GAP:
        return None, confidence_gap

    return (
        OPTION_LABELS[best_index],
        confidence_gap,
    )


def _decode_answers(
    gray: np.ndarray,
) -> tuple[
    list[dict[str, Any]],
    list[list[list[float]]],
]:
    """
    Decode all 30 objective answer bubbles.

    Q1-Q15  -> left answer section
    Q16-Q30 -> right answer section
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

    # ---------------------------------------------------------
    # Questions 1-15
    # ---------------------------------------------------------

    for question_number, scores in enumerate(
        left_scores,
        start=1,
    ):
        selected, confidence_gap = _classify_answer(
            scores
        )

        answers.append(
            {
                "question": question_number,
                "answer": selected,
                "confidence_gap": round(
                    float(confidence_gap),
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

    # ---------------------------------------------------------
    # Questions 16-30
    # ---------------------------------------------------------

    for question_number, scores in enumerate(
        right_scores,
        start=16,
    ):
        selected, confidence_gap = _classify_answer(
            scores
        )

        answers.append(
            {
                "question": question_number,
                "answer": selected,
                "confidence_gap": round(
                    float(confidence_gap),
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

    return (
        answers,
        [
            left_scores,
            right_scores,
        ],
    )


def process_omr_image(
    data: bytes,
) -> dict[str, Any]:
    """
    Main OMR processing pipeline.

    Current milestone:

        - Decode image
        - Detect four corner markers
        - Perspective correction
        - Read 30 objective answers

    Temporarily disabled:

        - Roll number
        - Registration number
        - Subject code
        - Set code

    """

    # ---------------------------------------------------------
    # 1. Decode uploaded image
    # ---------------------------------------------------------

    image = _decode_image(data)

    # ---------------------------------------------------------
    # 2. Find four corner markers
    # ---------------------------------------------------------

    markers = _find_corner_markers(image)

    # ---------------------------------------------------------
    # 3. Perspective correction
    # ---------------------------------------------------------

    warped = _warp_to_template(
        image,
        markers,
    )

    # ---------------------------------------------------------
    # 4. Convert normalized image to grayscale
    # ---------------------------------------------------------

    gray = cv2.cvtColor(
        warped,
        cv2.COLOR_BGR2GRAY,
    )

    # ---------------------------------------------------------
    # 5. Decode ONLY 30 answers
    # ---------------------------------------------------------

    answers, _answer_scores = _decode_answers(
        gray
    )

    # ---------------------------------------------------------
    # 6. Return result
    # ---------------------------------------------------------

    return {
        "template_id": "OMR-001",

        "image": {
            "input_width": int(
                image.shape[1]
            ),
            "input_height": int(
                image.shape[0]
            ),
            "normalized_width": IMAGE_WIDTH,
            "normalized_height": IMAGE_HEIGHT,
        },

        "corner_markers": [
            {
                "x": round(x, 2),
                "y": round(y, 2),
            }
            for x, y in markers
        ],

        "answers": answers,

        "note": (
            "Currently processing only the 30 objective "
            "answer bubbles. Roll number, registration "
            "number, subject code and set code are "
            "temporarily disabled."
        ),
    }