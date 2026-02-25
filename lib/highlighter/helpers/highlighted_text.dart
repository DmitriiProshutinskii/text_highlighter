import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';
import 'package:vector_math/vector_math.dart';

class HighlightContourPainter extends CustomPainter {
  final List<HighlightBounds> bounds;
  final Color highlightColor;

  const HighlightContourPainter({
    required this.bounds,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final contourPoints = _buildContourPoints(bounds);
    final roundedContourPoints = _roundContourCorners(contourPoints);
    final Path path = Path();
    path.moveTo(
      roundedContourPoints.first.$1.dx,
      roundedContourPoints.first.$1.dy,
    );
    void drawArc(int index) {
      final nextIndex = index < roundedContourPoints.length - 1 ? index + 1 : 0;
      path.arcToPoint(
        Offset(
          roundedContourPoints[nextIndex].$1.dx,
          roundedContourPoints[nextIndex].$1.dy,
        ),
        radius: const Radius.circular(6),
        clockwise: roundedContourPoints[index].$2 != true,
      );
    }

    drawArc(0);
    for (int i = 2; i < roundedContourPoints.length; i = i + 2) {
      path.lineTo(roundedContourPoints[i].$1.dx, roundedContourPoints[i].$1.dy);
      drawArc(i);
    }

    path.close();
    canvas.drawPath(path, Paint()..color = highlightColor);
    return;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

// Clockwise perimeter traversal
List<Offset> _buildContourPoints(List<HighlightBounds> bounds) {
  // 1. Build a list with all points
  // The main idea here is -- top and bottom points are the first and last bounds,
  // right and left points are the points on the right and left sides of the bounds.
  //
  // So if we want to take upper border we need to take a) first bound (it sorted) and b) topLeft and topRight points of the first bound.
  // Same for bottom border -- last bound and bottomLeft and bottomRight points of the last bound.
  //
  // For right we will take points with "right" suffix : topRight and bottomRight points
  // Also we keep clockwise order for right and left points. Its critical for the algorithm to work correctly.
  final List<Offset> topPoints = [bounds.first.topLeft, bounds.first.topRight];

  final List<Offset> rightPoints = [];
  for (int i = 0; i < bounds.length; i++) {
    rightPoints.add(bounds[i].topRight);
    rightPoints.add(bounds[i].bottomRight);
  }
  final List<Offset> bottomPoints = [
    bounds.last.bottomLeft,
    bounds.last.bottomRight,
  ];
  final List<Offset> leftPoints = [];
  for (int i = bounds.length - 1; i >= 0; i--) {
    leftPoints.add(bounds[i].bottomLeft);
    leftPoints.add(bounds[i].topLeft);
  }

  // 2. Glue points together if they are on the same x axis.
  // It means that we don't want to have space between highlighted text blocks.
  final rightIndexesToRemove = <int>[];
  for (int i = 1; i < rightPoints.length - 1; i++) {
    if (rightPoints[i].dx != rightPoints[i + 1].dx) {
      final diff = (rightPoints[i + 1].dy - rightPoints[i].dy).abs() / 2;
      rightPoints[i] = Offset(rightPoints[i].dx, rightPoints[i].dy + diff);
      rightPoints[i + 1] = Offset(
        rightPoints[i + 1].dx,
        rightPoints[i + 1].dy - diff,
      );
      if (rightPoints[i] == rightPoints[i + 1]) {
        rightIndexesToRemove.add(i);
      }
    }
  }
  for (int i in rightIndexesToRemove.reversed) {
    rightPoints.removeAt(i);
  }

  final leftIndexesToRemove = <int>[];
  for (int i = 1; i < leftPoints.length - 1; i++) {
    if (leftPoints[i].dx != leftPoints[i + 1].dx) {
      final diff = (leftPoints[i + 1].dy - leftPoints[i].dy).abs() / 2;
      leftPoints[i] = Offset(leftPoints[i].dx, leftPoints[i].dy - diff);
      leftPoints[i + 1] = Offset(
        leftPoints[i + 1].dx,
        leftPoints[i + 1].dy + diff,
      );
      if (leftPoints[i] == leftPoints[i + 1]) {
        leftIndexesToRemove.add(i);
      }
    }
  }
  for (int i in leftIndexesToRemove.reversed) {
    leftPoints.removeAt(i);
  }
  final perimeterPoints = [
    ...topPoints,
    ...rightPoints,
    ...bottomPoints,
    ...leftPoints,
  ];

  // 3. Filter out duplicate points
  final mergedPathPoints = <Offset>[];
  for (var point in perimeterPoints) {
    if (!mergedPathPoints.contains(point)) {
      mergedPathPoints.add(point);
    }
  }

  // Filter out points that are on the same x or y axis
  final simplifiedPathPoints = <Offset>[];
  for (int i = 0; i < mergedPathPoints.length; i++) {
    int nextIndex = i < mergedPathPoints.length - 1 ? i + 1 : 0;
    int prevIndex = i > 0 ? i - 1 : mergedPathPoints.length - 1;
    // Line lying on the same x
    if (mergedPathPoints[i].dx == mergedPathPoints[nextIndex].dx &&
        mergedPathPoints[i].dx == mergedPathPoints[prevIndex].dx) {
      continue;
    }
    if (mergedPathPoints[i].dy == mergedPathPoints[nextIndex].dy &&
        mergedPathPoints[i].dy == mergedPathPoints[prevIndex].dy) {
      continue;
    }
    simplifiedPathPoints.add(mergedPathPoints[i]);
  }
  return simplifiedPathPoints;
}

List<(Offset, bool?)> _roundContourCorners(List<Offset> contourPoints) {
  if (contourPoints.isEmpty) {
    return [];
  }

  // Tuple fields: point + isClockwise (null means draw a straight segment).
  final roundedPoints = <(Offset, bool?)>[];
  for (int i = 0; i < contourPoints.length; i++) {
    final point = Vector2(contourPoints[i].dx, contourPoints[i].dy);
    final prevPoint = i > 0
        ? Vector2(contourPoints[i - 1].dx, contourPoints[i - 1].dy)
        : Vector2(contourPoints.last.dx, contourPoints.last.dy);
    final nextPoint = i < contourPoints.length - 1
        ? Vector2(contourPoints[i + 1].dx, contourPoints[i + 1].dy)
        : Vector2(contourPoints.first.dx, contourPoints.first.dy);

    final prevVector = (prevPoint - point).normalized();
    final nextVector = (nextPoint - point).normalized();
    final radius = min(6.0, (nextPoint - point).length / 2);
    final pointCloseToNext = (nextVector * radius) + point;
    final pointCloseToPrev = (prevVector * radius) + point;

    // Cross product to determine if the contour is clockwise or counterclockwise
    final vectorToCurrent = point - pointCloseToPrev;
    final vectorToNext = pointCloseToNext - pointCloseToPrev;
    final crossProduct = vectorToNext.cross(vectorToCurrent);

    final isClockwise = crossProduct > 0;
    roundedPoints.add((
      Offset(pointCloseToPrev.x, pointCloseToPrev.y),
      isClockwise,
    ));
    roundedPoints.add((Offset(pointCloseToNext.x, pointCloseToNext.y), null));
  }
  return roundedPoints;
}
