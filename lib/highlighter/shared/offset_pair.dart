import 'dart:ui';

class HighlightBounds {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const HighlightBounds(
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  );

  factory HighlightBounds.fromTextBox(TextBox textBox) {
    return HighlightBounds(
      Offset(textBox.left, textBox.top),
      Offset(textBox.right, textBox.top),
      Offset(textBox.right, textBox.bottom),
      Offset(textBox.left, textBox.bottom),
    );
  }

  List<Offset> get clockwisePoints => [
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ];

  double get width => bottomRight.dx - topLeft.dx;
  double get height => bottomRight.dy - topLeft.dy;

  double get startX => topLeft.dx;
  double get endX => bottomRight.dx;
}
