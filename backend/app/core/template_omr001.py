
"""Measured geometry for the supplied clean Universal OMR-001 reference.

Reference raster: 1370 x 2048 pixels.
The four black registration markers are used to rectify a photo/scan to this
coordinate system before reading fixed bubble positions.
"""

IMAGE_WIDTH = 1370
IMAGE_HEIGHT = 2048

MARKER_CENTRES = (
    (32.0, 79.0),      # top-left
    (1340.0, 79.0),    # top-right
    (32.0, 2019.0),    # bottom-left
    (1340.0, 2019.0),  # bottom-right
)

ANSWER_X_LEFT = (122.5, 207.5, 293.0, 378.0)
ANSWER_X_RIGHT = (610.25, 695.5, 780.5, 866.0)
ANSWER_Y = (
    947.5, 1001.5, 1056.1, 1111.3, 1166.4,
    1221.8, 1276.9, 1332.4, 1387.4, 1442.7,
    1497.9, 1553.2, 1608.6, 1663.5, 1719.1,
)

# Roll Number: 6 columns x 10 digit rows.
ROLL_X = (976.0, 1018.0, 1060.0, 1102.0, 1144.0, 1186.0)
ROLL_Y = tuple(946.0 + 45.0 * i for i in range(10))

# Registration Number: 6 columns x 10 digit rows.
REG_X = ROLL_X
REG_Y = tuple(1424.0 + 45.0 * i for i in range(10))

# Subject Code: 3 columns x 10 digit rows.
SUBJECT_X = (1262.0, 1304.0, 1346.0)
SUBJECT_Y = tuple(1476.0 + 44.5 * i for i in range(10))

# The printed Bengali digit/option inside a blank bubble creates a small
# amount of darkness. A filled bubble is much darker, so detection uses
# conservative thresholds for the supplied OMR-001 sheet.
BUBBLE_INNER_RADIUS = 10
FILLED_DARKNESS_THRESHOLD = 150.0
MIN_SCORE_GAP = 40.0
