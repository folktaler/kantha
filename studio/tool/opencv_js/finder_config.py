# The OpenCV.js whitelist for the square finder (lib/finder/): only the functions it calls. Read by
# OpenCV's platforms/js/build_js.py (--config) through tool/opencv_js/build.sh. Mat itself, its views and
# MatVector come from OpenCV's own core_bindings.cpp and need no entry here.

core = {
    '': ['split', 'countNonZero', 'bitwise_and', 'bitwise_not', 'magnitude', 'addWeighted'],
    # The base of LineSegmentDetector and GraphSegmentation: they cannot be made without it.
    'Algorithm': [],
}

imgproc = {
    '': [
        'resize', 'cvtColor', 'GaussianBlur', 'Canny', 'dilate', 'getStructuringElement', 'threshold', 'adaptiveThreshold',
        'morphologyEx', 'Sobel', 'findContours', 'arcLength', 'approxPolyDP', 'contourArea',
        'isContourConvex', 'convexHull', 'fillPoly', 'calcHist', 'compareHist', 'createLineSegmentDetector',
        'getPerspectiveTransform', 'warpPerspective',
    ],
    'LineSegmentDetector': ['detect'],
}

# Felzenszwalb's graph-based segmentation, from opencv_contrib.
ximgproc = {
    # The generator reaches the function by its namespaced name, then binds it under its own name.
    '': ['ximgproc_segmentation_createGraphSegmentation', 'createGraphSegmentation'],
    'ximgproc_segmentation_GraphSegmentation': ['processImage'],
}

white_list = makeWhiteList([core, imgproc, ximgproc])
