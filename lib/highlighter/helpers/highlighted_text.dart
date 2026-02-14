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
    final contourPoints = buildContourPoints(bounds);
    final roundedContourPoints = roundContourCorners(contourPoints);
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

// Table-based method
List<Offset> buildContourPoints(List<HighlightBounds> bounds) {
  // 1. Build a table with all points
  // 1.1 Count unique points by X and Y
  final Set<double> uniqueX = {};
  final Set<double> uniqueY = {};
  for (var box in bounds) {
    uniqueX.add(box.topLeft.dx);
    uniqueX.add(box.bottomRight.dx);
    uniqueY.add(box.topLeft.dy);
    uniqueY.add(box.bottomRight.dy);
  }

  final uniqueXList = uniqueX.toList()..sort();
  final uniqueYList = uniqueY.toList()..sort();

  // 1.2 Create the table
  final List<List<Offset?>> matrix = List.generate(
    uniqueYList.length,
    (index) => List.generate(uniqueXList.length, (index) => null),
  );
  for (var box in bounds) {
    final corners = [
      box.topLeft,
      Offset(box.bottomRight.dx, box.topLeft.dy),
      box.bottomRight,
      Offset(box.topLeft.dx, box.bottomRight.dy),
    ];
    for (var point in corners) {
      final xIndex = uniqueXList.indexOf(point.dx);
      final yIndex = uniqueYList.indexOf(point.dy);
      matrix[yIndex][xIndex] = point;
    }
  }

  // 2. Collect points together
  // 2.1 Find all points where yIndex = 0 (top boundary)
  final topPoints = matrix[0].where((e) => e != null).map((e) => e!);
  // 2.2 Find all last points in each row (go top to bottom along the right edge).
  // This means we iterate by yIndex and take xIndex points near the end.
  final rightIndexesToRemove = <int>[];
  final rightPoints = matrix
      .map((e) => e.lastWhere((e) => e != null))
      .nonNulls
      .toList();
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

  // 2.3 Find all points where yIndex = maxY (bottom boundary)
  final bottomPoints = matrix[matrix.length - 1]
      .where((e) => e != null)
      .map((e) => e!)
      .toList()
      .reversed;
  // 2.4 Find all first points in each row (go bottom to top along the left edge).
  // This means we iterate by yIndex and take xIndex points near the beginning.
  final leftPoints = matrix.reversed
      .map((e) => e.firstWhere((e) => e != null))
      .nonNulls
      .toList();
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
  final uniquePoints = <Offset>{};
  final mergedPathPoints = <Offset>[];
  for (var point in perimeterPoints) {
    if (!uniquePoints.contains(point)) {
      uniquePoints.add(point);
      mergedPathPoints.add(point);
    }
  }

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

List<(Offset, bool?)> roundContourCorners(List<Offset> contourPoints) {
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

    final vectorToCurrent = point - pointCloseToPrev;
    final vectorToNext = pointCloseToNext - pointCloseToPrev;
    final crossProduct = vectorToCurrent.cross(vectorToNext);
    final isClockwise = crossProduct < 0;
    roundedPoints.add((Offset(pointCloseToPrev.x, pointCloseToPrev.y), isClockwise));
    roundedPoints.add((Offset(pointCloseToNext.x, pointCloseToNext.y), null));
  }
  return roundedPoints;
}
