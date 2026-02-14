import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';

List<OffsetPair> getPositionsPerLine(
  List<String> texts,
  int index,
  TextStyle style,
  double maxWidth, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  assert(index >= 0 && index < texts.length);

  // 1. Build the full text without separators
  final fullText = texts
      .mapIndexed(
        (i, element) => TextSpan(
          text: element,
          style: style,
          semanticsIdentifier: 'selected_text_$index',
        ),
      )
      .toList();

  // 2. Create a TextPainter
  final tp = TextPainter(
    text: TextSpan(children: fullText),
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);

  final full = texts.join('');
  final lines = tp.computeLineMetrics();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Index of the first character on the line
    final startOffset = tp.getPositionForOffset(
      Offset(0, line.baseline - line.ascent),
    );
    final startIndex = startOffset.offset;

    // Index of the end of the line
    final endOffset = tp.getPositionForOffset(
      Offset(tp.width, line.baseline - line.ascent),
    );
    final endIndex = endOffset.offset;

    print('Строка $i: start=$startIndex, end=$endIndex');
    print('Текст: "${full.substring(startIndex, endIndex)}"');
  }

  // 3. Start and end indexes of the target phrase
  int start = 0;
  for (int i = 0; i < index; i++) {
    start += texts[i].length;
  }
  final int end = start + texts[index].length;

  // 4. Get phrase rectangles split by lines
  final boxes = tp.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );

  // 5. Convert each TextBox into an OffsetPair
  if (boxes.isNotEmpty) {
    return boxes.map((b) {
      return OffsetPair(Offset(b.left, b.top), Offset(b.right, b.bottom));
    }).toList();
  }

  // 6. Fallback when boxes are empty
  final caretPrototype = Rect.fromLTWH(0, 0, 0, tp.preferredLineHeight);
  final Offset startCaret = tp.getOffsetForCaret(
    TextPosition(offset: start),
    caretPrototype,
  );
  final Offset endCaret = tp.getOffsetForCaret(
    TextPosition(offset: end),
    caretPrototype,
  );

  return [
    OffsetPair(
      Offset(startCaret.dx, startCaret.dy),
      Offset(endCaret.dx, endCaret.dy + tp.preferredLineHeight),
    ),
  ];
}
