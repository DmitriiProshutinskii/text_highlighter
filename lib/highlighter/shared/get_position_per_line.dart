import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';

List<OffsetPair> getPositionsPerLine(
  List<String> texts,
  int index,
  TextStyle style,
  TextStyle highlightedStyle,
  double maxWidth, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  assert(index >= 0 && index < texts.length);

  // 1. Собираем полный текст без разделителей
  final fullText = texts
      .mapIndexed(
        (i, element) => TextSpan(
          text: element,
          style: i == index ? highlightedStyle : style,
          semanticsIdentifier: 'selected_text_$index',
        ),
      )
      .toList();

  // 2. Создаём TextPainter
  final tp = TextPainter(
    text: TextSpan(children: fullText),
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);

  final full = texts.join('');
  final lines = tp.computeLineMetrics();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Индекс первого символа в строке
    final startOffset = tp.getPositionForOffset(
      Offset(0, line.baseline - line.ascent),
    );
    final startIndex = startOffset.offset;

    // Индекс конца строки
    final endOffset = tp.getPositionForOffset(
      Offset(tp.width, line.baseline - line.ascent),
    );
    final endIndex = endOffset.offset;

    print('Строка $i: start=$startIndex, end=$endIndex');
    print('Текст: "${full.substring(startIndex, endIndex)}"');
  }

  // 3. Индексы начала и конца нужной фразы
  int start = 0;
  for (int i = 0; i < index; i++) {
    start += texts[i].length;
  }
  final int end = start + texts[index].length;

  // 4. Получаем прямоугольники (по строкам) для фразы
  final boxes = tp.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  );

  // 5. Преобразуем каждый TextBox в OffsetPair
  if (boxes.isNotEmpty) {
    return boxes.map((b) {
      return OffsetPair(Offset(b.left, b.top), Offset(b.right, b.bottom));
    }).toList();
  }

  // 6. fallback (если боксы пусты)
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
