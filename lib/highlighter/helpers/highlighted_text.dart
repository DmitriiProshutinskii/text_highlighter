import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';
import 'package:vector_math/vector_math.dart';

class HighlightedTextPainterTable extends CustomPainter {
  final List<OffsetPair> boxes;
  final Color highlightColor;
  const HighlightedTextPainterTable({
    required this.boxes,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = allPointsToConnect(boxes);
    final cutedEgestOfPoints = cutEgestOfPoints(points, false);
    final Path path = Path();
    path.moveTo(cutedEgestOfPoints.first.$1.dx, cutedEgestOfPoints.first.$1.dy);

    void drawArc(int index) {
      final nextIndex = index < cutedEgestOfPoints.length - 1 ? index + 1 : 0;
      path.arcToPoint(
        Offset(
          cutedEgestOfPoints[nextIndex].$1.dx,
          cutedEgestOfPoints[nextIndex].$1.dy,
        ),
        radius: Radius.circular(6),
        clockwise: cutedEgestOfPoints[index].$2 != true,
      );
    }

    drawArc(0);
    for (int i = 2; i < cutedEgestOfPoints.length; i = i + 2) {
      path.lineTo(cutedEgestOfPoints[i].$1.dx, cutedEgestOfPoints[i].$1.dy);
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
List<Offset> allPointsToConnect(List<OffsetPair> boxes) {
  // 1. Build a table with all points
  // 1.1 Count unique points by X and Y
  final Set<double> uniqueX = {};
  final Set<double> uniqueY = {};
  for (var box in boxes) {
    uniqueX.add(box.first.dx);
    uniqueX.add(box.last.dx);
    uniqueY.add(box.first.dy);
    uniqueY.add(box.last.dy);
  }

  final uniqueXList = uniqueX.toList()..sort();
  final uniqueYList = uniqueY.toList()..sort();

  // 1.2 Create the table
  final List<List<Offset?>> matrix = List.generate(
    uniqueYList.length,
    (index) => List.generate(uniqueXList.length, (index) => null),
  );
  for (var box in boxes) {
    final fourPoints = [
      box.first,
      Offset(box.last.dx, box.first.dy),
      box.last,
      Offset(box.first.dx, box.last.dy),
    ];
    for (var point in fourPoints) {
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
  final indexesToRemove = <int>[];

  print('topPoints: $topPoints');
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
        indexesToRemove.add(i);
      }
    }
  }
  for (int i in indexesToRemove) {
    rightPoints.removeAt(i);
  }
  print('rightPoints: $rightPoints');
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
  for (int i = 1; i < leftPoints.length - 1; i++) {
    if (leftPoints[i].dx != leftPoints[i + 1].dx) {
      final diff = (leftPoints[i + 1].dy - leftPoints[i].dy).abs() / 2;
      leftPoints[i] = Offset(leftPoints[i].dx, leftPoints[i].dy - diff);
      leftPoints[i + 1] = Offset(
        leftPoints[i + 1].dx,
        leftPoints[i + 1].dy + diff,
      );
      if (leftPoints[i] == leftPoints[i + 1]) {
        indexesToRemove.add(i);
      }
    }
  }
  for (int i in indexesToRemove) {
    leftPoints.removeAt(i);
  }
  final result = [...topPoints, ...rightPoints, ...bottomPoints, ...leftPoints];
  final set = <Offset>{};
  final newResult = <Offset>[];
  for (var point in result) {
    if (!set.contains(point)) {
      set.add(point);
      newResult.add(point);
    }
  }

  final newResult2 = <Offset>[];
  for (int i = 0; i < newResult.length; i++) {
    int nextIndex = i < newResult.length - 1 ? i + 1 : 0;
    int prevIndex = i > 0 ? i - 1 : newResult.length - 1;
    // Line lying on the same x
    if (newResult[i].dx == newResult[nextIndex].dx &&
        newResult[i].dx == newResult[prevIndex].dx) {
      continue;
    }
    if (newResult[i].dy == newResult[nextIndex].dy &&
        newResult[i].dy == newResult[prevIndex].dy) {
      continue;
    }
    newResult2.add(newResult[i]);
  }
  return newResult2;
}

List<(Offset, bool?)> cutEgestOfPoints(
  List<Offset> points, [
  bool doNotDoIt = false,
]) {
  if (doNotDoIt) {
    return points.map((e) => (e, null)).toList();
  }
  // Point + isClocwise (if null -- this is the line, not arc)
  final result = <(Offset, bool?)>[];
  for (int i = 0; i < points.length; i++) {
    final point = Vector2(points[i].dx, points[i].dy);
    final prevPoint = i > 0
        ? Vector2(points[i - 1].dx, points[i - 1].dy)
        : Vector2(points.last.dx, points.last.dy);
    final nextPoint = i < points.length - 1
        ? Vector2(points[i + 1].dx, points[i + 1].dy)
        : Vector2(points.first.dx, points.first.dy);

    final prevVector = (prevPoint - point).normalized();
    final nextVector = (nextPoint - point).normalized();

    final radius = min(6.0, (nextPoint - point).length / 2);
    final pointCloseToNext = (nextVector * radius) + point;
    final pointCloseToPrev = (prevVector * radius) + point;

    final vectorToCurrent = point - pointCloseToPrev;
    final vectorToNext = pointCloseToNext - pointCloseToPrev;
    final crossProduct = vectorToCurrent.cross(vectorToNext);
    final isClockwise = crossProduct < 0;
    result.add((Offset(pointCloseToPrev.x, pointCloseToPrev.y), isClockwise));
    result.add((Offset(pointCloseToNext.x, pointCloseToNext.y), null));
  }
  return result;
}
