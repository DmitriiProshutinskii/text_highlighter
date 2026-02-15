import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';

List<HighlightBounds> calculateHighlightBoundsPerLine(
  List<String> textSegments,
  int segmentIndex,
  TextStyle textStyle,
  double maxWidth, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  assert(segmentIndex >= 0 && segmentIndex < textSegments.length);

  // 1. Build the full text without separators
  final inlineSpans = textSegments
      .mapIndexed(
        (currentIndex, segmentText) => TextSpan(
          text: segmentText,
          style: textStyle,
          semanticsIdentifier: 'highlight_segment_$currentIndex',
        ),
      )
      .toList();

  // 2. Create a TextPainter
  final textPainter = TextPainter(
    text: TextSpan(children: inlineSpans),
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);

  // 3. Start and end indexes of the target segment
  int selectionStart = 0;
  for (int i = 0; i < segmentIndex; i++) {
    selectionStart += textSegments[i].length;
  }
  final int selectionEnd = selectionStart + textSegments[segmentIndex].length;

  // 4. Get segment rectangles split by lines
  final selectionBoxes = textPainter.getBoxesForSelection(
    TextSelection(baseOffset: selectionStart, extentOffset: selectionEnd),
  );

  // 5. Convert each TextBox into HighlightBounds
  if (selectionBoxes.isNotEmpty) {
    return selectionBoxes.map(HighlightBounds.fromTextBox).toList();
  }

  // 6. Fallback when selection boxes are empty
  final caretPrototype = Rect.fromLTWH(
    0,
    0,
    0,
    textPainter.preferredLineHeight,
  );
  final Offset selectionStartCaret = textPainter.getOffsetForCaret(
    TextPosition(offset: selectionStart),
    caretPrototype,
  );
  final Offset selectionEndCaret = textPainter.getOffsetForCaret(
    TextPosition(offset: selectionEnd),
    caretPrototype,
  );

  final topLeft = Offset(selectionStartCaret.dx, selectionStartCaret.dy);
  final topRight = Offset(
    selectionEndCaret.dx,
    selectionEndCaret.dy + textPainter.preferredLineHeight,
  );
  final bottomRight = Offset(
    selectionEndCaret.dx,
    selectionEndCaret.dy + textPainter.preferredLineHeight,
  );
  final bottomLeft = Offset(selectionStartCaret.dx, selectionStartCaret.dy);
  return [HighlightBounds(topLeft, topRight, bottomRight, bottomLeft)];
}
