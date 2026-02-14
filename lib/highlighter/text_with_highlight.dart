import 'package:flutter/material.dart';
import 'package:flutter_highlighter/highlighter/helpers/highlighted_text.dart';
import 'package:flutter_highlighter/highlighter/shared/get_position_per_line.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';

class HighlightedSegmentsText extends StatefulWidget {
  final List<String> textSegments;
  final List<int> highlightedSegmentIndexes;
  final TextStyle textStyle;
  final Color highlightColor;

  const HighlightedSegmentsText({
    super.key,
    required this.textSegments,
    required this.highlightedSegmentIndexes,
    required this.textStyle,
    required this.highlightColor,
  });

  @override
  State<HighlightedSegmentsText> createState() =>
      _HighlightedSegmentsTextState();
}

class _HighlightedSegmentsTextState extends State<HighlightedSegmentsText> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (var bounds in _buildHighlightBounds(
              maxWidth: constraints.maxWidth,
            ))
              CustomPaint(
                painter: HighlightContourPainter(
                  bounds: bounds,
                  highlightColor: widget.highlightColor,
                ),
              ),
            IgnorePointer(
              ignoring: true,
              child: RichText(
                text: TextSpan(
                  children: widget.textSegments
                      .map(
                        (segment) =>
                            TextSpan(text: segment, style: widget.textStyle),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Get boxes for each indexed text that the user wants to highlight
  List<List<HighlightBounds>> _buildHighlightBounds({
    required double maxWidth,
  }) {
    final highlightBoundsGroups = widget.highlightedSegmentIndexes.map(
      (segmentIndex) => calculateHighlightBoundsPerLine(
        widget.textSegments,
        segmentIndex,
        widget.textStyle,
        maxWidth,
      ),
    );

    // Fix boxes where the first point is after the last point by 10px
    final normalizedBoundsGroups = <List<HighlightBounds>>[];
    for (var boundsGroup in highlightBoundsGroups) {
      if (boundsGroup.length > 1 &&
          boundsGroup[0].topLeft.dx > (boundsGroup[1].bottomRight.dx - 10)) {
        normalizedBoundsGroups.add([boundsGroup[0]]);
        boundsGroup.removeAt(0);
        normalizedBoundsGroups.add(boundsGroup);
      } else {
        normalizedBoundsGroups.add(boundsGroup);
      }
    }
    return normalizedBoundsGroups;
  }
}
