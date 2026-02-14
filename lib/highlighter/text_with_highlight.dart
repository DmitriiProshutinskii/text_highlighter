import 'package:flutter/material.dart';
import 'package:flutter_highlighter/highlighter/helpers/highlighted_text.dart';
import 'package:flutter_highlighter/highlighter/shared/get_position_per_line.dart';

class TextHighlighted extends StatefulWidget {
  final List<String> texts;
  final List<int> indexes;
  final TextStyle style;
  final TextStyle highlightedStyle;
  final Color highlightColor;
  const TextHighlighted({
    super.key,
    required this.texts,
    required this.indexes,
    required this.style,
    required this.highlightedStyle,
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
          (index) => getPositionsPerLine(
            widget.texts,
            index,
            widget.style,
            widget.highlightedStyle,
            maxWidth,
          ),
        );

        return Stack(
          children: [
            for (var box in boxes)
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
