import 'package:flutter/material.dart';
import 'package:flutter_highlighter/highlighter/helpers/highlighted_text.dart';
import 'package:flutter_highlighter/highlighter/shared/get_position_per_line.dart';
import 'package:flutter_highlighter/highlighter/shared/offset_pair.dart';

class TextHighlighted extends StatefulWidget {
  final List<String> texts;
  final List<int> indexes;
  final TextStyle style;
  final Color highlightColor;
  const TextHighlighted({
    super.key,
    required this.texts,
    required this.indexes,
    required this.style,
    required this.highlightColor,
  });

  @override
  State<TextHighlighted> createState() => _TextHighlightedState();
}

class _TextHighlightedState extends State<TextHighlighted> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        final boxes = widget.indexes.map(
          (index) =>
              getPositionsPerLine(widget.texts, index, widget.style, maxWidth),
        );
        final boxes2 = <List<OffsetPair>>[];
        for (var box in boxes) {
          if (box.length > 1) {
            if (box[0].first.dx > (box[1].last.dx - 10)) {
              boxes2.add([box[0]]);
              box.removeAt(0);
              boxes2.add(box);
            }
          } else {
            boxes2.add(box);
          }
        }

        return Stack(
          children: [
            for (var box in boxes2)
              CustomPaint(
                painter: HighlightedTextPainterTable(
                  boxes: box,
                  highlightColor: widget.highlightColor,
                ),
              ),
            IgnorePointer(
              ignoring: true,
              child: RichText(
                text: TextSpan(
                  children: widget.texts
                      .map((e) => TextSpan(text: e, style: widget.style))
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class TextLineInfo {
  final int lineIndex;
  final int startOffset;
  final int endOffset;
  final String text;

  TextLineInfo({
    required this.lineIndex,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  @override
  String toString() => '[$lineIndex] "$text" ($startOffset–$endOffset)';
}
